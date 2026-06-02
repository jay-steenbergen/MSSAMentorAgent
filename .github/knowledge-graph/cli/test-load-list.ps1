#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
Golden-file tests for Get-AgentLoadList. Pins (intent, method, track) -> expected file list.

.DESCRIPTION
Phase 4 of the graph-driven build: the agent's primary entry point is
Get-AgentLoadList. Phases 2 and 3 made node.file a bidirectional contract,
but neither catches a CHANGE in what the load list returns for a given
input. Adding a new skill that happens to match an intent keyword silently
shifts the load list — no error, just different teaching.

This script loads `test-load-list.goldens.json`, calls Get-AgentLoadList
for each case, and asserts the returned file list matches `expected`
EXACTLY (order-sensitive, no extras, no missing). Any difference is a
regression unless intentional — in which case update the JSON.

.PARAMETER Quiet
Only output the failure count and exit code. Suppress per-case detail.

.PARAMETER UpdateBaseline
Overwrite the goldens JSON with the current Get-AgentLoadList output for
every case. USE ONLY when the change is intentional and reviewed.

.EXAMPLE
pwsh .github/knowledge-graph/cli/test-load-list.ps1
pwsh .github/knowledge-graph/cli/test-load-list.ps1 -Quiet
pwsh .github/knowledge-graph/cli/test-load-list.ps1 -UpdateBaseline

.OUTPUTS
Exit code 0 = all goldens pass. Exit code 1 = one or more regressions.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Quiet,

    [Parameter()]
    [switch]$UpdateBaseline
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path (Split-Path (Split-Path $scriptDir -Parent) -Parent) -Parent
$goldensFile = Join-Path $scriptDir 'test-load-list.goldens.json'
$queryModule = Join-Path $repoRoot '.github/knowledge-graph/lib/query.psm1'

if (-not (Test-Path $goldensFile)) {
    Write-Error "Goldens file not found: $goldensFile"
    exit 2
}
if (-not (Test-Path $queryModule)) {
    Write-Error "Query module not found: $queryModule"
    exit 2
}

Import-Module $queryModule -Force

$goldens = Get-Content $goldensFile -Raw | ConvertFrom-Json

# Run each case
$results = [System.Collections.Generic.List[object]]::new()
foreach ($case in $goldens.cases) {
    $params = @{
        Intent = $case.inputs.intent
        Method = $case.inputs.method
    }
    if ($case.inputs.PSObject.Properties.Match('track').Count -gt 0 -and $case.inputs.track) {
        $params.Track = $case.inputs.track
    }
    if ($case.inputs.PSObject.Properties.Match('skipEssentials').Count -gt 0 -and $case.inputs.skipEssentials) {
        $params.SkipEssentials = $true
    }

    $actual = @(Get-AgentLoadList @params)
    $expected = @($case.expected)

    # Order-sensitive exact match
    $pass = $true
    if ($actual.Count -ne $expected.Count) {
        $pass = $false
    } else {
        for ($i = 0; $i -lt $actual.Count; $i++) {
            if ($actual[$i] -ne $expected[$i]) { $pass = $false; break }
        }
    }

    $results.Add([pscustomobject]@{
        Name     = $case.name
        Inputs   = $case.inputs
        Expected = $expected
        Actual   = $actual
        Pass     = $pass
    })
}

# Update mode: overwrite goldens with actuals
if ($UpdateBaseline) {
    Write-Host "Updating goldens with current Get-AgentLoadList output..." -ForegroundColor Yellow
    $updated = [ordered]@{
        '_doc'             = $goldens.'_doc'
        '_baseline_date'   = (Get-Date -Format 'yyyy-MM-dd')
        '_baseline_commit' = 'updated via -UpdateBaseline'
        cases              = @($results | ForEach-Object {
            [ordered]@{
                name     = $_.Name
                inputs   = $_.Inputs
                expected = $_.Actual
            }
        })
    }
    $updated | ConvertTo-Json -Depth 32 | Set-Content -Encoding utf8 -Path $goldensFile
    Write-Host "Wrote $($results.Count) cases to $goldensFile" -ForegroundColor Green
    exit 0
}

$failed = @($results | Where-Object { -not $_.Pass })

if ($Quiet) {
    Write-Host "Load list goldens: $($results.Count - $failed.Count)/$($results.Count) pass, $($failed.Count) regression(s)"
    if ($failed.Count -gt 0) { exit 1 } else { exit 0 }
}

Write-Host "`n=== Get-AgentLoadList Golden Tests ===" -ForegroundColor Cyan
Write-Host "Goldens file:  $goldensFile"
Write-Host "Cases:         $($results.Count)"
Write-Host "Passed:        $($results.Count - $failed.Count)"
Write-Host "Failed:        $($failed.Count)"
Write-Host ""

foreach ($r in $results) {
    if ($r.Pass) {
        Write-Host "  [PASS]  $($r.Name)" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL]  $($r.Name)" -ForegroundColor Red
        Write-Host "          Expected ($($r.Expected.Count)):" -ForegroundColor DarkGray
        foreach ($e in $r.Expected) { Write-Host "            $e" -ForegroundColor DarkGray }
        Write-Host "          Actual ($($r.Actual.Count)):" -ForegroundColor Yellow
        foreach ($a in $r.Actual) { Write-Host "            $a" -ForegroundColor Yellow }
        Write-Host ""
    }
}

Write-Host ""
if ($failed.Count -eq 0) {
    Write-Host "[OK] All load list goldens pass." -ForegroundColor Green
    exit 0
}

Write-Host "How to fix:" -ForegroundColor Cyan
Write-Host "  - If the change is UNINTENTIONAL: revert whatever changed the graph or query module."
Write-Host "  - If the change is INTENTIONAL (e.g., you added a skill on purpose):"
Write-Host "      1. Review each failing case above to confirm the new output is desired"
Write-Host "      2. Update goldens: pwsh .github/knowledge-graph/cli/test-load-list.ps1 -UpdateBaseline"
Write-Host "      3. Commit the updated test-load-list.goldens.json"
Write-Host ""
Write-Host "Bypass (not recommended): git commit --no-verify" -ForegroundColor DarkGray

exit 1
