<#
.SYNOPSIS
Show what depends on a node (incoming edges).

.DESCRIPTION
Lists all incoming edges to a node, showing what uses or depends on it.

.PARAMETER NodeName
Name or ID of the node to query. Supports fuzzy matching.

.PARAMETER AsJson
Output structured JSON instead of formatted text.

.EXAMPLE
.\Get-Dependents.ps1 -NodeName "query.psm1"
Show what uses the query.psm1 module.
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

# Get incoming edges
$incoming = $graph.edges | Where-Object { $_.target -eq $node.id }
$items = $incoming | ForEach-Object {
    $sourceNode = $graph.nodes | Where-Object { $_.id -eq $_.source }
    [PSCustomObject]@{
        edgeType = $_.type
        label = if ($sourceNode) { $sourceNode.label } else { $_.source }
        type = if ($sourceNode) { $sourceNode.type } else { $null }
        id = $_.source
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
        dependents = $items
    } | ConvertTo-Json -Depth 10
} else {
    Write-GraphHeader -Title "WHAT USES $($node.label)" -NodeId $node.id
    Write-GraphSection -Title "Dependents:" -Items $items -Direction "incoming" -ShowType
}

exit 0
