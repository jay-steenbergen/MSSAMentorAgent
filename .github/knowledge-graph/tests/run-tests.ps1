#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
Discover and run all *.test.ps1 files under tests/ subdirectories. Aggregates results, reports pass/fail counts, exits non-zero if anything fails.

.DESCRIPTION
Discovery rules:
  - Any *.test.ps1 file under tests/unit, integration, gate, e2e (and any new bucket).
  - Files starting with `_` are ignored (e.g. `_template.test.ps1`).
  - Each test file runs in its own scope (spawned as a child pwsh process so a
    crash in one file doesn't take down the runner).

Default behavior:
  - Runs unit + integration + gate.
  - Skips e2e (slow, opt in with -IncludeE2E).

Filtering:
  -Filter unit            run only the unit bucket
  -Filter unit,gate       run unit + gate
  -Tag fast               run tests tagged @tags: fast in the file header
  -Pattern "*audit*"      glob match on filename
  -IncludeE2E             include the e2e bucket (slow)

Output:
  -Quiet                  per-file pass/fail counts only
  -Json                   structured JSON to stdout
  default                 colored per-case + summary

Exit codes:
  0 = all tests passed
  1 = at least one test failed
  2 = invocation error (bad arg, no tests found)

.EXAMPLE
pwsh .github/knowledge-graph/tests/run-tests.ps1
pwsh .github/knowledge-graph/tests/run-tests.ps1 -Filter gate
pwsh .github/knowledge-graph/tests/run-tests.ps1 -Pattern "*extractor*"
pwsh .github/knowledge-graph/tests/run-tests.ps1 -IncludeE2E
pwsh .github/knowledge-graph/tests/run-tests.ps1 -Json
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string[]]$Filter = @('unit', 'integration', 'gate'),

    [Parameter()]
    [string[]]$Tag,

    [Parameter()]
    [string]$Pattern,

    [Parameter()]
    [switch]$IncludeE2E,

    [Parameter()]
    [switch]$IncludeKnownFailing,

    [Parameter()]
    [switch]$Quiet,

    [Parameter()]
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$testsRoot = $PSScriptRoot
if (-not $testsRoot) { $testsRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }

# Build active bucket set.
$buckets = [System.Collections.Generic.List[string]]::new()
foreach ($f in $Filter) { $buckets.Add($f) }
if ($IncludeE2E -and 'e2e' -notin $buckets) { $buckets.Add('e2e') }

# Discover test files.
$testFiles = @()
foreach ($bucket in $buckets) {
    $bucketDir = Join-Path $testsRoot $bucket
    if (-not (Test-Path $bucketDir)) { continue }
    $found = Get-ChildItem $bucketDir -Filter '*.test.ps1' -File -Recurse |
        Where-Object { -not $_.Name.StartsWith('_') }
    foreach ($f in $found) {
        $rel = $f.FullName.Substring($testsRoot.Length).TrimStart('\','/') -replace '\\','/'
        if ($Pattern -and $rel -notlike "*$Pattern*") { continue }
        $testFiles += [pscustomobject]@{
            Bucket = $bucket
            Path = $f.FullName
            RelPath = $rel
            Name = $f.BaseName
        }
    }
}

# Filter by @tags: header line if -Tag was specified.
if ($Tag) {
    $tagSet = $Tag
    $testFiles = $testFiles | Where-Object {
        $lines = Get-Content $_.Path -TotalCount 10
        $tagLine = $lines | Where-Object { $_ -match '^#\s*@tags:\s*(.+)$' } | Select-Object -First 1
        if ($tagLine) {
            $found = @($matches[1] -split ',' | ForEach-Object { $_.Trim() })
            $matched = @($found | Where-Object { $_ -in $tagSet })
            $matched.Count -gt 0
        } else {
            # No @tags line — treat the bucket name as implicit tag.
            $_.Bucket -in $tagSet
        }
    }
}

# Always exclude tests tagged @tags: known-failing unless -IncludeKnownFailing.
# These are tests for legacy code paths with KNOWN bugs that we've chosen to
# defer fixing. Skipping them prevents noise in the default run while keeping
# the test wired up so the day we fix the underlying bug, the test just passes.
if (-not $IncludeKnownFailing) {
    $testFiles = $testFiles | Where-Object {
        $lines = Get-Content $_.Path -TotalCount 10
        $tagLine = $lines | Where-Object { $_ -match '^#\s*@tags:\s*(.+)$' } | Select-Object -First 1
        if ($tagLine) {
            $found = $matches[1] -split ',' | ForEach-Object { $_.Trim() }
            'known-failing' -notin $found
        } else {
            $true
        }
    }
}

if (-not $testFiles -or $testFiles.Count -eq 0) {
    if (-not $Json) {
        Write-Host "No test files matched (filter=$($Filter -join ','), tag=$($Tag -join ','), pattern=$Pattern)." -ForegroundColor Yellow
    }
    if ($Json) { '{ "files": 0, "passed": 0, "failed": 0, "tests": [] }' | Write-Output }
    exit 2
}

if (-not ($Quiet -or $Json)) {
    Write-Host ""
    Write-Host "Running $($testFiles.Count) test file(s) across buckets: $($buckets -join ', ')" -ForegroundColor Cyan
}

# Run each file. Use a child pwsh process so a crash doesn't take down the runner.
# Each child writes its results to a temp JSON we aggregate.
$allResults = [System.Collections.Generic.List[object]]::new()
$totalFiles = $testFiles.Count
$failedFiles = 0
$passedFiles = 0

foreach ($tf in $testFiles) {
    if (-not ($Quiet -or $Json)) {
        Write-Host ""
        Write-Host "[$($tf.RelPath)]" -ForegroundColor DarkCyan
    }
    $resultsTmp = [System.IO.Path]::GetTempFileName()
    try {
        # Inject a shim that writes Get-GlobalTestResults to a JSON file when the
        # test file finishes. The shim wraps the user's test file via dot-source.
        $shim = @"
`$ErrorActionPreference = 'Stop'
Import-Module '$($testsRoot -replace "'","''")\_harness.psm1' -Force -DisableNameChecking
try {
    & '$($tf.Path -replace "'","''")' -Quiet:`$$([bool]($Quiet -or $Json))
} catch {
    # Surface fatal file-level errors so the runner sees the failure.
    Write-Host "FATAL: `$(`$_.Exception.Message)" -ForegroundColor Red
}
Get-GlobalTestResults | ConvertTo-Json -Depth 5 | Set-Content '$($resultsTmp -replace "'","''")' -Encoding utf8
"@
        $shimFile = [System.IO.Path]::GetTempFileName() + '.ps1'
        $shim | Set-Content $shimFile -Encoding utf8
        try {
            & pwsh -NoProfile -File $shimFile
            $childExit = $LASTEXITCODE
        } finally {
            Remove-Item $shimFile -ErrorAction SilentlyContinue
        }
        if (Test-Path $resultsTmp) {
            $raw = Get-Content $resultsTmp -Raw
            if ($raw) {
                $parsed = $raw | ConvertFrom-Json
                if ($parsed) {
                    # Single-result case: ConvertFrom-Json returns object, not array.
                    if ($parsed -isnot [array]) { $parsed = @($parsed) }
                    foreach ($r in $parsed) { $allResults.Add($r) }
                }
            }
        }
        if ($childExit -eq 0) { $passedFiles++ } else { $failedFiles++ }
    } finally {
        Remove-Item $resultsTmp -ErrorAction SilentlyContinue
    }
}

$passedTests = @($allResults | Where-Object { $_.Passed }).Count
$failedTests = @($allResults | Where-Object { -not $_.Passed }).Count

if ($Json) {
    [pscustomobject]@{
        files = $totalFiles
        files_passed = $passedFiles
        files_failed = $failedFiles
        tests = $allResults.Count
        passed = $passedTests
        failed = $failedTests
        cases = $allResults
    } | ConvertTo-Json -Depth 6
    if ($failedTests -gt 0) { exit 1 } else { exit 0 }
}

if ($Quiet) {
    Write-Host "Test runner: $passedTests pass, $failedTests fail across $totalFiles file(s)"
    if ($failedTests -gt 0) { exit 1 } else { exit 0 }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Files:  $passedFiles pass, $failedFiles fail (of $totalFiles)"
Write-Host "  Tests:  $passedTests pass, $failedTests fail (of $($allResults.Count))"
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if ($failedTests -gt 0) {
    Write-Host "FAILED:" -ForegroundColor Red
    foreach ($r in ($allResults | Where-Object { -not $_.Passed })) {
        Write-Host "  $($r.File) :: $($r.Name)" -ForegroundColor Red
        Write-Host "    $($r.ErrorMessage)" -ForegroundColor DarkRed
    }
    Write-Host ""
    exit 1
}

Write-Host "All tests passed." -ForegroundColor Green
exit 0
