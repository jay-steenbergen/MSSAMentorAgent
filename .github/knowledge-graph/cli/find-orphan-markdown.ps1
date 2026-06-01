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

# Build set of graph-tracked .md file paths (repo-relative, forward slashes)
$graphFiles = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($n in $systemGraph.nodes) {
    if ($n.PSObject.Properties.Match('file').Count -gt 0 -and $n.file -and $n.file -match '\.md$') {
        [void]$graphFiles.Add(($n.file -replace '\\', '/'))
    }
}

# Scan filesystem for artifact .md files
# Pattern → expected node type (kept here purely for the user-facing report)
$patterns = @(
    @{ Path = '.github/agents';  Filter = '*.agent.md'; Type = 'agent' }
    @{ Path = '.github/skills';  Filter = 'SKILL.md';   Type = 'skill / method / track' }
    @{ Path = '.github/skills';  Filter = '*.test.md';  Type = 'test' }
    @{ Path = '.github/tests';   Filter = '*.test.md';  Type = 'test' }
)

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
            })
        }
}

# Find orphans (file on disk, no graph node)
$orphans = $found | Where-Object { -not $graphFiles.Contains($_.File) } | Sort-Object File -Unique

if ($Quiet) {
    Write-Host "Orphan markdown files: $($orphans.Count)"
    if ($orphans.Count -gt 0) { exit 1 } else { exit 0 }
}

Write-Host "`n=== Orphan Markdown Report ===" -ForegroundColor Cyan
Write-Host "System graph:  $systemFile"
Write-Host "Scanned:       $($found.Count) artifact .md files in .github/agents, .github/skills, .github/tests"
Write-Host "Graph-tracked: $($graphFiles.Count) .md file references"
Write-Host ""

if ($orphans.Count -eq 0) {
    Write-Host "[OK] No orphan markdown files. Every artifact is registered in the graph." -ForegroundColor Green
    exit 0
}

Write-Host "Found $($orphans.Count) orphan markdown file(s) — on disk but missing from graph:" -ForegroundColor Yellow
Write-Host ""

foreach ($o in $orphans) {
    Write-Host "  [$($o.ExpectedType)]  $($o.File)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "How to fix (graph-first authoring):" -ForegroundColor Cyan
Write-Host "  1. Pick the right type: agent | skill | method | track | test"
Write-Host "  2. Register the node FIRST:"
Write-Host "       pwsh .github/knowledge-graph/cli/mentor.ps1 add <type> <slug> -Label '...' -Description '...'"
Write-Host "  3. Re-run the .md file's content as needed (mentor.ps1 will scaffold a stub if no file exists)"
Write-Host ""
Write-Host "Or, if the .md file should be removed: delete it and re-run this check." -ForegroundColor Gray
Write-Host ""

exit 1
