#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test suite for the knowledge graph — verifies query operations, relationships, and real-world use cases.

.DESCRIPTION
    Runs 10+ tests that validate the graph can be used for its intended purpose:
    - Finding nodes by type/cluster
    - Traversing edges
    - Path finding
    - Bridge verification
    - Real use cases (find skills for a track, agent dependencies, etc.)

.EXAMPLE
    .\test-graph.ps1 -Layer merged
#>
[CmdletBinding()]
param(
    [ValidateSet('code', 'system', 'merged')]
    [string]$Layer = 'merged',
    [switch]$ShowDetail
)

$ErrorActionPreference = 'Stop'
$kgRoot = (Resolve-Path "$PSScriptRoot\..").Path
$repoRoot = (Resolve-Path "$PSScriptRoot\..\..\..").Path

# Load graph (paths mirror build/core/health.ps1)
$graphPath = switch ($Layer) {
    'code'   { Join-Path $kgRoot 'data\MentorAgent\code\code-graph.json' }
    'system' { Join-Path $kgRoot 'data\MentorAgent\system\mentor-graph.json' }
    'merged' { Join-Path $kgRoot 'output\merged-graph.json' }
}
if (-not (Test-Path $graphPath)) {
    Write-Error "Graph not found: $graphPath`nHint: run build/core/merge.ps1 first if -Layer merged."
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Knowledge Graph Test Suite: $Layer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Graph: $graphPath" -ForegroundColor DarkGray
Write-Host ""

$graph = Get-Content $graphPath -Raw | ConvertFrom-Json -Depth 32

# Build indexes
$nodeById = @{}
foreach ($n in $graph.nodes) { $nodeById[$n.id] = $n }

$edgesBySource = @{}
$edgesByTarget = @{}
foreach ($e in $graph.edges) {
    if (-not $edgesBySource[$e.source]) { $edgesBySource[$e.source] = @() }
    $edgesBySource[$e.source] += $e
    if (-not $edgesByTarget[$e.target]) { $edgesByTarget[$e.target] = @() }
    $edgesByTarget[$e.target] += $e
}

# Test results
$passed = 0
$failed = 0
$tests = @()

function Test-Assert($name, $condition, $expected, $actual, $detail = $null) {
    $test = [PSCustomObject]@{
        Name      = $name
        Passed    = $condition
        Expected  = $expected
        Actual    = $actual
        Detail    = $detail
    }
    $script:tests += $test
    
    if ($condition) {
        $script:passed++
        Write-Host "  ✓ $name" -ForegroundColor Green
        if ($ShowDetail -and $detail) {
            Write-Host "    $detail" -ForegroundColor DarkGray
        }
    } else {
        $script:failed++
        Write-Host "  ✗ $name" -ForegroundColor Red
        Write-Host "    Expected: $expected" -ForegroundColor Yellow
        Write-Host "    Actual:   $actual" -ForegroundColor Yellow
        if ($detail) {
            Write-Host "    $detail" -ForegroundColor DarkGray
        }
    }
}

function Find-Path($from, $to, $maxDepth = 5) {
    $visited = @{}
    $queue = @(@{ node = $from; path = @($from) })
    
    while ($queue.Count -gt 0) {
        $current = $queue[0]
        $queue = $queue[1..($queue.Count-1)]
        
        if ($current.node -eq $to) { return $current.path }
        if ($current.path.Count -ge $maxDepth) { continue }
        if ($visited[$current.node]) { continue }
        $visited[$current.node] = $true
        
        $edges = $edgesBySource[$current.node]
        if ($edges) {
            foreach ($e in $edges) {
                $newPath = $current.path + @($e.target)
                $queue += @{ node = $e.target; path = $newPath }
            }
        }
    }
    return $null
}

# ========== TESTS ==========

Write-Host "Running tests..." -ForegroundColor Cyan
Write-Host ""

# Test 1: Find mentor agent node
Write-Host "[1] Find mentor agent node" -ForegroundColor Yellow
$mentor = $nodeById['agent:mentor']
Test-Assert "Mentor agent exists" `
    ($null -ne $mentor) `
    "agent:mentor node" `
    $(if ($mentor) { "found" } else { "missing" }) `
    $(if ($mentor) { "type=$($mentor.type), cluster=$($mentor.cluster)" } else { $null })

# Test 2: Find all tracks
Write-Host ""
Write-Host "[2] Find all track nodes" -ForegroundColor Yellow
$tracks = $graph.nodes | Where-Object { $_.type -eq 'track' }
$expectedTracks = 5
Test-Assert "All tracks present" `
    ($tracks.Count -eq $expectedTracks) `
    "$expectedTracks tracks" `
    "$($tracks.Count) tracks" `
    $($tracks.id -join ', ')

# Test 3: Find skills for cloud-app-dev track
Write-Host ""
Write-Host "[3] Find skills under cloud-app-dev track" -ForegroundColor Yellow
$cadEdges = $edgesBySource['track:cloud-app-dev'] | Where-Object { $_.type -eq 'contains' }
$cadSkills = @($cadEdges | ForEach-Object { $nodeById[$_.target] } | Where-Object { $_.type -eq 'skill' })
Test-Assert "cloud-app-dev has skills" `
    ($cadSkills.Count -ge 5) `
    "≥5 skills" `
    "$($cadSkills.Count) skills" `
    $(($cadSkills | Select-Object -First 5).label -join ', ')

# Test 4: Verify bridges exist
Write-Host ""
Write-Host "[4] Verify system→code bridges" -ForegroundColor Yellow
$bridgeEdges = $graph.edges | Where-Object { $_.label -eq 'bridge' }
Test-Assert "Bridges present" `
    ($bridgeEdges.Count -ge 200) `
    "≥200 bridges" `
    "$($bridgeEdges.Count) bridges"

# Test 5: Find path from mentor to a skill file
Write-Host ""
Write-Host "[5] Find path: mentor → skill file" -ForegroundColor Yellow
$path = Find-Path 'agent:mentor' 'skill:learner-profile'
Test-Assert "Path exists mentor→learner-profile skill" `
    ($null -ne $path) `
    "path found" `
    $(if ($path) { "$($path.Count) hops: $($path -join ' → ')" } else { "no path" })

# Test 6: Schema instances are bridged
Write-Host ""
Write-Host "[6] Verify schema instances bridged" -ForegroundColor Yellow
$schemaBridges = $bridgeEdges | Where-Object { $_.type -eq 'instance_of' }
Test-Assert "Schema instance bridges exist" `
    ($schemaBridges.Count -ge 6) `
    "≥6 instance_of bridges" `
    "$($schemaBridges.Count) instance_of bridges"

# Test 7: All tracks reachable from mentor
Write-Host ""
Write-Host "[7] All tracks reachable from mentor" -ForegroundColor Yellow
$unreachableTracks = @()
foreach ($t in $tracks) {
    $path = Find-Path 'agent:mentor' $t.id 3
    if (-not $path) { $unreachableTracks += $t.id }
}
Test-Assert "All tracks reachable from mentor" `
    ($unreachableTracks.Count -eq 0) `
    "all tracks reachable" `
    $(if ($unreachableTracks.Count -gt 0) { "unreachable: $($unreachableTracks -join ', ')" } else { "all reachable" })

# Test 8: Find learner-profile skill dependencies
Write-Host ""
Write-Host "[8] Find dependencies of learner-profile skill" -ForegroundColor Yellow
$lpInbound = @($edgesByTarget['skill:learner-profile'])
$lpOutbound = @($edgesBySource['skill:learner-profile'])
Test-Assert "learner-profile has connections" `
    (($lpInbound.Count + $lpOutbound.Count) -ge 3) `
    "≥3 edges" `
    "$($lpInbound.Count) inbound, $($lpOutbound.Count) outbound"

# Test 9: Cluster coverage
Write-Host ""
Write-Host "[9] Verify cluster coverage" -ForegroundColor Yellow
$nodesWithCluster = @($graph.nodes | Where-Object { $_.cluster })
$clusterCoverage = [math]::Round(100.0 * $nodesWithCluster.Count / $graph.nodes.Count, 1)
Test-Assert "Cluster coverage >90%" `
    ($clusterCoverage -ge 90) `
    "≥90% coverage" `
    "$clusterCoverage% coverage"

# Test 10: File nodes have valid file paths
Write-Host ""
Write-Host "[10] Validate file node paths" -ForegroundColor Yellow
$fileNodes = $graph.nodes | Where-Object { $_.type -in @('file', 'skill', 'track') -and $_.file }
$validFiles = 0
$invalidFiles = @()
foreach ($fn in $fileNodes) {
    $fullPath = Join-Path $repoRoot $fn.file
    if (Test-Path $fullPath) {
        $validFiles++
    } else {
        $invalidFiles += "$($fn.id) → $($fn.file)"
    }
}
Test-Assert "All file paths valid" `
    ($invalidFiles.Count -eq 0) `
    "all files exist" `
    "$validFiles/$($fileNodes.Count) exist" `
    $(if ($invalidFiles.Count -gt 0 -and $invalidFiles.Count -le 3) { $invalidFiles -join '; ' } elseif ($invalidFiles.Count -gt 3) { "$($invalidFiles.Count) invalid files" } else { $null })

# Test 11: Edge connectivity (no dangling)
Write-Host ""
Write-Host "[11] Edge connectivity check" -ForegroundColor Yellow
$danglingEdges = @($graph.edges | Where-Object { 
    -not $nodeById[$_.source] -or -not $nodeById[$_.target] 
})
Test-Assert "No dangling edges" `
    ($danglingEdges.Count -eq 0) `
    "0 dangling" `
    "$($danglingEdges.Count) dangling"

# Test 12: Query performance (find all skills)
Write-Host ""
Write-Host "[12] Query performance test" -ForegroundColor Yellow
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$allSkills = @($graph.nodes | Where-Object { $_.type -eq 'skill' })
$sw.Stop()
$queryMs = $sw.ElapsedMilliseconds
Test-Assert "Query completes <100ms" `
    ($queryMs -lt 100) `
    "<100ms" `
    "$($queryMs)ms to find $($allSkills.Count) skills"

# ========== SUMMARY ==========

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Test Results" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Passed:  $passed" -ForegroundColor Green
Write-Host "  Failed:  $failed" -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Green' })
Write-Host "  Total:   $($tests.Count)" -ForegroundColor Cyan
Write-Host ""

if ($failed -eq 0) {
    Write-Host "✓ All tests passed — graph is working correctly!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Some tests failed — see details above." -ForegroundColor Red
    exit 1
}
