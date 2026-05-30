#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Scaffold a new node type by analyzing existing graph patterns and suggesting edges.

.DESCRIPTION
    Interactive helper for adding a new node type to the system graph. It:
    1. Analyzes the merged graph to understand existing edge patterns
    2. Prompts for node details (id, label, cluster, description)
    3. Suggests edge types based on patterns (e.g., "agents usually 'loads' skills")
    4. Generates template JSON nodes with suggested edges
    5. Optionally adds them to the system graph

.PARAMETER NodeType
    The node type to scaffold (e.g., "architecture", "component").

.PARAMETER Count
    Number of nodes to scaffold (default: 1).

.PARAMETER DryRun
    Generate template without adding to graph.

.EXAMPLE
    pwsh .github/knowledge-graph/build/scaffold-node-type.ps1 -NodeType "architecture"
    
.EXAMPLE
    pwsh .github/knowledge-graph/build/scaffold-node-type.ps1 -NodeType "component" -Count 3 -DryRun
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$NodeType,
    
    [int]$Count = 1,
    
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $PSScriptRoot
$graphPath = Join-Path $scriptRoot "output/merged-graph.json"
$systemGraphPath = Join-Path $scriptRoot "data/MentorAgent/system/mentor-graph.json"

if (-not (Test-Path $graphPath)) {
    Write-Host "ERROR: merged-graph.json not found. Run rebuild-if-stale.ps1 first." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $systemGraphPath)) {
    Write-Host "ERROR: system graph not found at $systemGraphPath" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Scaffold Node Type: $NodeType" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Load graphs
$graph = Get-Content -Raw $graphPath | ConvertFrom-Json
$systemGraph = Get-Content -Raw $systemGraphPath | ConvertFrom-Json

# Analyze edge patterns
Write-Host "Analyzing existing graph patterns..." -ForegroundColor Yellow
Write-Host ""

# Group edges by source node type
$edgePatterns = @{}
foreach ($edge in $graph.edges) {
    $sourceNode = $graph.nodes | Where-Object { $_.id -eq $edge.source } | Select-Object -First 1
    $targetNode = $graph.nodes | Where-Object { $_.id -eq $edge.target } | Select-Object -First 1
    
    if ($sourceNode -and $targetNode) {
        $pattern = "$($sourceNode.type) --[$($edge.type)]--> $($targetNode.type)"
        if (-not $edgePatterns.ContainsKey($pattern)) {
            $edgePatterns[$pattern] = 0
        }
        $edgePatterns[$pattern]++
    }
}

# Show top patterns
$topPatterns = $edgePatterns.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 10

Write-Host "Top edge patterns in the graph:" -ForegroundColor Cyan
foreach ($pattern in $topPatterns) {
    Write-Host "  $($pattern.Value)× $($pattern.Key)" -ForegroundColor DarkGray
}
Write-Host ""

# Available clusters
$clusters = $systemGraph.clusters | ForEach-Object { $_.id }
Write-Host "Available clusters:" -ForegroundColor Cyan
foreach ($cluster in $clusters) {
    Write-Host "  - $cluster" -ForegroundColor DarkGray
}
Write-Host ""

# Scaffold nodes
$newNodes = @()

for ($i = 1; $i -le $Count; $i++) {
    Write-Host ""
    Write-Host "Node $i/$Count" -ForegroundColor Yellow
    Write-Host "--------" -ForegroundColor Yellow
    
    # Prompt for details
    $id = Read-Host "Node ID (e.g., 'arch:profile-layer')"
    $label = Read-Host "Label (human-readable)"
    
    Write-Host ""
    Write-Host "Select cluster:" -ForegroundColor Yellow
    for ($j = 0; $j -lt $clusters.Count; $j++) {
        Write-Host "  [$j] $($clusters[$j])"
    }
    $clusterIndex = Read-Host "Cluster index"
    $cluster = $clusters[[int]$clusterIndex]
    
    $description = Read-Host "Description"
    
    # Suggest edge types based on patterns
    Write-Host ""
    Write-Host "Suggested edge types for '$NodeType' nodes:" -ForegroundColor Cyan
    
    $suggestions = @()
    
    # Pattern 1: If type matches common source patterns
    $fromPatterns = $edgePatterns.Keys | Where-Object { $_ -match "^$NodeType --\[(.+)\]--> (.+)" }
    if ($fromPatterns) {
        Write-Host "  Outgoing edges (what this uses):" -ForegroundColor Yellow
        foreach ($pattern in $fromPatterns) {
            if ($pattern -match "^$NodeType --\[(.+)\]--> (.+)") {
                $edgeType = $matches[1]
                $targetType = $matches[2]
                Write-Host "    → [$edgeType] to $targetType nodes" -ForegroundColor DarkGray
                $suggestions += [PSCustomObject]@{
                    direction = "outgoing"
                    edgeType = $edgeType
                    targetType = $targetType
                }
            }
        }
    }
    
    # Pattern 2: If type matches common target patterns
    $toPatterns = $edgePatterns.Keys | Where-Object { $_ -match "^(.+) --\[(.+)\]--> $NodeType" }
    if ($toPatterns) {
        Write-Host "  Incoming edges (what uses this):" -ForegroundColor Yellow
        foreach ($pattern in $toPatterns) {
            if ($pattern -match "^(.+) --\[(.+)\]--> $NodeType") {
                $sourceType = $matches[1]
                $edgeType = $matches[2]
                Write-Host "    ← [$edgeType] from $sourceType nodes" -ForegroundColor DarkGray
                $suggestions += [PSCustomObject]@{
                    direction = "incoming"
                    edgeType = $edgeType
                    sourceType = $sourceType
                }
            }
        }
    }
    
    # Build node template
    $node = [PSCustomObject]@{
        id = $id
        type = $NodeType
        label = $label
        cluster = $cluster
        description = $description
        file = $null
    }
    
    $newNodes += $node
    
    Write-Host ""
    Write-Host "Node template:" -ForegroundColor Green
    Write-Host ($node | ConvertTo-Json -Depth 10) -ForegroundColor DarkGray
}

# Generate output
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Template Generated" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$template = [PSCustomObject]@{
    nodes = $newNodes
    edges = @()
    notes = "Add suggested edges based on patterns shown above. Common edge types: composes, loads, implements, has_phase, follows, reads_from, writes_to, validates, tests."
}

Write-Host ($template | ConvertTo-Json -Depth 10)

if ($DryRun) {
    Write-Host ""
    Write-Host "DRY RUN - nodes NOT added to system graph." -ForegroundColor Yellow
} else {
    Write-Host ""
    $confirm = Read-Host "Add these nodes to $systemGraphPath? (y/n)"
    
    if ($confirm -eq 'y') {
        # Add nodes to system graph
        $systemGraph.nodes += $newNodes
        
        # Write back
        $systemGraph | ConvertTo-Json -Depth 100 | Set-Content -Path $systemGraphPath -Encoding UTF8
        
        Write-Host ""
        Write-Host "✅ Added $($newNodes.Count) node(s) to system graph." -ForegroundColor Green
        Write-Host "   Next: Add edges manually in $systemGraphPath" -ForegroundColor Yellow
        Write-Host "   Then: Run rebuild-if-stale.ps1 to merge" -ForegroundColor Yellow
    } else {
        Write-Host "Cancelled." -ForegroundColor Yellow
    }
}

Write-Host ""
