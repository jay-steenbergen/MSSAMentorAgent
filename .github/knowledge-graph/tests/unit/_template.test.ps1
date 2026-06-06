#!/usr/bin/env pwsh
#Requires -Version 7.0
# @tags: fast
#
# Template for a new test file. Copy and rename to <your-thing>.test.ps1.
# Files starting with `_` are ignored by run-tests.ps1.

[CmdletBinding()] param([switch]$Quiet)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot '..' '_harness.psm1') -Force -DisableNameChecking

Begin-TestFile -Name 'Your thing' -Quiet:$Quiet

Test-Case 'agent:mentor exists' {
    Assert-NodeExists 'agent:mentor'
}

Test-Case 'agent follows the identify-learner behavior' {
    Assert-EdgeExists -Source 'agent:mentor' -Type 'follows' -Target 'behavior:01-identify-learner'
}

End-TestFile
