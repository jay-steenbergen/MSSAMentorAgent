#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Show what depends on a skill (impact analysis).

.DESCRIPTION
    Before changing or removing a skill, see what would break.
    Lists all agents, skills, and workflows that reference this skill.

.PARAMETER SkillId
    The skill ID to analyze (e.g., "skill:learner-profile").

.PARAMETER IncludeIndirect
    Include indirect dependencies (dependencies of dependencies).

.PARAMETER Json
    Output as JSON instead of formatted report.

.EXAMPLE
    ./show-skill-impact.ps1 -SkillId "skill:learner-profile"
    ./show-skill-impact.ps1 -SkillId "skill:ride-along" -IncludeIndirect
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SkillId,
    
    [switch]$IncludeIndirect,
    
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../../lib/query.psm1') -Force

$impact = Get-SkillImpact -SkillId $SkillId -IncludeIndirect:$IncludeIndirect

if ($Json) {
    $impact | ConvertTo-Json -Depth 10
    exit 0
}

# Format as readable report
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Impact Analysis: $SkillId" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($impact.direct.Count -eq 0) {
    Write-Host "✓ No direct dependencies found!" -ForegroundColor Green
    Write-Host ""
    Write-Host "This skill is not referenced by anything. Safe to modify or remove." -ForegroundColor White
    Write-Host ""
    exit 0
}

Write-Host "DIRECT IMPACT ($($impact.direct.Count) dependents):" -ForegroundColor Yellow
Write-Host ""

# Group by type
$grouped = $impact.direct | Group-Object type
foreach ($group in $grouped) {
    Write-Host "  [$($group.Count)] $($group.Name):" -ForegroundColor White
    foreach ($item in $group.Group) {
        Write-Host "    • $($item.label)" -ForegroundColor DarkGray
        Write-Host "      Relationship: $($item.relationship)" -ForegroundColor DarkGray
        if ($item.file) {
            Write-Host "      File: $($item.file)" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}

if ($IncludeIndirect -and $impact.indirect.Count -gt 0) {
    Write-Host "INDIRECT IMPACT ($($impact.indirect.Count) transitive dependents):" -ForegroundColor Yellow
    Write-Host ""
    
    $indirectGrouped = $impact.indirect | Group-Object type
    foreach ($group in $indirectGrouped) {
        Write-Host "  [$($group.Count)] $($group.Name):" -ForegroundColor White
        $group.Group | Select-Object -First 5 | ForEach-Object {
            Write-Host "    • $($_.label)" -ForegroundColor DarkGray
            Write-Host "      Via: $($_.via)" -ForegroundColor DarkGray
        }
        if ($group.Count -gt 5) {
            Write-Host "    ... and $($group.Count - 5) more" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total direct dependents: $($impact.summary.total)" -ForegroundColor White
Write-Host "  Agents: $($impact.summary.agents)" -ForegroundColor DarkGray
Write-Host "  Skills: $($impact.summary.skills)" -ForegroundColor DarkGray
Write-Host "  Tracks: $($impact.summary.tracks)" -ForegroundColor DarkGray
Write-Host "  Behaviors: $($impact.summary.behaviors)" -ForegroundColor DarkGray

if ($impact.indirect.Count -gt 0) {
    Write-Host "  Indirect: $($impact.indirect.Count)" -ForegroundColor DarkGray
}

Write-Host ""

if ($impact.summary.total -gt 0) {
    Write-Host "⚠️  WARNING: Changing this skill affects $($impact.summary.total) direct dependent(s)." -ForegroundColor Yellow
    if ($impact.summary.agents -gt 0) {
        Write-Host "   Agents depend on this - breaking changes require agent updates." -ForegroundColor Yellow
    }
} else {
    Write-Host "✓ Safe to modify - no dependencies found." -ForegroundColor Green
}

Write-Host ""
