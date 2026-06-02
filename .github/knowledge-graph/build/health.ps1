#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Forwarder to .github/knowledge-graph/build/core/health.ps1.

.DESCRIPTION
    This file used to hold a separate copy of the health-check logic.
    Two copies drift. They drifted (one over-counted code-coverage by 36 files).
    Now there is exactly one health check — core/health.ps1 — and this script
    just forwards every argument to it. All parameters (-Layer, -Json, -Quiet, etc.)
    pass through unchanged. Exit code passes through unchanged.

    DO NOT add logic here. If you need to change health checks, edit core/health.ps1.

.NOTES
    Created 2026-06-02 to dedupe build/health.ps1 vs build/core/health.ps1.
    See decision log if one exists; otherwise see git log -- this file.
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$ErrorActionPreference = 'Stop'
$core = Join-Path $PSScriptRoot 'core' 'health.ps1'

if (-not (Test-Path -LiteralPath $core)) {
    Write-Error "Forwarder cannot find core health script at: $core"
    exit 2
}

& pwsh -NoProfile -File $core @Args
exit $LASTEXITCODE
