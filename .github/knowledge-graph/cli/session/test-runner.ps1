#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Interactive runner for *.test.md behavioral specs.

.DESCRIPTION
    Sub-dispatcher under `kg test`. Three flavors:

      kg test list   [-State fresh|stale|never-run|all]
      kg test run    <slug>
      kg test record <slug> -Result <PASS|PARTIAL|FAIL> -Notes "..." [-Evidence "..."]

    `run` is interactive: prints the scenario, copies the User prompt to the
    clipboard, opens the spec in VS Code, then prompts for result + notes and
    writes the Actual Result block back to the spec.

    `record` is non-interactive: skips the prompts and just stamps the spec.

    `list` reuses the behavioral suite's classifier so freshness matches
    `pwsh scripts/test.ps1 -Suite behavioral`.

.NOTES
    Spec lookup: any *.test.md under .github/tests, .github/skills, or
    extensions where the basename (without .test) matches the slug.
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Action = '',

    [Parameter(ValueFromRemainingArguments=$true)]
    [object[]]$RestArgs = @()
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path

# Normalize for the rest of the script (preserves the original idiom).
$action = $Action
$rest   = @()
if ($null -ne $RestArgs) { $rest = @($RestArgs) }

function Show-Usage {
    Write-Host @"
kg test — behavioral spec runner

  kg test list   [-State fresh|stale|never-run|all]
  kg test run    <slug>
  kg test record <slug> -Result <PASS|PARTIAL|FAIL> -Notes "..." [-Evidence "..."]

EXAMPLES
  kg test list -State never-run
  kg test run cad-blob-uploader
  kg test record cad-blob-uploader -Result PASS -Notes "Ran end-to-end."
"@
}

# ---------- Helpers ----------

function Find-Spec {
    param([Parameter(Mandatory)][string]$Slug)
    $candidates = @(
        Get-ChildItem -Path (Join-Path $repoRoot '.github/tests')   -Filter "$Slug.test.md" -Recurse -ErrorAction SilentlyContinue
        Get-ChildItem -Path (Join-Path $repoRoot '.github/skills')  -Filter "$Slug.test.md" -Recurse -ErrorAction SilentlyContinue
        Get-ChildItem -Path (Join-Path $repoRoot 'extensions')      -Filter "$Slug.test.md" -Recurse -ErrorAction SilentlyContinue
    )
    if ($candidates.Count -eq 0) { return $null }
    if ($candidates.Count -gt 1) {
        Write-Host "Multiple specs match '$Slug':" -ForegroundColor Yellow
        $candidates | ForEach-Object { Write-Host "  $($_.FullName.Substring($repoRoot.Length + 1))" }
        Write-Host "Pick one and use the full path or a more specific slug." -ForegroundColor Yellow
        return $null
    }
    return $candidates[0]
}

function Get-SpecSection {
    param([string]$Content, [string]$Header)
    # Returns the body between "## $Header" and the next "## " header (or EOF).
    $pattern = '(?ms)^##\s+' + [regex]::Escape($Header) + '\s*$(.*?)(?=^##\s+|\z)'
    $m = [regex]::Match($Content, $pattern)
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    return ''
}

function Get-UserPromptBlock {
    param([string]$Content)
    # Find a fenced code block under "## Test Scenario" (or "## Scenario").
    $scenario = Get-SpecSection -Content $Content -Header 'Test Scenario'
    if (-not $scenario) { $scenario = Get-SpecSection -Content $Content -Header 'Scenario' }
    if (-not $scenario) { return $null }
    $m = [regex]::Match($scenario, '(?ms)```[a-z]*\s*\r?\n(.*?)\r?\n```')
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    return $null
}

function Set-ActualResult {
    param(
        [Parameter(Mandatory)][string]$SpecPath,
        [Parameter(Mandatory)][ValidateSet('PASS','PARTIAL','FAIL')][string]$Result,
        [string]$Notes = '',
        [string]$Evidence = ''
    )
    $content = Get-Content $SpecPath -Raw -Encoding utf8
    $today = (Get-Date).ToString('yyyy-MM-dd')

    $evidenceLine = if ($Evidence) { "**Evidence:**`n$Evidence`n" } else { '' }
    $notesLine    = if ($Notes)    { "**Notes:**`n$Notes`n" }       else { '' }

    $newBlock = @"
## Actual Result

**Date run:** $today
**Result:** $Result

$notesLine
$evidenceLine
"@

    # Replace existing ## Actual Result section (to end of file).
    $pattern = '(?ms)^##\s+Actual Result\s*$.*\z'
    $m = [regex]::Match($content, $pattern)
    if ($m.Success) {
        $updated = $content.Substring(0, $m.Index) + $newBlock
    } else {
        # Append a new Actual Result section.
        if (-not $content.EndsWith("`n")) { $content += "`n" }
        $updated = $content + "`n$newBlock"
    }

    Set-Content -Path $SpecPath -Value $updated -Encoding utf8
}

function Get-AllSpecs {
    return @(
        Get-ChildItem -Path (Join-Path $repoRoot '.github/tests')  -Filter '*.test.md' -ErrorAction SilentlyContinue
        Get-ChildItem -Path (Join-Path $repoRoot '.github/skills') -Filter '*.test.md' -Recurse -ErrorAction SilentlyContinue
        Get-ChildItem -Path (Join-Path $repoRoot 'extensions')     -Filter '*.test.md' -Recurse -ErrorAction SilentlyContinue
    )
}

function Get-SpecState {
    # Returns 'never-run' | 'fresh' (we don't compute stale here — that needs git;
    # reuse the behavioral suite for full classification).
    param([System.IO.FileInfo]$Spec)
    $content = Get-Content $Spec.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return 'never-run' }
    $m = [regex]::Match($content, '(?im)^\*\*Date run:\*\*\s*([^\r\n]+?)\s*$')
    if (-not $m.Success) { return 'never-run' }
    $dateStr = $m.Groups[1].Value.Trim()
    if ($dateStr -match '^_?Not yet run\._?$' -or $dateStr -eq '' -or $dateStr -match '^\{.*\}$') {
        return 'never-run'
    }
    return 'fresh'
}

# ---------- Actions ----------

function Action-List {
    # Use the behavioral suite for authoritative classification (handles stale).
    $behavioralPath = Join-Path $repoRoot 'scripts/test-suites/behavioral.ps1'
    if (-not (Test-Path $behavioralPath)) {
        Write-Host "behavioral.ps1 not found — falling back to never-run/fresh only" -ForegroundColor Yellow
        $stateFilter = if ($rest.Count -ge 2 -and $rest[0] -eq '-State') { $rest[1] } else { 'all' }
        $rows = Get-AllSpecs | ForEach-Object {
            [PSCustomObject]@{
                slug  = $_.BaseName -replace '\.test$', ''
                state = Get-SpecState -Spec $_
                file  = $_.FullName.Substring($repoRoot.Length + 1) -replace '\\', '/'
            }
        }
        if ($stateFilter -ne 'all') { $rows = $rows | Where-Object { $_.state -eq $stateFilter } }
        $rows | Sort-Object state, slug | Format-Table -AutoSize
        return
    }

    $stateFilter = 'all'
    for ($i = 0; $i -lt $rest.Count; $i++) {
        if ($rest[$i] -eq '-State' -and $i + 1 -lt $rest.Count) { $stateFilter = $rest[$i + 1].ToLower() }
    }

    Write-Host "Running behavioral classifier..." -ForegroundColor DarkGray
    $result = & $behavioralPath -RepoRoot $repoRoot

    $rows = @()
    foreach ($name in @($result.fresh))    { $rows += [PSCustomObject]@{ state='fresh';     slug=($name -replace '\.test\.md$', '') } }
    foreach ($name in @($result.stale))    { $rows += [PSCustomObject]@{ state='stale';     slug=($name -replace '\.test\.md$', '') } }
    foreach ($name in @($result.neverRun)) { $rows += [PSCustomObject]@{ state='never-run'; slug=($name -replace '\.test\.md$', '') } }

    if ($stateFilter -ne 'all') {
        $rows = $rows | Where-Object { $_.state -eq $stateFilter }
    }

    Write-Host ""
    Write-Host $result.detail -ForegroundColor Cyan
    Write-Host ""
    $rows | Sort-Object state, slug | Format-Table -AutoSize
}

function Action-Run {
    if ($rest.Count -lt 1) { Write-Host "kg test run: missing <slug>" -ForegroundColor Red; Show-Usage; exit 2 }
    $slug = $rest[0]
    $spec = Find-Spec -Slug $slug
    if (-not $spec) { Write-Host "kg test run: no spec matches '$slug'" -ForegroundColor Red; exit 2 }

    $relPath = $spec.FullName.Substring($repoRoot.Length + 1) -replace '\\', '/'
    $content = Get-Content $spec.FullName -Raw -Encoding utf8
    $prompt  = Get-UserPromptBlock -Content $content

    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "  Spec: $relPath" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host ""

    $setup = Get-SpecSection -Content $content -Header 'Setup'
    if ($setup) {
        Write-Host "SETUP" -ForegroundColor Yellow
        Write-Host $setup -ForegroundColor DarkGray
        Write-Host ""
    }

    if ($prompt) {
        Write-Host "USER PROMPT (copied to clipboard)" -ForegroundColor Yellow
        Write-Host "----------------------------------" -ForegroundColor DarkGray
        Write-Host $prompt
        Write-Host "----------------------------------" -ForegroundColor DarkGray
        try { Set-Clipboard -Value $prompt } catch { Write-Host "(clipboard unavailable: $_)" -ForegroundColor DarkYellow }
    } else {
        Write-Host "(no fenced User prompt found in spec — paste the Scenario manually)" -ForegroundColor DarkYellow
    }

    Write-Host ""
    Write-Host "NEXT STEPS" -ForegroundColor Yellow
    Write-Host "  1. Open a fresh Copilot Chat and type @Mentor"
    Write-Host "  2. Paste the prompt (Ctrl+V) and submit"
    Write-Host "  3. Watch the response against the Expected Behavior / Pass Criteria"
    Write-Host "  4. Come back here and record the result"
    Write-Host ""

    # Try to open the spec in VS Code so the user can see Expected Behavior.
    try { & code $spec.FullName 2>$null } catch { }

    Read-Host "Press Enter when the chat run is complete (or Ctrl+C to abort)" | Out-Null

    Write-Host ""
    $resultChoice = $null
    while (-not $resultChoice) {
        $raw = Read-Host "Result? [P]ass / pa[R]tial / [F]ail / [S]kip"
        switch ($raw.ToUpper()) {
            'P' { $resultChoice = 'PASS' }
            'R' { $resultChoice = 'PARTIAL' }
            'F' { $resultChoice = 'FAIL' }
            'S' { Write-Host "Skipped — spec untouched." -ForegroundColor DarkGray; return }
            default { Write-Host "  (enter P, R, F, or S)" -ForegroundColor DarkYellow }
        }
    }

    Write-Host "Notes (one line, observations from the run):"
    $notes = Read-Host "  "

    Write-Host "Evidence (one line — transcript excerpt / link / file change, optional):"
    $evidence = Read-Host "  "

    Set-ActualResult -SpecPath $spec.FullName -Result $resultChoice -Notes $notes -Evidence $evidence

    Write-Host ""
    Write-Host "[OK] Wrote Actual Result to $relPath" -ForegroundColor Green
    Write-Host "     Run 'pwsh scripts/test.ps1 -Suite behavioral' to refresh the classifier." -ForegroundColor DarkGray
}

function Action-Record {
    if ($rest.Count -lt 1) { Write-Host "kg test record: missing <slug>" -ForegroundColor Red; Show-Usage; exit 2 }
    $slug = $rest[0]
    $spec = Find-Spec -Slug $slug
    if (-not $spec) { Write-Host "kg test record: no spec matches '$slug'" -ForegroundColor Red; exit 2 }

    $result = ''; $notes = ''; $evidence = ''
    for ($i = 1; $i -lt $rest.Count; $i++) {
        switch ($rest[$i]) {
            '-Result'   { $result   = $rest[$i + 1]; $i++ }
            '-Notes'    { $notes    = $rest[$i + 1]; $i++ }
            '-Evidence' { $evidence = $rest[$i + 1]; $i++ }
        }
    }
    if ($result -notin @('PASS','PARTIAL','FAIL')) {
        Write-Host "kg test record: -Result must be PASS, PARTIAL, or FAIL (got '$result')" -ForegroundColor Red
        exit 2
    }

    Set-ActualResult -SpecPath $spec.FullName -Result $result -Notes $notes -Evidence $evidence
    $relPath = $spec.FullName.Substring($repoRoot.Length + 1) -replace '\\', '/'
    Write-Host "[OK] Wrote Actual Result to $relPath" -ForegroundColor Green
}

# ---------- Dispatch ----------

switch ($action) {
    'list'   { Action-List }
    'run'    { Action-Run }
    'record' { Action-Record }
    'help'   { Show-Usage }
    '-h'     { Show-Usage }
    '--help' { Show-Usage }
    ''       { Show-Usage; exit 2 }
    default  { Write-Host "kg test: unknown action '$action'" -ForegroundColor Red; Show-Usage; exit 2 }
}
