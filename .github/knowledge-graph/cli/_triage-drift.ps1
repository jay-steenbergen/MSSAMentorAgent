#!/usr/bin/env pwsh
# Triage drift findings: separate real file-path references from noise.
$ErrorActionPreference = 'Stop'

$tmp = Join-Path $env:TEMP 'drift.txt'
& pwsh -NoProfile -File "$PSScriptRoot/find-drift.ps1" 2>&1 | Out-File $tmp -Encoding utf8

$lines = Get-Content $tmp

$findings = @()
$currentNode = $null
foreach ($l in $lines) {
    if ($l -match '^\?\s+(\S+)') { $currentNode = $matches[1]; continue }
    if ($l -match '\[literal\]\s+(\S+)') {
        $findings += [pscustomobject]@{ Node = $currentNode; Literal = $matches[1] }
    }
}

# Classify: "real path" must look like a file (has a recognized extension OR has known dir prefix)
$realPathHints = @(
    '\.md$', '\.ps1$', '\.psm1$', '\.json$', '\.ts$', '\.js$', '\.yml$', '\.yaml$',
    '\.profiles/', '\.github/', 'docs/', '\.copilot/'
)
$realRegex = ($realPathHints -join '|')

$real = $findings | Where-Object { $_.Literal -match $realRegex }
$noise = $findings | Where-Object { $_.Literal -notmatch $realRegex }

Write-Host "=== REAL PATH DRIFTS ($($real.Count)) ===" -ForegroundColor Yellow
$real | Format-Table -AutoSize | Out-String | Write-Host

Write-Host "=== NOISE (slash strings that aren't paths): $($noise.Count) ===" -ForegroundColor DarkGray
$noise | Group-Object Literal | Sort-Object Count -Descending | Select-Object -First 30 | Format-Table Count, Name -AutoSize | Out-String | Write-Host
