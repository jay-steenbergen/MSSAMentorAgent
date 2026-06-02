#Requires -Version 7.0
<#
.SYNOPSIS
    Graph suite: knowledge-graph health gate.

.DESCRIPTION
    Wraps the health checker via the thin forwarder at
    .github/knowledge-graph/build/health.ps1, which delegates to
    .github/knowledge-graph/build/core/health.ps1 (single source of truth).
    PASS when health.ps1 exits 0 AND no FAIL category is reported.

.OUTPUTS
    A hashtable: @{ name; result; detail; durationMs }
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = 'Continue'
$start = Get-Date

$healthScript = Join-Path $RepoRoot '.github/knowledge-graph/build/health.ps1'

if (-not (Test-Path $healthScript)) {
    return @{
        name = 'graph'
        result = 'FAIL'
        detail = "health.ps1 not found at $healthScript"
        durationMs = 0
    }
}

# Run silently — we just want the summary line.
$output = & pwsh -NoProfile -File $healthScript 2>&1 | Out-String
$exit = $LASTEXITCODE

# Parse the summary line: "Summary: PASS 10 | WARN 1 | FAIL 0"
$summary = ($output -split "`n") |
    Where-Object { $_ -match 'Summary:\s+PASS\s+\d+' } |
    Select-Object -First 1

$detail = if ($summary) {
    ($summary -replace '^\s*Summary:\s*', '').Trim()
} else {
    "no summary line (exit=$exit)"
}

$failCount = 0
if ($summary -match 'FAIL\s+(\d+)') { $failCount = [int]$Matches[1] }

$result = if ($exit -eq 0 -and $failCount -eq 0) { 'PASS' } else { 'FAIL' }

return @{
    name = 'graph'
    result = $result
    detail = $detail
    durationMs = [int]((Get-Date) - $start).TotalMilliseconds
}
