#!/usr/bin/env pwsh
#Requires -Version 7.0
# @tags: integration, fast
#
# Asserts the edge-claim audit (audit-edge-claims.ps1) stays at or above the
# trust threshold. Lowering this number is allowed but it has to be an
# intentional commit — otherwise the gate catches the drift.

[CmdletBinding()] param([switch]$Quiet)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot '..' '_harness.psm1') -Force -DisableNameChecking

# Trust floor — raised as we close more gaps. Currently 100%.
# If a future change introduces unverified edges, this fails and the commit
# message has to justify the regression OR add the evidence.
$script:TRUST_FLOOR = 100

Begin-TestFile -Name 'Audit trust floor' -Quiet:$Quiet

Test-Case "edge-claim audit verifies at least $script:TRUST_FLOOR% of claims" {
    Assert-AuditRateAtLeast -MinPercent $script:TRUST_FLOOR
}

End-TestFile
