#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Demo the knowledge graph query module capabilities.
#>

$ErrorActionPreference = 'Stop'
Import-Module (Resolve-Path '.github/knowledge-graph/lib/query.psm1')

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Knowledge Graph Query Demo" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Dynamic skill loading for different intents
Write-Host "[1] Dynamic Skill Loading" -ForegroundColor Yellow
Write-Host ""

$scenarios = @(
    @{ Intent = "build a REST API"; Method = "TDD"; Track = "cloud-app-dev" }
    @{ Intent = "learn testing"; Method = "TDD"; Track = $null }
    @{ Intent = "deploy to Azure"; Method = "ride-along"; Track = "cloud-app-dev" }
    @{ Intent = "manage learner profile"; Method = "ride-along"; Track = $null }
)

foreach ($s in $scenarios) {
    $trackStr = if ($s.Track) { " (Track: $($s.Track))" } else { "" }
    Write-Host "  Intent: '$($s.Intent)' | Method: $($s.Method)$trackStr" -ForegroundColor White
    $files = Get-AgentLoadList -Intent $s.Intent -Method $s.Method -Track $s.Track
    foreach ($f in $files) {
        Write-Host "    → $f" -ForegroundColor DarkGray
    }
    Write-Host ""
}

# Test 2: Find skills for a track
Write-Host "[2] Track Skills Discovery" -ForegroundColor Yellow
Write-Host ""

$tracks = @('cloud-app-dev', 'cybersecurity-ops', 'github-copilot')
foreach ($track in $tracks) {
    Write-Host "  $track skills:" -ForegroundColor White
    $skills = Get-TrackSkills -Track $track
    Write-Host "    Found $($skills.Count) skills" -ForegroundColor Green
    $skills | Select-Object -First 3 | ForEach-Object {
        Write-Host "    → $($_.label)" -ForegroundColor DarkGray
    }
    if ($skills.Count -gt 3) {
        Write-Host "    ... and $($skills.Count - 3) more" -ForegroundColor DarkGray
    }
    Write-Host ""
}

# Test 3: Keyword-based skill search
Write-Host "[3] Keyword-Based Search" -ForegroundColor Yellow
Write-Host ""

$queries = @("profile", "deploy", "test", "security")
foreach ($q in $queries) {
    Write-Host "  Query: '$q'" -ForegroundColor White
    $results = Get-RelevantSkills -Intent $q -MaxResults 3
    if ($results.Count -gt 0) {
        foreach ($r in $results) {
            Write-Host "    → $($r.label) - $($r.description)" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "    (no matches)" -ForegroundColor DarkGray
    }
    Write-Host ""
}

# Test 4: Path finding
Write-Host "[4] Path Finding" -ForegroundColor Yellow
Write-Host ""

$pathTests = @(
    @{ From = 'agent:mentor'; To = 'skill:learner-profile' }
    @{ From = 'agent:mentor'; To = 'track:cloud-app-dev' }
)

foreach ($pt in $pathTests) {
    Write-Host "  Path from $($pt.From) to $($pt.To):" -ForegroundColor White
    $path = Get-SkillPath -From $pt.From -To $pt.To
    if ($path) {
        Write-Host "    $($path -join ' → ')" -ForegroundColor Green
    } else {
        Write-Host "    (no path found)" -ForegroundColor Red
    }
    Write-Host ""
}

# Test 5: Performance
Write-Host "[5] Performance Check" -ForegroundColor Yellow
Write-Host ""

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$result = Get-AgentLoadList -Intent "build a web app" -Method "ride-along" -Track "cloud-app-dev"
$sw.Stop()
Write-Host "  Query completed in $($sw.ElapsedMilliseconds)ms" -ForegroundColor Green
Write-Host "  Returned $($result.Count) skills" -ForegroundColor Green
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Demo Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "The knowledge graph enables:" -ForegroundColor White
Write-Host "  • Dynamic skill loading based on intent" -ForegroundColor DarkGray
Write-Host "  • Track-aware skill discovery" -ForegroundColor DarkGray
Write-Host "  • Keyword-based search" -ForegroundColor DarkGray
Write-Host "  • Relationship traversal (path finding)" -ForegroundColor DarkGray
Write-Host "  • Sub-100ms query performance" -ForegroundColor DarkGray
Write-Host ""
