#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Split code-graph.json into separate files by node type.

.DESCRIPTION
    Reads the monolithic code-graph.json and creates one {type}-graph.json
    per node type. Each file contains:
    - All nodes of that type
    - All edges where both source and target are in that file's nodes
    - Metadata from original file

    Outputs to the same directory as the input file.

.PARAMETER InputFile
    Input code-graph.json path (default: data/MentorAgent/code/code-graph.json)

.EXAMPLE
    .\split-code-graph.ps1
    .\split-code-graph.ps1 -InputFile data/custom/code-graph.json
#>

param(
    [string]$InputFile = "data/MentorAgent/code/code-graph.json"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$scriptDir = $PSScriptRoot  # .github/knowledge-graph/build
$kgRoot = Split-Path $scriptDir -Parent  # .github/knowledge-graph
$githubRoot = Split-Path $kgRoot -Parent  # .github
$repoRoot = Split-Path $githubRoot -Parent  # repo root

$inputPath = if ([System.IO.Path]::IsPathRooted($InputFile)) {
    $InputFile
} else {
    # Normalize path separators and join
    $normalizedInput = $InputFile.Replace('/', '\')
    Join-Path $kgRoot $normalizedInput
}
$outputDir = Split-Path $inputPath -Parent

Write-Host "📦 Splitting code graph by type..." -ForegroundColor Cyan
Write-Host "  Input: $inputPath" -ForegroundColor Gray

# ============================================================================
# Load code-graph.json
# ============================================================================

if (-not (Test-Path $inputPath)) {
    Write-Host "❌ Input file not found: $inputPath" -ForegroundColor Red
    exit 1
}

$codeGraph = Get-Content $inputPath -Raw | ConvertFrom-Json -Depth 32
$allNodes = @($codeGraph.nodes)
$allEdges = @($codeGraph.edges)
$allBridges = if ($codeGraph.bridges) { @($codeGraph.bridges) } else { @() }

Write-Host "  Loaded: $($allNodes.Count) nodes, $($allEdges.Count) edges, $($allBridges.Count) bridges" -ForegroundColor DarkGray

# ============================================================================
# Group nodes by type
# ============================================================================

$typeGroups = $allNodes | Group-Object type

Write-Host "`n📊 Node types found: $($typeGroups.Count)" -ForegroundColor Cyan
foreach ($group in $typeGroups | Sort-Object Count -Descending) {
    Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor DarkGray
}

# ============================================================================
# Create separate graph per type (edges stay with source node)
# ============================================================================

$filesCreated = 0
$edgeCatalog = @{}  # Track edge types → files for catalog

foreach ($group in $typeGroups) {
    $typeName = $group.Name
    $typeNodes = @($group.Group)
    $nodeIds = @($typeNodes | ForEach-Object { $_.id })
    
    # Find edges where SOURCE is in this type's nodes (edges follow their source)
    $typeEdges = @($allEdges | Where-Object {
        $nodeIds -contains $_.source
    })
    
    # Track edge types for catalog
    foreach ($edge in $typeEdges) {
        $edgeType = $edge.type
        if (-not $edgeCatalog[$edgeType]) {
            $edgeCatalog[$edgeType] = @{
                files = @()
                count = 0
                description = ""
            }
        }
        
        $fileName = "$typeName-graph.json"
        if ($fileName -notin $edgeCatalog[$edgeType].files) {
            $edgeCatalog[$edgeType].files += $fileName
        }
        $edgeCatalog[$edgeType].count++
    }
    
    # Create output filename
    $outputFile = Join-Path $outputDir "$typeName-graph.json"
    
    # Build graph
    $typeGraph = @{
        nodes = $typeNodes
        edges = $typeEdges
        metadata = @{
            generated_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            generated_by = "split-code-graph.ps1"
            source_file = "code-graph.json"
            node_type = $typeName
            version = "1.0"
            edge_rule = "All edges where source is $typeName"
        }
    }
    
    # Add bridges to code-file graph (bridges connect system nodes to code-file nodes)
    if ($typeName -eq 'code-file' -and $allBridges.Count -gt 0) {
        $typeGraph['bridges'] = $allBridges
    }
    
    # Write file
    $typeGraph | ConvertTo-Json -Depth 32 | Set-Content $outputFile -Encoding UTF8
    $filesCreated++
    
    $bridgeInfo = if ($typeName -eq 'code-file' -and $allBridges.Count -gt 0) {
        ", $($allBridges.Count) bridges"
    } else {
        ""
    }
    
    Write-Host "  ✅ $typeName-graph.json" -ForegroundColor Green -NoNewline
    Write-Host " ($($typeNodes.Count) nodes, $($typeEdges.Count) edges$bridgeInfo)" -ForegroundColor DarkGray
}

# ============================================================================
# Generate edge catalog (lookup index)
# ============================================================================

$catalogFile = Join-Path $outputDir "code-edge-catalog.json"
$catalog = @{
    edge_types = $edgeCatalog
    metadata = @{
        generated_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        generated_by = "split-code-graph.ps1"
        description = "Index of edge types → files containing them"
        total_edge_types = $edgeCatalog.Count
        total_edges = ($edgeCatalog.Values | ForEach-Object { $_.count } | Measure-Object -Sum).Sum
    }
}

$catalog | ConvertTo-Json -Depth 32 | Set-Content $catalogFile -Encoding UTF8
$filesCreated++

Write-Host "  ✅ code-edge-catalog.json" -ForegroundColor Green -NoNewline
Write-Host " ($($edgeCatalog.Count) edge types indexed)" -ForegroundColor DarkGray

# ============================================================================
# Summary
# ============================================================================

Write-Host "`n✅ Split complete!" -ForegroundColor Green
Write-Host "  Files created: $filesCreated" -ForegroundColor White
Write-Host "  Output directory: $outputDir" -ForegroundColor DarkGray
Write-Host "`nOriginal code-graph.json preserved. Delete it after verifying split files." -ForegroundColor Yellow
