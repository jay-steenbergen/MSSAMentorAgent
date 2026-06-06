#!/usr/bin/env pwsh
#Requires -Version 7.0
# @tags: integration, fast
#
# Wraps test-extractor-stability.ps1 (14 hand-curated pins on contract-shape
# nodes/edges the extractor MUST produce). The wrapped script lives at
# .github/knowledge-graph/cli/tests/test-extractor-stability.ps1 and runs in
# < 1s by querying the merged graph in-memory.

[CmdletBinding()] param([switch]$Quiet)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot '..' '_harness.psm1') -Force -DisableNameChecking

Begin-TestFile -Name 'Extractor stability pins' -Quiet:$Quiet

Test-Case 'all 14 extractor-stability pins pass' {
    Assert-ScriptExitCode `
        -Path '.github/knowledge-graph/cli/tests/test-extractor-stability.ps1' `
        -Arguments @('-Quiet') `
        -Expected 0
}

End-TestFile
