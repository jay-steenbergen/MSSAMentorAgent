<#
.SYNOPSIS
Append a planning-phase beat result to {projectId}.progress.json.

.DESCRIPTION
Persists `field:progress.session_plan` per phase:planning's 9 beats. One call per
beat. Atomic write. Creates the session_plan object on first call. Honors
MSSA_MENTOR_HOME (matches extensions/mssa-mentor/src/paths.ts) and falls back to
the in-repo .profiles/profiles/mentees/{username}/{projectId}.progress.json when
the env var is unset.

The schema written matches `field:progress.session_plan` in
mentor-graph.json:

  {
    "restated": "<string>",                    # beat:restate-brief
    "user":     "<string>",                    # beat:identify-user (omitted if -Skip)
    "chunks":           ["..."],               # beat:decompose
    "chunks_today":     ["..."],               # beat:decompose
    "unknowns": [{ "name":"", "resolution":"" }], # beat:name-unknowns
    "sketch":   { "text":"", "mermaid":"" },   # beat:sketch-shape
    "folders":  { "tree":"", "explanations":[{ "folder":"", "job":"" }] }, # beat:folder-walk
    "done_when": "<string>",                   # beat:define-done
    "risks":    [{ "scenario":"", "handling":"" }], # beat:predict-breaks
    "why":       "<string>",                   # beat:why-this-matters
    "skipped":  ["beat:identify-user", ...],
    "created_at":   "YYYY-MM-DD",
    "last_updated": "YYYY-MM-DD"
  }

.PARAMETER Username
Mentee github username — folder name under .../profiles/mentees/.

.PARAMETER ProjectId
Project slug — matches {projectId}.progress.json filename.

.PARAMETER Beat
Which planning beat is being persisted. One of:
  restate-brief | identify-user | decompose | name-unknowns | sketch-shape
  | folder-walk | define-done | predict-breaks | why-this-matters

.PARAMETER Value
The string payload for simple-string beats. For decompose/name-unknowns/
predict-breaks/folder-walk-explanations, pass a JSON string and add -Json.

.PARAMETER Mermaid
Optional Mermaid snippet for beat:sketch-shape (paired with -Value as the text).

.PARAMETER FolderTree
Required for beat:folder-walk — the printed tree string.
-Value for folder-walk is interpreted as the JSON-encoded explanations array.

.PARAMETER Json
Treat -Value as already-encoded JSON (used for array-valued beats).

.PARAMETER Skip
Mark this beat as skipped. Appends to session_plan.skipped[] instead of writing
the field. Only valid for beats that ARE skippable per phase:planning
(identify-user, sketch-shape -> never skipped in beginner mode, etc. — the CLI
does not enforce that; the agent does).

.PARAMETER DryRun
Print the merged session_plan JSON to stdout instead of writing to disk.

.EXAMPLE
# Beat 1 (restate)
./append-session-plan.ps1 -Username alex_smith -ProjectId weather-api `
  -Beat restate-brief -Value "Pull current temp for a zip code from the OpenWeather API and print it."

.EXAMPLE
# Beat 3 (decompose) — JSON payload
$payload = @{
  chunks       = @("read zip from argv","call API","parse JSON","print temp")
  chunks_today = @("read zip from argv","call API")
} | ConvertTo-Json -Compress
./append-session-plan.ps1 -Username alex_smith -ProjectId weather-api `
  -Beat decompose -Value $payload -Json

.EXAMPLE
# Beat 2 (identify-user) — skipped
./append-session-plan.ps1 -Username alex_smith -ProjectId weather-api `
  -Beat identify-user -Skip

.EXAMPLE
# Dry-run to inspect what would be written
./append-session-plan.ps1 -Username alex_smith -ProjectId weather-api `
  -Beat why-this-matters -Value "First step toward the weather dashboard project." -DryRun
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Username,

    [Parameter(Mandatory)]
    [string]$ProjectId,

    [Parameter(Mandatory)]
    [ValidateSet(
        'restate-brief','identify-user','decompose','name-unknowns',
        'sketch-shape','folder-walk','define-done','predict-breaks','why-this-matters'
    )]
    [string]$Beat,

    [string]$Value,

    [string]$Mermaid,

    [string]$FolderTree,

    [switch]$Json,

    [switch]$Skip,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Resolve-ProgressPath {
    param([string]$User, [string]$Project)

    $mentorHome = $env:MSSA_MENTOR_HOME
    if (-not [string]::IsNullOrWhiteSpace($mentorHome)) {
        $base = Join-Path $mentorHome 'profiles/mentees'
    } else {
        # Repo fallback. PSScriptRoot = .../.github/knowledge-graph/cli
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..')
        $base = Join-Path $repoRoot '.profiles/profiles/mentees'
    }

    $userDir = Join-Path $base $User
    if (-not (Test-Path -LiteralPath $userDir)) {
        if ($DryRun) {
            # DryRun is allowed to operate on a phantom path so the agent can preview.
            return (Join-Path $userDir "$Project.progress.json")
        }
        throw "User folder not found: $userDir. Run scaffold first or set MSSA_MENTOR_HOME."
    }

    return (Join-Path $userDir "$Project.progress.json")
}

function New-EmptySessionPlan {
    [ordered]@{
        restated     = ''
        user         = ''
        chunks       = @()
        chunks_today = @()
        unknowns     = @()
        sketch       = [ordered]@{ text = ''; mermaid = '' }
        folders      = [ordered]@{ tree = ''; explanations = @() }
        done_when    = ''
        risks        = @()
        why          = ''
        skipped      = @()
        created_at   = (Get-Date -Format 'yyyy-MM-dd')
        last_updated = (Get-Date -Format 'yyyy-MM-dd')
    }
}

function Read-Progress {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        if ($DryRun) {
            return [ordered]@{
                project_id            = $ProjectId
                last_used_method      = ''
                track                 = ''
                status                = 'in_progress'
                current_step          = 0
                completed_milestones  = @()
                session_history       = @()
            }
        }
        throw "progress.json not found: $Path. Run scaffold first."
    }

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    try {
        return ($raw | ConvertFrom-Json -AsHashtable -Depth 32)
    } catch {
        throw "progress.json at $Path is invalid JSON: $($_.Exception.Message)"
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
        throw "Value is not valid JSON: $($_.Exception.Message)"
    }
}

# --- Main ---

$progressPath = Resolve-ProgressPath -User $Username -Project $ProjectId
$progress     = Read-Progress -Path $progressPath

# Read-Progress returns Hashtable (from ConvertFrom-Json -AsHashtable) when reading from disk,
# or OrderedDictionary in the DryRun-on-missing-path branch. Both expose Contains() but only
# Hashtable has ContainsKey(). Use Contains() for portability.
if (-not $progress.Contains('session_plan') -or $null -eq $progress['session_plan']) {
    $progress['session_plan'] = New-EmptySessionPlan
}

$plan = $progress.session_plan
$beatKey = "beat:$Beat"

if ($Skip) {
    if ($plan.skipped -notcontains $beatKey) {
        $plan.skipped += $beatKey
    }
} else {
    switch ($Beat) {
        'restate-brief' {
            $plan.restated = $Value
        }
        'identify-user' {
            $plan.user = $Value
        }
        'decompose' {
            if (-not $Json) { throw "Beat 'decompose' requires -Json with payload { chunks, chunks_today }." }
            $obj = Parse-JsonValue -Raw $Value
            if ($null -ne $obj.chunks)       { $plan.chunks       = @($obj.chunks) }
            if ($null -ne $obj.chunks_today) { $plan.chunks_today = @($obj.chunks_today) }
        }
        'name-unknowns' {
            if (-not $Json) { throw "Beat 'name-unknowns' requires -Json with an array of { name, resolution }." }
            $obj = Parse-JsonValue -Raw $Value
            $plan.unknowns = @($obj)
        }
        'sketch-shape' {
            $plan.sketch.text = $Value
            if ($PSBoundParameters.ContainsKey('Mermaid')) {
                $plan.sketch.mermaid = $Mermaid
            }
        }
        'folder-walk' {
            if (-not $PSBoundParameters.ContainsKey('FolderTree')) {
                throw "Beat 'folder-walk' requires -FolderTree '<tree string>' and -Value '<json explanations>' -Json."
            }
            $plan.folders.tree = $FolderTree
            if ($Json -and -not [string]::IsNullOrWhiteSpace($Value)) {
                $obj = Parse-JsonValue -Raw $Value
                $plan.folders.explanations = @($obj)
            }
        }
        'define-done' {
            $plan.done_when = $Value
        }
        'predict-breaks' {
            if (-not $Json) { throw "Beat 'predict-breaks' requires -Json with an array of { scenario, handling }." }
            $obj = Parse-JsonValue -Raw $Value
            $plan.risks = @($obj)
        }
        'why-this-matters' {
            $plan.why = $Value
        }
    }
}

$plan.last_updated = (Get-Date -Format 'yyyy-MM-dd')
$progress.session_plan = $plan

if ($DryRun) {
    Write-Output ($plan | ConvertTo-Json -Depth 32)
    return
}

Write-ProgressAtomic -Path $progressPath -Data $progress
Write-Output "OK: beat=$Beat -> $progressPath"
