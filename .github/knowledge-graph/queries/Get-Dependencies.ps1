<#
.SYNOPSIS
Show what a node depends on (outgoing edges).

.DESCRIPTION
Lists all outgoing edges from a node, showing what it uses, loads, or invokes.

.PARAMETER NodeName
Name or ID of the node to query. Supports fuzzy matching.

.PARAMETER AsJson
Output structured JSON instead of formatted text.

.EXAMPLE
.\Get-Dependencies.ps1 -NodeName "learner-profile"
Show what the learner-profile skill depends on.
#>

param(
    [Parameter(Mandatory)]
    [string]$NodeName,
    
    [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $PSScriptRoot

# Load query module and formatting functions
Import-Module "$scriptRoot/lib/query.psm1" -Force
. "$PSScriptRoot/_Format-GraphOutput.ps1"

# Load graph
$graph = Get-KnowledgeGraph

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

# Get outgoing edges
$outgoing = $graph.edges | Where-Object { $_.source -eq $node.id }
$items = $outgoing | ForEach-Object {
    $targetNode = $graph.nodes | Where-Object { $_.id -eq $_.target }
    [PSCustomObject]@{
        edgeType = $_.type
        label = if ($targetNode) { $targetNode.label } else { $_.target }
        type = if ($targetNode) { $targetNode.type } else { $null }
        id = $_.target
    }
}

# Output
if ($AsJson) {
    [PSCustomObject]@{
        node = [PSCustomObject]@{
            id = $node.id
            label = $node.label
            type = $node.type
        }
        dependencies = $items
    } | ConvertTo-Json -Depth 10
} else {
    Write-GraphHeader -Title "WHAT $($node.label) USES" -NodeId $node.id
    Write-GraphSection -Title "Dependencies:" -Items $items -Direction "outgoing" -ShowType
}

exit 0
