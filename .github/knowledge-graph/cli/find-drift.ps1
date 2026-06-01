#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
Find drift between system-layer text (behaviors, descriptions, steps) and code-file ground truth in the merged graph.

.DESCRIPTION
Scans all text fields in the system-layer graph for file path references, then checks each
against code-file nodes in the merged graph. Reports paths that don't exist on disk.

Template paths like `.profiles/profiles/mentees/{username}.json` are normalized by treating
`{...}` tokens as `[^/]+` wildcards, then matched against code-file IDs.

This is the missing primitive: the graph already has ground truth (code-file nodes), but no
tool was flagging when behavior/description text disagrees with it. Closes the loop so agents
never need to filesystem-grep to verify a documented path.

.PARAMETER PathPrefix
Optional. Filter to paths starting with this prefix (e.g. ".profiles/").
Default: scan all paths.

.PARAMETER Quiet
Only output the drift count and exit code. Suppress per-finding detail.

.EXAMPLE
pwsh .github/knowledge-graph/cli/find-drift.ps1
pwsh .github/knowledge-graph/cli/find-drift.ps1 -PathPrefix ".profiles/"

.OUTPUTS
Exit code 0 = no drift. Exit code 1 = drift found.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$PathPrefix = '',

    [Parameter()]
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

# Resolve paths
$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path (Split-Path (Split-Path $scriptDir -Parent) -Parent) -Parent
$systemFile = Join-Path $repoRoot ".github/knowledge-graph/data/MentorAgent/system/mentor-graph.json"
$mergedFile = Join-Path $repoRoot ".github/knowledge-graph/output/merged-graph.json"

foreach ($f in @($systemFile, $mergedFile)) {
    if (-not (Test-Path $f)) {
        Write-Error "Graph file not found: $f"
        exit 2
    }
}

$systemGraph = Get-Content $systemFile -Raw | ConvertFrom-Json
$mergedGraph = Get-Content $mergedFile -Raw | ConvertFrom-Json

# Index code-file nodes (ground truth)
$codeFiles = [System.Collections.Generic.HashSet[string]]::new()
foreach ($n in $mergedGraph.nodes) {
    if ($n.id -like 'code-file:*') {
        [void]$codeFiles.Add($n.id.Substring('code-file:'.Length))
    }
}

# Recursively walk an object collecting all string values, returning [pscustomobject]@{Path; Value}
function Get-StringFields {
    param(
        [Parameter(Mandatory)]$Object,
        [string]$BasePath = ''
    )
    if ($null -eq $Object) { return }
    if ($Object -is [string]) {
        [pscustomobject]@{ Path = $BasePath; Value = $Object }
        return
    }
    if ($Object -is [System.Collections.IList]) {
        for ($i = 0; $i -lt $Object.Count; $i++) {
            Get-StringFields -Object $Object[$i] -BasePath "$BasePath[$i]"
        }
        return
    }
    if ($Object -is [pscustomobject] -or $Object -is [hashtable]) {
        $props = if ($Object -is [hashtable]) { $Object.Keys } else { $Object.PSObject.Properties.Name }
        foreach ($p in $props) {
            $val = if ($Object -is [hashtable]) { $Object[$p] } else { $Object.$p }
            Get-StringFields -Object $val -BasePath "$BasePath.$p"
        }
    }
}

# Extract path-like tokens. Matches `.foo/...` or `path/to/file.ext`, including {placeholders}.
# Stops at whitespace, quote, backtick, paren, comma, end-of-line.
$pathRegex = [regex]'(?<![A-Za-z0-9_])(\.?[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.{}-]+)+)'

$findings = [System.Collections.Generic.List[object]]::new()

foreach ($node in $systemGraph.nodes) {
    $nodeId = $node.id
    foreach ($field in Get-StringFields -Object $node) {
        $text = $field.Value
        if (-not $text) { continue }
        # Skip display-only fields. `.label` is a short human name, not a reference.
        # `.file` and `.id` are path anchors, not prose containing references.
        if ($field.Path -eq '.label' -or $field.Path -eq '.file' -or $field.Path -eq '.id') { continue }
        $matches = $pathRegex.Matches($text)
        foreach ($m in $matches) {
            $candidate = $m.Value.TrimEnd('.', ',', ')', ']')
            # Filter: must have a / and look like a repo-relative or dot-prefixed path
            if ($candidate -notmatch '/') { continue }
            # Skip URLs and namespaces
            if ($candidate -match '^https?:' -or $candidate -match '^@') { continue }
            # Skip non-file references (e.g. "skill:foo", "agent:mentor")
            if ($candidate -match '^[a-z-]+:[^/]') { continue }
            # Must look file-like: either a dot-anchored repo path (.github/, .profiles/, .copilot/)
            # OR end with a recognized file extension. Rejects prose like "Given/When/Then",
            # "Army/Navy/AF", "method/track" — they have slashes but aren't paths.
            $looksLikePath = ($candidate -match '^\.[A-Za-z]') -or
                             ($candidate -match '\.(md|ps1|psm1|json|ts|tsx|cs|yaml|yml|toml|txt|html|css|js)$')
            if (-not $looksLikePath) { continue }
            # PathPrefix filter
            if ($PathPrefix -and -not $candidate.StartsWith($PathPrefix)) { continue }

            # Resolve template tokens {anything} → [^/]+ for matching.
            # Note: [regex]::Escape escapes `{` to `\{` but leaves `}` alone, so the
            # replace pattern matches `\{...}` (escaped open brace, raw close brace).
            $hasTemplate = $candidate -match '\{[^}]+\}'
            $pattern = '^' + [regex]::Escape($candidate) + '$'
            $pattern = $pattern -replace '\\\{[^}]+\}', '[^/]+'

            $hit = $false
            foreach ($cf in $codeFiles) {
                if ($cf -match $pattern) { $hit = $true; break }
            }

            if (-not $hit) {
                $findings.Add([pscustomobject]@{
                    NodeId      = $nodeId
                    FieldPath   = $field.Path
                    Path        = $candidate
                    HasTemplate = $hasTemplate
                })
            }
        }
    }
}

# Deduplicate (same path, same node, same field)
$unique = $findings | Sort-Object NodeId, FieldPath, Path -Unique

if ($Quiet) {
    Write-Host "Drift findings: $($unique.Count)"
    if ($unique.Count -gt 0) { exit 1 } else { exit 0 }
}

Write-Host "`n=== Graph Drift Report ===" -ForegroundColor Cyan
Write-Host "System graph: $systemFile"
Write-Host "Ground truth: code-file nodes in merged graph ($($codeFiles.Count) files)"
if ($PathPrefix) { Write-Host "Filter: paths starting with '$PathPrefix'" }
Write-Host ""

if ($unique.Count -eq 0) {
    Write-Host "✓ No drift found. All documented paths resolve to code-file nodes." -ForegroundColor Green
    exit 0
}

Write-Host "Found $($unique.Count) drifted path reference(s):" -ForegroundColor Yellow
Write-Host ""

foreach ($group in $unique | Group-Object NodeId) {
    Write-Host "● $($group.Name)" -ForegroundColor Yellow
    foreach ($f in $group.Group) {
        $marker = if ($f.HasTemplate) { '[template]' } else { '[literal] ' }
        Write-Host "    $marker $($f.Path)" -ForegroundColor White
        Write-Host "               at $($f.FieldPath)" -ForegroundColor DarkGray
    }
    Write-Host ""
}

Write-Host "How to fix:" -ForegroundColor Cyan
Write-Host "  1. Update the system-layer text to match a real code-file path, OR"
Write-Host "  2. Create the missing file so the documented path becomes real."
Write-Host ""

exit 1
