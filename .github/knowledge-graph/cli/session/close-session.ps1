<#
.SYNOPSIS
Wrap-up gate. Verifies a session is closeable, then emits session_ended.

.DESCRIPTION
Phase 1 contract (intentionally loose so existing sessions can close):
  - The given -SessionId MUST have a session_started event on field:profile.events.
  - The given -SessionId MUST NOT already have a session_ended event.
That's it. Phase 4 will tighten requirements (e.g. >= 1 concept_taught,
>= 1 method_used, >= 1 quiz_answered for non-trivial sessions).

On pass, calls cli-tool:append-event to emit session_ended (single writer rule).
On fail, prints diagnostics and exits 2 — non-zero so wrap-up flows can
detect the violation programmatically.

.PARAMETER Username
Mentee github username.

.PARAMETER ProjectId
Project slug.

.PARAMETER SessionId
The session being closed.

.PARAMETER Reason
Optional free-text close reason recorded on session_ended.data.reason.

.PARAMETER Outcome
Optional. One of: completed | partial | abandoned. Recorded on
session_ended.data.outcome. Defaults to 'completed'.

.PARAMETER DryRun
Run the checks and print what would be emitted — do not write.

.EXAMPLE
./close-session.ps1 -Username alex_smith -ProjectId weather-api `
  -SessionId 6db81745-... -Outcome completed -Reason 'AAR done'

.NOTES
Exit codes: 0 success, 1 gate failed (closeable diagnostics printed),
2 environment error.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Username,

    [Parameter(Mandatory)]
    [string]$ProjectId,

    [Parameter(Mandatory)]
    [string]$SessionId,

    [string]$Reason,

    [ValidateSet('completed','partial','abandoned')]
    [string]$Outcome = 'completed',

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Resolve-ProgressPath {
    param([string]$User, [string]$Project)

    $mentorHome = $env:MSSA_MENTOR_HOME
    if (-not [string]::IsNullOrWhiteSpace($mentorHome)) {
        $base = Join-Path $mentorHome 'profiles/mentees'
    } else {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../../..')
        $base = Join-Path $repoRoot '.profiles/profiles/mentees'
    }

    return (Join-Path (Join-Path $base $User) "$Project.progress.json")
}

# --- Gate ---

$progressPath = Resolve-ProgressPath -User $Username -Project $ProjectId

if (-not (Test-Path -LiteralPath $progressPath)) {
    Write-Error "progress.json not found: $progressPath"
    exit 2
}

$progress = Get-Content -LiteralPath $progressPath -Raw -Encoding UTF8 |
    ConvertFrom-Json -AsHashtable -Depth 32

$events = if ($progress.Contains('events')) { @($progress['events']) } else { @() }
$sessionEvents = @($events | Where-Object { $_.session_id -eq $SessionId })

$startedCount = @($sessionEvents | Where-Object { $_.type -eq 'session_started' }).Count
$endedCount   = @($sessionEvents | Where-Object { $_.type -eq 'session_ended'   }).Count

$failures = New-Object System.Collections.Generic.List[string]
if ($startedCount -eq 0) {
    $failures.Add("MISSING session_started for session_id=$SessionId. Did you call append-event -Type session_started first?")
}
if ($endedCount -gt 0) {
    $failures.Add("session_id=$SessionId already has $endedCount session_ended event(s). Refusing to close twice.")
}

if ($failures.Count -gt 0) {
    Write-Host "close-session GATE FAILED for $Username / $ProjectId / $SessionId" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    Write-Host "Total events for session: $($sessionEvents.Count)" -ForegroundColor Yellow
    exit 1
}

# --- Emit session_ended via cli-tool:append-event (single writer rule) ---

$payload = [ordered]@{
    outcome = $Outcome
}
if (-not [string]::IsNullOrWhiteSpace($Reason)) {
    $payload['reason'] = $Reason
}
# Useful at-close metrics for downstream readers / wrap-up gates.
$payload['event_count']           = $sessionEvents.Count
$payload['concept_taught_count']  = @($sessionEvents | Where-Object { $_.type -eq 'concept_taught' }).Count
$payload['quiz_answered_count']   = @($sessionEvents | Where-Object { $_.type -eq 'quiz_answered'  }).Count
$payload['method_used_count']     = @($sessionEvents | Where-Object { $_.type -eq 'method_used'    }).Count

$dataJson = $payload | ConvertTo-Json -Compress -Depth 16

$appendScript = Join-Path $PSScriptRoot 'append-event.ps1'

if ($DryRun) {
    Write-Host "[DryRun] Would emit session_ended:" -ForegroundColor Cyan
    Write-Host $dataJson
    Write-Host "[DryRun] Would invoke: $appendScript -Username $Username -ProjectId $ProjectId -Type session_ended -SessionId $SessionId -Data ..."
    exit 0
}

& $appendScript -Username $Username -ProjectId $ProjectId `
    -Type session_ended -SessionId $SessionId -Data $dataJson

if ($LASTEXITCODE -ne 0) {
    Write-Error "append-event failed with exit code $LASTEXITCODE"
    exit 2
}

Write-Host "close-session OK: $SessionId -> $progressPath" -ForegroundColor Green
exit 0
