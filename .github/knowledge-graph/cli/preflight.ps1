#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
Run the full pre-commit graph chain locally and report all issues at once.

.DESCRIPTION
Mirrors what .github/hooks/pre-commit.ps1 does on commit, but runs unconditionally
and reports every issue in one pass instead of failing one-at-a-time.

Chain:
  1. extract-code-graph    (rebuild code-graph.json from disk)
  2. merge                 (rebuild merged-graph.json from system + code)
  3. fix-dangling-edges    (report dangling edges; auto-fix where possible)
  4. health                (run all health checks against merged graph)
  5. find-drift            (verify documented paths resolve)

Use this before staging a knowledge-graph change. If preflight is green, the
pre-commit hook will be green.

.PARAMETER SkipExtract
Skip step 1 (extract-code-graph). Useful when iterating on graph JSON only.

.OUTPUTS
Exit code 0 = all clear. Exit code 1 = one or more failures.
#>

[CmdletBinding()]
param(
    [switch]$SkipExtract
)

$ErrorActionPreference = 'Continue'
$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot  = Split-Path (Split-Path (Split-Path $scriptDir -Parent) -Parent) -Parent
$graphDir  = Join-Path $repoRoot '.github/knowledge-graph'

# Step scripts
$autoDiscoverPs1 = Join-Path $graphDir 'build/advanced/auto-discover-features.ps1'
$extractScript  = Join-Path $graphDir 'build/core/extract-code-graph.ps1'
$mergeScript    = Join-Path $graphDir 'build/core/merge.ps1'
$fixDanglingPs1 = Join-Path $graphDir 'build/repair/fix-dangling-edges.ps1'
$healthScript   = Join-Path $graphDir 'build/core/health.ps1'
$driftScript    = Join-Path $graphDir 'cli/find-drift.ps1'

# Results table
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result($step, $status, $detail = '') {
    $results.Add([pscustomobject]@{
        Step   = $step
        Status = $status
        Detail = $detail
    })
}

function Write-Step($msg) { Write-Host "`n>> $msg" -ForegroundColor Cyan }

# Step 0: auto-discover (mirror what the pre-commit hook does)
Write-Step "Auto-discovering features (skills, CLI tools, modules, extensions)..."
$out = & pwsh -NoProfile -File $autoDiscoverPs1 2>&1 | Out-String
if ($LASTEXITCODE -eq 0) {
    $detail = if ($out -match 'Will add:\s*\r?\n\s*Nodes:\s*(\d+)\s*\r?\n\s*Edges:\s*(\d+)') {
        "added $($matches[1]) node(s), $($matches[2]) edge(s)"
    } else { 'nothing new to wire' }
    Add-Result 'auto-discover' 'PASS' $detail
} else {
    Add-Result 'auto-discover' 'FAIL' "exit $LASTEXITCODE"
    $out | Select-Object -Last 10 | Write-Host
}

# Step 1: extract
if (-not $SkipExtract) {
    Write-Step "Extracting code graph..."
    $out = & pwsh -NoProfile -File $extractScript 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        Add-Result 'extract' 'PASS'
    } else {
        Add-Result 'extract' 'FAIL' "exit $LASTEXITCODE"
        $out | Select-Object -Last 10 | Write-Host
    }
} else {
    Add-Result 'extract' 'SKIP'
}

# Step 2: merge
Write-Step "Merging graph layers..."
$out = & pwsh -NoProfile -File $mergeScript 2>&1 | Out-String
if ($LASTEXITCODE -eq 0) {
    Add-Result 'merge' 'PASS'
} else {
    Add-Result 'merge' 'FAIL' "exit $LASTEXITCODE"
    $out | Select-Object -Last 10 | Write-Host
}

# Step 3: fix-dangling-edges (report-only mode would be nice; for now just run it)
Write-Step "Checking dangling edges..."
$out = & pwsh -NoProfile -File $fixDanglingPs1 2>&1 | Out-String
if ($LASTEXITCODE -eq 0) {
    $detail = if ($out -match 'Fixed (\d+)') { "fixed $($matches[1])" } else { '0 dangling' }
    Add-Result 'dangling-edges' 'PASS' $detail
} else {
    Add-Result 'dangling-edges' 'FAIL' 'manual review needed'
    Write-Host ''
    $out | Write-Host
    Write-Host ''
}

# Step 4: health
Write-Step "Running health checks..."
$out = & pwsh -NoProfile -File $healthScript -Layer merged 2>&1 | Out-String
$pass = if ($out -match 'Summary:\s*PASS\s*(\d+)') { $matches[1] } else { '?' }
$warn = if ($out -match '\|\s*WARN\s*(\d+)') { $matches[1] } else { '?' }
$fail = if ($out -match '\|\s*FAIL\s*(\d+)') { $matches[1] } else { '?' }
$detail = "$pass pass / $warn warn / $fail fail"

# Pull blocking conditions from health output (mirror pre-commit logic)
$blocking = @()
if ($out -match '\[FAIL\]\s+dangling-edges\s+\((\d+)\)') { $blocking += "dangling=$($matches[1])" }
if ($out -match '\[FAIL\]\s+duplicate-node-ids\s+\((\d+)\)') { $blocking += "duplicate=$($matches[1])" }
if ($out -match '\[WARN\]\s+islands\s+\((\d+)\)') { $blocking += "islands=$($matches[1])" }
if ($out -match '\[WARN\]\s+code-coverage\s+\((\d+)\)') { $blocking += "coverage=$($matches[1])" }

if ($blocking) {
    Add-Result 'health' 'FAIL' "$detail | blocking: $($blocking -join ', ')"
    Write-Host ''
    $out | Select-String -Pattern 'FAIL|WARN|Stale|Missing|island|stale' -Context 0,2 | Select-Object -First 30 | Write-Host
    Write-Host ''
} else {
    Add-Result 'health' 'PASS' $detail
}

# Step 5: find-drift
Write-Step "Checking path drift in descriptions..."
$out = & pwsh -NoProfile -File $driftScript -Quiet 2>&1 | Out-String
if ($LASTEXITCODE -eq 0) {
    Add-Result 'drift' 'PASS'
} else {
    $count = if ($out -match 'Drift findings:\s*(\d+)') { $matches[1] } else { '?' }
    Add-Result 'drift' 'FAIL' "$count drifted path reference(s)"
    Write-Host ''
    & pwsh -NoProfile -File $driftScript 2>&1 | Select-Object -Last 30 | Write-Host
    Write-Host ''
}

# Summary table
Write-Host ''
Write-Host ('=' * 60) -ForegroundColor DarkGray
Write-Host '  Preflight Summary' -ForegroundColor Cyan
Write-Host ('=' * 60) -ForegroundColor DarkGray
$results | ForEach-Object {
    $color = switch ($_.Status) {
        'PASS' { 'Green' }
        'FAIL' { 'Red' }
        'SKIP' { 'DarkGray' }
        default { 'Yellow' }
    }
    $line = ('  {0,-18} {1,-6} {2}' -f $_.Step, $_.Status, $_.Detail)
    Write-Host $line -ForegroundColor $color
}
Write-Host ('=' * 60) -ForegroundColor DarkGray

$failed = ($results | Where-Object Status -eq 'FAIL').Count
if ($failed -gt 0) {
    Write-Host "  RESULT: $failed step(s) failed. Pre-commit will reject this commit." -ForegroundColor Red
    Write-Host ''
    exit 1
} else {
    Write-Host "  RESULT: All checks passed. Safe to commit." -ForegroundColor Green
    Write-Host ''
    exit 0
}
