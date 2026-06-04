#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Phase 3 backfill: synthesize field:profile.events from legacy snapshot
    fields on a *.progress.json file.

.DESCRIPTION
    Reads a learner progress file containing legacy snapshot fields
    (session_history, method_proficiency, quiz_history, concept_proficiency)
    and writes the minimum events that, when fed through derive-views.ps1,
    reproduce a faithful re-derivation of those snapshots.

    Per the design doc (docs/design/event-log-design.md, Phase 3):
      * single writer remains append-event.ps1 (we invoke it via -BackdateTs)
      * append-only ordering preserved (events emitted oldest-first)
      * one synthetic session_id per legacy session_history entry
      * legacy method_proficiency.level/notes (Familiar/Competent/...) are
        intentionally NOT carried over: the new model derives proficiency
        from used_count + last_used, not free-form level labels.

    Safe to re-run: refuses to migrate a file that already has a non-empty
    events array unless -Force is passed.

.PARAMETER Username
    Profile folder under .profiles/profiles/<role>/

.PARAMETER ProjectId
    Project slug (matches <project_id>.progress.json filename stem).

.PARAMETER Role
    'mentee' (default) or 'mentor'.

.PARAMETER Force
    Migrate even if events[] is already non-empty (appends additional synthetic events).

.PARAMETER DryRun
    Print the planned event sequence to stdout; do not write.

.PARAMETER RepoRoot
    Optional explicit repo root.

.EXAMPLE
    pwsh .github/knowledge-graph/cli/session/migrate-profile-to-events.ps1 `
      -Username test_user -ProjectId cad-02-rest-api

.EXAMPLE
    pwsh .github/knowledge-graph/cli/session/migrate-profile-to-events.ps1 `
      -Username jasteenb -ProjectId mssa-mentor-agent -Role mentor

.EXAMPLE
    pwsh .github/knowledge-graph/cli/session/migrate-profile-to-events.ps1 `
      -Username test_user -ProjectId cad-02-rest-api -DryRun
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Username,

    [Parameter(Mandatory)]
    [string]$ProjectId,

    [ValidateSet('mentee','mentor')]
    [string]$Role = 'mentee',

    [switch]$Force,

    [switch]$DryRun,

    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

# --- Resolve paths ---
if (-not $RepoRoot) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $RepoRoot = Resolve-Path (Join-Path $scriptDir '..' '..' '..' '..') | Select-Object -ExpandProperty Path
}

$roleDir       = if ($Role -eq 'mentor') { 'mentors' } else { 'mentees' }
$progressPath  = Join-Path $RepoRoot ".profiles/profiles/$roleDir/$Username/$ProjectId.progress.json"
$appendEvent   = Join-Path $RepoRoot '.github/knowledge-graph/cli/session/append-event.ps1'

if (-not (Test-Path -LiteralPath $progressPath)) {
    Write-Error "Progress file not found: $progressPath"
    exit 2
}
if (-not (Test-Path -LiteralPath $appendEvent)) {
    Write-Error "append-event.ps1 not found: $appendEvent"
    exit 2
}

# --- Read source snapshot ---
$progress = Get-Content -LiteralPath $progressPath -Raw -Encoding UTF8 |
    ConvertFrom-Json -AsHashtable -Depth 32

$existingEvents = @()
if ($progress.Contains('events') -and $null -ne $progress['events']) {
    $existingEvents = @($progress['events'])
}

if ($existingEvents.Count -gt 0 -and -not $Force) {
    Write-Error "events[] already has $($existingEvents.Count) entries on $progressPath. Re-run with -Force to append more."
    exit 1
}

# --- Synthesize the event sequence ---

# Returns a list of [hashtable]@{ ts; type; session_id; data } the migrator
# will then forward to append-event.ps1 (the single writer).
$plan = New-Object System.Collections.Generic.List[object]

# (1) session_history -> session_started + method_used + session_ended
#     - synthesize ts from legacy "date" (00:00:00Z start) + duration_minutes
#     - mint one session_id per row
$sessionHistory = @()
if ($progress.Contains('session_history') -and $progress['session_history']) {
    $sessionHistory = @($progress['session_history'])
}

foreach ($s in $sessionHistory) {
    $dateRaw = [string]$s.date
    if ([string]::IsNullOrWhiteSpace($dateRaw)) {
        Write-Warning "session_history entry missing 'date'; skipping ($s)"
        continue
    }

    $startDt = [datetime]::MinValue
    if (-not [datetime]::TryParse($dateRaw, [ref]$startDt)) {
        Write-Warning "session_history.date not parseable: '$dateRaw'; skipping"
        continue
    }
    $startUtc = $startDt.ToUniversalTime()
    $durationMin = if ($s.duration_minutes) { [int]$s.duration_minutes } else { 0 }
    $endUtc = $startUtc.AddMinutes($durationMin)

    $sid = [Guid]::NewGuid().ToString()
    $method = [string]$s.method_used
    $milestones = if ($s.milestones_completed) { @($s.milestones_completed) } else { @() }
    $notes = [string]$s.notes

    # session_started — at the start ts
    $plan.Add(@{
        ts         = $startUtc.ToString('o')
        type       = 'session_started'
        session_id = $sid
        data       = (@{
            method = $method
            backfilled_from = 'session_history'
            notes  = $notes
        } | ConvertTo-Json -Compress -Depth 8)
    })

    # method_used — +1 second after session_started so ordering is strict ASC
    if (-not [string]::IsNullOrWhiteSpace($method)) {
        $plan.Add(@{
            ts         = $startUtc.AddSeconds(1).ToString('o')
            type       = 'method_used'
            session_id = $sid
            data       = (@{
                method  = $method
                tier    = $null
                success = $true
                backfilled_from = 'session_history'
            } | ConvertTo-Json -Compress -Depth 8)
        })
    }

    # session_ended — at the end ts
    $methodUsedCount = if ([string]::IsNullOrWhiteSpace($method)) { 0 } else { 1 }
    $plan.Add(@{
        ts         = $endUtc.ToString('o')
        type       = 'session_ended'
        session_id = $sid
        data       = (@{
            outcome = 'completed'
            reason  = 'backfilled from session_history'
            duration_minutes = $durationMin
            milestones_completed = $milestones
            method_used_count = $methodUsedCount
            backfilled_from = 'session_history'
        } | ConvertTo-Json -Compress -Depth 8)
    })
}

# (2) method_proficiency (snapshot) -> intentionally NOT replayed.
#     The new model derives method_proficiency from method_used counts; legacy
#     "level: Competent / notes: ..." cannot be faithfully reduced to discrete
#     events without inventing usage history. The session_history pass above
#     produces one method_used per legacy session, which is the closest
#     honest reconstruction.
$skippedMethodProf = if ($progress.Contains('method_proficiency') -and $progress['method_proficiency']) {
    @($progress['method_proficiency'].Keys).Count
} else { 0 }

# (3) concept_proficiency (snapshot) -> concept_calibrated per concept.
#     Each legacy entry becomes one concept_calibrated event so the derived
#     tier matches the snapshot exactly. Attached to a synthesized "migration"
#     session_id so it does not get paired with any real session.
$migrationSid = [Guid]::NewGuid().ToString()
$migrationTs  = (Get-Date).ToUniversalTime()
$conceptCount = 0
if ($progress.Contains('concept_proficiency') -and $progress['concept_proficiency']) {
    foreach ($conceptId in @($progress['concept_proficiency'].Keys)) {
        $entry = $progress['concept_proficiency'][$conceptId]
        $tier  = [string]$entry.tier
        if ([string]::IsNullOrWhiteSpace($tier)) { $tier = 'exposed' }

        $plan.Add(@{
            ts         = $migrationTs.AddSeconds($conceptCount).ToString('o')
            type       = 'concept_calibrated'
            session_id = $migrationSid
            data       = (@{
                concept_id = $conceptId
                tier       = $tier
                reason     = 'backfilled from concept_proficiency snapshot'
                backfilled_from = 'concept_proficiency'
            } | ConvertTo-Json -Compress -Depth 8)
        })
        $conceptCount++
    }
}

# (4) quiz_history (snapshot) -> quiz_answered per row.
#     Use entry.ts if present; otherwise fall back to migration ts.
$quizCount = 0
if ($progress.Contains('quiz_history') -and $progress['quiz_history']) {
    foreach ($q in @($progress['quiz_history'])) {
        $qTsRaw = [string]$q.ts
        $qDt = $migrationTs.AddMinutes($quizCount + 1)
        if (-not [string]::IsNullOrWhiteSpace($qTsRaw)) {
            $tmp = [datetime]::MinValue
            if ([datetime]::TryParse($qTsRaw, [ref]$tmp)) { $qDt = $tmp.ToUniversalTime() }
        }
        $quizSid = if ($q.session_id) { [string]$q.session_id } else { $migrationSid }
        $plan.Add(@{
            ts         = $qDt.ToString('o')
            type       = 'quiz_answered'
            session_id = $quizSid
            data       = (@{
                concept_id = [string]$q.concept_id
                trigger    = [string]$q.trigger
                form       = [string]$q.form
                question   = [string]$q.question
                answer     = [string]$q.answer
                correct    = [bool]$q.correct
                backfilled_from = 'quiz_history'
            } | ConvertTo-Json -Compress -Depth 8)
        })
        $quizCount++
    }
}

# --- Sort plan by ts to satisfy append-only ordering ---
$sortedPlan = $plan | Sort-Object {
    $dt = [datetime]::MinValue
    [datetime]::TryParse($_.ts, [ref]$dt) | Out-Null
    $dt
}

Write-Host ''
Write-Host "Migration plan for $Role/$Username/$ProjectId" -ForegroundColor Cyan
Write-Host "  Source snapshot: $progressPath"
Write-Host "  Session history rows  : $($sessionHistory.Count)"
Write-Host "  Concept profs synth'd : $conceptCount"
Write-Host "  Quizzes synth'd       : $quizCount"
Write-Host "  Method profs skipped  : $skippedMethodProf (re-derived from session_history)"
Write-Host "  Total events to emit  : $($sortedPlan.Count)"

if ($DryRun) {
    Write-Host ''
    Write-Host '--- DRY RUN: planned events ---' -ForegroundColor Yellow
    foreach ($ev in $sortedPlan) {
        Write-Host ("  {0,-22} {1}  ({2})" -f $ev.type, $ev.ts, $ev.session_id)
    }
    exit 0
}

# --- Forward each event to append-event.ps1 (single-writer invariant) ---
$emitted = 0
foreach ($ev in $sortedPlan) {
    $args = @(
        '-File', $appendEvent,
        '-Username', $Username,
        '-ProjectId', $ProjectId,
        '-Role', $Role,
        '-Type', $ev.type,
        '-SessionId', $ev.session_id,
        '-BackdateTs', $ev.ts,
        '-Data', $ev.data
    )

    $proc = & pwsh -NoProfile @args 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error ("append-event.ps1 failed for type=$($ev.type) ts=$($ev.ts): $proc")
        exit 1
    }
    $emitted++
}

Write-Host ''
Write-Host "Migration complete. Emitted $emitted event(s) to $progressPath" -ForegroundColor Green
Write-Host "Next: pwsh .github/knowledge-graph/cli/session/derive-views.ps1 -Username $Username -ProjectId $ProjectId -Role $Role"
exit 0
