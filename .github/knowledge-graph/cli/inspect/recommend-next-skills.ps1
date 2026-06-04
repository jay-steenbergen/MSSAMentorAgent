#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Recommend next skills based on completed skills.

.DESCRIPTION
    After completing skills, get personalized recommendations for what
    to learn next based on:
    - Direct recommendations (skill A → skill B edges)
    - Skills in the same cluster
    - Skills required by more advanced skills
    - Track progression

.PARAMETER CompletedSkills
    Array of completed skill IDs (e.g., "skill:cad-hello-console", "skill:ride-along").

.PARAMETER Track
    Optional: Filter recommendations to a specific track.

.PARAMETER MaxResults
    Maximum number of recommendations. Default 5.

.PARAMETER Json
    Output as JSON instead of formatted report.

.EXAMPLE
    ./recommend-next-skills.ps1 -CompletedSkills "skill:cad-hello-console"
    ./recommend-next-skills.ps1 -CompletedSkills "skill:ride-along","skill:learner-profile" -Track "cloud-app-dev"
    ./recommend-next-skills.ps1 -CompletedSkills "skill:cad-hello-console" -MaxResults 10
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]]$CompletedSkills,
    
    [ValidateSet('cloud-app-dev', 'cybersecurity-ops', 'github-copilot', 'server-cloud-admin', 'whiteboarding')]
    [string]$Track,
    
    [int]$MaxResults = 5,
    
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../../lib/query.psm1') -Force

$params = @{
    CompletedSkills = $CompletedSkills
    MaxResults = $MaxResults
}
if ($Track) {
    $params.Track = $Track
}

$recommendations = Get-SkillRecommendations @params

if ($Json) {
    $recommendations | ConvertTo-Json -Depth 10
    exit 0
}

# Format as readable report
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Skill Recommendations" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Based on completed skills:" -ForegroundColor White
foreach ($cs in $CompletedSkills) {
    Write-Host "  • $cs" -ForegroundColor DarkGray
}
Write-Host ""

if ($recommendations.Count -eq 0) {
    Write-Host "No recommendations found." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This could mean:" -ForegroundColor White
    Write-Host "  • You've completed a standalone skill with no follow-ups" -ForegroundColor DarkGray
    Write-Host "  • The skill isn't connected to others in the graph yet" -ForegroundColor DarkGray
    if ($Track) {
        Write-Host "  • No skills in '$Track' track match your progress" -ForegroundColor DarkGray
    }
    Write-Host ""
    exit 0
}

Write-Host "TOP $($recommendations.Count) RECOMMENDATIONS:" -ForegroundColor Green
Write-Host ""

$rank = 1
foreach ($rec in $recommendations) {
    $color = switch ($rec.priority) {
        'HIGH' { 'Green' }
        'MEDIUM' { 'Yellow' }
        default { 'White' }
    }
    
    Write-Host "[$rank] $($rec.label) [$($rec.priority)]" -ForegroundColor $color
    Write-Host "    Score: $($rec.score)" -ForegroundColor DarkGray
    Write-Host "    ID: $($rec.id)" -ForegroundColor DarkGray
    Write-Host "    Type: $($rec.type)" -ForegroundColor DarkGray
    if ($rec.file) {
        Write-Host "    File: $($rec.file)" -ForegroundColor DarkGray
    }
    if ($rec.cluster) {
        Write-Host "    Cluster: $($rec.cluster)" -ForegroundColor DarkGray
    }
    if ($rec.description) {
        Write-Host "    Description: $($rec.description)" -ForegroundColor DarkGray
    }
    Write-Host "    Why: $($rec.reasons)" -ForegroundColor DarkGray
    Write-Host ""
    
    $rank++
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Next Steps" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$topRec = $recommendations[0]
Write-Host "→ Start with: $($topRec.label)" -ForegroundColor Green
if ($topRec.file) {
    Write-Host "  File: $($topRec.file)" -ForegroundColor White
}
Write-Host ""
