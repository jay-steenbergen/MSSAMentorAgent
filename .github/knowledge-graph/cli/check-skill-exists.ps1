#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Check if a similar skill already exists before building a new one.

.DESCRIPTION
    Searches the knowledge graph for skills matching the proposed name
    and description. Prevents duplicate work by surfacing existing skills
    that might already solve the problem.

.PARAMETER Name
    Proposed skill name (e.g., "learn-git-basics").

.PARAMETER Description
    Optional description of what the skill will do.

.PARAMETER Threshold
    Minimum similarity score (0-100). Default 30.

.PARAMETER Json
    Output as JSON instead of formatted report.

.EXAMPLE
    ./check-skill-exists.ps1 -Name "git-basics"
    ./check-skill-exists.ps1 -Name "api-auth" -Description "Teach REST API authentication"
    ./check-skill-exists.ps1 -Name "docker-intro" -Threshold 50
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Name,
    
    [string]$Description = "",
    
    [ValidateRange(0, 100)]
    [int]$Threshold = 30,
    
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../lib/query.psm1') -Force

$results = Find-SimilarSkills -Name $Name -Description $Description -Threshold $Threshold

if ($Json) {
    $results | ConvertTo-Json -Depth 10
    exit 0
}

# Format as readable report
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Skill Discovery Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Searching for: '$Name'" -ForegroundColor White
if ($Description) {
    Write-Host "Description: '$Description'" -ForegroundColor White
}
Write-Host ""

if ($results.Count -eq 0) {
    Write-Host "✓ No similar skills found!" -ForegroundColor Green
    Write-Host ""
    Write-Host "This appears to be a new skill. Safe to build." -ForegroundColor White
    Write-Host ""
    exit 0
}

Write-Host "Found $($results.Count) similar skill(s):" -ForegroundColor Yellow
Write-Host ""

foreach ($r in $results) {
    $color = switch ($r.recommendation) {
        { $_ -match 'EXACT' } { 'Red' }
        { $_ -match 'VERY' } { 'Yellow' }
        default { 'White' }
    }
    
    Write-Host "[$($r.score)] $($r.label)" -ForegroundColor $color
    Write-Host "  ID: $($r.id)" -ForegroundColor DarkGray
    Write-Host "  Type: $($r.type)" -ForegroundColor DarkGray
    Write-Host "  File: $($r.file)" -ForegroundColor DarkGray
    if ($r.cluster) {
        Write-Host "  Cluster: $($r.cluster)" -ForegroundColor DarkGray
    }
    if ($r.description) {
        Write-Host "  Description: $($r.description)" -ForegroundColor DarkGray
    }
    Write-Host "  → $($r.recommendation)" -ForegroundColor $color
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Recommendation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$topScore = $results[0].score
if ($topScore -ge 70) {
    Write-Host "⚠️  STOP: Exact match found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "The skill '$($results[0].label)' already exists." -ForegroundColor White
    Write-Host "File: $($results[0].file)" -ForegroundColor White
    Write-Host ""
    Write-Host "→ Use the existing skill instead of building a new one." -ForegroundColor Yellow
} elseif ($topScore -ge 50) {
    Write-Host "⚠️  CAUTION: Very similar skill(s) found." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Review these skills before building:" -ForegroundColor White
    $results | Where-Object { $_.score -ge 50 } | ForEach-Object {
        Write-Host "  • $($_.label) ($($_.file))" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "→ Check if you can extend/reuse instead of creating new." -ForegroundColor Yellow
} elseif ($topScore -ge 30) {
    Write-Host "✓ Similar skills exist, but likely different enough." -ForegroundColor White
    Write-Host ""
    Write-Host "Review for potential overlap:" -ForegroundColor White
    $results | Where-Object { $_.score -ge 30 } | ForEach-Object {
        Write-Host "  • $($_.label) ($($_.file))" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "→ Safe to build if your skill focuses on something different." -ForegroundColor Green
}

Write-Host ""
