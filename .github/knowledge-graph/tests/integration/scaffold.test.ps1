#!/usr/bin/env pwsh
#Requires -Version 7.0
# @tags: integration
#
# Wraps test-scaffold.ps1 (isolation test for scaffold.psm1: scaffolds one
# stub of each type to a sandbox dir, asserts shape, cleans up).

[CmdletBinding()] param([switch]$Quiet)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot '..' '_harness.psm1') -Force -DisableNameChecking

Begin-TestFile -Name 'Scaffold module' -Quiet:$Quiet

Test-Case 'scaffold isolation test passes' {
    Assert-ScriptExitCode `
        -Path '.github/knowledge-graph/cli/tests/test-scaffold.ps1' `
        -Arguments @() `
        -Expected 0
}

End-TestFile
