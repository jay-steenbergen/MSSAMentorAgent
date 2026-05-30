#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Topology health check for the knowledge graph (code, system, or merged).
.DESCRIPTION
    Read-only diagnostic that reports on the internal well-formedness of a
    graph file. Distinct from system/audit.ps1 — that one checks the graph
    against the live repo (drift). This one checks the graph against itself
    (structure).

    Checks:
      FAIL  dangling-edges      edge source/target points to missing node
      FAIL  duplicate-node-ids  same id appears in nodes[] more than once
      FAIL  stub-nodes          nodes with missing:true (broken refs)
      WARN  islands             connected components > 1
      WARN  orphan-nodes        zero incoming and zero outgoing edges
      WARN  unclustered-nodes   cluster field empty or points to missing cluster
      WARN  duplicate-edges     same (source, target, type) > 1
      WARN  dropped-bridges     unresolved cross-layer bridges (merged only)
      INFO  node-type-dist      counts per node.type
      INFO  edge-type-dist      counts per edge.type
      INFO  top-hubs            top 10 highest-degree nodes
      INFO  cluster-sizes       node count per cluster
      INFO  prunable            leaf nodes reached only by 'contains' with no description

    Exit code: 0 on all-pass, non-zero if any FAIL.
.PARAMETER Layer
    Which graph to check: code, system, or merged. Default: merged.
.PARAMETER Json
    Output a single JSON object instead of human-readable console text.
.PARAMETER Quiet
    Suppress INFO sections. WARN/FAIL still shown.
.EXAMPLE
    pwsh .github/knowledge-graph/health.ps1
.EXAMPLE
    pwsh .github/knowledge-graph/health.ps1 -Layer code
.EXAMPLE
    pwsh .github/knowledge-graph/health.ps1 -Json | ConvertFrom-Json
#>
[CmdletBinding()]
param(
    [ValidateSet('code', 'system', 'merged')]
    [string]$Layer = 'merged',
    [switch]$Json,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$scriptDir = (Resolve-Path "$PSScriptRoot\..").Path

# ---------- locate graph ----------
$graphPath = switch ($Layer) {
    'code'   { Join-Path $scriptDir 'data\MentorAgent\code\code-graph.json' }
    'system' { Join-Path $scriptDir 'data\MentorAgent\system\mentor-graph.json' }
    'merged' { Join-Path $scriptDir 'output/merged-graph.json' }
}

if (-not (Test-Path $graphPath)) {
    Write-Host "ERROR: Graph file not found: $graphPath" -ForegroundColor Red
    if ($Layer -eq 'merged') {
        Write-Host "Hint: run merge.ps1 first." -ForegroundColor DarkGray
    }
    exit 2
}

$graph = Get-Content $graphPath -Raw | ConvertFrom-Json -Depth 32
$nodes = @($graph.nodes)
$edges = @($graph.edges)
$clusters = @($graph.clusters)

# ---------- index ----------
$nodeIdSet = @{}
$dupeIds = @()
foreach ($n in $nodes) {
    if ($nodeIdSet.ContainsKey($n.id)) {
        $dupeIds += $n.id
    }
    else {
        $nodeIdSet[$n.id] = $n
    }
}

$clusterIdSet = @{}
foreach ($c in $clusters) { $clusterIdSet[$c.id] = $c }

# ---------- checks ----------
$findings = [ordered]@{}

# FAIL: dangling edges
$dangling = @()
foreach ($e in $edges) {
    $srcOk = $nodeIdSet.ContainsKey($e.source)
    $tgtOk = $nodeIdSet.ContainsKey($e.target)
    if (-not $srcOk -or -not $tgtOk) {
        $dangling += [pscustomobject]@{
            source       = $e.source
            target       = $e.target
            type         = $e.type
            missing_side = if (-not $srcOk -and -not $tgtOk) { 'both' } elseif (-not $srcOk) { 'source' } else { 'target' }
        }
    }
}
$findings['dangling-edges'] = @{ severity = 'FAIL'; count = $dangling.Count; items = $dangling }

# FAIL: duplicate node IDs
$findings['duplicate-node-ids'] = @{ severity = 'FAIL'; count = $dupeIds.Count; items = $dupeIds }

# FAIL: stub nodes (exclude intentionally excluded paths)
$excludedPatterns = @(
    '\.github[/\\]knowledge-graph[/\\]build[/\\]',      # Graph build scripts
    '\.github[/\\]knowledge-graph[/\\]data[/\\]',       # Graph source data
    '\.github[/\\]knowledge-graph[/\\]tests[/\\]',      # Graph tests
    '\.github[/\\]knowledge-graph[/\\]output[/\\]'      # Graph artifacts
)
$stubs = @($nodes | Where-Object { 
    $_.PSObject.Properties.Name -contains 'missing' -and $_.missing -eq $true 
} | Where-Object {
    $id = $_.id
    # Exclude if matches any intentionally excluded pattern
    -not ($excludedPatterns | Where-Object { $id -match $_ })
})
$findings['stub-nodes'] = @{ severity = 'FAIL'; count = $stubs.Count; items = $stubs.id }

# WARN: islands (connected components, undirected)
$parent = @{}
foreach ($n in $nodes) { $parent[$n.id] = $n.id }
function Find-Root($id) {
    $cur = $id
    while ($parent[$cur] -ne $cur) {
        $parent[$cur] = $parent[$parent[$cur]]   # path compression
        $cur = $parent[$cur]
    }
    return $cur
}
foreach ($e in $edges) {
    if (-not $nodeIdSet.ContainsKey($e.source)) { continue }
    if (-not $nodeIdSet.ContainsKey($e.target)) { continue }
    $rs = Find-Root $e.source
    $rt = Find-Root $e.target
    if ($rs -ne $rt) { $parent[$rs] = $rt }
}
$components = @{}
foreach ($n in $nodes) {
    $r = Find-Root $n.id
    if (-not $components.ContainsKey($r)) { $components[$r] = @() }
    $components[$r] += $n.id
}
$componentSizes = $components.Values | ForEach-Object { $_.Count } | Sort-Object -Descending
$islandCount = if ($components.Count -gt 1) { $components.Count - 1 } else { 0 }
$smallIslands = @()
if ($components.Count -gt 1) {
    $sorted = $components.GetEnumerator() | Sort-Object { $_.Value.Count } -Descending | Select-Object -Skip 1
    foreach ($kv in $sorted) {
        $smallIslands += [pscustomobject]@{
            root  = $kv.Key
            size  = $kv.Value.Count
            nodes = ($kv.Value | Select-Object -First 5)
        }
    }
}
$findings['islands'] = @{
    severity         = 'WARN'
    count            = $islandCount
    component_total  = $components.Count
    component_sizes  = @($componentSizes)
    items            = $smallIslands
}

# WARN: orphan nodes (degree 0)
$degree = @{}
foreach ($n in $nodes) { $degree[$n.id] = 0 }
foreach ($e in $edges) {
    if ($degree.ContainsKey($e.source)) { $degree[$e.source]++ }
    if ($degree.ContainsKey($e.target)) { $degree[$e.target]++ }
}
$orphans = @($degree.GetEnumerator() | Where-Object { $_.Value -eq 0 } | ForEach-Object { $_.Key })
$findings['orphan-nodes'] = @{ severity = 'WARN'; count = $orphans.Count; items = $orphans }

# WARN: unclustered nodes
$unclustered = @()
foreach ($n in $nodes) {
    $hasField = $n.PSObject.Properties.Name -contains 'cluster'
    $val = if ($hasField) { $n.cluster } else { $null }
    if ([string]::IsNullOrWhiteSpace($val)) {
        $unclustered += [pscustomobject]@{ id = $n.id; reason = 'empty' }
    }
    elseif ($clusterIdSet.Count -gt 0 -and -not $clusterIdSet.ContainsKey($val)) {
        $unclustered += [pscustomobject]@{ id = $n.id; reason = "missing-cluster:$val" }
    }
}
$findings['unclustered-nodes'] = @{ severity = 'WARN'; count = $unclustered.Count; items = $unclustered }

# WARN: duplicate edges
$edgeKeys = @{}
$dupeEdges = @()
foreach ($e in $edges) {
    $k = "$($e.source)|$($e.target)|$($e.type)"
    if ($edgeKeys.ContainsKey($k)) { $dupeEdges += $k } else { $edgeKeys[$k] = 1 }
}
$findings['duplicate-edges'] = @{ severity = 'WARN'; count = $dupeEdges.Count; items = $dupeEdges }

# WARN: dropped bridges (merged layer only — bridges that reference unknown nodes)
$droppedBridges = @()
if ($Layer -eq 'merged' -and $graph.PSObject.Properties.Name -contains 'bridges') {
    foreach ($b in @($graph.bridges)) {
        $sysOk = $nodeIdSet.ContainsKey($b.system)
        $codeOk = $nodeIdSet.ContainsKey($b.code)
        if (-not $sysOk -or -not $codeOk) {
            $droppedBridges += [pscustomobject]@{
                system       = $b.system
                code         = $b.code
                type         = $b.type
                missing_side = if (-not $sysOk -and -not $codeOk) { 'both' } elseif (-not $sysOk) { 'system' } else { 'code' }
            }
        }
    }
}
$findings['dropped-bridges'] = @{ severity = 'WARN'; count = $droppedBridges.Count; items = $droppedBridges }

# INFO: node type distribution
$nodeTypeDist = $nodes | Group-Object -Property type | Sort-Object Count -Descending | ForEach-Object {
    [pscustomobject]@{ type = $_.Name; count = $_.Count }
}
$findings['node-type-dist'] = @{ severity = 'INFO'; count = ($nodeTypeDist | Measure-Object).Count; items = @($nodeTypeDist) }

# INFO: edge type distribution
$edgeTypeDist = $edges | Group-Object -Property type | Sort-Object Count -Descending | ForEach-Object {
    [pscustomobject]@{ type = $_.Name; count = $_.Count }
}
$findings['edge-type-dist'] = @{ severity = 'INFO'; count = ($edgeTypeDist | Measure-Object).Count; items = @($edgeTypeDist) }

# INFO: top hub nodes (top 10 by degree)
$topHubs = $degree.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10 | ForEach-Object {
    [pscustomobject]@{ id = $_.Key; degree = $_.Value }
}
$findings['top-hubs'] = @{ severity = 'INFO'; count = 10; items = @($topHubs) }

# INFO: cluster sizes
$nodesByCluster = @{}
foreach ($n in $nodes) {
    $hasField = $n.PSObject.Properties.Name -contains 'cluster'
    $cid = if ($hasField -and -not [string]::IsNullOrWhiteSpace($n.cluster)) { $n.cluster } else { '<none>' }
    if (-not $nodesByCluster.ContainsKey($cid)) { $nodesByCluster[$cid] = 0 }
    $nodesByCluster[$cid]++
}
$clusterSizes = $nodesByCluster.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
    [pscustomobject]@{ cluster = $_.Key; nodes = $_.Value }
}
$findings['cluster-sizes'] = @{ severity = 'INFO'; count = ($clusterSizes | Measure-Object).Count; items = @($clusterSizes) }

# INFO: prunable candidates
# Leaf nodes (incoming-only, single 'contains' incoming, no description) — low signal
$incomingByType = @{}
$outDegree = @{}
foreach ($n in $nodes) {
    $incomingByType[$n.id] = @{}
    $outDegree[$n.id] = 0
}
foreach ($e in $edges) {
    if ($outDegree.ContainsKey($e.source)) { $outDegree[$e.source]++ }
    if ($incomingByType.ContainsKey($e.target)) {
        if (-not $incomingByType[$e.target].ContainsKey($e.type)) {
            $incomingByType[$e.target][$e.type] = 0
        }
        $incomingByType[$e.target][$e.type]++
    }
}
$prunable = @()
foreach ($n in $nodes) {
    if ($outDegree[$n.id] -ne 0) { continue }
    $inMap = $incomingByType[$n.id]
    if ($inMap.Count -ne 1) { continue }
    if (-not $inMap.ContainsKey('contains')) { continue }
    if ($inMap['contains'] -ne 1) { continue }
    $hasDesc = $n.PSObject.Properties.Name -contains 'description' -and -not [string]::IsNullOrWhiteSpace($n.description)
    if ($hasDesc) { continue }
    $prunable += $n.id
}
$findings['prunable'] = @{ severity = 'INFO'; count = $prunable.Count; items = $prunable }

# ---------- output ----------
$failCount = 0
$warnCount = 0
foreach ($k in $findings.Keys) {
    $f = $findings[$k]
    if ($f.count -le 0) { continue }
    if ($f.severity -eq 'FAIL') { $failCount++ }
    elseif ($f.severity -eq 'WARN') { $warnCount++ }
}
$passCount = ($findings.Keys | Where-Object { $findings[$_].severity -ne 'INFO' -and $findings[$_].count -eq 0 }).Count

if ($Json) {
    $out = [ordered]@{
        layer    = $Layer
        graph    = (Resolve-Path $graphPath).Path
        nodes    = $nodes.Count
        edges    = $edges.Count
        clusters = $clusters.Count
        summary  = @{ pass = $passCount; warn = $warnCount; fail = $failCount }
        findings = $findings
    }
    $out | ConvertTo-Json -Depth 12
    if ($failCount -gt 0) { exit 1 } else { exit 0 }
}

# Human output
function Write-Section($name, $finding, $renderer) {
    $sev = $finding.severity
    if ($Quiet -and $sev -eq 'INFO') { return }
    if ($Quiet -and $finding.count -eq 0 -and $sev -ne 'FAIL') { return }
    $color = switch ($sev) {
        'FAIL' { if ($finding.count -gt 0) { 'Red' } else { 'Green' } }
        'WARN' { if ($finding.count -gt 0) { 'Yellow' } else { 'Green' } }
        default { 'Cyan' }
    }
    $tag = if ($finding.count -eq 0 -and $sev -ne 'INFO') { 'PASS' } else { $sev }
    Write-Host ""
    Write-Host ("[{0}] {1}  ({2})" -f $tag, $name, $finding.count) -ForegroundColor $color
    if ($finding.count -gt 0 -and $renderer) {
        & $renderer $finding
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Knowledge Graph Health: $Layer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ("  File:     {0}" -f (Resolve-Path $graphPath).Path) -ForegroundColor DarkGray
Write-Host ("  Nodes:    {0}" -f $nodes.Count) -ForegroundColor DarkGray
Write-Host ("  Edges:    {0}" -f $edges.Count) -ForegroundColor DarkGray
Write-Host ("  Clusters: {0}" -f $clusters.Count) -ForegroundColor DarkGray

Write-Section 'dangling-edges' $findings['dangling-edges'] {
    param($f) $f.items | Select-Object -First 10 | ForEach-Object {
        Write-Host ("    {0} -[{1}]-> {2}  (missing: {3})" -f $_.source, $_.type, $_.target, $_.missing_side) -ForegroundColor DarkGray
    }
    if ($f.count -gt 10) { Write-Host ("    ... and {0} more" -f ($f.count - 10)) -ForegroundColor DarkGray }
}
Write-Section 'duplicate-node-ids' $findings['duplicate-node-ids'] {
    param($f) $f.items | Select-Object -First 10 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    if ($f.count -gt 10) { Write-Host ("    ... and {0} more" -f ($f.count - 10)) -ForegroundColor DarkGray }
}
Write-Section 'stub-nodes' $findings['stub-nodes'] {
    param($f) $f.items | Select-Object -First 10 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    if ($f.count -gt 10) { Write-Host ("    ... and {0} more" -f ($f.count - 10)) -ForegroundColor DarkGray }
}
Write-Section 'islands' $findings['islands'] {
    param($f)
    Write-Host ("    {0} connected component(s), sizes: {1}" -f $f.component_total, ($f.component_sizes -join ', ')) -ForegroundColor DarkGray
    foreach ($i in $f.items | Select-Object -First 5) {
        Write-Host ("    island root={0} size={1}" -f $i.root, $i.size) -ForegroundColor DarkGray
        foreach ($id in $i.nodes) { Write-Host "      - $id" -ForegroundColor DarkGray }
    }
    if ($f.count -gt 5) { Write-Host ("    ... and {0} more island(s)" -f ($f.count - 5)) -ForegroundColor DarkGray }
}
Write-Section 'orphan-nodes' $findings['orphan-nodes'] {
    param($f) $f.items | Select-Object -First 10 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    if ($f.count -gt 10) { Write-Host ("    ... and {0} more" -f ($f.count - 10)) -ForegroundColor DarkGray }
}
Write-Section 'unclustered-nodes' $findings['unclustered-nodes'] {
    param($f) $f.items | Select-Object -First 10 | ForEach-Object {
        Write-Host ("    {0}  ({1})" -f $_.id, $_.reason) -ForegroundColor DarkGray
    }
    if ($f.count -gt 10) { Write-Host ("    ... and {0} more" -f ($f.count - 10)) -ForegroundColor DarkGray }
}
Write-Section 'duplicate-edges' $findings['duplicate-edges'] {
    param($f) $f.items | Select-Object -First 10 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    if ($f.count -gt 10) { Write-Host ("    ... and {0} more" -f ($f.count - 10)) -ForegroundColor DarkGray }
}
Write-Section 'dropped-bridges' $findings['dropped-bridges'] {
    param($f) $f.items | Select-Object -First 10 | ForEach-Object {
        Write-Host ("    {0} <-[{1}]-> {2}  (missing: {3})" -f $_.system, $_.type, $_.code, $_.missing_side) -ForegroundColor DarkGray
    }
    if ($f.count -gt 10) { Write-Host ("    ... and {0} more" -f ($f.count - 10)) -ForegroundColor DarkGray }
}
Write-Section 'node-type-dist' $findings['node-type-dist'] {
    param($f) foreach ($r in $f.items) { Write-Host ("    {0,-25} {1,6}" -f $r.type, $r.count) -ForegroundColor DarkGray }
}
Write-Section 'edge-type-dist' $findings['edge-type-dist'] {
    param($f) foreach ($r in $f.items) { Write-Host ("    {0,-25} {1,6}" -f $r.type, $r.count) -ForegroundColor DarkGray }
}
Write-Section 'top-hubs' $findings['top-hubs'] {
    param($f) foreach ($r in $f.items) { Write-Host ("    [{0,4}]  {1}" -f $r.degree, $r.id) -ForegroundColor DarkGray }
}
Write-Section 'cluster-sizes' $findings['cluster-sizes'] {
    param($f) foreach ($r in $f.items) { Write-Host ("    {0,-30} {1,5}" -f $r.cluster, $r.nodes) -ForegroundColor DarkGray }
}
Write-Section 'prunable' $findings['prunable'] {
    param($f) $f.items | Select-Object -First 10 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    if ($f.count -gt 10) { Write-Host ("    ... and {0} more" -f ($f.count - 10)) -ForegroundColor DarkGray }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
$summaryColor = if ($failCount -gt 0) { 'Red' } elseif ($warnCount -gt 0) { 'Yellow' } else { 'Green' }
Write-Host (" Summary: PASS {0} | WARN {1} | FAIL {2}" -f $passCount, $warnCount, $failCount) -ForegroundColor $summaryColor
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($failCount -gt 0) { exit 1 } else { exit 0 }
