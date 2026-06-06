#!/usr/bin/env pwsh
#Requires -Version 7.0
# @tags: e2e
#
# Wraps test-e2e.ps1 (full add-skill / link / unlink / remove round-trip via
# mentor.ps1 CLI; asserts graph file is byte-identical at end). Slow because
# it spawns multiple pwsh children — excluded from default run; opt in with
# `run-tests.ps1 -IncludeE2E`.

[CmdletBinding()] param([switch]$Quiet)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot '..' '_harness.psm1') -Force -DisableNameChecking

Begin-TestFile -Name 'Add-skill round-trip (E2E)' -Quiet:$Quiet

Test-Case 'mentor.ps1 add/link/unlink/remove leaves graph unchanged' {
    Assert-ScriptExitCode `
        -Path '.github/knowledge-graph/cli/tests/test-e2e.ps1' `
        -Arguments @() `
        -Expected 0
}

End-TestFile
