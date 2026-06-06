#!/usr/bin/env pwsh
#Requires -Version 7.0
# @tags: unit, fast
#
# Sanity checks on the graph's structural invariants. Sub-millisecond — no
# subprocesses. If any of these fail, something is fundamentally broken with
# the graph itself before we even get to behavioral correctness.

[CmdletBinding()] param([switch]$Quiet)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot '..' '_harness.psm1') -Force -DisableNameChecking

Begin-TestFile -Name 'Graph structural invariants' -Quiet:$Quiet

Test-Case 'no dangling edge endpoints' {
    Assert-NoDanglingEdges
}

Test-Case 'agent:mentor exists and is the root' {
    Assert-NodeExists 'agent:mentor'
}

Test-Case 'purpose:mentor exists (Meadows leverage-point anchor)' {
    Assert-NodeExists 'purpose:mentor'
}

Test-Case 'entry-point:user-typed exists (2026-06-04 regression fix)' {
    Assert-NodeExists 'entry-point:user-typed'
}

Test-Case 'entry-point:extension-seed exists' {
    Assert-NodeExists 'entry-point:extension-seed'
}

Test-Case 'agent follows behavior:01-identify-learner' {
    Assert-EdgeExists -Source 'agent:mentor' -Type 'follows' -Target 'behavior:01-identify-learner'
}

Test-Case 'agent follows behavior:33-open-with-mos-joke (greeting fix)' {
    Assert-EdgeExists -Source 'agent:mentor' -Type 'follows' -Target 'behavior:33-open-with-mos-joke'
}

Test-Case 'agent follows behavior:34-verify-ux-fix-in-fresh-chat' {
    Assert-EdgeExists -Source 'agent:mentor' -Type 'follows' -Target 'behavior:34-verify-ux-fix-in-fresh-chat'
}

Test-Case 'entry-point:user-typed triggers behavior:33-open-with-mos-joke' {
    Assert-EdgeExists -Source 'entry-point:user-typed' -Type 'triggers' -Target 'behavior:33-open-with-mos-joke'
}

Test-Case 'entry-point:extension-seed triggers behavior:33-open-with-mos-joke' {
    Assert-EdgeExists -Source 'entry-point:extension-seed' -Type 'triggers' -Target 'behavior:33-open-with-mos-joke'
}

End-TestFile
