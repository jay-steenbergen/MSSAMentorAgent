#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Merge every *-graph.json under .github/knowledge-graph/ into a single graph.
.DESCRIPTION
    Finds all subfolders containing a JSON file ending in '-graph.json', loads them,
    checks for ID collisions, merges clusters/nodes/edges, resolves cross-graph
    bridges into typed edges, and writes merged-graph.json at the root.

    ID-collision policy: ABORT. Each graph must use a distinct prefix scheme
    (see README.md). Collisions indicate prefix overlap that should be fixed in
    the source graph, not silently merged.

    Empty graphs (no nodes/edges) are allowed — they contribute clusters + bridges only.
.EXAMPLE
    pwsh .github/knowledge-graph/merge.ps1
.EXAMPLE
    pwsh .github/knowledge-graph/merge.ps1 -Output combined.json
#>
[CmdletBinding()]
param(
    [string]$Output = "output/merged-graph.json"
)

$ErrorActionPreference = "Stop"

$scriptDir = (Resolve-Path "$PSScriptRoot\..\..").Path
$outPath = Join-Path $scriptDir $Output

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Knowledge Graph Merge" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ---------- discover layers ----------
$graphFiles = Get-ChildItem -Path $scriptDir -Recurse -Filter "*-graph.json" `
    | Where-Object { $_.FullName -ne $outPath -and $_.Name -ne (Split-Path $outPath -Leaf) }

if ($graphFiles.Count -eq 0) {
    Write-Host "ERROR: No *-graph.json files found under $scriptDir" -ForegroundColor Red
    exit 1
}

Write-Host "Discovered $($graphFiles.Count) layer graph(s):" -ForegroundColor Green
foreach ($f in $graphFiles) {
    $rel = $f.FullName.Substring($scriptDir.Length + 1)
    Write-Host "  - $rel" -ForegroundColor DarkGray
}
Write-Host ""

# ---------- load + tag with layer ----------
$layers = @()
foreach ($f in $graphFiles) {
    try {
        $g = Get-Content $f.FullName -Raw | ConvertFrom-Json
    } catch {
        Write-Host "ERROR: Could not parse $($f.Name): $_" -ForegroundColor Red
        exit 1
    }
    $layerName = Split-Path (Split-Path $f.FullName -Parent) -Leaf
    $layers += [PSCustomObject]@{
        Name  = $layerName
        Path  = $f.FullName
        Graph = $g
    }
}

# ---------- check ID collisions across layers ----------
Write-Host "Checking for cross-layer ID collisions..." -ForegroundColor Cyan
$seen = @{}
$collisions = @()
foreach ($layer in $layers) {
    if (-not $layer.Graph.nodes) { continue }
    foreach ($node in $layer.Graph.nodes) {
        if ($seen.ContainsKey($node.id)) {
            $collisions += "  ID '$($node.id)' appears in BOTH '$($seen[$node.id])' AND '$($layer.Name)'"
        } else {
            $seen[$node.id] = $layer.Name
        }
    }
}
if ($collisions.Count -gt 0) {
    Write-Host "FAIL: ID collisions detected:" -ForegroundColor Red
    foreach ($c in $collisions) { Write-Host $c -ForegroundColor Red }
    Write-Host ""
    Write-Host "Fix: each layer must use distinct ID prefixes. See README.md." -ForegroundColor Yellow
    exit 1
}
Write-Host "  OK: no collisions across $($seen.Count) total nodes" -ForegroundColor Green
Write-Host ""

# ---------- merge ----------
Write-Host "Merging layers..." -ForegroundColor Cyan

$merged = [ordered]@{
    metadata = [ordered]@{
        name        = "MSSA Mentor — Merged Knowledge Graph"
        generated   = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
        last_updated = (Get-Date).ToString("yyyy-MM-dd")
        generator   = "merge.ps1"
        source_layers = @($layers | ForEach-Object {
            [ordered]@{
                name = $_.Name
                file = (Split-Path $_.Path -Leaf)
                nodes = if ($_.Graph.nodes) { $_.Graph.nodes.Count } else { 0 }
                edges = if ($_.Graph.edges) { $_.Graph.edges.Count } else { 0 }
            }
        })
    }
    clusters = @()
    nodes    = @()
    edges    = @()
    bridges  = @()
}

foreach ($layer in $layers) {
    if ($layer.Graph.clusters) {
        foreach ($c in $layer.Graph.clusters) {
            # tag cluster with its source layer, preserve any extra semantic fields
            $cluster = [ordered]@{
                id          = $c.id
                label       = $c.label
                description = $c.description
                layer       = $layer.Name
            }
            foreach ($prop in $c.PSObject.Properties) {
                if ($cluster.Contains($prop.Name)) { continue }
                $cluster[$prop.Name] = $prop.Value
            }
            $merged.clusters += [PSCustomObject]$cluster
        }
    }
    if ($layer.Graph.nodes) {
        foreach ($n in $layer.Graph.nodes) {
            # add 'layer' property to every node
            $node = $n | Select-Object *, @{ Name = "layer"; Expression = { $layer.Name } }
            $merged.nodes += $node
        }
    }
    if ($layer.Graph.edges) {
        foreach ($e in $layer.Graph.edges) {
            $edge = $e | Select-Object *, @{ Name = "layer"; Expression = { $layer.Name } }
            $merged.edges += $edge
        }
    }
    if ($layer.Graph.bridges) {
        foreach ($b in $layer.Graph.bridges) {
            $merged.bridges += [PSCustomObject]@{
                from_layer = $layer.Name
                system     = $b.system
                code       = $b.code
                type       = if ($b.type) { $b.type } else { "implemented_by" }
            }
        }
    }
}

# ---------- auto-declare clusters referenced by nodes but never defined ----------
# Nodes can carry a `cluster` field that points to a cluster id. If a layer assigns
# nodes to a cluster but forgets to declare it in clusters[], the gap audit (rightly)
# flags every such node. Rather than fail loudly, we synthesize a placeholder so the
# graph stays self-consistent and mark it auto_declared so a human can curate later.
$declaredClusterIds = @{}
foreach ($c in $merged.clusters) { $declaredClusterIds[$c.id] = $true }

$usedClusters = @{}
foreach ($n in $merged.nodes) {
    if ($n.PSObject.Properties.Name -contains 'cluster' -and $n.cluster) {
        if (-not $usedClusters.ContainsKey($n.cluster)) {
            $usedClusters[$n.cluster] = $n.layer
        }
    }
}

$autoDeclaredCount = 0
foreach ($cid in $usedClusters.Keys) {
    if (-not $declaredClusterIds.ContainsKey($cid)) {
        $merged.clusters += [PSCustomObject]([ordered]@{
            id            = $cid
            label         = $cid
            description   = "Auto-declared during merge — referenced by nodes but missing from clusters[] in source layer. Curate label/description in the originating graph."
            layer         = $usedClusters[$cid]
            auto_declared = $true
        })
        $autoDeclaredCount++
    }
}
if ($autoDeclaredCount -gt 0) {
    Write-Host "Auto-declared $autoDeclaredCount cluster(s) referenced by nodes but not in clusters[]" -ForegroundColor Yellow
}

# ---------- resolve bridges into edges ----------
Write-Host "Resolving $($merged.bridges.Count) bridge(s) into edges..." -ForegroundColor Cyan
$bridgeEdges = 0
$bridgeDropped = 0
foreach ($b in $merged.bridges) {
    $sysOk  = $seen.ContainsKey($b.system)
    $codeOk = $seen.ContainsKey($b.code)
    if ($sysOk -and $codeOk) {
        $merged.edges += [PSCustomObject]@{
            source = $b.system
            target = $b.code
            type   = $b.type
            label  = "bridge"
            layer  = "merged"
        }
        $bridgeEdges++
    } else {
        $missing = @()
        if (-not $sysOk)  { $missing += "system='$($b.system)'" }
        if (-not $codeOk) { $missing += "code='$($b.code)'" }
        Write-Host "  WARN: dropped bridge — missing nodes: $($missing -join ', ')" -ForegroundColor Yellow
        $bridgeDropped++
    }
}
Write-Host "  Resolved: $bridgeEdges | Dropped: $bridgeDropped" -ForegroundColor Green
Write-Host ""

# ---------- write output ----------
$json = $merged | ConvertTo-Json -Depth 32
# Ensure output dir exists — gitignored, so missing on fresh CI checkouts.
$outDir = Split-Path $outPath -Parent
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}
Set-Content -Path $outPath -Value $json -Encoding UTF8

# ---------- summary ----------
$nodeCount = $merged.nodes.Count
$edgeCount = $merged.edges.Count
$clusterCount = $merged.clusters.Count

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Layers merged:  $($layers.Count)" -ForegroundColor Green
Write-Host "  Clusters:       $clusterCount" -ForegroundColor Green
Write-Host "  Nodes:          $nodeCount" -ForegroundColor Green
Write-Host "  Edges:          $edgeCount  (incl. $bridgeEdges resolved bridges)" -ForegroundColor Green
Write-Host "  Output:         $Output" -ForegroundColor Green
Write-Host ""
