<#
.SYNOPSIS
Display learner progress dashboard.

.DESCRIPTION
Shows learner progress across all projects and tracks:
- Completion percentage per track
- Skills completed, in-progress, and recommended
- Track milestones status
- Visual progress indicators

.PARAMETER Username
GitHub username of the learner (required)

.PARAMETER Track
Optional: Filter to specific track (cloud-app-dev, server-cloud-admin, cybersecurity-ops)

.PARAMETER Json
Output raw JSON instead of formatted display

.EXAMPLE
.github/knowledge-graph/cli/show-progress.ps1 -Username "alex_smith"

.EXAMPLE
.github/knowledge-graph/cli/show-progress.ps1 -Username "alex_smith" -Track "cloud-app-dev"

.EXAMPLE
.github/knowledge-graph/cli/show-progress.ps1 -Username "alex_smith" -Json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Username,
    
    [string]$Track = $null,
    
    [switch]$Json
)

# Import the query module
$modulePath = Join-Path $PSScriptRoot '../lib/query.psm1'
Import-Module $modulePath -Force

# Get progress data
$progressParams = @{
    Username = $Username
}
if ($Track) {
    $progressParams.Track = $Track
}
$progress = Get-LearnerProgress @progressParams

if (-not $progress) {
    Write-Error "Failed to load progress for user: $Username"
    exit 1
}

# JSON output mode
if ($Json) {
    $progress | ConvertTo-Json -Depth 32
    exit 0
}

# Formatted display
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Progress Dashboard: $($progress.preferred_name)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Username: $($progress.username)" -ForegroundColor DarkGray
Write-Host "Last Updated: $($progress.last_updated)" -ForegroundColor DarkGray
Write-Host ""

# Track summaries
foreach ($trackName in @($progress.tracks.Keys)) {
    $trackData = $progress.tracks[$trackName]
    
    # Track header
    $trackDisplay = switch ($trackName) {
        "cloud-app-dev" { "Cloud Application Development" }
        "server-cloud-admin" { "Server & Cloud Administration" }
        "cybersecurity-ops" { "Cybersecurity Operations" }
        default { $trackName }
    }
    
    Write-Host "Track: " -NoNewline -ForegroundColor White
    Write-Host $trackDisplay -ForegroundColor Yellow
    Write-Host "Progress: " -NoNewline -ForegroundColor White
    
    $percentColor = if ($trackData.percent_complete -ge 75) { "Green" }
                    elseif ($trackData.percent_complete -ge 50) { "Yellow" }
                    elseif ($trackData.percent_complete -ge 25) { "DarkYellow" }
                    else { "Red" }
    
    Write-Host "$($trackData.percent_complete)% " -NoNewline -ForegroundColor $percentColor
    Write-Host "($($trackData.completed_milestones)/$($trackData.total_milestones) milestones)" -ForegroundColor DarkGray
    Write-Host ""
    
    # Completed projects
    $completed = $trackData.projects | Where-Object { $_.status -eq 'completed' }
    if ($completed) {
        Write-Host "✓ Completed Projects:" -ForegroundColor Green
        foreach ($project in $completed) {
            Write-Host "  → $($project.display_name)" -ForegroundColor White
            Write-Host "     Completed: $($project.last_session)" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
    
    # In-progress projects
    $inProgress = $trackData.projects | Where-Object { $_.status -eq 'in_progress' }
    if ($inProgress) {
        Write-Host "⚠ In Progress:" -ForegroundColor Yellow
        foreach ($project in $inProgress) {
            Write-Host "  → $($project.display_name)" -ForegroundColor White
            Write-Host "     Step $($project.current_step)/$($project.total_steps) | " -NoNewline -ForegroundColor DarkGray
            Write-Host "Method: $($project.method) | " -NoNewline -ForegroundColor DarkGray
            Write-Host "Last: $($project.last_session)" -ForegroundColor DarkGray
            
            if ($project.milestones.Count -gt 0) {
                Write-Host "     Milestones: " -NoNewline -ForegroundColor DarkGray
                Write-Host ($project.milestones -join ", ") -ForegroundColor Cyan
            }
        }
        Write-Host ""
    }
    
    # Not started message
    if (-not $completed -and -not $inProgress) {
        Write-Host "○ No projects started in this track yet" -ForegroundColor DarkGray
        Write-Host ""
    }
}

# Recommendations
if ($progress.recommendations.Count -gt 0) {
    Write-Host "→ Recommended Next Skills:" -ForegroundColor Cyan
    
    foreach ($rec in $progress.recommendations) {
        $priorityColor = switch ($rec.priority) {
            "HIGH" { "Green" }
            "MEDIUM" { "Yellow" }
            "LOW" { "DarkGray" }
            default { "White" }
        }
        
        Write-Host "  $($rec.rank). " -NoNewline -ForegroundColor White
        Write-Host "$($rec.label) " -NoNewline -ForegroundColor White
        Write-Host "[$($rec.priority)]" -ForegroundColor $priorityColor
        Write-Host "     Score: $($rec.score) | " -NoNewline -ForegroundColor DarkGray
        Write-Host $rec.reason -ForegroundColor DarkGray
        
        if ($rec.strategies.Count -gt 0) {
            Write-Host "     Why: " -NoNewline -ForegroundColor DarkGray
            Write-Host ($rec.strategies -join ", ") -ForegroundColor Cyan
        }
    }
    Write-Host ""
}

# Summary stats
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Projects: $($progress.all_projects.Count)" -ForegroundColor White
Write-Host "  Completed: $($progress.completed_skills.Count)" -ForegroundColor Green
Write-Host "  In Progress: $($progress.in_progress.Count)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
