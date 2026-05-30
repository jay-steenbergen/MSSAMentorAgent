<#
.SYNOPSIS
Show the call flow for a node (what it uses and what uses it).

.DESCRIPTION
Traces execution flow from a node by showing:
- Outgoing edges (what this node uses/loads/invokes)
- Incoming edges (what uses this node)
- Dependency chains for loaded skills

Attempts to use pre-computed call-flow nodes (instant lookup) and falls back
to live traversal if not available.

.PARAMETER NodeName
Name or ID of the node to trace. Supports fuzzy matching.

.PARAMETER AsJson
Output structured JSON instead of formatted text.

.PARAMETER Force
Force live traversal even if pre-computed call-flow exists.

.EXAMPLE
.\Get-CallFlow.ps1 -NodeName "Mentor"
Show call flow for the Mentor agent (uses pre-computed if available).

.EXAMPLE
.\Get-CallFlow.ps1 -NodeName "learner-profile" -AsJson
Get learner-profile call flow as JSON.

.EXAMPLE
.\Get-CallFlow.ps1 -NodeName "Mentor" -Force
Force live traversal (ignore pre-computed call-flow).
#>

param(
    [Parameter(Mandatory)]
    [string]$NodeName,
    
    [switch]$AsJson,
    
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $PSScriptRoot

# Load query module and formatting functions
Import-Module "$scriptRoot/lib/query.psm1" -Force
. "$PSScriptRoot/_Format-GraphOutput.ps1"

# Load graph
$graph = Get-KnowledgeGraph

# Try to load pre-computed call flows
$callFlowData = $null
$callFlowPath = "$scriptRoot/../output/call-flow-nodes.json"
if (-not $Force -and (Test-Path $callFlowPath)) {
    try {
        $callFlowData = Get-Content -Raw $callFlowPath | ConvertFrom-Json
    } catch {
        # Fall back to live traversal
    }
}

# Find node (fuzzy match)
$node = $graph.nodes | Where-Object { 
    $_.label -like "*$NodeName*" -or $_.id -like "*$NodeName*" 
} | Select-Object -First 1

if (-not $node) {
    if (-not $AsJson) {
        $suggestions = $graph.nodes | Where-Object { 
            $_.label -match ($NodeName.Split()[0]) 
        }
        Write-GraphSuggestions -Query $NodeName -Suggestions $suggestions
    }
    exit 1
}

# Checcall flow data (pre-computed or live)
if ($usePrecomputed) {
    # Get nodes referenced by the call-flow node
    $callFlowEdges = ($graph.edges + $callFlowData.edges) | Where-Object { 
        $_.source -eq $callFlowNode.id -and $_.type -eq "references" 
    }
    $referencedNodeIds = $callFlowEdges.target
    
    # Separate into outgoing and incoming
    $outgoing = $graph.edges | Where-Object { 
        $_.source -eq $node.id -and $referencedNodeIds -contains $_.target 
    }
    $incoming = $graph.edges | Where-Object { 
        $_.target -eq $node.id -and $referencedNodeIds -contains $_.source 
    }
} else {
    # Live traversal
    $outgoing = $graph.edges | Where-Object { $_.source -eq $node.id }
    $incoming = $graph.edges | Where-Object { $_.target -eq $node.id }
}

$outgoingItems = $outgoing | ForEach-Object {
    $targetNode = $graph.nodes | Where-Object { $_.id -eq $_.target }
    [PSCustomObject]@{
        edgeType = $_.type
        label = if ($targetNode) { $targetNode.label } else { $_.target }
        type = if ($targetNode) { $targetNode.type } else { $null }
        id = $_.target
    }
}

$outgoing = $graph.edges | Where-Object { $_.source -eq $node.id }
$outgoingItems = $outgoing | ForEach-Object {
    $targetNode = $graph.nodes | Where-Object { $_.id -eq $_.target }
    [PSCustomObject]@{
        edgeType = $_.type
        label = if ($targetNode) { $targetNode.label } else { $_.target }
        type = if ($targetNode) { $targetNode.type } else { $null }
        id = $_.target
    }
}

# Get incoming edges (what uses this node)
$incoming = $graph.edges | Where-Object { $_.target -eq $node.id }
$incomingItems = $incoming | ForEach-Object {
    $sourceNode = $graph.nodes | Where-Object { $_.id -eq $_.source }
    [PSCustomObject]@{
        edgeType = $_.type
        label = if ($sourceNode) { $sourceNode.label } else { $_.source }
        type = if ($sourceNode) { $sourceNode.type } else { $null }
        id = $_.source
    }
}

# Get dependency chains for loaded skills (if this is an agent)
$dependencyChains = @()
if ($node.type -eq "agent" -and $outgoing) {
    foreach ($edge in ($outgoing | Where-Object { $_.type -eq "loads" })) {
        $skill = $graph.nodes | Where-Object { $_.id -eq $edge.target }
        $skillDeps = $graph.edges | Where-Object { $_.source -eq $skill.id }
        
        $deps = $skillDeps | ForEach-Object {
            $depNode = $graph.nodes | Where-Object { $_.id -eq $_.target }
            [PSCustomObject]@{
                edgeType = $_.type
                label = if ($depNode) { $depNode.label } else { $_.target }
                type = if ($depNode) { $depNode.type } else { $null }
            }
        precomputed = $usePrecomputed
        call_flow_node = if ($callFlowNode) { $callFlowNode.id } else { $null }
        outgoing = $outgoingItems
        incoming = $incomingItems
        dependencyChains = $dependencyChains
    } | ConvertTo-Json -Depth 10
} else {
    $title = "CALL FLOW: $($node.label)"
    if ($usePrecomputed) {
        $title += " [cached]"
    }
    Write-GraphHeader -Title $title -NodeId $node.id
    Write-GraphSection -Title "Uses/Loads:" -Items $outgoingItems -Direction "outgoing" -ShowType
    Write-GraphSection -Title "Used By:" -Items $incomingItems -Direction "incoming" -ShowType
    
    if ($dependencyChains.Count -gt 0) {
        Write-Host "Skill dependency chains:" -ForegroundColor Yellow
        foreach ($chain in $dependencyChains) {
            Write-Host "`n  $($chain.skill):" -ForegroundColor White
            if ($chain.dependencies.Count -eq 0) {
                Write-Host "    (no dependencies)" -ForegroundColor Gray
            } else {
                foreach ($dep in $chain.dependencies) {
                    Write-Host "    → [$($dep.edgeType)] $($dep.label)" -ForegroundColor Gray
                }
            }
        }
        Write-Host ""
    }
    
    if ($usePrecomputed -and $callFlowNode) {
        Write-Host "Metadata:" -ForegroundColor DarkGray
        Write-Host "  Generated: $($callFlowNode.generated)" -ForegroundColor DarkGray
        Write-Host "  Depth: $($callFlowNode.depth)" -ForegroundColor DarkGray
    Write-GraphHeader -Title "CALL FLOW: $($node.label)" -NodeId $node.id
    Write-GraphSection -Title "Uses/Loads:" -Items $outgoingItems -Direction "outgoing" -ShowType
    Write-GraphSection -Title "Used By:" -Items $incomingItems -Direction "incoming" -ShowType
    
    if ($dependencyChains.Count -gt 0) {
        Write-Host "Skill dependency chains:" -ForegroundColor Yellow
        foreach ($chain in $dependencyChains) {
            Write-Host "`n  $($chain.skill):" -ForegroundColor White
            if ($chain.dependencies.Count -eq 0) {
                Write-Host "    (no dependencies)" -ForegroundColor Gray
            } else {
                foreach ($dep in $chain.dependencies) {
                    Write-Host "    → [$($dep.edgeType)] $($dep.label)" -ForegroundColor Gray
                }
            }
        }
        Write-Host ""
    }
}

exit 0
