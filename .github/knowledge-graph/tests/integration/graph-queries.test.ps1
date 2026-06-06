#!/usr/bin/env pwsh
#Requires -Version 7.0
# @tags: integration
#
# Wraps test-graph.ps1, the 10+ test suite validating graph query operations.

[CmdletBinding()] param([switch]$Quiet)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot '..' '_harness.psm1') -Force -DisableNameChecking

Begin-TestFile -Name 'Graph query operations' -Quiet:$Quiet

Test-Case 'all graph query tests pass' {
    Assert-ScriptExitCode `
        -Path '.github/knowledge-graph/cli/tests/test-graph.ps1' `
        -Arguments @() `
        -Expected 0
}

End-TestFile
