#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
Audit graph edges that make claims about behavior or implementation, and verify each claim has evidence in the source files.

.DESCRIPTION
Why this exists:
  On 2026-06-04 the graph contained `agent:mentor [follows] behavior:01-identify-learner`
  asserting the agent identifies the learner on the first message. The agent replied
  "Hey. What are we working on?" — no name, no profile load. The edge was a CLAIM
  the agent never honored. The graph had no way to surface the trust gap.

  This tool walks every edge whose type asserts a behavioral / implementation
  relationship and looks for textual evidence in the source files. Edges WITHOUT
  evidence are reported as "unverified claims" — they may still be valid (the
  evidence might live in compiled behavior or implicit imports), but they are
  not provable from the source.

Edge types audited and what evidence we look for:

  [follows] AGENT -> BEHAVIOR
    Evidence: agent.file or its frontmatter mentions the behavior id OR label.
    Reason: agents are supposed to follow named behaviors; if the behavior id
    appears nowhere in the agent's own files, the agent has no way to know to
    follow it.

  [tests] TEST -> X
    Evidence: test.file mentions X.id OR X.label OR X.file basename.
    Reason: a test that doesn't reference its target by name probably isn't
    actually testing it.

  [implemented_by] BEHAVIOR/RULE -> CODE
    Evidence: code.file mentions the behavior id OR label OR a fragment of
    description; OR behavior.file mentions code.file path.
    Reason: implementation claims should be backed by a textual reference in
    the implementing code (function name, comment, etc.).

  [uses] AGENT/BEHAVIOR -> CLI-TOOL
    Evidence: source.file mentions the tool id OR tool.file basename OR
    full path.
    Reason: claiming to use a tool you never reference is dead documentation.

How the report is used:
  - As a number: "X of Y claims verified (Z%)" — a confidence proxy.
  - Per-edge: surface unverified claims so they can be fixed (add evidence)
    or pruned (delete the edge).
  - In confidence scoring (show-confidence.ps1): unverified edges lower a
    node's confidence tier.

.PARAMETER Quiet
Print summary only.

.PARAMETER Json
Emit the full audit as JSON for downstream tools (confidence scoring etc.).

.PARAMETER EdgeTypes
Limit to specific edge types. Default: all four covered above.

.EXAMPLE
pwsh .github/knowledge-graph/cli/audit/audit-edge-claims.ps1
pwsh .github/knowledge-graph/cli/audit/audit-edge-claims.ps1 -EdgeTypes follows,tests
pwsh .github/knowledge-graph/cli/audit/audit-edge-claims.ps1 -Json > audit.json

.OUTPUTS
Exit 0 always (advisory). Use -Json or grep the report to gate.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Quiet,

    [Parameter()]
    [switch]$Json,

    [Parameter()]
    [string[]]$EdgeTypes = @('follows', 'tests', 'implemented_by', 'uses')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot -or $LASTEXITCODE -ne 0) {
    Write-Host "Not in a git repository." -ForegroundColor Red
    exit 2
}
$repoRoot = $repoRoot.TrimEnd('/', '\')

$mergedFile = Join-Path $repoRoot ".github/knowledge-graph/output/merged-graph.json"
if (-not (Test-Path $mergedFile)) {
    Write-Host "Merged graph not found at $mergedFile" -ForegroundColor Red
    Write-Host "Run: pwsh .github/knowledge-graph/build/core/merge.ps1" -ForegroundColor Yellow
    exit 2
}

$graph = Get-Content $mergedFile -Raw | ConvertFrom-Json

# Index nodes by id for O(1) lookup.
$nodesById = @{}
foreach ($n in $graph.nodes) { $nodesById[$n.id] = $n }

# Cache file content reads so we don't re-read the same file dozens of times.
# When the path points to a directory (e.g. extension:mssa-mentor.file is
# `extensions/mssa-mentor/`), concatenate all top-level .md + package.json so
# the audit can find evidence in conventional manifest files without
# recursively reading the entire tree.
$fileContentCache = @{}
function Get-CachedContent {
    param([string]$Path)
    if (-not $Path) { return $null }
    if ($fileContentCache.ContainsKey($Path)) {
        return $fileContentCache[$Path]
    }
    $abs = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $repoRoot $Path }
    if (-not (Test-Path $abs)) {
        $fileContentCache[$Path] = $null
        return $null
    }
    try {
        if (Test-Path $abs -PathType Container) {
            # Directory source: aggregate top-level .md + package.json.
            $parts = @()
            foreach ($pattern in @('*.md', 'package.json')) {
                Get-ChildItem $abs -Filter $pattern -File -ErrorAction SilentlyContinue | ForEach-Object {
                    try { $parts += (Get-Content $_.FullName -Raw -ErrorAction Stop) } catch {}
                }
            }
            $content = $parts -join "`n"
        } else {
            $content = Get-Content $abs -Raw -ErrorAction Stop
        }
        $fileContentCache[$Path] = $content
        return $content
    } catch {
        $fileContentCache[$Path] = $null
        return $null
    }
}

# Evidence check: does $haystack contain ANY of the $needles as a substring?
function Test-Evidence {
    param(
        [string]$Haystack,
        [string[]]$Needles
    )
    if (-not $Haystack) { return $false }
    foreach ($n in $Needles) {
        if (-not $n) { continue }
        if ($Haystack.Contains($n)) { return $true }
    }
    return $false
}

# Build the candidate-needle list for a node (id, label, file basename).
function Get-NodeNeedles {
    param($Node)
    $needles = [System.Collections.Generic.List[string]]::new()
    if ($Node.id) { $needles.Add($Node.id) }
    if ($Node.PSObject.Properties.Name -contains 'label' -and $Node.label) {
        $needles.Add($Node.label)
    }
    if ($Node.PSObject.Properties.Name -contains 'file' -and $Node.file) {
        $base = Split-Path $Node.file -Leaf
        if ($base) { $needles.Add($base) }
    }
    # Strip the type prefix from id for behaviors / rules (e.g. behavior:01-identify-learner -> 01-identify-learner)
    if ($Node.id -match '^[a-z-]+:(.+)$') {
        $needles.Add($matches[1])
    }
    return $needles
}

$findings = [System.Collections.Generic.List[object]]::new()
$auditedCount = 0
$skippedTautologies = 0

# Tautology filter: a claim where the source was EXTRACTED FROM the target
# (or vice versa) is structural, not an independent assertion the source
# should textually reference. Examples:
#   - code-test:X.test.md -> code-import:X.test.md::tests::Y    (same file)
#   - core-behavior:X -> code-file:Mentor.agent.md  WHERE source.file == target.file
#   - cli-tool:X -> code-file:X.ps1                  (cli-tool node IS that file)
#
# IMPORTANT — only applies to edges where same-file means "extraction artifact":
#   * implemented_by: a [implemented_by] b where source extracted from target IS tautological.
#   * tests:          test extracts an import-node from itself — pure artifact.
#
# Does NOT apply to follows / uses. For [follows] AGENT -> BEHAVIOR where both files
# match: the agent SHOULD textually reference the behavior — same-file is expected
# AND meaningful (it's the proper place to look for the reference). This was the
# failure mode of the 2026-06-04 greeting bug — agent claimed to follow a behavior
# whose id never appeared in the agent file.
function Test-IsTautology {
    param($Source, $Target, [string]$EdgeType)
    # Only filter extraction-artifact edge types.
    if ($EdgeType -ne 'implemented_by' -and $EdgeType -ne 'tests') {
        return $false
    }
    $sf = if ($Source.PSObject.Properties.Name -contains 'file') { $Source.file } else { $null }
    $tf = if ($Target.PSObject.Properties.Name -contains 'file') { $Target.file } else { $null }
    if ($sf -and $tf -and $sf -eq $tf) { return $true }
    # Code-* target whose id embeds the source's file path (extracted children).
    if ($Target.id -match '^code-(import|section|yaml-field|test|func):([^:]+)::') {
        $embeddedFile = $matches[2]
        if ($sf -and $embeddedFile -eq $sf) { return $true }
        if ($tf -and $embeddedFile -eq $tf) { return $true }
    }
    return $false
}

foreach ($edge in $graph.edges) {
    if ($EdgeTypes -notcontains $edge.type) { continue }

    $source = $nodesById[$edge.source]
    $target = $nodesById[$edge.target]
    if (-not $source -or -not $target) { continue }  # Dangling edge — separate concern.

    if (Test-IsTautology -Source $source -Target $target -EdgeType $edge.type) {
        $skippedTautologies++
        continue
    }

    $auditedCount++

    # Determine which file to look in for evidence based on edge type.
    $searchFiles = [System.Collections.Generic.List[string]]::new()
    $needles = @()

    switch ($edge.type) {
        'follows' {
            # Agent claims to follow behavior. Look in source (agent) file for target needles.
            if ($source.PSObject.Properties.Name -contains 'file' -and $source.file) {
                $searchFiles.Add($source.file)
            }
            $needles = Get-NodeNeedles $target
        }
        'tests' {
            # Test claims to test target. Look in source (test) file for target needles.
            if ($source.PSObject.Properties.Name -contains 'file' -and $source.file) {
                $searchFiles.Add($source.file)
            }
            $needles = Get-NodeNeedles $target
        }
        'implemented_by' {
            # Behavior claims to be implemented by code. Look in target (code) file for source needles.
            if ($target.PSObject.Properties.Name -contains 'file' -and $target.file) {
                $searchFiles.Add($target.file)
            }
            $needles = Get-NodeNeedles $source
        }
        'uses' {
            # Agent claims to use tool. Look in source (agent) file for target needles.
            if ($source.PSObject.Properties.Name -contains 'file' -and $source.file) {
                $searchFiles.Add($source.file)
            }
            $needles = Get-NodeNeedles $target
        }
    }

    # Collect haystack from all search files.
    $haystack = ''
    foreach ($sf in $searchFiles) {
        $c = Get-CachedContent $sf
        if ($c) { $haystack += "`n$c" }
    }

    $hasEvidence = Test-Evidence -Haystack $haystack -Needles $needles

    if (-not $hasEvidence) {
        $findings.Add([pscustomobject]@{
            EdgeType    = $edge.type
            Source      = $edge.source
            Target      = $edge.target
            SourceFile  = if ($source.PSObject.Properties.Name -contains 'file') { $source.file } else { $null }
            TargetFile  = if ($target.PSObject.Properties.Name -contains 'file') { $target.file } else { $null }
            SearchedIn  = ($searchFiles -join '; ')
            LookedFor   = ($needles -join ' OR ')
        })
    }
}

# Report.
if ($Json) {
    [pscustomobject]@{
        audited_count   = $auditedCount
        verified_count  = $auditedCount - $findings.Count
        unverified_count = $findings.Count
        skipped_tautologies = $skippedTautologies
        verification_rate = if ($auditedCount -gt 0) { [math]::Round(100.0 * ($auditedCount - $findings.Count) / $auditedCount, 1) } else { 0 }
        edge_types      = $EdgeTypes
        unverified      = $findings | ForEach-Object {
            @{
                edge_type    = $_.EdgeType
                source       = $_.Source
                target       = $_.Target
                source_file  = $_.SourceFile
                target_file  = $_.TargetFile
                searched_in  = $_.SearchedIn
                looked_for   = $_.LookedFor
            }
        }
    } | ConvertTo-Json -Depth 10
    exit 0
}

$verifiedCount = $auditedCount - $findings.Count
$rate = if ($auditedCount -gt 0) { [math]::Round(100.0 * $verifiedCount / $auditedCount, 1) } else { 0 }

if ($Quiet) {
    Write-Host "Edge-claim audit: $verifiedCount / $auditedCount verified ($rate%), $($findings.Count) unverified, $skippedTautologies tautologies skipped"
    exit 0
}

Write-Host ""
Write-Host "=== Edge-Claim Audit ===" -ForegroundColor Cyan
Write-Host "Edge types audited: $($EdgeTypes -join ', ')"
Write-Host "Total edges audited: $auditedCount"
Write-Host "Tautologies skipped: $skippedTautologies (extractor artifacts; source.file == target.file or target embeds source.file)"
Write-Host "Verified (evidence found): $verifiedCount ($rate%)"
Write-Host "Unverified (no evidence in source): $($findings.Count)"
Write-Host ""

if ($findings.Count -eq 0) {
    Write-Host "All audited edges have textual evidence in their source files." -ForegroundColor Green
    exit 0
}

# Group and print findings.
$byType = $findings | Group-Object EdgeType | Sort-Object Count -Descending
foreach ($group in $byType) {
    Write-Host "[$($group.Name)] $($group.Count) unverified" -ForegroundColor Yellow
    foreach ($f in $group.Group | Select-Object -First 10) {
        Write-Host "  $($f.Source) -> $($f.Target)" -ForegroundColor White
        Write-Host "    searched: $($f.SearchedIn)" -ForegroundColor DarkGray
        Write-Host "    for     : $($f.LookedFor)" -ForegroundColor DarkGray
    }
    if ($group.Count -gt 10) {
        Write-Host "  ... and $($group.Count - 10) more (run with -Json for full list)" -ForegroundColor DarkGray
    }
    Write-Host ""
}

Write-Host "How to fix an unverified edge:" -ForegroundColor Cyan
Write-Host "  1. Add evidence: reference the target id or label in the source file's text."
Write-Host "  2. Prune: delete the edge if it never reflected reality."
Write-Host "  3. Restructure: if the edge is semantically right but the evidence lives elsewhere,"
Write-Host "     either move the evidence into the source file or change the edge direction."
Write-Host ""
Write-Host "This audit is advisory. It does NOT block commits. Trust requires you to act on it." -ForegroundColor DarkGray
Write-Host ""
exit 0
