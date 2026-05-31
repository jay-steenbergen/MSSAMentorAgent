#!/usr/bin/env pwsh
<#
.SYNOPSIS
    One-shot mutation: adds 5 track: nodes + 45 skill: nodes + 50 edges + 1 cluster
    to system/mentor-graph.json, then re-runs the pipeline and reports.

    Read-only against the repo for discovery. Writes only to mentor-graph.json.
    Idempotent: skips nodes/edges/clusters that already exist (by id).
#>
[CmdletBinding()]
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$graphPath = Join-Path $root '.github/knowledge-graph/system/mentor-graph.json'
$tracksDir = Join-Path $root '.github/skills/tracks'

# Discover tracks + skills from the file system (source of truth)
$tracks = Get-ChildItem $tracksDir -Directory | Sort-Object Name
$plan = @()
foreach ($t in $tracks) {
    $trackId = "track:$($t.Name)"
    $readme  = ".github/skills/tracks/$($t.Name)/README.md"
    $trackLabel = $t.Name
    $plan += [pscustomobject]@{
        Kind = 'track'; Id = $trackId; Label = $trackLabel; File = $readme; Parent = $null
    }
    foreach ($s in Get-ChildItem $t.FullName -Directory | Sort-Object Name) {
        $skillFile = ".github/skills/tracks/$($t.Name)/$($s.Name)/SKILL.md"
        $skillFullPath = Join-Path $root $skillFile
        if (-not (Test-Path $skillFullPath)) { continue }   # skip folders w/o SKILL.md
        $plan += [pscustomobject]@{
            Kind = 'skill'; Id = "skill:$($s.Name)"; Label = $s.Name; File = $skillFile; Parent = $trackId
        }
    }
}

Write-Host "Discovered $($plan.Where({$_.Kind -eq 'track'}).Count) tracks + $($plan.Where({$_.Kind -eq 'skill'}).Count) skills" -ForegroundColor Cyan

$graph = Get-Content $graphPath -Raw | ConvertFrom-Json -Depth 32

# Index existing
$existingNodeIds = @{}
foreach ($n in $graph.nodes) { $existingNodeIds[$n.id] = $true }
$existingClusterIds = @{}
foreach ($c in $graph.clusters) { $existingClusterIds[$c.id] = $true }
$existingEdgeKeys = @{}
foreach ($e in $graph.edges) { $existingEdgeKeys["$($e.source)|$($e.target)|$($e.type)"] = $true }

# Build additions
$newCluster = $null
if (-not $existingClusterIds.ContainsKey('track-curriculum')) {
    $newCluster = [pscustomobject][ordered]@{
        id          = 'track-curriculum'
        label       = 'Track Curriculum'
        description = 'MSSA track curricula and their per-project skill catalogs.'
    }
}

$newNodes = @()
$newEdges = @()
foreach ($p in $plan) {
    if ($existingNodeIds.ContainsKey($p.Id)) { continue }
    if ($p.Kind -eq 'track') {
        $newNodes += [pscustomobject][ordered]@{
            id          = $p.Id
            type        = 'track'
            label       = $p.Label
            cluster     = 'track-curriculum'
            file        = $p.File
            description = "MSSA track: $($p.Label). Curriculum + project skills under this folder."
        }
        $ek = "agent:mentor|$($p.Id)|offers"
        if (-not $existingEdgeKeys.ContainsKey($ek)) {
            $newEdges += [pscustomobject][ordered]@{ source = 'agent:mentor'; target = $p.Id; type = 'offers' }
        }
    } else {
        $newNodes += [pscustomobject][ordered]@{
            id          = $p.Id
            type        = 'skill'
            label       = $p.Label
            cluster     = 'track-curriculum'
            file        = $p.File
            description = "Project skill under $($p.Parent)."
        }
        $ek = "$($p.Parent)|$($p.Id)|contains"
        if (-not $existingEdgeKeys.ContainsKey($ek)) {
            $newEdges += [pscustomobject][ordered]@{ source = $p.Parent; target = $p.Id; type = 'contains' }
        }
    }
}

Write-Host "Will add: $($newNodes.Count) nodes, $($newEdges.Count) edges, $(if ($newCluster) {1} else {0}) cluster(s)" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "DryRun set — not writing." -ForegroundColor Yellow
    return
}

# Mutate
if ($newCluster) { $graph.clusters = @($graph.clusters) + @($newCluster) }
if ($newNodes.Count -gt 0) { $graph.nodes = @($graph.nodes) + $newNodes }
if ($newEdges.Count -gt 0) { $graph.edges = @($graph.edges) + $newEdges }

# Bump metadata.last_updated if present
if ($graph.metadata -and ($graph.metadata.PSObject.Properties.Name -contains 'last_updated')) {
    $graph.metadata.last_updated = (Get-Date -Format 'yyyy-MM-dd')
}

$graph | ConvertTo-Json -Depth 32 | Set-Content $graphPath -Encoding utf8 -NoNewline
Write-Host "Wrote $graphPath" -ForegroundColor Green
