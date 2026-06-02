#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
Find markdown artifact files (skills, agents, tests) on disk with no corresponding
node in the system-layer knowledge graph.

.DESCRIPTION
This is the "graph-first" enforcement primitive. Phase 2 of the graph-driven build:
markdown files for agent/skill/method/track/test artifacts MUST be registered in the
graph. Authoring a .md file without first running `mentor.ps1 add ...` creates drift —
the agent can't discover the artifact, the load list doesn't know about it, and the
catalog grows out of sync with the filesystem.

This script scans the filesystem for artifact-shaped .md files and checks each one
against the system graph's `file` fields. Files with no matching node are orphans.

.PARAMETER Quiet
Only output the orphan count and exit code. Suppress per-finding detail.

.EXAMPLE
pwsh .github/knowledge-graph/cli/find-orphan-markdown.ps1
pwsh .github/knowledge-graph/cli/find-orphan-markdown.ps1 -Quiet

.OUTPUTS
Exit code 0 = no orphans. Exit code 1 = orphans found.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

# Resolve paths
$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path (Split-Path (Split-Path $scriptDir -Parent) -Parent) -Parent
$systemFile = Join-Path $repoRoot ".github/knowledge-graph/data/MentorAgent/system/mentor-graph.json"

if (-not (Test-Path $systemFile)) {
    Write-Error "System graph not found: $systemFile"
    exit 2
}

$systemGraph = Get-Content $systemFile -Raw | ConvertFrom-Json

# Map: repo-relative file path (forward slashes) -> node id
$fileToNodeId = @{}
foreach ($n in $systemGraph.nodes) {
    if ($n.PSObject.Properties.Match('file').Count -gt 0 -and $n.file -and $n.file -match '\.md$') {
        $fileToNodeId[($n.file -replace '\\', '/')] = $n.id
    }
}

# Count degree (in + out) per node id
$nodeDegree = @{}
foreach ($e in $systemGraph.edges) {
    if ($e.source) {
        if (-not $nodeDegree.ContainsKey($e.source)) { $nodeDegree[$e.source] = 0 }
        $nodeDegree[$e.source]++
    }
    if ($e.target) {
        if (-not $nodeDegree.ContainsKey($e.target)) { $nodeDegree[$e.target] = 0 }
        $nodeDegree[$e.target]++
    }
}

# Scan filesystem for artifact .md files
# Pattern → expected node type (kept here purely for the user-facing report)
$patterns = @(
    @{ Path = '.github/agents';           Filter = '*.agent.md'; Type = 'agent' }
    @{ Path = '.github/skills';           Filter = 'SKILL.md';   Type = 'skill / method / track' }
    @{ Path = '.github/skills';           Filter = '*.test.md';  Type = 'test' }
    @{ Path = '.github/tests';            Filter = '*.test.md';  Type = 'test' }
    @{ Path = '.github/knowledge-graph';  Filter = '*.md';       Type = 'kg-doc' }
)

# Files exempt by basename: implicit entrypoints (landing-page docs)
$implicitEntrypoints = @('README.md', 'CONTRIBUTING.md')

$found = [System.Collections.Generic.List[object]]::new()
foreach ($p in $patterns) {
    $fullPath = Join-Path $repoRoot $p.Path
    if (-not (Test-Path $fullPath)) { continue }
    Get-ChildItem -Recurse -File -Path $fullPath -Filter $p.Filter -ErrorAction SilentlyContinue |
        ForEach-Object {
            $rel = $_.FullName.Substring($repoRoot.Length).TrimStart('\','/') -replace '\\','/'
            $found.Add([pscustomobject]@{
                File = $rel
                ExpectedType = $p.Type
                BaseName = $_.Name
            })
        }
}

# Classify each file. Two failure modes:
#   1. ORPHAN — no graph node
#   2. STALE  — node exists but has zero edges (in+out) → nothing in the system points at or from it
# Implicit entrypoints (README.md, CONTRIBUTING.md) are exempt: they're landing pages.
$orphans = [System.Collections.Generic.List[object]]::new()
$uniqueFiles = $found | Sort-Object File -Unique
foreach ($f in $uniqueFiles) {
    if ($implicitEntrypoints -contains $f.BaseName) { continue }
    $nid = $fileToNodeId[$f.File]
    if (-not $nid) {
        $orphans.Add([pscustomobject]@{
            File = $f.File
            ExpectedType = $f.ExpectedType
            Reason = 'NO-NODE'
            Detail = 'File on disk but not registered in graph'
        })
        continue
    }
    $deg = if ($nodeDegree.ContainsKey($nid)) { $nodeDegree[$nid] } else { 0 }
    if ($deg -eq 0) {
        $orphans.Add([pscustomobject]@{
            File = $f.File
            ExpectedType = $f.ExpectedType
            Reason = 'NO-EDGES'
            Detail = "Node $nid has zero edges (in + out) — disconnected from the system"
        })
    }
}

if ($Quiet) {
    Write-Host "Orphan markdown files: $($orphans.Count)"
    if ($orphans.Count -gt 0) { exit 1 } else { exit 0 }
}

Write-Host "`n=== Orphan Markdown Report ===" -ForegroundColor Cyan
Write-Host "System graph:  $systemFile"
Write-Host "Scanned:       $($uniqueFiles.Count) artifact .md files in .github/agents, .github/skills, .github/tests, .github/knowledge-graph"
Write-Host "Graph-tracked: $($fileToNodeId.Count) .md file references"
Write-Host "Exempt:        README.md, CONTRIBUTING.md (implicit entrypoints)"
Write-Host ""

if ($orphans.Count -eq 0) {
    Write-Host "[OK] Every artifact .md is either an implicit entrypoint OR has a graph node with >=1 edge." -ForegroundColor Green
    exit 0
}

$noNodeCount  = @($orphans | Where-Object { $_.Reason -eq 'NO-NODE'  }).Count
$noEdgesCount = @($orphans | Where-Object { $_.Reason -eq 'NO-EDGES' }).Count

Write-Host "Found $($orphans.Count) orphan markdown file(s):" -ForegroundColor Yellow
Write-Host "  $noNodeCount  with NO graph node (never registered)" -ForegroundColor Yellow
Write-Host "  $noEdgesCount with a node but ZERO edges (disconnected from system)" -ForegroundColor Yellow
Write-Host ""

foreach ($o in $orphans) {
    Write-Host "  [$($o.Reason)] [$($o.ExpectedType)]  $($o.File)" -ForegroundColor Yellow
    Write-Host "             $($o.Detail)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "How to fix:" -ForegroundColor Cyan
Write-Host "  NO-NODE  → register the artifact in the graph:" -ForegroundColor White
Write-Host "             pwsh .github/knowledge-graph/cli/mentor.ps1 add <type> <slug> -Label '...' -Description '...'" -ForegroundColor Gray
Write-Host "  NO-EDGES → either add an edge connecting the node to the system, OR delete the file" -ForegroundColor White
Write-Host "             (a node nothing references and that references nothing isn't earning its keep)" -ForegroundColor Gray
Write-Host ""
Write-Host "Or, if the .md file should be removed: delete it and re-run this check." -ForegroundColor Gray
Write-Host ""

exit 1
