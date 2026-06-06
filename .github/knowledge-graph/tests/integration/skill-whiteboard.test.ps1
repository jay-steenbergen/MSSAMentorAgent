#!/usr/bin/env pwsh
#Requires -Version 7.0
# @tags: integration
#
# Wraps smoke-whiteboard.ps1 (whiteboard method integration check).

[CmdletBinding()] param([switch]$Quiet)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot '..' '_harness.psm1') -Force -DisableNameChecking

Begin-TestFile -Name 'Whiteboard skill smoke' -Quiet:$Quiet

Test-Case 'whiteboard smoke test passes' {
    Assert-ScriptExitCode `
        -Path '.github/knowledge-graph/cli/tests/smoke-whiteboard.ps1' `
        -Arguments @() `
        -Expected 0
}

End-TestFile
