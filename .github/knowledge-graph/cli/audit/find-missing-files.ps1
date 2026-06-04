#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
Find graph nodes whose `file` field points at a path that does not exist on disk.

.DESCRIPTION
Phase 3 of the graph-driven build: this is the inverse of find-orphan-markdown.

  find-orphan-markdown : file on disk, no graph node    (graph-first authoring)
  find-missing-files   : graph node, no file on disk    (graph integrity)

When a node's `file` field rots (file renamed, moved, or deleted without updating
the graph), Get-AgentLoadList silently returns broken paths. The agent then
"loads" a non-existent skill — no error, just degraded behavior.

This check enforces that every `file` reference in the system graph resolves to
a real file in the repo.

.PARAMETER Quiet
Only output the count and exit code. Suppress per-finding detail.

.EXAMPLE
pwsh .github/knowledge-graph/cli/audit/find-missing-files.ps1
pwsh .github/knowledge-graph/cli/audit/find-missing-files.ps1 -Quiet

.OUTPUTS
Exit code 0 = all file refs resolve. Exit code 1 = one or more missing.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

# Resolve paths
$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $scriptDir -Parent) -Parent) -Parent) -Parent
$systemFile = Join-Path $repoRoot ".github/knowledge-graph/data/MentorAgent/system/mentor-graph.json"

if (-not (Test-Path $systemFile)) {
    Write-Error "System graph not found: $systemFile"
    exit 2
}

$systemGraph = Get-Content $systemFile -Raw | ConvertFrom-Json

# Collect every node that has a non-empty `file` field
$nodesWithFiles = [System.Collections.Generic.List[object]]::new()
foreach ($n in $systemGraph.nodes) {
    if ($n.PSObject.Properties.Match('file').Count -gt 0 -and $n.file) {
        $nodesWithFiles.Add($n)
    }
}

# Check each path
$missing = [System.Collections.Generic.List[object]]::new()
foreach ($n in $nodesWithFiles) {
    $relPath = $n.file -replace '\\', '/'
    $fullPath = Join-Path $repoRoot $relPath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        $missing.Add([pscustomobject]@{
            NodeId = $n.id
            Type   = $n.type
            File   = $relPath
        })
    }
}

if ($Quiet) {
    Write-Host "Missing file references: $($missing.Count)"
    if ($missing.Count -gt 0) { exit 1 } else { exit 0 }
}

Write-Host "`n=== Missing File Reference Report ===" -ForegroundColor Cyan
Write-Host "System graph:    $systemFile"
Write-Host "Nodes with file: $($nodesWithFiles.Count)"
Write-Host ""

if ($missing.Count -eq 0) {
    Write-Host "[OK] All file references resolve to real files on disk." -ForegroundColor Green
    exit 0
}

Write-Host "Found $($missing.Count) node(s) referencing missing files:" -ForegroundColor Yellow
Write-Host ""

$missing | Sort-Object NodeId | ForEach-Object {
    Write-Host ("  [{0}]  {1}" -f $_.Type, $_.NodeId) -ForegroundColor Yellow
    Write-Host ("      -> {0}" -f $_.File) -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "How to fix:" -ForegroundColor Cyan
Write-Host "  - If the file was renamed/moved: update the node's 'file' field in the system graph"
Write-Host "    (.github/knowledge-graph/data/MentorAgent/system/mentor-graph.json)"
Write-Host "  - If the artifact was removed: pwsh .github/knowledge-graph/cli/authoring/mentor.ps1 remove <id>"
Write-Host "  - If the file should exist but doesn't: create it"
Write-Host ""

exit 1
