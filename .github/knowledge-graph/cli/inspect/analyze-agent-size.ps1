#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
Analyze agent file size and suggest extraction opportunities.

.PARAMETER AgentId
The agent ID to analyze (e.g., "agent:mentor")

.PARAMETER ShowRecommendations
Show specific recommendations for shrinking the file
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$AgentId,
    
    [Parameter()]
    [switch]$ShowRecommendations
)

$ErrorActionPreference = 'Stop'

# Resolve paths
$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $scriptDir -Parent) -Parent) -Parent) -Parent
$graphFile = Join-Path $repoRoot ".github/knowledge-graph/data/MentorAgent/system/mentor-graph.json"

if (-not (Test-Path $graphFile)) {
    Write-Error "Graph file not found: $graphFile"
    exit 1
}

# Load graph
$graph = Get-Content $graphFile -Raw | ConvertFrom-Json

# Find agent node
$agent = $graph.nodes | Where-Object { $_.id -eq $AgentId }
if (-not $agent) {
    Write-Error "Agent '$AgentId' not found"
    exit 1
}

# Get agent file
$agentFile = Join-Path $repoRoot $agent.file
if (-not (Test-Path $agentFile)) {
    Write-Error "Agent file not found: $agentFile"
    exit 1
}

# Read file
$content = Get-Content $agentFile -Raw
$lines = Get-Content $agentFile

Write-Host "`n=== AGENT FILE ANALYSIS: $AgentId ===" -ForegroundColor Cyan
Write-Host "File: $($agent.file)"
Write-Host "Size: $($content.Length) chars, $($lines.Count) lines"

# Analyze edges
$edges = $graph.edges | Where-Object { $_.source -eq $AgentId }
$edgesByType = $edges | Group-Object -Property type

Write-Host "`n=== EDGE ANALYSIS ===" -ForegroundColor Green
$edgesByType | Sort-Object Count -Descending | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Count) edges"
}

if ($ShowRecommendations) {
    Write-Host "`n=== EXTRACTION OPPORTUNITIES ===" -ForegroundColor Yellow
    
    # Behaviors that could be extracted
    $behaviors = $edges | Where-Object { $_.type -eq 'follows' }
    if ($behaviors.Count -gt 5) {
        Write-Host "`n1. EXTRACT BEHAVIORS to tool:" -ForegroundColor Magenta
        Write-Host "   Current: $($behaviors.Count) 'follows' behaviors embedded inline"
        Write-Host "   Recommendation: Create cli/inspect/get-behavior.ps1"
        Write-Host "   Savings: ~30-40 lines per behavior = ~$($behaviors.Count * 35) lines"
        Write-Host "   Usage: pwsh cli/inspect/get-behavior.ps1 'identify-learner'"
    }
    
    # Adaptation rules
    $adaptations = $edges | Where-Object { $_.type -eq 'adapts_via' }
    if ($adaptations.Count -gt 5) {
        Write-Host "`n2. EXTRACT ADAPTATION RULES to tool:" -ForegroundColor Magenta
        Write-Host "   Current: $($adaptations.Count) 'adapts_via' rules embedded inline"
        Write-Host "   Recommendation: Create cli/adapt-to-learner.ps1"
        Write-Host "   Input: profile.json | Output: teaching parameters"
        Write-Host "   Savings: ~15-20 lines per rule = ~$($adaptations.Count * 17) lines"
    }
    
    # Antipatterns
    $antipatterns = $edges | Where-Object { $_.type -eq 'avoids' }
    if ($antipatterns.Count -gt 3) {
        Write-Host "`n3. EXTRACT ANTIPATTERNS to tool:" -ForegroundColor Magenta
        Write-Host "   Current: $($antipatterns.Count) 'avoids' antipatterns listed inline"
        Write-Host "   Recommendation: Create cli/check-antipatterns.ps1"
        Write-Host "   Savings: ~5-8 lines per antipattern = ~$($antipatterns.Count * 6) lines"
    }
    
    # CLI tools already exist
    $cliTools = $edges | Where-Object { $_.type -eq 'uses' }
    if ($cliTools.Count -gt 0) {
        Write-Host "`n4. CLI TOOLS (already extracted):" -ForegroundColor Green
        $cliTools | ForEach-Object {
            $target = $_.target -replace 'cli-tool:', ''
            Write-Host "   ✓ $target"
        }
    }
    
    # Method enforcement
    $methods = ($graph.nodes | Where-Object { $_.id -eq 'list:methods' })
    if ($methods) {
        Write-Host "`n5. EXTRACT METHOD ENFORCEMENT to tool:" -ForegroundColor Magenta
        Write-Host "   Current: 200+ lines of TDD/BDD/spike/ride-along rules inline"
        Write-Host "   Recommendation: Create cli/validate/enforce-method.ps1"
        Write-Host "   Input: method name + learner action"
        Write-Host "   Output: STOP/CONTINUE + violation message"
        Write-Host "   Savings: ~200 lines"
    }
    
    # Track enforcement
    $tracks = ($graph.nodes | Where-Object { $_.id -eq 'list:tracks' })
    if ($tracks) {
        Write-Host "`n6. EXTRACT TRACK ENFORCEMENT to tool:" -ForegroundColor Magenta
        Write-Host "   Current: ~100 lines of track domain rules inline"
        Write-Host "   Recommendation: Create cli/validate/enforce-track.ps1"
        Write-Host "   Input: track name + code/action"
        Write-Host "   Output: IN_DOMAIN/OUT_OF_DOMAIN + redirect message"
        Write-Host "   Savings: ~100 lines"
    }
    
    # Session protocols
    $sessionProtocols = $edges | Where-Object { $_.type -eq 'follows' -and $_.target -like 'session-*' }
    if ($sessionProtocols.Count -gt 0) {
        Write-Host "`n7. EXTRACT SESSION PROTOCOLS to tool:" -ForegroundColor Magenta
        Write-Host "   Current: Session start/end/switch protocols inline"
        Write-Host "   Recommendation: Create cli/session/session-protocol.ps1"
        Write-Host "   Phases: start | end | switch-method | switch-track"
        Write-Host "   Savings: ~80-100 lines"
    }
    
    Write-Host "`n=== TOTAL POTENTIAL SAVINGS ===" -ForegroundColor Cyan
    $totalSavings = ($behaviors.Count * 35) + ($adaptations.Count * 17) + ($antipatterns.Count * 6) + 200 + 100 + 90
    Write-Host "Estimated: ~$totalSavings lines (~$(($totalSavings / $lines.Count * 100).ToString('0'))% reduction)"
    Write-Host "`nResult: Agent file becomes pure coordinator, calls tools for logic"
}

Write-Host ""
