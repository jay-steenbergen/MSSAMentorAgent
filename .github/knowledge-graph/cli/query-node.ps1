#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
Query a node and its relationships from the knowledge graph.

.PARAMETER NodeId
The node ID to query (e.g., "agent:mentor", "skill:learner-profile")

.PARAMETER ShowEdges
Show all edges connected to this node

.PARAMETER Layer
Which layer to query: system, code, or merged (default: system)
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$NodeId,
    
    [Parameter()]
    [switch]$ShowEdges,
    
    [Parameter()]
    [ValidateSet('system', 'code', 'merged')]
    [string]$Layer = 'system'
)

$ErrorActionPreference = 'Stop'

# Resolve paths
$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path (Split-Path (Split-Path $scriptDir -Parent) -Parent) -Parent
$dataDir = Join-Path $repoRoot ".github/knowledge-graph/data/MentorAgent/$Layer"
$graphFile = Join-Path $dataDir "mentor-graph.json"

if (-not (Test-Path $graphFile)) {
    Write-Error "Graph file not found: $graphFile"
    exit 1
}

# Load graph
$graph = Get-Content $graphFile -Raw | ConvertFrom-Json

# Find node
$node = $graph.nodes | Where-Object { $_.id -eq $NodeId }

if (-not $node) {
    Write-Warning "Node '$NodeId' not found in $Layer layer"
    exit 1
}

# Display node
Write-Host "`n=== NODE: $($node.id) ===" -ForegroundColor Cyan
Write-Host "Type: $($node.type)"
if ($node.file) { Write-Host "File: $($node.file)" }
if ($node.description) { Write-Host "Description: $($node.description)" }
if ($node.metadata) {
    Write-Host "`nMetadata:"
    $node.metadata.PSObject.Properties | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Value)"
    }
}

if ($ShowEdges) {
    # Find all edges
    $outgoing = $graph.edges | Where-Object { $_.source -eq $NodeId }
    $incoming = $graph.edges | Where-Object { $_.target -eq $NodeId }
    
    if ($outgoing) {
        Write-Host "`n=== OUTGOING EDGES ===" -ForegroundColor Green
        $outgoing | ForEach-Object {
            Write-Host "  [$($_.type)] -> $($_.target)"
            if ($_.metadata) {
                $_.metadata.PSObject.Properties | ForEach-Object {
                    Write-Host "    $($_.Name): $($_.Value)"
                }
            }
        }
    }
    
    if ($incoming) {
        Write-Host "`n=== INCOMING EDGES ===" -ForegroundColor Yellow
        $incoming | ForEach-Object {
            Write-Host "  $($_.source) -> [$($_.type)]"
            if ($_.metadata) {
                $_.metadata.PSObject.Properties | ForEach-Object {
                    Write-Host "    $($_.Name): $($_.Value)"
                }
            }
        }
    }
}

Write-Host ""
