<#
.SYNOPSIS
Derive snapshot views (session_history, method_proficiency, quiz_history,
concept_proficiency) from field:profile.events.

.DESCRIPTION
Pure function — reads progress.json, prints derived views as JSON to stdout.
NEVER writes. Implements rule:events-are-source-of-truth: the events array is
authoritative; everything else is a recomputation. Mirrors the rollup rules
documented in rule:proficiency-derived-from-quiz-history (3+ correct quizzes
across 2+ sessions bumps tier; callbacks bump guided->independent).

.PARAMETER Username
Github username (folder name under .../profiles/mentees/ or mentors/).

.PARAMETER ProjectId
Project slug.

.PARAMETER Role
Which role folder to read from. 'mentee' (default) or 'mentor'.

.PARAMETER View
Optional. If supplied, returns only the named view. One of:
  all (default) | session_history | method_proficiency |
  quiz_history  | concept_proficiency

.EXAMPLE
./derive-views.ps1 -Username alex_smith -ProjectId weather-api
# -> all four views as one JSON object

.EXAMPLE
./derive-views.ps1 -Username alex_smith -ProjectId weather-api -View quiz_history
# -> just the quiz_history array

.NOTES
Exit codes: 0 success, 2 environment error (profile missing).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Username,

    [Parameter(Mandatory)]
    [string]$ProjectId,

    [ValidateSet('mentee','mentor')]
    [string]$Role = 'mentee',

    [ValidateSet('all','session_history','method_proficiency','quiz_history','concept_proficiency')]
    [string]$View = 'all'
)

$ErrorActionPreference = 'Stop'

function Resolve-ProgressPath {
    param([string]$User, [string]$Project, [string]$RoleFolder)

    $roleDir = if ($RoleFolder -eq 'mentor') { 'mentors' } else { 'mentees' }

    $mentorHome = $env:MSSA_MENTOR_HOME
    if (-not [string]::IsNullOrWhiteSpace($mentorHome)) {
        $base = Join-Path $mentorHome "profiles/$roleDir"
    } else {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..')
        $base = Join-Path $repoRoot ".profiles/profiles/$roleDir"
    }

    return (Join-Path (Join-Path $base $User) "$Project.progress.json")
}

function Read-Events {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Error "progress.json not found: $Path"
        exit 2
    }

    $progress = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 |
        ConvertFrom-Json -AsHashtable -Depth 32

    if (-not $progress.Contains('events') -or $null -eq $progress['events']) {
        return @()
    }
    return @($progress['events'])
}

# --- Derivers (one per view, all pure) ---

function Get-SessionHistory {
    param([array]$Events)

    # Pair session_started with session_ended on session_id. Unclosed sessions
    # are still listed (ended_at = null) so wrap-up gates can spot them.
    $started = @{}
    $ended   = @{}

    foreach ($e in $Events) {
        if ($e.type -eq 'session_started') { $started[$e.session_id] = $e }
        if ($e.type -eq 'session_ended')   { $ended[$e.session_id]   = $e }
    }

    $rows = foreach ($sid in $started.Keys) {
        $s = $started[$sid]
        $end = $ended[$sid]
        [ordered]@{
            session_id = $sid
            started_at = $s.ts
            ended_at   = if ($end) { $end.ts } else { $null }
            started_data = $s.data
            ended_data   = if ($end) { $end.data } else { $null }
        }
    }

    return @($rows | Sort-Object started_at)
}

function Get-MethodProficiency {
    param([array]$Events)

    $methodEvents = @($Events | Where-Object { $_.type -eq 'method_used' })
    if ($methodEvents.Count -eq 0) { return @() }

    $byMethod = @{}
    foreach ($e in $methodEvents) {
        $m = $e.data.method
        if ([string]::IsNullOrWhiteSpace($m)) { continue }
        if (-not $byMethod.ContainsKey($m)) {
            $byMethod[$m] = [ordered]@{
                method     = $m
                used_count = 0
                last_used  = $null
            }
        }
        $byMethod[$m].used_count++
        if ($null -eq $byMethod[$m].last_used -or $e.ts -gt $byMethod[$m].last_used) {
            $byMethod[$m].last_used = $e.ts
        }
    }

    return @($byMethod.Values | Sort-Object -Property @{Expression={$_.used_count}; Descending=$true})
}

function Get-QuizHistory {
    param([array]$Events)

    # Mirror the legacy quiz_history shape (one row per quiz_answered).
    # quiz_asked events stay in the raw log; only answered events become snapshot rows.
    $rows = foreach ($e in $Events | Where-Object { $_.type -eq 'quiz_answered' }) {
        [ordered]@{
            ts         = $e.ts
            session_id = $e.session_id
            concept_id = $e.data.concept_id
            trigger    = $e.data.trigger
            form       = $e.data.form
            question   = $e.data.question
            answer     = $e.data.answer
            correct    = [bool]$e.data.correct
        }
    }

    return @($rows | Sort-Object ts)
}

function Get-ConceptProficiency {
    param([array]$Events)

    # Per rule:proficiency-derived-from-quiz-history:
    #   - 3+ correct quiz_answered events across 2+ distinct sessions => bump up one tier
    #   - 1 callback_made with success=true => guided -> independent
    #   - incorrect answers never downgrade
    # Tier order: unknown -> exposed -> guided -> independent -> teach-back
    $tierOrder = @('unknown','exposed','guided','independent','teach-back')

    # First pass: explicit calibration events set a baseline tier.
    $byConcept = @{}
    foreach ($e in $Events | Where-Object { $_.type -in @('concept_taught','concept_calibrated') }) {
        $c = $e.data.concept_id
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        if (-not $byConcept.ContainsKey($c)) {
            $byConcept[$c] = [ordered]@{
                concept_id = $c
                tier       = 'exposed'
                evidence   = [ordered]@{ correct_quizzes = 0; distinct_sessions = @(); callback_successes = 0 }
                last_seen  = $e.ts
            }
        } else {
            $byConcept[$c].last_seen = $e.ts
        }
        if ($e.type -eq 'concept_calibrated' -and $e.data.tier) {
            $byConcept[$c].tier = $e.data.tier
        }
    }

    # Second pass: tally quiz + callback evidence.
    foreach ($e in $Events | Where-Object { $_.type -eq 'quiz_answered' -and $_.data.correct }) {
        $c = $e.data.concept_id
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        if (-not $byConcept.ContainsKey($c)) {
            $byConcept[$c] = [ordered]@{
                concept_id = $c
                tier       = 'exposed'
                evidence   = [ordered]@{ correct_quizzes = 0; distinct_sessions = @(); callback_successes = 0 }
                last_seen  = $e.ts
            }
        }
        $byConcept[$c].evidence.correct_quizzes++
        if ($byConcept[$c].evidence.distinct_sessions -notcontains $e.session_id) {
            $byConcept[$c].evidence.distinct_sessions += $e.session_id
        }
        if ($e.ts -gt $byConcept[$c].last_seen) { $byConcept[$c].last_seen = $e.ts }
    }

    foreach ($e in $Events | Where-Object { $_.type -eq 'callback_made' -and $_.data.success }) {
        $c = $e.data.concept_id
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        if (-not $byConcept.ContainsKey($c)) {
            $byConcept[$c] = [ordered]@{
                concept_id = $c
                tier       = 'guided'
                evidence   = [ordered]@{ correct_quizzes = 0; distinct_sessions = @(); callback_successes = 0 }
                last_seen  = $e.ts
            }
        }
        $byConcept[$c].evidence.callback_successes++
        if ($e.ts -gt $byConcept[$c].last_seen) { $byConcept[$c].last_seen = $e.ts }
    }

    # Third pass: apply tier-bump rules (cumulative — does not regress).
    foreach ($c in $byConcept.Keys) {
        $row = $byConcept[$c]
        $idx = [array]::IndexOf($tierOrder, $row.tier)
        if ($idx -lt 0) { $idx = 1 }  # default 'exposed'

        $ev = $row.evidence
        if ($ev.correct_quizzes -ge 3 -and ($ev.distinct_sessions.Count) -ge 2) {
            $idx = [Math]::Min($idx + 1, $tierOrder.Count - 1)
        }
        if ($ev.callback_successes -ge 1 -and $row.tier -eq 'guided') {
            $idx = [Math]::Max($idx, [array]::IndexOf($tierOrder, 'independent'))
        }
        $row.tier = $tierOrder[$idx]
        # Cast distinct_sessions to plain count for JSON cleanliness.
        $row.evidence.distinct_sessions = $ev.distinct_sessions.Count
    }

    return @($byConcept.Values | Sort-Object concept_id)
}

# --- Main ---

$path   = Resolve-ProgressPath -User $Username -Project $ProjectId -RoleFolder $Role
$events = Read-Events -Path $path

switch ($View) {
    'session_history'      { ,(@(Get-SessionHistory     -Events $events)) | ConvertTo-Json -Depth 16 }
    'method_proficiency'   { ,(@(Get-MethodProficiency  -Events $events)) | ConvertTo-Json -Depth 16 }
    'quiz_history'         { ,(@(Get-QuizHistory        -Events $events)) | ConvertTo-Json -Depth 16 }
    'concept_proficiency'  { ,(@(Get-ConceptProficiency -Events $events)) | ConvertTo-Json -Depth 16 }
    'all' {
        $bundle = [ordered]@{
            session_history     = @(Get-SessionHistory     -Events $events)
            method_proficiency  = @(Get-MethodProficiency  -Events $events)
            quiz_history        = @(Get-QuizHistory        -Events $events)
            concept_proficiency = @(Get-ConceptProficiency -Events $events)
        }
        $bundle | ConvertTo-Json -Depth 16 -AsArray:$false
    }
}
