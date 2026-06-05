#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
Validate that path references in source markdown (agents, skills, instructions, docs) resolve to real files on disk. Runs BEFORE the graph extractor.

.DESCRIPTION
Why this exists:
  On 2026-06-04 a hand edit in `Mentor.agent.md` changed `cli/inspect/get-behavior.ps1`
  to `cli/get-behavior.ps1`. The path didn't exist on disk. The pre-commit hook's
  existing `find-drift.ps1` only scans graph JSON text — not source markdown — so the
  bad path passed straight into the extractor, which dutifully created 5 stub nodes
  for the non-existent files. Health check caught it AFTER the damage; auto-fix
  couldn't recover. The fix had to revert the markdown edit.

  This validator runs BEFORE the extractor. It scans markdown file content for
  repo-relative path references (`.github/...`, `extensions/...`, `.profiles/...`,
  etc.) and checks each one exists. Bad paths block the commit at source, never
  reach the graph.

What it checks:
  - Staged .md files in `.github/agents/`, `.github/skills/`, `.github/instructions/`,
    `docs/`, and `extensions/*/README.md`. (Configurable via -Roots.)
  - Path-like tokens that look like repo-relative file refs:
       `.github/foo/bar.ps1`, `extensions/mssa-mentor/src/x.ts`, `docs/y.md`
  - Skips: URLs, namespaces (`skill:foo`), template paths (`{username}`), prose with
    slashes (`Given/When/Then`, `Army/Navy`), code fence content (```...```).
  - Skips: tilde-or-dot anchored relative paths inside MD links when target equals
    the source file's own path.

What it does NOT check:
  - File content correctness (just existence).
  - Graph JSON files (that's `find-drift.ps1`'s job).
  - Code files like .ts / .ps1 — only markdown.

.PARAMETER Files
Optional. Explicit list of files to scan. If omitted, scans staged .md files in
the configured roots. Use this for ad-hoc validation outside pre-commit.

.PARAMETER Roots
Optional. Repo-relative directory roots to scan markdown under. Defaults to:
  .github/agents/, .github/skills/, .github/instructions/, docs/

.PARAMETER Quiet
Only output a one-line summary and exit code. Suppress per-finding detail.

.PARAMETER AllStaged
Force scan ALL staged .md files regardless of root. Useful when this script is
run as a generic gate rather than scoped to known authoring roots.

.EXAMPLE
pwsh .github/knowledge-graph/cli/validate/validate-paths.ps1
pwsh .github/knowledge-graph/cli/validate/validate-paths.ps1 -Files .github/agents/Mentor.agent.md
pwsh .github/knowledge-graph/cli/validate/validate-paths.ps1 -Quiet
pwsh .github/knowledge-graph/cli/validate/validate-paths.ps1 -AllStaged

.OUTPUTS
Exit code 0 = all paths resolve. Exit code 1 = at least one unresolved path.
Exit code 2 = invocation error (bad args, not in a git repo, etc.).
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string[]]$Files,

    [Parameter()]
    [string[]]$Roots = @(
        '.github/agents/',
        '.github/skills/',
        '.github/instructions/',
        'docs/'
    ),

    [Parameter()]
    [switch]$Quiet,

    [Parameter()]
    [switch]$AllStaged
)

$ErrorActionPreference = 'Stop'

# Resolve repo root via git.
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot -or $LASTEXITCODE -ne 0) {
    Write-Host "Not in a git repository." -ForegroundColor Red
    exit 2
}
$repoRoot = $repoRoot.TrimEnd('/', '\')

# 1. Build the file list.
$mdFiles = @()
if ($Files) {
    $mdFiles = $Files | Where-Object { $_ -match '\.md$' }
} else {
    $staged = git diff --cached --name-only --diff-filter=ACM 2>$null
    if (-not $staged) {
        if (-not $Quiet) {
            Write-Host "No staged files. Nothing to validate." -ForegroundColor Gray
        }
        exit 0
    }
    $stagedMd = @($staged | Where-Object { $_ -match '\.md$' })
    if ($AllStaged) {
        $mdFiles = $stagedMd
    } else {
        $mdFiles = $stagedMd | Where-Object {
            $f = $_
            ($Roots | Where-Object { $f.StartsWith($_) }).Count -gt 0
        }
    }
}

if (-not $mdFiles -or $mdFiles.Count -eq 0) {
    if (-not $Quiet) {
        Write-Host "No markdown files in scope. Nothing to validate." -ForegroundColor Gray
    }
    exit 0
}

# 2. Path-like-token regex.
# Repo-relative paths: start with `.github/`, `.profiles/`, `.claude/`, `.copilot/`,
# `docs/`, `extensions/`, `scripts/`, `src/`, OR any segment ending in a known
# code/data extension. We anchor on (?<![A-Za-z0-9_/]) to avoid matching the
# trailing half of `https://...`. Token allows `{template}` placeholders, which
# we treat as wildcards when resolving.
$pathRegex = [regex]'(?<![A-Za-z0-9_/])((?:\.github|\.profiles|\.claude|\.copilot|docs|extensions|scripts|src)(?:/[A-Za-z0-9_.{}-]+)+|[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.{}-]+)+\.(?:md|ps1|psm1|json|ts|tsx|cs|yaml|yml|toml|html|css|js))'

# Files referenced via templated paths (`{username}`) can't be verified — skip silently.
# A separate audit can dig into templates if needed.

$findings = [System.Collections.Generic.List[object]]::new()

foreach ($f in $mdFiles) {
    # Support both repo-relative paths (from git diff) and absolute paths
    # (from ad-hoc -Files invocations). On Windows, Join-Path on an absolute
    # second arg produces garbage like "C:\repo\C:\Users\foo" — must guard.
    $abs = if ([System.IO.Path]::IsPathRooted($f)) { $f } else { Join-Path $repoRoot $f }
    if (-not (Test-Path $abs)) {
        # File staged for delete or already gone — nothing to validate.
        continue
    }

    $lines = Get-Content $abs
    $lineNo = 0
    $inFence = $false
    $skipFence = $false

    foreach ($line in $lines) {
        $lineNo++

        # Track ```fenced code``` blocks. Some fence languages are runnable
        # commands that legitimately reference repo paths (shell, PowerShell,
        # pwsh, bash, sh, batch, cmd) — we DO want to validate those. Others
        # are example output, syntax demos, or other-language code that
        # commonly contains slash-separated text that isn't a repo path
        # (json, yaml, ts, tsx, js, html, css, mermaid, sql) — skip those.
        if ($line -match '^\s*```(\w+)?') {
            $fenceLang = if ($matches[1]) { $matches[1].ToLower() } else { '' }
            if (-not $inFence) {
                # Opening a fence.
                $inFence = $true
                $runnableLangs = @('powershell','pwsh','ps','shell','sh','bash','zsh','cmd','batch','console','text','plaintext','')
                $skipFence = ($runnableLangs -notcontains $fenceLang)
            } else {
                # Closing a fence.
                $inFence = $false
                $skipFence = $false
            }
            continue
        }
        if ($inFence -and $skipFence) { continue }

        foreach ($match in $pathRegex.Matches($line)) {
            $raw = $match.Value
            $candidate = $raw.TrimEnd('.', ',', ')', ']', ':', ';', '`', '"', "'")

            # Skip URLs (defensive — anchor should already prevent these).
            if ($candidate -match '^https?:' -or $candidate -match '^@') { continue }
            # Skip namespace ids like `skill:foo/bar`.
            if ($candidate -match '^[a-z-]+:[^/]') { continue }
            # Skip templated paths (`{username}`) — cannot verify, separate concern.
            if ($candidate -match '\{[^}]+\}') { continue }
            # Skip pure-relative anchors in markdown links like `(#section)` (regex
            # shouldn't catch them, but defensive).
            if ($candidate.StartsWith('#')) { continue }

            $diskPath = Join-Path $repoRoot $candidate
            if (Test-Path $diskPath) { continue }

            # Try resolving relative to the source file's own directory (handles
            # frontmatter `skills:` arrays and intra-doc links like `../foo.md`).
            $sourceDir = Split-Path $abs -Parent
            $relPath = Join-Path $sourceDir $candidate
            if (Test-Path $relPath) { continue }

            $findings.Add([pscustomobject]@{
                File   = $f
                Line   = $lineNo
                Path   = $candidate
                Excerpt = $line.Trim()
            })
        }
    }
}

# 3. Report.
if ($Quiet) {
    Write-Host "Path validation findings: $($findings.Count)"
    if ($findings.Count -gt 0) { exit 1 } else { exit 0 }
}

if ($findings.Count -eq 0) {
    Write-Host "✓ All path references in staged markdown resolve to real files ($($mdFiles.Count) file(s) scanned)." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "=== Path Validation Report ===" -ForegroundColor Cyan
Write-Host "Files scanned: $($mdFiles.Count)"
Write-Host "Broken references: $($findings.Count)"
Write-Host ""

foreach ($group in $findings | Group-Object File) {
    Write-Host "● $($group.Name)" -ForegroundColor Yellow
    foreach ($f in $group.Group) {
        Write-Host "    line $($f.Line):  $($f.Path)" -ForegroundColor White
        Write-Host "                $($f.Excerpt)" -ForegroundColor DarkGray
    }
    Write-Host ""
}

Write-Host "How to fix:" -ForegroundColor Cyan
Write-Host "  1. The path moved or was renamed — update the markdown to the new path."
Write-Host "  2. The path was a typo or guess — replace with the real path."
Write-Host "  3. The file should exist but doesn't — create it before committing."
Write-Host ""
Write-Host "Why this gate exists: source markdown is what feeds the graph extractor."
Write-Host "Broken paths in source MD become stub nodes, then auto-fix failures, then"
Write-Host "reverts. The 2026-06-04 Mentor.agent.md edit is the canonical case."
Write-Host ""

exit 1
