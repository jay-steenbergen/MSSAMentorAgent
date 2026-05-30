<#
.SYNOPSIS
Extract and export a subgraph from the knowledge graph.

.DESCRIPTION
Filters the graph by various criteria and exports the result for analysis.
Useful for:
- Exporting specific domains for visualization (Gephi, Neo4j, etc.)
- Analyzing skill dependencies
- Finding all nodes related to a specific component

.PARAMETER RootNode
Starting node name or ID. Exports this node and all nodes within MaxDepth.

.PARAMETER NodeTypes
Array of node types to include (e.g., "skill", "agent", "code-file").

.PARAMETER EdgeTypes
Array of edge types to include (e.g., "loads", "composes", "invokes").

.PARAMETER MaxDepth
Maximum distance from RootNode (if specified). Default: 3.

.PARAMETER OutputFormat
Export format: JSON (default), GraphML, or DOT.

.PARAMETER OutputPath
Where to save the export. If omitted, prints to console.

.EXAMPLE
.\Get-Subgraph.ps1 -RootNode "Mentor" -MaxDepth 2 -OutputFormat GraphML -OutputPath mentor-subgraph.graphml
Export Mentor's 2-hop neighborhood as GraphML for Gephi.

.EXAMPLE
.\Get-Subgraph.ps1 -NodeTypes "skill","agent" -OutputFormat JSON
Export all skills and agents as JSON (console output).

.EXAMPLE
.\Get-Subgraph.ps1 -NodeTypes "call-flow" -EdgeTypes "references" -OutputPath call-flows.json
Export all call-flow nodes and their referenced nodes.
#>

param(
    [string]$RootNode,
    [string[]]$NodeTypes,
    [string[]]$EdgeTypes,
    [int]$MaxDepth = 3,
    [ValidateSet("JSON", "GraphML", "DOT")]
    [string]$OutputFormat = "JSON",
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $PSScriptRoot

# Load graph
Import-Module "$scriptRoot/lib/query.psm1" -Force
$graph = Get-KnowledgeGraph

# Filter nodes
$filteredNodes = $graph.nodes

if ($RootNode) {
    # Find root node
    $root = $graph.nodes | Where-Object { 
        $_.label -like "*$RootNode*" -or $_.id -like "*$RootNode*" 
    } | Select-Object -First 1
    
    if (-not $root) {
        Write-Host "Root node not found: $RootNode" -ForegroundColor Red
        exit 1
    }
    
    # BFS to find all nodes within MaxDepth
    $visited = @{}
    $queue = New-Object System.Collections.Queue
    $queue.Enqueue(@{ id = $root.id; depth = 0 })
    $visited[$root.id] = $true
    
    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        
        if ($current.depth -ge $MaxDepth) {
            continue
        }
        
        # Get neighbors
        $neighbors = @(
            ($graph.edges | Where-Object { $_.source -eq $current.id } | ForEach-Object { $_.target }),
            ($graph.edges | Where-Object { $_.target -eq $current.id } | ForEach-Object { $_.source })
        ) | Select-Object -Unique
        
        foreach ($neighborId in $neighbors) {
            if (-not $visited.ContainsKey($neighborId)) {
                $visited[$neighborId] = $true
                $queue.Enqueue(@{ id = $neighborId; depth = $current.depth + 1 })
            }
        }
    }
    
    $filteredNodes = $graph.nodes | Where-Object { $visited.ContainsKey($_.id) }
}

if ($NodeTypes) {
    $filteredNodes = $filteredNodes | Where-Object { $NodeTypes -contains $_.type }
}

# Filter edges
$nodeIds = $filteredNodes.id
$filteredEdges = $graph.edges | Where-Object { 
    $nodeIds -contains $_.source -and $nodeIds -contains $_.target 
}

if ($EdgeTypes) {
    $filteredEdges = $filteredEdges | Where-Object { $EdgeTypes -contains $_.type }
}

# Export based on format
$output = $null

switch ($OutputFormat) {
    "JSON" {
        $output = @{
            metadata = @{
                generated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                node_count = $filteredNodes.Count
                edge_count = $filteredEdges.Count
                root_node = if ($RootNode) { $root.id } else { $null }
                max_depth = if ($RootNode) { $MaxDepth } else { $null }
            }
            nodes = $filteredNodes
            edges = $filteredEdges
        } | ConvertTo-Json -Depth 10
    }
    
    "GraphML" {
        $xml = @"
<?xml version="1.0" encoding="UTF-8"?>
<graphml xmlns="http://graphml.graphdrawing.org/xmlns">
  <key id="label" for="node" attr.name="label" attr.type="string"/>
  <key id="type" for="node" attr.name="type" attr.type="string"/>
  <key id="type" for="edge" attr.name="type" attr.type="string"/>
  <graph id="G" edgedefault="directed">
"@
        foreach ($node in $filteredNodes) {
            $safeId = $node.id -replace '[^a-zA-Z0-9_]', '_'
            $xml += "    <node id=`"$safeId`">`n"
            $xml += "      <data key=`"label`">$([System.Security.SecurityElement]::Escape($node.label))</data>`n"
            $xml += "      <data key=`"type`">$($node.type)</data>`n"
            $xml += "    </node>`n"
        }
        
        foreach ($edge in $filteredEdges) {
            $safeSource = $edge.source -replace '[^a-zA-Z0-9_]', '_'
            $safeTarget = $edge.target -replace '[^a-zA-Z0-9_]', '_'
            $xml += "    <edge source=`"$safeSource`" target=`"$safeTarget`">`n"
            $xml += "      <data key=`"type`">$($edge.type)</data>`n"
            $xml += "    </edge>`n"
        }
        
        $xml += "  </graph>`n</graphml>"
        $output = $xml
    }
    
    "DOT" {
        $dot = "digraph G {`n"
        $dot += "  rankdir=LR;`n"
        $dot += "  node [shape=box];`n`n"
        
        foreach ($node in $filteredNodes) {
            $safeId = $node.id -replace '[^a-zA-Z0-9_]', '_'
            $label = $node.label -replace '"', '\"'
            $dot += "  $safeId [label=`"$label`"]`n"
        }
        
        $dot += "`n"
        
        foreach ($edge in $filteredEdges) {
            $safeSource = $edge.source -replace '[^a-zA-Z0-9_]', '_'
            $safeTarget = $edge.target -replace '[^a-zA-Z0-9_]', '_'
            $dot += "  $safeSource -> $safeTarget [label=`"$($edge.type)`"]`n"
        }
        
        $dot += "}`n"
        $output = $dot
    }
}

# Write output
if ($OutputPath) {
    $output | Set-Content -Path $OutputPath
    Write-Host "Exported subgraph:" -ForegroundColor Green
    Write-Host "  Nodes: $($filteredNodes.Count)" -ForegroundColor White
    Write-Host "  Edges: $($filteredEdges.Count)" -ForegroundColor White
    Write-Host "  Format: $OutputFormat" -ForegroundColor White
    Write-Host "  Path: $OutputPath" -ForegroundColor Gray
} else {
    Write-Output $output
}

exit 0
