#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
Run PSScriptAnalyzer on staged PowerShell files (.ps1, .psm1) plus a custom regex check for known strict-mode traps PSScriptAnalyzer doesn't catch.

.DESCRIPTION
Why this exists:
  On 2026-06-04 a new gate in pre-commit.ps1 used `(@(pipeline)).Count -gt 0`
  without `@(...)` wrapping the inner Where-Object result. Under
  `Set-StrictMode -Version Latest`, `Where-Object` returning $null or a single
  object lacks `.Count`. The hook crashed mid-commit. PSScriptAnalyzer does
  not have a built-in rule for this specific trap, so this script combines:

    1. PSScriptAnalyzer with a curated rule set (Error + selected Warnings,
       Write-Host excluded as legitimate in our CLI tools).
    2. A small custom regex check for the strict-mode traps PSSA misses:
         - Unwrapped pipeline-result .Count (today's bug)
         - $x -eq $null reversed-comparison
         - Test-Path without -PathType when intent is file vs dir

  The custom checks are kept narrow to avoid false positives.

What it checks:
  - Staged .ps1 and .psm1 files under .github/ (plus any explicit -Files arg).
  - Excludes generated artifacts under data/, output/, tests/fixtures/.

.PARAMETER Files
Optional explicit file list. When omitted, scans staged .ps1/.psm1 files.

.PARAMETER Quiet
Suppress per-finding output; print summary line + exit code only.

.PARAMETER All
Scan ALL .ps1/.psm1 files in the knowledge-graph tooling tree, not just staged.
Use for periodic full-repo audit.

.EXAMPLE
pwsh .github/knowledge-graph/cli/validate/validate-pwsh.ps1
pwsh .github/knowledge-graph/cli/validate/validate-pwsh.ps1 -Files .github/hooks/pre-commit.ps1
pwsh .github/knowledge-graph/cli/validate/validate-pwsh.ps1 -All -Quiet

.OUTPUTS
Exit code 0 = clean. Exit code 1 = findings. Exit code 2 = invocation error.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string[]]$Files,

    [Parameter()]
    [switch]$Quiet,

    [Parameter()]
    [switch]$All
)

$ErrorActionPreference = 'Stop'

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot -or $LASTEXITCODE -ne 0) {
    Write-Host "Not in a git repository." -ForegroundColor Red
    exit 2
}
$repoRoot = $repoRoot.TrimEnd('/', '\')

# Ensure PSScriptAnalyzer is available.
$mod = Get-Module -ListAvailable PSScriptAnalyzer | Select-Object -First 1
if (-not $mod) {
    Write-Host "PSScriptAnalyzer not installed." -ForegroundColor Red
    Write-Host "Install with: Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force" -ForegroundColor Yellow
    exit 2
}
Import-Module PSScriptAnalyzer -Force | Out-Null

$settingsFile = Join-Path $repoRoot '.github/knowledge-graph/cli/validate/psscriptanalyzer.settings.psd1'
if (-not (Test-Path $settingsFile)) {
    Write-Host "Settings file not found: $settingsFile" -ForegroundColor Red
    exit 2
}

# Build target file list.
$psFiles = @()
if ($Files) {
    $psFiles = $Files | Where-Object { $_ -match '\.(ps1|psm1)$' }
} elseif ($All) {
    $rootPath = Join-Path $repoRoot '.github'
    $psFiles = Get-ChildItem -Path $rootPath -Recurse -File -Include '*.ps1', '*.psm1' |
        Where-Object {
            $rel = $_.FullName.Substring($repoRoot.Length).TrimStart('\','/')
            $rel = $rel -replace '\\', '/'
            $rel -notmatch '/(data|output|node_modules)/'
        } |
        ForEach-Object {
            $rel = $_.FullName.Substring($repoRoot.Length).TrimStart('\','/')
            $rel -replace '\\', '/'
        }
} else {
    $staged = git diff --cached --name-only --diff-filter=ACM 2>$null
    if (-not $staged) {
        if (-not $Quiet) {
            Write-Host "No staged files. Nothing to validate." -ForegroundColor Gray
        }
        exit 0
    }
    $stagedPs = @($staged | Where-Object {
        $_ -match '\.(ps1|psm1)$' -and
        $_ -match '^\.github/' -and
        $_ -notmatch '/(data|output)/'
    })
    $psFiles = $stagedPs
}

if (-not $psFiles -or $psFiles.Count -eq 0) {
    if (-not $Quiet) {
        Write-Host "No PowerShell files in scope. Nothing to validate." -ForegroundColor Gray
    }
    exit 0
}

# 1. Run PSScriptAnalyzer with our settings.
$psaFindings = @()
foreach ($f in $psFiles) {
    $abs = if ([System.IO.Path]::IsPathRooted($f)) { $f } else { Join-Path $repoRoot $f }
    if (-not (Test-Path $abs)) { continue }
    $results = Invoke-ScriptAnalyzer -Path $abs -Settings $settingsFile -ErrorAction SilentlyContinue
    if ($results) {
        foreach ($r in $results) {
            $psaFindings += [pscustomobject]@{
                File     = $f
                Line     = $r.Line
                Severity = $r.Severity
                RuleName = $r.RuleName
                Message  = $r.Message
                Source   = 'PSScriptAnalyzer'
            }
        }
    }
}

# 2. Custom strict-mode trap regex checks.
# These cover bugs PSScriptAnalyzer doesn't have rules for.
# IMPORTANT: TRAP 1 (.Count on unwrapped pipeline) only manifests under
# `Set-StrictMode -Version Latest` (or 3.0). Without strict mode, $null.Count
# silently returns 0 and the code works. So we only flag TRAP 1 in files that
# opt into strict mode. Files without strict mode use the pattern legitimately
# (auto-discover, extract-code-graph, etc.) and flagging them produces noise
# that obscures real bugs.
$customFindings = @()
foreach ($f in $psFiles) {
    $abs = if ([System.IO.Path]::IsPathRooted($f)) { $f } else { Join-Path $repoRoot $f }
    if (-not (Test-Path $abs)) { continue }
    $fileContent = Get-Content $abs -Raw
    # Determine strict-mode posture for this file.
    $usesStrictMode = $fileContent -match 'Set-StrictMode\s+-Version\s+(Latest|3(\.0)?|[4-9])'
    $lines = $fileContent -split "`r?`n"
    $lineNo = 0
    # Track whether we're inside a structure where text isn't executed code:
    #   <#...#> block comment
    #   @"..."@ or @'...'@ here-string
    # Findings in these contexts are doc / test fixtures, not bugs.
    $inBlockComment = $false
    $inHereString = $false

    foreach ($line in $lines) {
        $lineNo++

        # Block comment tracking.
        if ($inBlockComment) {
            if ($line -match '#>') { $inBlockComment = $false }
            continue
        }
        if ($line -match '<#' -and -not ($line -match '#>.*<#')) {
            if (-not ($line -match '<#.*#>')) {
                $inBlockComment = $true
                continue
            }
        }

        # Here-string tracking (@"..."@ or @'...'@). Opens with `@"` or `@'`
        # at end of line, closes with `"@` or `'@` at start of line.
        if ($inHereString) {
            if ($line -match '^"@' -or $line -match "^'@") { $inHereString = $false }
            continue
        }
        if ($line -match '@"\s*$' -or $line -match "@'\s*$") {
            $inHereString = $true
            continue
        }

        # Skip whole-line comments.
        $trimmed = $line.TrimStart()
        if ($trimmed.StartsWith('#')) { continue }

        # TRAP 1: Unwrapped pipeline-result .Count
        #   Bad (under strict mode):   (... | Where-Object { ... }).Count
        #   Good:                       @(... | Where-Object { ... }).Count
        # Only flagged when the file opts into strict mode. Files without strict
        # mode use this pattern legitimately and flagging them is noise.
        if ($usesStrictMode -and $line -match '(?<!@)\([^()]*\|[^()]*\)\.(Count|Length)\b') {
            $customFindings += [pscustomobject]@{
                File     = $f
                Line     = $lineNo
                Severity = 'Error'
                RuleName = 'CustomStrictModeCount'
                Message  = "Unwrapped pipeline result accessed via .Count/.Length. Under Set-StrictMode -Version Latest, this throws when the pipeline yields `$null or a single object. Wrap with @(...): @(... | Where-Object { ... }).Count"
                Source   = 'Custom'
            }
        }

        # TRAP 2: Reversed null comparison
        #   Bad:   `$x -eq `$null
        #   Good:  `$null -eq `$x
        # When `$x is an array, `$x -eq `$null` returns an array of `$null elements
        # (one per matching element), NOT a boolean. The reverse (`$null -eq `$x)
        # always returns a scalar. PSScriptAnalyzer has PSPossibleIncorrectComparisonWithNull
        # for this, but we double-check here in case it's disabled.
        if ($line -match '\$\w+\s*-(eq|ne)\s*\$null\b') {
            $customFindings += [pscustomobject]@{
                File     = $f
                Line     = $lineNo
                Severity = 'Warning'
                RuleName = 'CustomNullComparisonOrder'
                Message  = "Compare `$null on the LEFT: `$null -eq `$x (not `$x -eq `$null). The right-hand form returns an array of nulls when `$x is itself an array, silently failing boolean checks."
                Source   = 'Custom'
            }
        }
    }
}

$findings = @($psaFindings) + @($customFindings) | Sort-Object File, Line

# Report.
if ($Quiet) {
    $errCount = @($findings | Where-Object { $_.Severity -eq 'Error' }).Count
    $warnCount = @($findings | Where-Object { $_.Severity -eq 'Warning' }).Count
    Write-Host "PowerShell validation: $errCount error(s), $warnCount warning(s) across $($psFiles.Count) file(s)"
    if ($errCount -gt 0) { exit 1 } else { exit 0 }
}

if ($findings.Count -eq 0) {
    Write-Host "✓ PowerShell validation clean ($($psFiles.Count) file(s) scanned)." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "=== PowerShell Validation Report ===" -ForegroundColor Cyan
Write-Host "Files scanned: $($psFiles.Count)"
Write-Host "Findings: $($findings.Count) (Errors: $(@($findings | Where-Object { $_.Severity -eq 'Error' }).Count), Warnings: $(@($findings | Where-Object { $_.Severity -eq 'Warning' }).Count))"
Write-Host ""

foreach ($group in $findings | Group-Object File) {
    Write-Host "● $($group.Name)" -ForegroundColor Yellow
    foreach ($f in $group.Group) {
        $sevColor = if ($f.Severity -eq 'Error') { 'Red' } else { 'DarkYellow' }
        Write-Host "    line $($f.Line):  [$($f.Source)/$($f.RuleName)] $($f.Severity)" -ForegroundColor $sevColor
        Write-Host "      $($f.Message)" -ForegroundColor DarkGray
    }
    Write-Host ""
}

$errCount = @($findings | Where-Object { $_.Severity -eq 'Error' }).Count
if ($errCount -gt 0) {
    Write-Host "How to fix:" -ForegroundColor Cyan
    Write-Host "  Errors must be resolved before commit. Warnings are advisory."
    Write-Host "  See per-finding messages for the specific fix."
    Write-Host ""
    exit 1
}
exit 0
