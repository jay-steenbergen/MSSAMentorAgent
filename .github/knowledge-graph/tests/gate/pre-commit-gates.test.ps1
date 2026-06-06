#!/usr/bin/env pwsh
#Requires -Version 7.0
# @tags: gate, fast
#
# Wraps test-pre-commit-hook.ps1, the 8-case smoke test for the pre-commit
# gates (validate-paths, validate-pwsh, UX-tag matcher). Runs in <1s by
# invoking each validator on synthetic inputs.

[CmdletBinding()] param([switch]$Quiet)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot '..' '_harness.psm1') -Force -DisableNameChecking

Begin-TestFile -Name 'Pre-commit gates smoke' -Quiet:$Quiet

Test-Case 'all 8 pre-commit gate cases pass' {
    Assert-ScriptExitCode `
        -Path '.github/knowledge-graph/cli/tests/test-pre-commit-hook.ps1' `
        -Arguments @('-Quiet') `
        -Expected 0
}

End-TestFile
