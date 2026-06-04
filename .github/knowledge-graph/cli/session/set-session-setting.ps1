<#
.SYNOPSIS
Write ONE session-plan setting to {projectId}.progress.json.

.DESCRIPTION
Generic single-field writer for `field:progress.session_plan.settings`. The
mentor calls this after a focused edit picker (picker:edit-method,
picker:edit-track, picker:edit-mode, picker:edit-comment-depth,
picker:edit-time-box, picker:edit-goal, picker:edit-project) per
behavior:32-edit-setting-on-request.

Atomic JSON write. Honors MSSA_MENTOR_HOME. Validates the field name AND, for
enum fields, the value.

For `project` (the active project pointer), the writer ALSO updates
profile.json's projects[] ordering — moving the chosen project to index 0 — so
that show-profile.ps1's auto-pick continues to land on it next session. (No
project file is created here; that's the scaffolder's job.)

.PARAMETER Username
Mentee github username.

.PARAMETER ProjectId
Project slug whose progress.json receives the update. For -Field project, this
is the CURRENT project — the new project goes in -Value.

.PARAMETER Field
One of: project | track | method | mode | time_box | goal | comment_depth

.PARAMETER Value
The new value. Enum fields are validated; free-text fields (goal) are not.

.PARAMETER Json
Emit a JSON receipt to stdout instead of human text.

.PARAMETER DryRun
Print the merged session_plan.settings without writing to disk.

.EXAMPLE
pwsh .github/knowledge-graph/cli/session/set-session-setting.ps1 `
  -Username jay-steenbergen -ProjectId weather-api `
  -Field comment_depth -Value block

.EXAMPLE
pwsh .github/knowledge-graph/cli/session/set-session-setting.ps1 `
  -Username jay-steenbergen -ProjectId weather-api `
  -Field goal -Value "Wire up the temperature parser end-to-end"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Username,

    [Parameter(Mandatory)]
    [string]$ProjectId,

    [Parameter(Mandatory)]
    [ValidateSet('project','track','method','mode','time_box','goal','comment_depth')]
    [string]$Field,

    [Parameter(Mandatory)]
    [string]$Value,

    [switch]$Json,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# --- Enum validation for the closed-set fields ---
$enums = @{
    method        = @('ride-along','TDD','BDD','whiteboard','spike-then-refactor')
    track         = @('cloud-app-dev','server-cloud-admin','cybersecurity-ops','github-copilot','whiteboarding')
    mode          = @('hand-held','standard','advanced')
    time_box      = @('15m','30m','60m','multi-session','skip')
    comment_depth = @('heavy','block','concept-only')
    # 'goal' and 'project' are free-text — not validated here.
}

if ($enums.ContainsKey($Field)) {
    if ($enums[$Field] -notcontains $Value) {
        throw "Invalid value for -Field $Field. Allowed: $($enums[$Field] -join ', '). Got: '$Value'."
    }
}

# --- Path resolution (matches show-profile.ps1 / append-session-plan.ps1) ---
function Resolve-MenteesDir {
    $mentorHome = $env:MSSA_MENTOR_HOME
    if (-not [string]::IsNullOrWhiteSpace($mentorHome)) {
        return (Join-Path $mentorHome 'profiles/mentees')
    }
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../../..')
    return (Join-Path $repoRoot '.profiles/profiles/mentees')
}

function Read-Hashtable {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    try {
        return ($raw | ConvertFrom-Json -AsHashtable -Depth 32)
    } catch {
        throw "Invalid JSON at ${Path}: $($_.Exception.Message)"
    }
}

function Write-JsonAtomic {
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

# --- Main ---
$menteesDir   = Resolve-MenteesDir
$userDir      = Join-Path $menteesDir $Username
$profilePath  = Join-Path $userDir 'profile.json'

if (-not (Test-Path -LiteralPath $userDir)) {
    throw "User folder not found: $userDir. Run the first-time interview first."
}

# ── Special case: -Field project just updates the profile.json projects[] order ──
if ($Field -eq 'project') {
    $profile = Read-Hashtable -Path $profilePath
    if ($null -eq $profile) {
        throw "profile.json not found at $profilePath."
    }
    $projects = @($profile['projects'])
    $match = $projects | Where-Object { $_.id -eq $Value }
    if (-not $match) {
        throw "Project '$Value' is not in profile.projects[]. Scaffold it first."
    }
    # Move the chosen project to index 0
    $reordered = @(@($match) + @($projects | Where-Object { $_.id -ne $Value }))
    $profile['projects'] = $reordered

    if ($DryRun) {
        Write-Output ($profile | ConvertTo-Json -Depth 32)
        return
    }
    Write-JsonAtomic -Path $profilePath -Data $profile

    if ($Json) {
        @{ ok = $true; field = 'project'; value = $Value; path = $profilePath } | ConvertTo-Json -Depth 8
    } else {
        Write-Output "OK: active project -> $Value  (profile.json reordered)"
    }
    return
}

# ── All other fields: write into progress.session_plan.settings ──
$progressPath = Join-Path $userDir "$ProjectId.progress.json"
$progress = Read-Hashtable -Path $progressPath
if ($null -eq $progress) {
    throw "progress.json not found at $progressPath. Scaffold the project first."
}

if (-not $progress.Contains('session_plan') -or $null -eq $progress['session_plan']) {
    $progress['session_plan'] = [ordered]@{
        settings     = [ordered]@{}
        created_at   = (Get-Date -Format 'yyyy-MM-dd')
        last_updated = (Get-Date -Format 'yyyy-MM-dd')
    }
}
if (-not $progress.session_plan.Contains('settings') -or $null -eq $progress.session_plan['settings']) {
    $progress.session_plan['settings'] = [ordered]@{}
}

$progress.session_plan.settings[$Field] = $Value
$progress.session_plan['last_updated'] = (Get-Date -Format 'yyyy-MM-dd')

# Mirror method/track to the progress.json root so legacy readers (show-progress.ps1)
# stay consistent.
if ($Field -eq 'method') { $progress['last_used_method'] = $Value }
if ($Field -eq 'track')  { $progress['track']            = $Value }

if ($DryRun) {
    Write-Output ($progress.session_plan | ConvertTo-Json -Depth 32)
    return
}

Write-JsonAtomic -Path $progressPath -Data $progress

if ($Json) {
    @{ ok = $true; field = $Field; value = $Value; path = $progressPath } | ConvertTo-Json -Depth 8
} else {
    Write-Output "OK: $Field -> $Value  ($progressPath)"
}
