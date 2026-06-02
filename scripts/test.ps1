#Requires -Version 7.0
<#
.SYNOPSIS
    MSSA Mentor Agent — unified test harness.

.DESCRIPTION
    Single entry point for every test suite in the repo:
      - graph       (knowledge-graph health gate)
      - profiles    (xUnit + PS validators on learner profile JSON)
      - extension   (Mocha + @vscode/test-electron for the VS Code extension)
      - behavioral  (freshness report for *.test.md specs — info only)

    Each suite is independently runnable via -Suite. Default runs all four.

.PARAMETER Suite
    One of: all, graph, profiles, extension, behavioral. Default: all.

.PARAMETER Quick
    Skip the slow extension suite (which downloads VS Code on first run).

.PARAMETER Coverage
    Include line-coverage report for the extension suite.

.PARAMETER Verbose
    Show stale spec list and individual suite output.

.EXAMPLE
    pwsh scripts/test.ps1
    pwsh scripts/test.ps1 -Suite graph
    pwsh scripts/test.ps1 -Quick -Verbose
    pwsh scripts/test.ps1 -Coverage

.OUTPUTS
    Exit code 0 when all non-INFO suites are PASS. Non-zero otherwise.
#>
[CmdletBinding()]
param(
    [ValidateSet('all', 'graph', 'profiles', 'extension', 'behavioral')]
    [string]$Suite = 'all',
    [switch]$Quick,
    [switch]$Coverage,
    [switch]$ShowDetails
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$repoRoot = Split-Path -Parent $PSScriptRoot
$suitesDir = Join-Path $PSScriptRoot 'test-suites'

# Determine which suites to run
$toRun = @()
switch ($Suite) {
    'all'   { $toRun = @('graph', 'profiles', 'extension', 'behavioral') }
    default { $toRun = @($Suite) }
}
if ($Quick) {
    $toRun = $toRun | Where-Object { $_ -ne 'extension' }
}

# ASCII-only banner so it renders cleanly on every shell
Write-Host ''
Write-Host ('=' * 60) -ForegroundColor Cyan
Write-Host '  MSSA Mentor Agent - Test Harness' -ForegroundColor Cyan
Write-Host ('=' * 60) -ForegroundColor Cyan
Write-Host ("  Suites: {0}" -f ($toRun -join ', ')) -ForegroundColor DarkGray
if ($Coverage) { Write-Host '  Coverage: enabled' -ForegroundColor DarkGray }
Write-Host ''

$results = @()
$totalStart = Get-Date

foreach ($suiteName in $toRun) {
    Write-Host ("[{0}] running..." -f $suiteName) -ForegroundColor Yellow

    $scriptPath = Join-Path $suitesDir "$suiteName.ps1"
    if (-not (Test-Path $scriptPath)) {
        Write-Host ("[{0}] FAIL - script not found: {1}" -f $suiteName, $scriptPath) -ForegroundColor Red
        $results += @{ name = $suiteName; result = 'FAIL'; detail = 'script not found'; durationMs = 0 }
        continue
    }

    try {
        $result = if ($suiteName -eq 'extension' -and $Coverage) {
            & $scriptPath -RepoRoot $repoRoot -Coverage
        } else {
            & $scriptPath -RepoRoot $repoRoot
        }
    } catch {
        $result = @{
            name = $suiteName
            result = 'FAIL'
            detail = "exception: $($_.Exception.Message)"
            durationMs = 0
        }
    }

    $results += $result

    $colorMap = @{ PASS = 'Green'; FAIL = 'Red'; INFO = 'Cyan'; WARN = 'Yellow' }
    $color = $colorMap[$result.result]
    if (-not $color) { $color = 'White' }

    Write-Host ("[{0}] {1} - {2} ({3}ms)" -f $suiteName, $result.result, $result.detail, $result.durationMs) -ForegroundColor $color

    # Show behavioral spec lists when asked
    if ($ShowDetails -and $suiteName -eq 'behavioral') {
        $staleList = if ($result.PSObject.Properties['stale']) { $result.stale } else { @() }
        $neverList = if ($result.PSObject.Properties['neverRun']) { $result.neverRun } else { @() }
        if ($staleList -and $staleList.Count -gt 0) {
            Write-Host '  Stale specs (covered code changed since last run):' -ForegroundColor Yellow
            $staleList | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
        }
        if ($neverList -and $neverList.Count -gt 0) {
            Write-Host '  Never-run specs:' -ForegroundColor DarkYellow
            $neverList | ForEach-Object { Write-Host "    - $_" -ForegroundColor DarkYellow }
        }
    }
}

# ---- Summary ----
$totalMs = [int]((Get-Date) - $totalStart).TotalMilliseconds

Write-Host ''
Write-Host ('=' * 60) -ForegroundColor Cyan
Write-Host '  Summary' -ForegroundColor Cyan
Write-Host ('=' * 60) -ForegroundColor Cyan

$nameWidth = 12
foreach ($r in $results) {
    $colorMap = @{ PASS = 'Green'; FAIL = 'Red'; INFO = 'Cyan'; WARN = 'Yellow' }
    $color = $colorMap[$r.result]
    if (-not $color) { $color = 'White' }
    Write-Host ("  {0,-$nameWidth}  {1,-6}  {2}" -f $r.name, $r.result, $r.detail) -ForegroundColor $color
}

# Exit logic: any non-INFO non-PASS = non-zero
$blockingFailures = @($results | Where-Object { $_.result -eq 'FAIL' })
$overall = if ($blockingFailures.Count -eq 0) { 'PASS' } else { 'FAIL' }
$overallColor = if ($overall -eq 'PASS') { 'Green' } else { 'Red' }

Write-Host ('-' * 60) -ForegroundColor DarkGray
Write-Host ("  OVERALL: {0}  ({1:N1}s)" -f $overall, ($totalMs / 1000)) -ForegroundColor $overallColor
Write-Host ''

if ($overall -eq 'PASS') { exit 0 } else { exit 1 }
