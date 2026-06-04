<#
.SYNOPSIS
Display learner profile + active session settings. Verify that the 7 Build
Options are set before phase:planning begins.

.DESCRIPTION
The mentor calls this BEFORE planning to confirm all session settings are filled
in (per protocol:verify-build-settings). Any missing setting triggers
picker:build-options. Any setting the learner wants to change triggers
behavior:32-edit-setting-on-request.

Reads:
  - .profiles/profiles/mentees/{username}/profile.json (identity, projects list)
  - .profiles/profiles/mentees/{username}/{projectId}.progress.json
      - root: track, last_used_method
      - session_plan.settings: { method, track, mode, time_box, goal, comment_depth }

Honors MSSA_MENTOR_HOME (matches extensions/mssa-mentor/src/paths.ts) and falls
back to the in-repo .profiles/ tree when the env var is unset.

.PARAMETER Username
Mentee github username — folder name under .../profiles/mentees/.

.PARAMETER ProjectId
Optional project slug. If omitted, the script auto-picks profile.projects[0]
(the most recently scaffolded project) and reports which it chose.

.PARAMETER Json
Output raw JSON for agent consumption instead of formatted display.

.EXAMPLE
pwsh .github/knowledge-graph/cli/inspect/show-profile.ps1 -Username jay-steenbergen

.EXAMPLE
pwsh .github/knowledge-graph/cli/inspect/show-profile.ps1 -Username jay-steenbergen -ProjectId weather-api -Json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Username,

    [string]$ProjectId,

    [switch]$Json
)

$ErrorActionPreference = 'Stop'

# --- Path resolution: honor MSSA_MENTOR_HOME, fall back to in-repo .profiles/ ---
function Resolve-MenteesDir {
    $mentorHome = $env:MSSA_MENTOR_HOME
    if (-not [string]::IsNullOrWhiteSpace($mentorHome)) {
        return (Join-Path $mentorHome 'profiles/mentees')
    }
    # PSScriptRoot = .../.github/knowledge-graph/cli  →  walk up 3 to repo root
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../../..')
    return (Join-Path $repoRoot '.profiles/profiles/mentees')
}

# --- Read JSON, returning $null on missing/bad (so we can flag, not crash) ---
function Read-Json {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable -Depth 32)
    } catch {
        return $null
    }
}

# --- "Set" check: a value counts as set when it's a non-empty string ---
function Get-SettingStatus {
    param($Value)
    if ($null -eq $Value) { return 'MISSING' }
    if ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value)) { return 'MISSING' }
    return 'SET'
}

# --- Main ---
$menteesDir = Resolve-MenteesDir
$userDir    = Join-Path $menteesDir $Username
$profilePath = Join-Path $userDir 'profile.json'

$profile = Read-Json -Path $profilePath
if ($null -eq $profile) {
    if ($Json) {
        @{ ok = $false; reason = 'profile_missing'; username = $Username; profile_path = $profilePath } | ConvertTo-Json -Depth 8
    } else {
        Write-Host ""
        Write-Host "✗ Profile not found for '$Username'" -ForegroundColor Red
        Write-Host "  Expected at: $profilePath" -ForegroundColor DarkGray
        Write-Host "  → Run the first-time interview (skill: learner-profile)." -ForegroundColor Yellow
        Write-Host ""
    }
    exit 1
}

# Resolve project: explicit -ProjectId wins; otherwise pick profile.projects[0]
$projects = @($profile.projects)
if (-not $ProjectId) {
    if ($projects.Count -gt 0 -and $projects[0].id) {
        $ProjectId = $projects[0].id
        $autoSelected = $true
    } else {
        $autoSelected = $false
    }
}

$progressPath = if ($ProjectId) { Join-Path $userDir "$ProjectId.progress.json" } else { $null }
$progress = if ($progressPath) { Read-Json -Path $progressPath } else { $null }

# Pull session settings — prefer session_plan.settings, fall back to progress.json root
$sessionSettings = $null
if ($progress -and $progress.Contains('session_plan') -and $progress.session_plan.Contains('settings')) {
    $sessionSettings = $progress.session_plan.settings
}

function Get-SessionValue {
    param([string]$Key, $Fallback)
    if ($sessionSettings -and $sessionSettings.Contains($Key) -and -not [string]::IsNullOrWhiteSpace([string]$sessionSettings[$Key])) {
        return $sessionSettings[$Key]
    }
    return $Fallback
}

# The 7 Build Options — values + status
$rootTrack  = if ($progress) { $progress['track'] } else { $null }
$rootMethod = if ($progress) { $progress['last_used_method'] } else { $null }

$settings = [ordered]@{
    project        = $ProjectId
    track          = Get-SessionValue -Key 'track'         -Fallback $rootTrack
    method         = Get-SessionValue -Key 'method'        -Fallback $rootMethod
    mode           = Get-SessionValue -Key 'mode'          -Fallback $null
    time_box       = Get-SessionValue -Key 'time_box'      -Fallback $null
    goal           = Get-SessionValue -Key 'goal'          -Fallback $null
    comment_depth  = Get-SessionValue -Key 'comment_depth' -Fallback $null
}

$status = [ordered]@{}
foreach ($k in $settings.Keys) { $status[$k] = Get-SettingStatus -Value $settings[$k] }
$missing = @($status.Keys | Where-Object { $status[$_] -eq 'MISSING' })
$allSet  = ($missing.Count -eq 0)

# --- JSON mode: machine-readable for the agent ---
if ($Json) {
    @{
        ok               = $true
        username         = $Username
        preferred_name   = $profile.preferred_name
        project_id       = $ProjectId
        project_auto_selected = [bool]$autoSelected
        settings         = $settings
        status           = $status
        missing          = $missing
        all_set          = $allSet
        ready_to_plan    = $allSet
        profile_path     = $profilePath
        progress_path    = $progressPath
    } | ConvertTo-Json -Depth 16
    exit 0
}

# --- Formatted display ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Profile: $($profile.preferred_name) ($Username)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($autoSelected) {
    Write-Host "Active project (auto-picked from profile.projects[0]): $ProjectId" -ForegroundColor DarkGray
} elseif ($ProjectId) {
    Write-Host "Active project: $ProjectId" -ForegroundColor DarkGray
} else {
    Write-Host "Active project: (none — profile.projects is empty)" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "Build Options (the 7 settings phase:planning needs):" -ForegroundColor White
Write-Host ""

$labels = [ordered]@{
    project       = '1. Project'
    track         = '2. Track'
    method        = '3. Method'
    mode          = '4. Mode'
    time_box      = "5. Time box"
    goal          = "6. Today's goal anchor"
    comment_depth = '7. Code comment depth'
}

foreach ($k in $labels.Keys) {
    $marker = if ($status[$k] -eq 'SET') { '✓' } else { '✗' }
    $color  = if ($status[$k] -eq 'SET') { 'Green' } else { 'Red' }
    $val    = if ($status[$k] -eq 'SET') { $settings[$k] } else { '(not set)' }
    Write-Host ("  {0} {1,-26} {2}" -f $marker, $labels[$k], $val) -ForegroundColor $color
}
Write-Host ""

if ($allSet) {
    Write-Host "✓ Ready for phase:planning." -ForegroundColor Green
} else {
    Write-Host "✗ Missing: $($missing -join ', ')" -ForegroundColor Red
    Write-Host "  → Fire picker:build-options to fill the gaps before planning starts." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Want to change any of these? Reply with the setting name" -ForegroundColor DarkGray
Write-Host "(project, track, method, mode, time-box, goal, comment-depth) or 'no'." -ForegroundColor DarkGray
Write-Host "  → triggers behavior:32-edit-setting-on-request" -ForegroundColor DarkGray
Write-Host ""

if ($allSet) { exit 0 } else { exit 2 }
