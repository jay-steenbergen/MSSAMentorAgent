<#
.SYNOPSIS
Generate pre-computed call-flow nodes for the knowledge graph.

.DESCRIPTION
Materializes call flows as first-class nodes in the graph. For each agent and high-value skill:
1. Traverse outgoing edges (what it uses/loads)
2. Traverse incoming edges (what uses it)
3. Create a call-flow node with metadata
4. Create edges from the source node to its call-flow

This makes call flow lookups instant (no traversal needed) and enables queries like:
"Which call flows use authentication?"

.PARAMETER GraphPath
Path to the merged graph JSON file. Defaults to merged-graph.json.

.PARAMETER OutputPath
Where to write the call-flow nodes JSON. Defaults to data/call-flow-nodes.json.

.PARAMETER MaxDepth
Maximum traversal depth for dependency chains. Default: 2.

.EXAMPLE
.\generate-call-flow-nodes.ps1
Generate call flows for all agents and top-level skills.

.EXAMPLE
.\generate-call-flow-nodes.ps1 -MaxDepth 3
Generate deeper call flows (3 levels of dependencies).
#>

param(
    [string]$GraphPath = "$PSScriptRoot/../output/merged-graph.json",
    [string]$OutputPath = "$PSScriptRoot/../output/call-flow-nodes.json",
    [int]$MaxDepth = 2
)

$ErrorActionPreference = "Stop"

# Load graph
Write-Host "Loading graph from $GraphPath..." -ForegroundColor Cyan
$graph = Get-Content -Raw $GraphPath | ConvertFrom-Json

# Select nodes to generate call flows for
$targetNodes = $graph.nodes | Where-Object { 
    $_.type -eq "agent" -or 
    ($_.type -eq "skill" -and $_.file -match "^\.github/skills/(learner-profile|methods|tracks)")
}

Write-Host "Generating call flows for $($targetNodes.Count) nodes..." -ForegroundColor Cyan

$callFlowNodes = @()
$callFlowEdges = @()

foreach ($node in $targetNodes) {
    Write-Host "  Processing: $($node.label)..." -ForegroundColor Gray
    
    # Get outgoing edges (what this node uses)
    $outgoing = $graph.edges | Where-Object { $_.source -eq $node.id }
    
    # Get incoming edges (what uses this node)
    $incoming = $graph.edges | Where-Object { $_.target -eq $node.id }
    
    # Build dependency chains (depth-limited traversal)
    $visited = @{}
    $script:dependencyChains = @()
    
    function Get-Dependencies {
        param($nodeId, $currentDepth)
        
        if ($currentDepth -ge $MaxDepth -or $visited.ContainsKey($nodeId)) {
            return
        }
        
        $visited[$nodeId] = $true
        $deps = $graph.edges | Where-Object { $_.source -eq $nodeId }
        
        foreach ($dep in $deps) {
            $targetNode = $graph.nodes | Where-Object { $_.id -eq $dep.target } | Select-Object -First 1
            if ($targetNode) {
                $script:dependencyChains += [PSCustomObject]@{
                    source = $nodeId
                    target = $dep.target
                    edgeType = $dep.type
                    label = $targetNode.label
                    depth = $currentDepth + 1
                }
                Get-Dependencies -nodeId $dep.target -currentDepth ($currentDepth + 1)
            }
        }
    }
    
    Get-Dependencies -nodeId $node.id -currentDepth 0
    $dependencyChains = $script:dependencyChains
    
    # Create call-flow node
    $callFlowId = "call-flow:$($node.id -replace '^[^:]+:', '')"
    $callFlowNode = @{
        id = $callFlowId
        type = "call-flow"
        label = "$($node.label) Call Flow"
        description = "Pre-computed call flow for $($node.label)"
        source_node = $node.id
        source_type = $node.type
        depth = $MaxDepth
        outgoing_count = $outgoing.Count
        incoming_count = $incoming.Count
        dependency_chain_count = $dependencyChains.Count
        generated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $callFlowNodes += $callFlowNode
    
    # Create edge from source node to its call-flow
    $callFlowEdges += @{
        source = $node.id
        target = $callFlowId
        type = "has-call-flow"
    }
    
    # Create edges to all nodes in the call flow (for easy querying)
    $allReferencedNodes = @($outgoing.target) + @($incoming.source) + @($dependencyChains.target) | Select-Object -Unique
    foreach ($refNodeId in $allReferencedNodes) {
        if ($refNodeId) {
            $callFlowEdges += @{
                source = $callFlowId
                target = $refNodeId
                type = "references"
            }
        }
    }
}

# Write output
$output = @{
    generated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    max_depth = $MaxDepth
    node_count = $callFlowNodes.Count
    edge_count = $callFlowEdges.Count
    nodes = $callFlowNodes
    edges = $callFlowEdges
}

$outputDir = Split-Path -Parent $OutputPath
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$output | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath

Write-Host "`n✅ Generated $($callFlowNodes.Count) call-flow nodes" -ForegroundColor Green
Write-Host "   Created $($callFlowEdges.Count) edges" -ForegroundColor Green
Write-Host "   Output: $OutputPath" -ForegroundColor Gray
