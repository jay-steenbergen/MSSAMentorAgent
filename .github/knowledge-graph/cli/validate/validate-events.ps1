#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Validates the events[] array shape in all learner progress files.

.DESCRIPTION
    Scans .profiles/profiles/mentees/*/*.progress.json files and verifies, per
    rule:events-are-source-of-truth, that each event in field:profile.events
    conforms to the envelope contract:
      - ts          : ISO-8601 UTC timestamp (parseable by [datetime])
      - type        : one of the 10 canonical event types
      - session_id  : non-empty string (UUID-shaped)
      - project_id  : matches the filename stem (<project_id>.progress.json)
      - data        : null or a JSON object (never a primitive or array)

    Append-only ordering is also checked: events must be sorted by ts ASC.

    This replaces the old validate-proficiency.ps1, which checked a snapshot
    shape that no longer has a single writer. method_proficiency, quiz_history,
    session_history, and concept_proficiency are now derived views computed
    by cli-tool:derive-views from this events[] log.

.PARAMETER Username
    If supplied, validates only that learner's *.progress.json files.
    Otherwise scans every learner under .profiles/profiles/mentees/ AND mentors/.

.PARAMETER Role
    Limit scan to one role folder: 'mentee' or 'mentor'. If unset, both are scanned.

.PARAMETER RepoRoot
    Explicit repo root override. Defaults to the repo containing this script.

.EXAMPLE
    pwsh .github/knowledge-graph/cli/validate/validate-events.ps1
    Scans all progress files, reports per-file status, exits 1 on any failure.

.EXAMPLE
    pwsh .github/knowledge-graph/cli/validate/validate-events.ps1 -Username test_user
    Validates only test_user's progress files.

.OUTPUTS
    Per-file status lines to stdout. Exit code 0 on full pass, 1 on any errors.
#>
[CmdletBinding()]
param(
    [string]$Username,
    [ValidateSet('mentee','mentor')]
    [string]$Role,
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

# Resolve repo root: this script lives at <repo>/.github/knowledge-graph/cli/
if (-not $RepoRoot) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $RepoRoot = Resolve-Path (Join-Path $scriptDir '..' '..' '..' '..') | Select-Object -ExpandProperty Path
}

$roleFolders = switch ($Role) {
    'mentee' { @('mentees') }
    'mentor' { @('mentors') }
    default  { @('mentees','mentors') }
}
$profilesDirs = $roleFolders | ForEach-Object { Join-Path $RepoRoot '.profiles' 'profiles' $_ }

$validEventTypes = @(
    'session_started'
    'session_ended'
    'concept_taught'
    'concept_calibrated'
    'quiz_asked'
    'quiz_answered'
    'method_used'
    'analogy_offered'
    'callback_made'
    'celebration'
)

function Test-Event {
    param(
        [object]$Event,
        [int]$Index,
        [string]$ExpectedProjectId
    )

    $errors = @()

    # ts: present, string, ISO-8601 parseable
    if (-not $Event.PSObject.Properties['ts']) {
        $errors += "events[$Index]: missing 'ts'"
    } else {
        $parsed = [datetime]::MinValue
        if (-not [datetime]::TryParse([string]$Event.ts, [ref]$parsed)) {
            $errors += "events[$Index].ts is not ISO-8601 parseable: '$($Event.ts)'"
        }
    }

    # type: present and in enum
    if (-not $Event.PSObject.Properties['type']) {
        $errors += "events[$Index]: missing 'type'"
    } elseif ($Event.type -notin $validEventTypes) {
        $errors += "events[$Index].type '$($Event.type)' is not in enum ($($validEventTypes -join ', '))"
    }

    # session_id: present and non-empty string
    if (-not $Event.PSObject.Properties['session_id']) {
        $errors += "events[$Index]: missing 'session_id'"
    } elseif ([string]::IsNullOrWhiteSpace([string]$Event.session_id)) {
        $errors += "events[$Index].session_id is empty"
    }

    # project_id: present, matches filename
    if (-not $Event.PSObject.Properties['project_id']) {
        $errors += "events[$Index]: missing 'project_id'"
    } elseif ([string]$Event.project_id -ne $ExpectedProjectId) {
        $errors += "events[$Index].project_id '$($Event.project_id)' != filename stem '$ExpectedProjectId'"
    }

    # data: null OR a PSCustomObject (JSON object). Arrays/primitives rejected.
    if ($Event.PSObject.Properties['data']) {
        $data = $Event.data
        if ($null -ne $data) {
            if ($data -is [System.Array]) {
                $errors += "events[$Index].data is an array; must be null or an object"
            } elseif ($data -is [string] -or $data -is [bool] -or $data -is [int] -or $data -is [long] -or $data -is [double]) {
                $errors += "events[$Index].data is a primitive ($($data.GetType().Name)); must be null or an object"
            }
        }
    }
    # If 'data' property is missing entirely, treat as equivalent to null — no error.

    return $errors
}

function Get-ProgressFiles {
    param([string]$Username)

    $all = @()
    foreach ($dir in $profilesDirs) {
        if (-not (Test-Path $dir)) {
            Write-Host "No profiles directory at $dir (skipping)" -ForegroundColor DarkGray
            continue
        }

        if ($Username) {
            $userDir = Join-Path $dir $Username
            if (-not (Test-Path $userDir)) { continue }
            $all += Get-ChildItem -Path $userDir -Filter '*.progress.json' -File
        } else {
            $all += Get-ChildItem -Path $dir -Filter '*.progress.json' -File -Recurse
        }
    }
    return $all
}

$files = Get-ProgressFiles -Username $Username

if ($files.Count -eq 0) {
    Write-Host 'No progress files found.' -ForegroundColor Yellow
    exit 0
}

$totalErrors = 0
$totalEvents = 0
$filesOk     = 0

foreach ($file in $files) {
    # Filename stem before '.progress.json'
    $projectId = $file.BaseName -replace '\.progress$', ''

    try {
        $json = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
    } catch {
        Write-Host "FAIL  $($file.FullName)  -- invalid JSON: $($_.Exception.Message)" -ForegroundColor Red
        $totalErrors++
        continue
    }

    # events[] is optional today (legacy files), but if present it must be an array.
    if (-not $json.PSObject.Properties['events']) {
        Write-Host "SKIP  $($file.FullName)  -- no events[] field (legacy / pre-Phase-1)" -ForegroundColor DarkGray
        continue
    }

    $events = $json.events
    if ($null -eq $events) {
        Write-Host "OK    $($file.FullName)  -- events is null (0 events)" -ForegroundColor Green
        $filesOk++
        continue
    }

    if ($events -isnot [System.Array]) {
        Write-Host "FAIL  $($file.FullName)  -- events is not an array" -ForegroundColor Red
        $totalErrors++
        continue
    }

    $fileErrors = @()
    $prevTs = $null
    for ($i = 0; $i -lt $events.Count; $i++) {
        $e = $events[$i]
        $fileErrors += Test-Event -Event $e -Index $i -ExpectedProjectId $projectId

        # Append-only ordering
        if ($e.PSObject.Properties['ts']) {
            $parsed = [datetime]::MinValue
            if ([datetime]::TryParse([string]$e.ts, [ref]$parsed)) {
                if ($null -ne $prevTs -and $parsed -lt $prevTs) {
                    $fileErrors += "events[$i].ts ($($e.ts)) is earlier than events[$($i - 1)].ts ($($prevTs.ToString('o'))) -- events must be append-only ASC"
                }
                $prevTs = $parsed
            }
        }
    }

    $totalEvents += $events.Count

    if ($fileErrors.Count -eq 0) {
        Write-Host "OK    $($file.FullName)  -- $($events.Count) events" -ForegroundColor Green
        $filesOk++
    } else {
        Write-Host "FAIL  $($file.FullName)  -- $($fileErrors.Count) error(s):" -ForegroundColor Red
        foreach ($err in $fileErrors) { Write-Host "        $err" -ForegroundColor Red }
        $totalErrors += $fileErrors.Count
    }
}

Write-Host ''
Write-Host "Summary: $filesOk file(s) OK, $totalEvents total events, $totalErrors error(s)" -ForegroundColor Cyan

if ($totalErrors -gt 0) { exit 1 } else { exit 0 }
