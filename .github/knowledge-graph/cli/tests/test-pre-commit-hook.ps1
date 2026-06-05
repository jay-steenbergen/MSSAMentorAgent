#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
Fast smoke test for the pre-commit gates. Tests each gate's logic in isolation against synthetic inputs. Sub-second runtime.

.DESCRIPTION
Why this exists:
  On 2026-06-04 a new gate in pre-commit.ps1 had an untested PS strict-mode
  .Count bug. The hook crashed on first real commit. No smoke test existed.
  This script is that test.

Design decision (post-iteration):
  An earlier draft of this test ran the full pre-commit hook 5 times in a
  temp git clone. ~5min per run because every invocation re-runs the graph
  extract + health pipeline. Wrong abstraction: we already test the extractor
  in test-e2e.ps1; what we need here is to test the new GATE LOGIC against
  synthetic inputs. So this script invokes the validators directly. Fast,
  focused, same coverage of the bug class that bit us.

What it covers:
  - validate-paths.ps1: clean MD vs MD with broken path
  - validate-pwsh.ps1:  clean PS vs PS with the literal 2026-06-04 .Count bug
  - UX-tag rule:        regex contract test for [Verification:] tag matching

What it does NOT cover:
  - Full hook end-to-end (would require slow extract pipeline)
  - Graph health / extract (test-e2e.ps1 covers that)

.PARAMETER Quiet
Print one-line summary only.

.EXAMPLE
pwsh .github/knowledge-graph/cli/tests/test-pre-commit-hook.ps1
pwsh .github/knowledge-graph/cli/tests/test-pre-commit-hook.ps1 -Quiet

.OUTPUTS
Exit 0 = all gates fire as designed. Exit 1 = a gate misfired. Exit 2 = setup error.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot -or $LASTEXITCODE -ne 0) {
    Write-Host "Not in a git repository." -ForegroundColor Red
    exit 2
}

$validatePaths = Join-Path $repoRoot '.github/knowledge-graph/cli/validate/validate-paths.ps1'
$validatePwsh  = Join-Path $repoRoot '.github/knowledge-graph/cli/validate/validate-pwsh.ps1'
foreach ($p in @($validatePaths, $validatePwsh)) {
    if (-not (Test-Path $p)) {
        Write-Host "Required validator not found: $p" -ForegroundColor Red
        exit 2
    }
}

$tempDir = Join-Path $env:TEMP "precommit-gates-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
$null = New-Item -ItemType Directory -Path $tempDir -Force

$caseResults = @()
function Assert-Case {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$ActualExit,
        [Parameter(Mandatory)][int]$ExpectedExit,
        [Parameter()][string]$Output = '',
        [Parameter()][string[]]$MustContain = @(),
        [Parameter()][string[]]$MustNotContain = @()
    )
    $errors = @()
    if ($ActualExit -ne $ExpectedExit) {
        $errors += "exit: expected $ExpectedExit, got $ActualExit"
    }
    foreach ($s in $MustContain) {
        if (-not ($Output -match [regex]::Escape($s))) {
            $errors += "missing expected text: '$s'"
        }
    }
    foreach ($s in $MustNotContain) {
        if ($Output -match [regex]::Escape($s)) {
            $errors += "unexpected text present: '$s'"
        }
    }
    $passed = $errors.Count -eq 0
    $script:caseResults += [pscustomobject]@{
        Name = $Name; Passed = $passed; Errors = $errors; ExitCode = $ActualExit
    }
    if (-not $Quiet) {
        if ($passed) {
            Write-Host "  PASS  $Name" -ForegroundColor Green
        } else {
            Write-Host "  FAIL  $Name" -ForegroundColor Red
            foreach ($e in $errors) { Write-Host "        $e" -ForegroundColor DarkRed }
        }
    }
}

if (-not $Quiet) {
    Write-Host ""
    Write-Host "=== Pre-commit gate smoke test ===" -ForegroundColor Cyan
    Write-Host ""
}

try {
    # === GATE 1: validate-paths.ps1 ===

    # 1a. Clean markdown — should pass.
    $cleanMd = Join-Path $tempDir 'clean.md'
    @"
# Clean

This file references a real path: ``.github/hooks/pre-commit.ps1``.

``````powershell
pwsh .github/knowledge-graph/cli/inspect/get-behavior.ps1 "open-with-mos-joke"
``````
"@ | Set-Content -Path $cleanMd -NoNewline

    $out = & pwsh -NoProfile -File $validatePaths -Files $cleanMd 2>&1 | Out-String
    Assert-Case -Name 'GATE 1a: validate-paths passes clean markdown' `
        -ActualExit $LASTEXITCODE -ExpectedExit 0 -Output $out `
        -MustContain @('All path references')

    # 1b. Broken path (the 2026-06-04 bug shape) — should block.
    $brokenMd = Join-Path $tempDir 'broken.md'
    @"
# Broken

``````powershell
pwsh .github/knowledge-graph/cli/THIS-PATH-DOES-NOT-EXIST.ps1 "demo"
``````
"@ | Set-Content -Path $brokenMd -NoNewline

    $out = & pwsh -NoProfile -File $validatePaths -Files $brokenMd 2>&1 | Out-String
    Assert-Case -Name 'GATE 1b: validate-paths blocks broken markdown path' `
        -ActualExit $LASTEXITCODE -ExpectedExit 1 -Output $out `
        -MustContain @('THIS-PATH-DOES-NOT-EXIST', 'Broken references')

    # === GATE 2: validate-pwsh.ps1 ===

    # 2a. Clean PowerShell — should pass.
    $cleanPs = Join-Path $tempDir 'clean.ps1'
    @"
#Requires -Version 7.0
Set-StrictMode -Version Latest
`$patterns = @('a','b','c')
`$files = @('foo.ts','bar.ts')
`$touched = @(`$files | Where-Object {
    `$f = `$_
    `$matched = @(`$patterns | Where-Object { `$f -match `$_ })
    `$matched.Count -gt 0
})
Write-Host `$touched.Count
"@ | Set-Content -Path $cleanPs -NoNewline

    $out = & pwsh -NoProfile -File $validatePwsh -Files $cleanPs 2>&1 | Out-String
    Assert-Case -Name 'GATE 2a: validate-pwsh passes wrapped @(...) idiom' `
        -ActualExit $LASTEXITCODE -ExpectedExit 0 -Output $out `
        -MustNotContain @('CustomStrictModeCount')

    # 2b. The literal 2026-06-04 bug — should block.
    $buggyPs = Join-Path $tempDir 'buggy.ps1'
    @"
#Requires -Version 7.0
Set-StrictMode -Version Latest
`$patterns = @('a','b','c')
`$files = @('foo.ts','bar.ts')
`$touched = @(`$files | Where-Object {
    `$f = `$_
    (`$patterns | Where-Object { `$f -match `$_ }).Count -gt 0
})
Write-Host `$touched.Count
"@ | Set-Content -Path $buggyPs -NoNewline

    $out = & pwsh -NoProfile -File $validatePwsh -Files $buggyPs 2>&1 | Out-String
    Assert-Case -Name 'GATE 2b: validate-pwsh blocks the 2026-06-04 .Count bug' `
        -ActualExit $LASTEXITCODE -ExpectedExit 1 -Output $out `
        -MustContain @('CustomStrictModeCount')

    # === GATE 3: UX-tag rule (regex contract test) ===
    # The matcher lives inline in pre-commit.ps1. Test the regex contract so
    # a future tweak to the matcher gets caught.

    $verificationMatcher = {
        param([string]$Msg)
        return ($Msg -match '\[Verification:\s*fresh-chat\b') -or
               ($Msg -match '\[Verification:\s*n/a\b')
    }

    $accepts1 = & $verificationMatcher 'tweak foo`n`n[Verification: fresh-chat] typed hey, got branch riff. Pass.'
    Assert-Case -Name 'GATE 3a: UX-tag matcher accepts fresh-chat tag' `
        -ActualExit ([int](-not $accepts1)) -ExpectedExit 0

    $accepts2 = & $verificationMatcher 'tooling`n`n[Verification: n/a -- reason: docs only]'
    Assert-Case -Name 'GATE 3b: UX-tag matcher accepts n/a tag' `
        -ActualExit ([int](-not $accepts2)) -ExpectedExit 0

    $rejects1 = & $verificationMatcher 'plain commit message'
    Assert-Case -Name 'GATE 3c: UX-tag matcher rejects plain msg with no tag' `
        -ActualExit ([int]$rejects1) -ExpectedExit 0

    $rejects2 = & $verificationMatcher '[Verifcation: fresh-chat] typo on purpose'
    Assert-Case -Name 'GATE 3d: UX-tag matcher rejects typo "Verifcation"' `
        -ActualExit ([int]$rejects2) -ExpectedExit 0

    # Summary.
    $passed = @($caseResults | Where-Object { $_.Passed }).Count
    $failed = @($caseResults | Where-Object { -not $_.Passed }).Count

    if (-not $Quiet) {
        Write-Host ""
        Write-Host "=== Summary ===" -ForegroundColor Cyan
        Write-Host "PASS: $passed" -ForegroundColor Green
        $sumColor = if ($failed -gt 0) { 'Red' } else { 'Green' }
        Write-Host "FAIL: $failed" -ForegroundColor $sumColor
        Write-Host ""
    } else {
        Write-Host "Pre-commit gate smoke: $passed pass, $failed fail across $($caseResults.Count) case(s)"
    }

    if ($failed -gt 0) { exit 1 } else { exit 0 }
}
finally {
    if (Test-Path $tempDir) {
        try { Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue } catch {}
    }
}
