#!/usr/bin/env pwsh
#Requires -Version 7.0
# @tags: integration
#
# Wraps test-graph-writer.ps1 (isolation test for graph-writer.psm1).

[CmdletBinding()] param([switch]$Quiet)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot '..' '_harness.psm1') -Force -DisableNameChecking

Begin-TestFile -Name 'Graph-writer module' -Quiet:$Quiet

Test-Case 'graph-writer isolation test passes' {
    Assert-ScriptExitCode `
        -Path '.github/knowledge-graph/cli/tests/test-graph-writer.ps1' `
        -Arguments @() `
        -Expected 0
}

End-TestFile
