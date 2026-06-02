#Requires -Version 7.0
<#
.SYNOPSIS
    Extension suite: Mocha tests via @vscode/test-electron, with optional c8 coverage.

.DESCRIPTION
    Runs `npm test` (or `npm run coverage`) inside extensions/mssa-mentor/.
    PASS when the npm script exits 0.

    Auto-installs dependencies if node_modules is missing.

.OUTPUTS
    @{ name; result; detail; durationMs }
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [switch]$Coverage
)

$ErrorActionPreference = 'Continue'
$start = Get-Date

$extDir = Join-Path $RepoRoot 'extensions/mssa-mentor'
if (-not (Test-Path $extDir)) {
    return @{
        name = 'extension'
        result = 'FAIL'
        detail = "extension directory not found: $extDir"
        durationMs = 0
    }
}

Push-Location $extDir
try {
    # Auto-install if needed (slow first run, fast after)
    if (-not (Test-Path 'node_modules')) {
        Write-Host "  [extension] installing dependencies..." -ForegroundColor DarkGray
        & npm install --no-audit --no-fund *>$null
        if ($LASTEXITCODE -ne 0) {
            return @{
                name = 'extension'
                result = 'FAIL'
                detail = "npm install failed (exit $LASTEXITCODE)"
                durationMs = [int]((Get-Date) - $start).TotalMilliseconds
            }
        }
    }

    $script = if ($Coverage) { 'coverage' } else { 'test' }
    $output = & npm run $script 2>&1 | Out-String
    $exit = $LASTEXITCODE

    # Parse Mocha summary: "37 passing (338ms)" / "3 failing"
    $passing = 0; $failing = 0
    if ($output -match '(\d+)\s+passing') { $passing = [int]$Matches[1] }
    if ($output -match '(\d+)\s+failing') { $failing = [int]$Matches[1] }

    # Optional coverage % from c8 text reporter: "All files |   52.10 |"
    $coveragePct = $null
    if ($Coverage) {
        $covMatch = [regex]::Match($output, 'All files\s*\|\s*([\d.]+)')
        if ($covMatch.Success) { $coveragePct = [double]$covMatch.Groups[1].Value }
    }

    $result = if ($exit -eq 0 -and $failing -eq 0) { 'PASS' } else { 'FAIL' }
    $detail = "$passing pass, $failing fail"
    if ($null -ne $coveragePct) {
        $detail += ", $([math]::Round($coveragePct, 1))% line coverage"
    }

    return @{
        name = 'extension'
        result = $result
        detail = $detail
        durationMs = [int]((Get-Date) - $start).TotalMilliseconds
    }
} finally {
    Pop-Location
}
