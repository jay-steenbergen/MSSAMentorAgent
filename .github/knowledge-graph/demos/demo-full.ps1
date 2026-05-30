#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive demo of all knowledge graph capabilities.
#>

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Knowledge Graph Full Demo" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "The knowledge graph enables 3 key workflows:" -ForegroundColor White
Write-Host "  1. Dynamic skill loading (load less, run faster)" -ForegroundColor DarkGray
Write-Host "  2. Quality audit (find technical debt)" -ForegroundColor DarkGray
Write-Host "  3. Skill discovery (avoid duplicates)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Press Enter to continue..." -ForegroundColor Yellow
$null = Read-Host

# Demo 1: Dynamic Skill Loading
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " [1] Dynamic Skill Loading" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Scenario: User says 'I want to build a REST API with TDD'" -ForegroundColor White
Write-Host ""
Write-Host "Running: Get-AgentLoadList -Intent 'build a REST API' -Method 'TDD' -Track 'cloud-app-dev'" -ForegroundColor Yellow
Write-Host ""

Import-Module (Resolve-Path '.github/knowledge-graph/lib/query.psm1') -Force
$files = Get-AgentLoadList -Intent "build a REST API" -Method "TDD" -Track "cloud-app-dev"

Write-Host "Skills to load (6 files instead of 20+):" -ForegroundColor Green
$files | ForEach-Object {
    Write-Host "  → $_" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Press Enter to continue..." -ForegroundColor Yellow
$null = Read-Host

# Demo 2: Quality Audit
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " [2] Quality Audit" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Scenario: Find technical debt in the graph" -ForegroundColor White
Write-Host ""
Write-Host "Running: audit-quality.ps1 -Category untested" -ForegroundColor Yellow
Write-Host ""

$report = Get-GraphQualityReport -Category untested

Write-Host "Found $($report.untested.Count) skills with no test coverage:" -ForegroundColor Yellow
$report.untested | Select-Object -First 3 | ForEach-Object {
    Write-Host "  • $($_.label) ($($_.file))" -ForegroundColor DarkGray
}
if ($report.untested.Count -gt 3) {
    Write-Host "  ... and $($report.untested.Count - 3) more" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Recommendation: Add test nodes with 'tests' edges" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press Enter to continue..." -ForegroundColor Yellow
$null = Read-Host

# Demo 3: Skill Discovery
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " [3] Skill Discovery" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Scenario: About to build 'TDD' skill - check if it exists" -ForegroundColor White
Write-Host ""
Write-Host "Running: Find-SimilarSkills -Name 'TDD'" -ForegroundColor Yellow
Write-Host ""

$similar = Find-SimilarSkills -Name "TDD" -Description "Test-driven development"

if ($similar.Count -gt 0) {
    $top = $similar[0]
    Write-Host "⚠️  Found existing skill:" -ForegroundColor Red
    Write-Host "  [$($top.score)] $($top.label)" -ForegroundColor White
    Write-Host "    File: $($top.file)" -ForegroundColor DarkGray
    Write-Host "    → $($top.recommendation)" -ForegroundColor Red
} else {
    Write-Host "✓ No similar skills found - safe to build!" -ForegroundColor Green
}

Write-Host ""
Write-Host "Press Enter to continue..." -ForegroundColor Yellow
$null = Read-Host

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "The knowledge graph transforms 3 workflows:" -ForegroundColor White
Write-Host ""
Write-Host "  BEFORE: Load 20+ skills every session" -ForegroundColor DarkGray
Write-Host "  AFTER:  Load 4-6 relevant skills (dynamic)" -ForegroundColor Green
Write-Host ""
Write-Host "  BEFORE: Manual tracking of technical debt" -ForegroundColor DarkGray
Write-Host "  AFTER:  Automatic quality audit (54 issues surfaced)" -ForegroundColor Green
Write-Host ""
Write-Host "  BEFORE: Build duplicate skills by accident" -ForegroundColor DarkGray
Write-Host "  AFTER:  Discovery check warns before building" -ForegroundColor Green
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
