<#
.SYNOPSIS
Find the shortest path between two nodes in the graph.

.DESCRIPTION
Uses breadth-first search to find the shortest path between two nodes,
showing the edge types along the path.

.PARAMETER From
Starting node name or ID. Supports fuzzy matching.

.PARAMETER To
Ending node name or ID. Supports fuzzy matching.

.PARAMETER MaxDepth
Maximum path length to search (default: 5).

.PARAMETER AsJson
Output structured JSON instead of formatted text.

.EXAMPLE
.\Get-SkillPath.ps1 -From "Mentor" -To "query.psm1"
Find path from Mentor agent to query.psm1 module.

.EXAMPLE
.\Get-SkillPath.ps1 -From "learner-profile" -To "ride-along" -MaxDepth 3
Find path between two skills (max 3 hops).
#>

param(
    [Parameter(Mandatory)]
    [string]$From,
    
    [Parameter(Mandatory)]
    [string]$To,
    
    [int]$MaxDepth = 5,
    
    [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $PSScriptRoot

# Load query module and formatting functions
Import-Module "$scriptRoot/lib/query.psm1" -Force
. "$PSScriptRoot/_Format-GraphOutput.ps1"

# Load graph
$graph = Get-KnowledgeGraph

# Find start node (fuzzy match)
$fromNode = $graph.nodes | Where-Object { 
    $_.label -like "*$From*" -or $_.id -like "*$From*" 
} | Select-Object -First 1

if (-not $fromNode) {
    if (-not $AsJson) {
        $suggestions = $graph.nodes | Where-Object { 
            $_.label -match ($From.Split()[0]) 
        }
        Write-Host "Could not find start node: $From" -ForegroundColor Yellow
        Write-GraphSuggestions -Query $From -Suggestions $suggestions
    }
    exit 1
}

# Find end node (fuzzy match)
$toNode = $graph.nodes | Where-Object { 
    $_.label -like "*$To*" -or $_.id -like "*$To*" 
} | Select-Object -First 1

if (-not $toNode) {
    if (-not $AsJson) {
        $suggestions = $graph.nodes | Where-Object { 
            $_.label -match ($To.Split()[0]) 
        }
        Write-Host "Could not find end node: $To" -ForegroundColor Yellow
        Write-GraphSuggestions -Query $To -Suggestions $suggestions
    }
    exit 1
}

# Find path using query module
$path = Get-SkillPath -From $fromNode.id -To $toNode.id -MaxDepth $MaxDepth

# Build path details
$pathDetails = @()
if ($path -and $path.Count -gt 0) {
    for ($i = 0; $i -lt $path.Count; $i++) {
        $node = $graph.nodes | Where-Object { $_.id -eq $path[$i] }
        $step = [PSCustomObject]@{
            index = $i + 1
            id = $node.id
            label = $node.label
            type = $node.type
            edgeType = $null
        }
        
        if ($i -lt $path.Count - 1) {
            $edge = $graph.edges | Where-Object { 
                $_.source -eq $path[$i] -and $_.target -eq $path[$i + 1] 
            } | Select-Object -First 1
            $step.edgeType = if ($edge) { $edge.type } else { "unknown" }
        }
        
        $pathDetails += $step
    }
}

# Output
if ($AsJson) {
    [PSCustomObject]@{
        from = [PSCustomObject]@{ id = $fromNode.id; label = $fromNode.label }
        to = [PSCustomObject]@{ id = $toNode.id; label = $toNode.label }
        found = ($null -ne $path -and $path.Count -gt 0)
        pathLength = if ($path) { $path.Count } else { 0 }
        path = $pathDetails
    } | ConvertTo-Json -Depth 10
} else {
    if (-not $path -or $path.Count -eq 0) {
        Write-Host "No path found within $MaxDepth hops" -ForegroundColor Yellow
        Write-Host "Try increasing -MaxDepth or check if nodes are connected" -ForegroundColor Gray
        exit 1
    }
    
    Write-GraphPath -Path $path -Graph $graph
}

exit 0
