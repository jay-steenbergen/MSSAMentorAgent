<#
.SYNOPSIS
Get skill recommendations for a user intent.

.DESCRIPTION
Uses the graph's Get-AgentLoadList function to find which skills should load
for a given user intent and track.

.PARAMETER Intent
User's goal (e.g., "build a REST API", "debug a bug").

.PARAMETER Track
MSSA track (cloud-app-dev, server-cloud-admin, cybersecurity-ops).
Optional - will try all tracks if not specified.

.PARAMETER SkipEssentials
Skip essentials (learner-profile, method, track README) and only return intent-specific skills.

.PARAMETER AsJson
Output structured JSON instead of formatted text.

.EXAMPLE
.\Get-SkillRecommendations.ps1 -Intent "build a REST API" -Track "cloud-app-dev"
Get skills for REST API building in the CAD track.

.EXAMPLE
.\Get-SkillRecommendations.ps1 -Intent "learn TDD" -SkipEssentials
Get only TDD-specific skills (no essentials).
#>

param(
    [Parameter(Mandatory)]
    [string]$Intent,
    
    [string]$Track,
    
    [switch]$SkipEssentials,
    
    [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $PSScriptRoot

# Load query module and formatting functions
Import-Module "$scriptRoot/lib/query.psm1" -Force
. "$PSScriptRoot/_Format-GraphOutput.ps1"

# Get skill recommendations
$params = @{
    Intent = $Intent
}
if ($Track) { $params.Track = $Track }
if ($SkipEssentials) { $params.SkipEssentials = $true }

$skillFiles = Get-AgentLoadList @params

if (-not $skillFiles -or $skillFiles.Count -eq 0) {
    if (-not $AsJson) {
        Write-Host "No skills found for intent: $Intent" -ForegroundColor Yellow
        Write-Host "Try a different phrasing or check available tracks" -ForegroundColor Gray
    }
    exit 1
}

# Load graph to get skill metadata
$graph = Get-KnowledgeGraph

# Build skill details
$skills = @()
foreach ($file in $skillFiles) {
    $skillNode = $graph.nodes | Where-Object { $_.file -eq $file } | Select-Object -First 1
    $skills += [PSCustomObject]@{
        index = $skillFiles.IndexOf($file) + 1
        label = if ($skillNode) { $skillNode.label } else { Split-Path -Leaf $file }
        file = $file
        type = if ($skillNode) { $skillNode.type } else { "unknown" }
        id = if ($skillNode) { $skillNode.id } else { $null }
    }
}

# Output
if ($AsJson) {
    [PSCustomObject]@{
        intent = $Intent
        track = $Track
        skipEssentials = $SkipEssentials.IsPresent
        count = $skills.Count
        skills = $skills
    } | ConvertTo-Json -Depth 10
} else {
    Write-Host "=== SKILLS FOR: $Intent ===" -ForegroundColor Cyan
    if ($Track) {
        Write-Host "Track: $Track`n" -ForegroundColor Gray
    }
    
    Write-Host "Load order:" -ForegroundColor Green
    foreach ($skill in $skills) {
        Write-Host "  $($skill.index). $($skill.label)" -ForegroundColor White
        Write-Host "     $($skill.file)" -ForegroundColor Gray
    }
    Write-Host ""
}

exit 0
