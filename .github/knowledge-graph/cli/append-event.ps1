<#
.SYNOPSIS
Append an event to field:profile.events on {projectId}.progress.json.

.DESCRIPTION
Single writer for the event log per rule:events-are-source-of-truth. Mirrors
cli-tool:append-session-plan's atomic write pattern. Honors MSSA_MENTOR_HOME
and falls back to the in-repo .profiles/profiles/mentees/{username}/
{projectId}.progress.json when the env var is unset.

Each appended event:

  {
    "ts":         "ISO8601 UTC",
    "type":       "<one of the enum below>",
    "session_id": "<uuid-or-string passed by caller>",
    "project_id": "<projectId>",
    "data":       { ... type-specific JSON ... }
  }

The events array is created on first call.

.PARAMETER Username
Github username (folder name under .../profiles/mentees/ or mentors/).

.PARAMETER ProjectId
Project slug (matches {projectId}.progress.json filename).

.PARAMETER Role
Which role folder to write under. 'mentee' (default) or 'mentor'.

.PARAMETER Type
Event type. One of:
  session_started | session_ended | concept_taught | concept_calibrated |
  quiz_asked      | quiz_answered | method_used    | analogy_offered    |
  callback_made   | celebration

.PARAMETER SessionId
UUID grouping events into one logical session. Required for every type
EXCEPT session_started — for session_started a new UUID is minted if not
provided, and the value is echoed on stdout so the caller can reuse it.

.PARAMETER Data
JSON string payload (per-type shape). Optional for simple events
(session_started, celebration); required for typed events that carry context.

.PARAMETER DryRun
Print the event JSON to stdout instead of writing to disk.

.PARAMETER BackdateTs
Override the event timestamp (ISO-8601). Reserved for migrate-profile-to-events.ps1
backfilling historical events. Normal callers should never set this.

.EXAMPLE
# Start a session — mint a new session_id and echo it back.
./append-event.ps1 -Username alex_smith -ProjectId weather-api `
  -Type session_started

.EXAMPLE
# Log a concept_taught event mid-session.
$payload = @{ concept_id = 'variable'; analogy_used = $true; method = 'ride-along' } |
  ConvertTo-Json -Compress
./append-event.ps1 -Username alex_smith -ProjectId weather-api `
  -Type concept_taught -SessionId $sid -Data $payload

.EXAMPLE
# Log a quiz answer.
$payload = @{
  concept_id = 'for-loop'; trigger = 'reappearance'; form = 'code-fill';
  question   = 'fill the hole: for ___ in range(5)'; answer = 'i'; correct = $true
} | ConvertTo-Json -Compress
./append-event.ps1 -Username alex_smith -ProjectId weather-api `
  -Type quiz_answered -SessionId $sid -Data $payload

.NOTES
Atomic write: writes to .tmp sibling then Move-Item -Force. Never mutates an
existing event. Exit codes: 0 success, 1 caller error (bad type, missing data),
2 environment error (profile missing, IO failure).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Username,

    [Parameter(Mandatory)]
    [string]$ProjectId,

    [Parameter(Mandatory)]
    [ValidateSet(
        'session_started','session_ended',
        'concept_taught','concept_calibrated',
        'quiz_asked','quiz_answered',
        'method_used','analogy_offered',
        'callback_made','celebration'
    )]
    [string]$Type,

    [string]$SessionId,

    [string]$Data,

    [ValidateSet('mentee','mentor')]
    [string]$Role = 'mentee',

    [string]$BackdateTs,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Resolve-ProgressPath {
    param([string]$User, [string]$Project, [string]$RoleFolder)

    $roleDir = if ($RoleFolder -eq 'mentor') { 'mentors' } else { 'mentees' }

    $mentorHome = $env:MSSA_MENTOR_HOME
    if (-not [string]::IsNullOrWhiteSpace($mentorHome)) {
        $base = Join-Path $mentorHome "profiles/$roleDir"
    } else {
        # Repo fallback. PSScriptRoot = .../.github/knowledge-graph/cli
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..')
        $base = Join-Path $repoRoot ".profiles/profiles/$roleDir"
    }

    $userDir = Join-Path $base $User
    if (-not (Test-Path -LiteralPath $userDir)) {
        if ($DryRun) {
            return (Join-Path $userDir "$Project.progress.json")
        }
        Write-Error "User folder not found: $userDir. Run scaffold first or set MSSA_MENTOR_HOME."
        exit 2
    }

    return (Join-Path $userDir "$Project.progress.json")
}

function Read-Progress {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        if ($DryRun) {
            return [ordered]@{
                project_id = $ProjectId
                events     = @()
            }
        }
        Write-Error "progress.json not found: $Path. Run scaffold first."
        exit 2
    }

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    try {
        return ($raw | ConvertFrom-Json -AsHashtable -Depth 32)
    } catch {
        Write-Error "progress.json at $Path is invalid JSON: $($_.Exception.Message)"
        exit 2
    }
}

function Write-ProgressAtomic {
    param([string]$Path, $Data)

    $json = $Data | ConvertTo-Json -Depth 32
    $dir  = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $tmp = "$Path.tmp"
    Set-Content -LiteralPath $tmp -Value $json -Encoding UTF8
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Parse-JsonValue {
    param([string]$Raw)

    if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }
    try {
        return ($Raw | ConvertFrom-Json -AsHashtable -Depth 16)
    } catch {
        Write-Error "Value is not valid JSON: $($_.Exception.Message)"
        exit 1
    }
}

# --- Validation ---

if ($Type -ne 'session_started' -and [string]::IsNullOrWhiteSpace($SessionId)) {
    Write-Error "Type '$Type' requires -SessionId (only session_started may mint a new one)."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($SessionId)) {
    $SessionId = [Guid]::NewGuid().ToString()
}

$dataObj = $null
if (-not [string]::IsNullOrWhiteSpace($Data)) {
    $dataObj = Parse-JsonValue -Raw $Data
}

# --- Main ---

$progressPath = Resolve-ProgressPath -User $Username -Project $ProjectId -RoleFolder $Role
$progress     = Read-Progress -Path $progressPath

# Read-Progress returns Hashtable from disk, OrderedDictionary in DryRun-on-missing branch.
# Both expose Contains(); only Hashtable has ContainsKey(). Use Contains().
if (-not $progress.Contains('events') -or $null -eq $progress['events']) {
    $progress['events'] = @()
}

# Honor -BackdateTs for migrate-profile-to-events.ps1; default = now (UTC).
$ts = if (-not [string]::IsNullOrWhiteSpace($BackdateTs)) {
    $parsed = [datetime]::MinValue
    if (-not [datetime]::TryParse($BackdateTs, [ref]$parsed)) {
        Write-Error "-BackdateTs is not ISO-8601 parseable: '$BackdateTs'"
        exit 1
    }
    $parsed.ToUniversalTime().ToString('o')
} else {
    (Get-Date).ToUniversalTime().ToString('o')
}

$event = [ordered]@{
    ts         = $ts
    type       = $Type
    session_id = $SessionId
    project_id = $ProjectId
    data       = $dataObj
}

# Force array semantics (PowerShell unwraps single-item arrays on +=).
$existing = @($progress['events'])
$existing += , $event
$progress['events'] = $existing

if ($DryRun) {
    Write-Output ($event | ConvertTo-Json -Depth 16)
    return
}

Write-ProgressAtomic -Path $progressPath -Data $progress

# Echo session_id so callers (especially session_started) can capture it.
Write-Output "OK: type=$Type session_id=$SessionId -> $progressPath"
