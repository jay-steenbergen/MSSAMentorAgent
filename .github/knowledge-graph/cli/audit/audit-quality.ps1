#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Run quality audit on the knowledge graph to find technical debt.

.DESCRIPTION
    Surfaces quality issues:
    - Orphans: Skills nothing references (dead code candidates)
    - Dead-ends: Skills that don't reference anything (isolated)
    - Broken refs: Files that don't exist
    - No description: Skills with empty descriptions (hurts search)
    - Unclustered: Skills not assigned to any cluster
    - Untested: Skills with no test coverage

.PARAMETER Category
    Filter to specific category or 'all' (default).

.PARAMETER Json
    Output as JSON instead of formatted report.

.EXAMPLE
    ./audit-quality.ps1
    ./audit-quality.ps1 -Category orphans
    ./audit-quality.ps1 -Json
#>

[CmdletBinding()]
param(
    [ValidateSet('all', 'orphans', 'dead-ends', 'broken-refs', 'no-description', 'unclustered', 'untested', 'no-purpose')]
    [string]$Category = 'all',
    
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../../lib/query.psm1') -Force

$report = Get-GraphQualityReport -Category $Category

# Augment with purpose-linkage check (decision:2026-06-03-purpose-experiment).
# Translates the forward-reachability result into the same { id, label, type, file, issue }
# shape as the other categories so the existing loop renders it without special-casing.
if ($Category -in @('all', 'no-purpose')) {
    $linkage = Get-PurposeLinkageReport
    $report | Add-Member -NotePropertyName no_purpose -NotePropertyValue (@(
        $linkage.unlinked | ForEach-Object {
            [PSCustomObject]@{
                id    = $_.id
                label = $_.label
                type  = $_.type
                file  = $_.file
                issue = "No outgoing-edge path to any purpose:* node"
            }
        }
    )) -Force
} else {
    $report | Add-Member -NotePropertyName no_purpose -NotePropertyValue @() -Force
}

if ($Json) {
    $report | ConvertTo-Json -Depth 10
    exit 0
}

# Format as readable report
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Knowledge Graph Quality Audit" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$categories = @(
    @{ Key = 'orphans'; Title = 'Orphan Skills (Nothing References Them)'; Color = 'Yellow' }
    @{ Key = 'dead_ends'; Title = 'Dead-End Skills (Reference Nothing)'; Color = 'Yellow' }
    @{ Key = 'broken_refs'; Title = 'Broken File References'; Color = 'Red' }
    @{ Key = 'no_description'; Title = 'Missing Descriptions'; Color = 'Yellow' }
    @{ Key = 'unclustered'; Title = 'Unclustered Nodes'; Color = 'Yellow' }
    @{ Key = 'untested'; Title = 'Untested Skills'; Color = 'Magenta' }
    @{ Key = 'no_purpose'; Title = 'No Purpose Linkage (rule/behavior/skill not reaching purpose:*)'; Color = 'Yellow' }
)

$totalIssues = 0
foreach ($cat in $categories) {
    # Normalize: param values use hyphens (no-purpose), hash keys use underscores (no_purpose).
    if ($Category -ne 'all' -and ($Category -replace '-', '_') -ne $cat.Key) { continue }
    
    $issues = $report.($cat.Key)
    $totalIssues += $issues.Count
    
    Write-Host "[$($issues.Count)] $($cat.Title)" -ForegroundColor $cat.Color
    
    if ($issues.Count -eq 0) {
        Write-Host "  ✓ No issues" -ForegroundColor Green
        Write-Host ""
        continue
    }
    
    Write-Host ""
    
    # Show up to 10 examples
    $shown = 0
    foreach ($issue in $issues) {
        if ($shown -ge 10) {
            Write-Host "  ... and $($issues.Count - 10) more" -ForegroundColor DarkGray
            break
        }
        
        Write-Host "  • $($issue.label)" -ForegroundColor White
        Write-Host "    ID: $($issue.id)" -ForegroundColor DarkGray
        Write-Host "    Type: $($issue.type)" -ForegroundColor DarkGray
        if ($issue.file) {
            Write-Host "    File: $($issue.file)" -ForegroundColor DarkGray
        }
        Write-Host "    Issue: $($issue.issue)" -ForegroundColor DarkGray
        Write-Host ""
        
        $shown++
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($totalIssues -eq 0) {
    Write-Host "✓ No quality issues found!" -ForegroundColor Green
} else {
    Write-Host "Found $totalIssues quality issues across $($categories.Count) categories." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Recommendations:" -ForegroundColor White
    
    if ($report.orphans.Count -gt 0) {
        Write-Host "  • Orphans: Wire to agent/track or delete if unused" -ForegroundColor DarkGray
    }
    if ($report.dead_ends.Count -gt 0) {
        Write-Host "  • Dead-ends: Add 'requires' or 'recommends' edges" -ForegroundColor DarkGray
    }
    if ($report.broken_refs.Count -gt 0) {
        Write-Host "  • Broken refs: Fix file paths or delete stale nodes" -ForegroundColor DarkGray
    }
    if ($report.no_description.Count -gt 0) {
        Write-Host "  • No description: Add descriptions for better search" -ForegroundColor DarkGray
    }
    if ($report.unclustered.Count -gt 0) {
        Write-Host "  • Unclustered: Assign to relevant clusters" -ForegroundColor DarkGray
    }
    if ($report.untested.Count -gt 0) {
        Write-Host "  • Untested: Add test nodes with 'tests' edges" -ForegroundColor DarkGray
    }
    if ($report.no_purpose.Count -gt 0) {
        Write-Host "  • No purpose linkage: link via [serves] edge OR through an existing behavior:NN-* that does" -ForegroundColor DarkGray
    }
}

Write-Host ""
