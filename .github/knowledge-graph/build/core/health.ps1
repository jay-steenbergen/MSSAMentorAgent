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
      WARN  duplicate-pairs     same (source, target) carrying multiple types — drop the weaker
      WARN  dropped-bridges     unresolved cross-layer bridges (merged only)
      WARN  doc-drift           TYPE_CATALOG.md out of sync with actual graph files
      WARN  code-coverage       repo files not in graph (by category) + stale nodes
      WARN  session-artifacts   code files with zero system-layer reachability (deletion candidates)
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
$scriptDir = (Resolve-Path "$PSScriptRoot\..\..").Path

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
    '\.github[/\\]knowledge-graph[/\\]output[/\\]'      # Graph artifacts
    # NOTE: knowledge-graph/tests/ is intentionally NOT excluded — the new
    # test infrastructure lives there and every .test.ps1 file gets a code-file
    # node so the audit can verify [tests] edges.
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

# edge-quality: classify edges against Get-EdgeTaxonomy.
# Detects (1) new edge types added without being classified, (2) annotation creep.
# Why this exists: decision:2026-06-03-purpose-experiment relies on the carrier/noise
# split to compute purpose linkage. If new edge types appear without being added to
# the taxonomy, linkage scores drift silently. This check forces explicit triage.
$taxonomyModule = Join-Path $scriptDir 'lib\query.psm1'
if (Test-Path $taxonomyModule) {
    Import-Module $taxonomyModule -Force -DisableNameChecking | Out-Null
    $tx = Get-EdgeTaxonomy
    $carriers = [System.Collections.Generic.HashSet[string]]::new([string[]]$tx.carrier, [StringComparer]::OrdinalIgnoreCase)
    $inverses = [System.Collections.Generic.HashSet[string]]::new([string[]]$tx.inverse, [StringComparer]::OrdinalIgnoreCase)
    $noises   = [System.Collections.Generic.HashSet[string]]::new([string[]]$tx.noise,   [StringComparer]::OrdinalIgnoreCase)
    $cls = @{ carrier = 0; inverse = 0; noise = 0; unclassified = 0 }
    $unclassifiedTypes = @{}
    foreach ($e in $edges) {
        if ($carriers.Contains($e.type))     { $cls.carrier++ }
        elseif ($inverses.Contains($e.type)) { $cls.inverse++ }
        elseif ($noises.Contains($e.type))   { $cls.noise++ }
        else {
            $cls.unclassified++
            if (-not $unclassifiedTypes.ContainsKey($e.type)) { $unclassifiedTypes[$e.type] = 0 }
            $unclassifiedTypes[$e.type]++
        }
    }
    $totalEdges = [math]::Max(1, $edges.Count)
    $noisePct = [math]::Round(100 * $cls.noise / $totalEdges, 1)
    $unclPct  = [math]::Round(100 * $cls.unclassified / $totalEdges, 1)
    # Threshold rationale:
    #   - any unclassified edge type is a structural smell (graph vocabulary expanded
    #     without taxonomy update) -> WARN
    #   - noise > 15% suggests over-reliance on 'references'/'related_to' instead of
    #     real dependency edges -> WARN
    $severity = 'INFO'
    if ($cls.unclassified -gt 0) { $severity = 'WARN' }
    elseif ($noisePct -gt 15)    { $severity = 'WARN' }
    $eqItems = @(
        [pscustomobject]@{ bucket = 'carrier';      count = $cls.carrier;      pct = [math]::Round(100*$cls.carrier/$totalEdges,1) }
        [pscustomobject]@{ bucket = 'inverse';      count = $cls.inverse;      pct = [math]::Round(100*$cls.inverse/$totalEdges,1) }
        [pscustomobject]@{ bucket = 'noise';        count = $cls.noise;        pct = $noisePct }
        [pscustomobject]@{ bucket = 'unclassified'; count = $cls.unclassified; pct = $unclPct }
    )
    $unclassifiedList = $unclassifiedTypes.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        [pscustomobject]@{ type = $_.Key; count = $_.Value }
    }
    $findings['edge-quality'] = @{
        severity           = $severity
        count              = $eqItems.Count
        items              = $eqItems
        unclassified_count = $cls.unclassified
        unclassified_types = @($unclassifiedList)
        noise_pct          = $noisePct
        unclassified_pct   = $unclPct
    }

    # duplicate-pairs: same (source, target) carrying multiple edge types.
    # Why this exists: Phase 2 cleanup found 75 hand-authored redundancies
    # (e.g. skill [forbids] X + skill [references] X). Once classified, the
    # weaker edge is just annotation creep that inflates noise %. This check
    # catches future regressions where someone re-adds a 'references' or
    # 'related_to' edge next to an existing carrier/inverse.
    $pairTypes = @{}
    foreach ($e in $edges) {
        $k = '{0}|{1}' -f $e.source, $e.target
        if (-not $pairTypes.ContainsKey($k)) { $pairTypes[$k] = @() }
        $pairTypes[$k] += $e.type
    }
    $dupPairs = @()
    foreach ($k in $pairTypes.Keys) {
        $types = $pairTypes[$k]
        if ($types.Count -le 1) { continue }
        $distinct = $types | Sort-Object -Unique
        if ($distinct.Count -le 1) { continue }  # plain (s,t,type) dupes are caught by duplicate-edges
        $hasC = $false; $hasI = $false; $hasN = $false
        foreach ($t in $distinct) {
            if ($carriers.Contains($t))     { $hasC = $true }
            elseif ($inverses.Contains($t)) { $hasI = $true }
            elseif ($noises.Contains($t))   { $hasN = $true }
        }
        # Classify the pair. Actionable = a noise type co-exists with carrier or inverse.
        $klass = if ($hasN -and ($hasC -or $hasI)) { 'noise-over-carrier' }
                 elseif ($hasC -and $hasI)         { 'carrier-with-inverse' }
                 elseif ($hasC)                    { 'multi-carrier' }
                 elseif ($hasI)                    { 'multi-inverse' }
                 else                              { 'multi-noise' }
        $parts = $k -split '\|', 2
        $dupPairs += [pscustomobject]@{
            source = $parts[0]
            target = $parts[1]
            types  = ($distinct -join ', ')
            class  = $klass
        }
    }
    $actionable = @($dupPairs | Where-Object { $_.class -eq 'noise-over-carrier' }).Count
    $dpSeverity = if ($actionable -gt 0) { 'WARN' } else { 'INFO' }
    $findings['duplicate-pairs'] = @{
        severity          = $dpSeverity
        count             = $dupPairs.Count
        items             = @($dupPairs | Sort-Object @{e={ if ($_.class -eq 'noise-over-carrier') { 0 } else { 1 } }}, class, source, target)
        actionable_count  = $actionable
    }
}

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

# WARN: doc-drift (TYPE_CATALOG.md vs actual graph)
$catalogPath = Join-Path $scriptDir 'TYPE_CATALOG.md'
$docDriftItems = @()
if (Test-Path $catalogPath) {
    $catalogText = Get-Content $catalogPath -Raw
    $catalogLines = Get-Content $catalogPath

    # Check 1: File references — every *-graph.json or *.json mentioned should exist
    $referencedFiles = [regex]::Matches($catalogText, 'code-[a-z-]+-graph\.json|code-edge-catalog\.json') |
        ForEach-Object { $_.Value } | Sort-Object -Unique
    $codeDir = Join-Path $scriptDir 'data\MentorAgent\code'
    foreach ($ref in $referencedFiles) {
        $refPath = Join-Path $codeDir $ref
        if (-not (Test-Path $refPath)) {
            $docDriftItems += [pscustomobject]@{
                check   = 'missing-file'
                detail  = "TYPE_CATALOG.md references '$ref' but it does not exist on disk"
                fix     = "Remove reference or create the file"
            }
        }
    }

    # Check 1b: Actual files on disk not mentioned in catalog
    if (Test-Path $codeDir) {
        $actualFiles = Get-ChildItem $codeDir -Filter '*-graph.json' | ForEach-Object { $_.Name }
        foreach ($af in $actualFiles) {
            if ($catalogText -notmatch [regex]::Escape($af)) {
                $docDriftItems += [pscustomobject]@{
                    check   = 'unlisted-file'
                    detail  = "'$af' exists on disk but is not mentioned in TYPE_CATALOG.md"
                    fix     = "Add it to the Physical File Organization and Quick Reference sections"
                }
            }
        }
    }

    # Check 2: Node count drift — extract "(N nodes" from catalog, compare to graph
    $countMatches = [regex]::Matches($catalogText, '(code-[a-z-]+-graph\.json)\s+.*?\((\d+)\s+nodes')
    foreach ($m in $countMatches) {
        $fileName = $m.Groups[1].Value
        $docCount = [int]$m.Groups[2].Value
        $filePath = Join-Path $codeDir $fileName
        if (Test-Path $filePath) {
            $fileGraph = Get-Content $filePath -Raw | ConvertFrom-Json -Depth 32
            $actualCount = @($fileGraph.nodes).Count
            if ($docCount -ne $actualCount) {
                $docDriftItems += [pscustomobject]@{
                    check   = 'count-mismatch'
                    detail  = "${fileName}: catalog says ${docCount} nodes, actual is ${actualCount}"
                    fix     = "Update TYPE_CATALOG.md node count from ${docCount} to ${actualCount}"
                }
            }
        }
    }

    # Check 3: Duplicate #### headings (same type defined twice)
    $h4Headings = $catalogLines | Where-Object { $_ -match '^####\s+' } | ForEach-Object { $_.Trim() }
    $h4Groups = $h4Headings | Group-Object | Where-Object { $_.Count -gt 1 }
    foreach ($dup in $h4Groups) {
        $docDriftItems += [pscustomobject]@{
            check   = 'duplicate-section'
            detail  = "Heading '$($dup.Name)' appears $($dup.Count) times in TYPE_CATALOG.md"
            fix     = "Remove the duplicate definition (keep the one with more detail)"
        }
    }
}
$findings['doc-drift'] = @{ severity = 'WARN'; count = $docDriftItems.Count; items = $docDriftItems }

# WARN: code-coverage (repo files vs graph code-file nodes)
$coverageItems = @()
$coverageStats = @{ total = 0; mapped = 0; missing = 0; stale = 0; excluded = 0 }
$repoRoot = (Resolve-Path "$scriptDir\..\..").Path
$gitAvailable = $false
try {
    Push-Location $repoRoot
    $gitTest = git rev-parse --is-inside-work-tree 2>&1
    $gitAvailable = ($LASTEXITCODE -eq 0)
} finally { Pop-Location }

if ($gitAvailable) {
    Push-Location $repoRoot
    try {
        # Get all tracked source files. Subtract files marked for deletion in the
        # working tree (git ls-files --deleted) — they're still indexed but the
        # file no longer exists, so they'd false-fail the coverage check.
        $deletedFiles = @(git ls-files --deleted | ForEach-Object { $_ -replace '\\', '/' })
        $deletedSet = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($d in $deletedFiles) { [void]$deletedSet.Add($d) }
        $trackedFiles = @(git ls-files | Where-Object {
            $_ -match '\.(ps1|psm1|ts|tsx|cs|csproj|md|json|yaml|yml|agent\.md)$'
        } | ForEach-Object { $_ -replace '\\', '/' } | Where-Object {
            -not $deletedSet.Contains($_)
        })

        # Paths the extractor intentionally excludes (self-referential or build artifacts)
        # NOTE: knowledge-graph/tests/ removed from this list — see comment above.
        $intentionalExcludes = @(
            '[/\\](bin|obj|node_modules)[/\\]',
            'knowledge-graph[/\\](build|data|output|demos)[/\\]',
            'knowledge-graph[/\\](build|data|output|demos)$',
            # cli/archive/ holds historical scripts the agent no longer uses.
            # Excluded from auto-discover (no cli-tool node) and extract-code-graph
            # (no code-file node). Coverage check must mirror or it false-fails.
            'knowledge-graph[/\\]cli[/\\]archive[/\\]',
            # Template test files (start with `_`) are scaffolding, not invoked
            # by run-tests.ps1. Mirrored in extract-code-graph.ps1 $excludeMatch.
            'knowledge-graph[/\\]tests[/\\].*[/\\]_[^/\\]+\.test\.ps1$',
            # Implicit entrypoint landing-page docs — same exemption as find-orphan-markdown.ps1.
            # These don't need graph nodes (they're navigation, not artifacts).
            '(^|[/\\])README\.md$',
            '(^|[/\\])CONTRIBUTING\.md$'
        )

        # Graph file paths — any node whose `file` field points at a tracked repo file
        # (covers code-file nodes AND log nodes like session/experiment/decision that own .md bodies)
        $graphFilePaths = @($nodes | Where-Object { $_.file } |
            ForEach-Object { $_.file -replace '\\', '/' }) | Sort-Object -Unique

        $coverageStats.total = $trackedFiles.Count

        foreach ($f in $trackedFiles) {
            $isExcluded = $intentionalExcludes | Where-Object { $f -match $_ }
            if ($isExcluded) {
                $coverageStats.excluded++
                continue
            }

            if ($f -in $graphFilePaths) {
                $coverageStats.mapped++
            } else {
                $coverageStats.missing++
                # Categorize the gap
                $category = if ($f -match '\.github[/\\]hooks[/\\]') { 'hooks' }
                    elseif ($f -match '\.github[/\\]skills[/\\]') { 'skill' }
                    elseif ($f -match '\.github[/\\]agents[/\\]') { 'agent' }
                    elseif ($f -match 'extensions[/\\]') { 'extension' }
                    elseif ($f -match '\.profiles[/\\]') { 'profile' }
                    elseif ($f -match 'knowledge-graph[/\\]') { 'kg-infra' }
                    elseif ($f -match 'docs[/\\]') { 'docs' }
                    else { 'other' }

                $coverageItems += [pscustomobject]@{
                    file     = $f
                    category = $category
                }
            }
        }

        # Check for stale nodes (graph has file, repo doesn't)
        foreach ($gf in $graphFilePaths) {
            $fullPath = Join-Path $repoRoot $gf
            if (-not (Test-Path $fullPath)) {
                $coverageStats.stale++
                $coverageItems += [pscustomobject]@{
                    file     = $gf
                    category = 'stale'
                }
            }
        }
    } finally { Pop-Location }
}

$eligibleTotal = $coverageStats.total - $coverageStats.excluded
$coveragePct = if ($eligibleTotal -gt 0) { [math]::Round(100.0 * $coverageStats.mapped / $eligibleTotal, 1) } else { 100.0 }
$findings['code-coverage'] = @{
    severity = 'WARN'
    count    = $coverageItems.Count
    stats    = $coverageStats
    pct      = $coveragePct
    items    = $coverageItems
}

# WARN: session-artifacts (code-file nodes completely disconnected from the system layer)
# A file is "connected" if:
#   1. It has a direct edge to/from a system-layer node (skill, agent, test, hook, etc.), OR
#   2. It's contained by a directory/parent file that IS connected (e.g., extension source files under extension:mssa-mentor)
# Files with ZERO system reachability are deletion candidates.

$artifactItems = @()

# Step 1: Build a set of code-file IDs that have direct system-layer connections
$directlyConnected = @{}
foreach ($cf in ($nodes | Where-Object { $_.type -eq 'code-file' })) {
    foreach ($e in $edges) {
        if ($e.target -eq $cf.id -or $e.source -eq $cf.id) {
            $otherSide = if ($e.source -eq $cf.id) { $e.target } else { $e.source }
            if ($otherSide -notlike 'code-*') {
                $directlyConnected[$cf.id] = $true
                break
            }
        }
    }
}

# Step 2: For files NOT directly connected, check if a parent directory file IS connected
# (e.g., extension source .ts files are children of extension:mssa-mentor via contains edges)
$allCodeFiles = @($nodes | Where-Object { $_.type -eq 'code-file' })
$reachable = @{} + $directlyConnected  # copy

# Propagate: if file A is connected and has a 'contains' edge to file B, B is reachable
$changed = $true
while ($changed) {
    $changed = $false
    foreach ($e in $edges) {
        if ($e.type -eq 'contains' -and $reachable.ContainsKey($e.source) -and
            $nodeIdSet.ContainsKey($e.target) -and $nodeIdSet[$e.target].type -eq 'code-file' -and
            -not $reachable.ContainsKey($e.target)) {
            $reachable[$e.target] = $true
            $changed = $true
        }
    }
}

# Step 3: Files that are NOT reachable from any system node are deletion candidates
# Exclude files in directories that are inherently infrastructure (knowledge-graph build/data/tests)
$infraExcludes = @(
    'knowledge-graph[/\\](build|data|output|demos|queries|cli|lib)[/\\]',
    'knowledge-graph[/\\](build|data|output|demos|queries|cli|lib)$'
)

foreach ($cf in $allCodeFiles) {
    if ($reachable.ContainsKey($cf.id)) { continue }

    # Skip infrastructure files (graph build scripts, etc.)
    $isInfra = $infraExcludes | Where-Object { $cf.file -match $_ }
    if ($isInfra) { continue }

    # Classify: data files are expected to lack system edges (they're runtime, not design)
    $isDataFile = $cf.file -match '^\.profiles[/\\]profiles[/\\]'
    if ($isDataFile) { continue }

    # Count code-layer edges (to distinguish "truly isolated" from "has internal structure")
    $codeEdgeCount = 0
    $incomingFrom = @()
    foreach ($e in $edges) {
        if ($e.target -eq $cf.id) {
            $codeEdgeCount++
            if ($e.source -notlike 'code-*') { $incomingFrom += $e.source }
        }
        if ($e.source -eq $cf.id) { $codeEdgeCount++ }
    }

    # Classify the verdict
    $verdict = if ($codeEdgeCount -eq 0) {
        'ISOLATED — zero edges, likely a session artifact. Safe to delete.'
    } elseif ($cf.file -match '(HANDOFF|VALIDATION|CHECKLIST|SUMMARY|ANALYSIS|TODO)') {
        'SESSION DOC — name pattern suggests one-time session artifact. Review and delete.'
    } else {
        'UNWIRED — has code structure but no system node claims it. Wire to a skill/agent/test or delete.'
    }

    $artifactItems += [pscustomobject]@{
        file         = $cf.file
        system_edges = 0
        code_edges   = $codeEdgeCount
        incoming     = ($incomingFrom -join ', ')
        verdict      = $verdict
    }
}

$findings['session-artifacts'] = @{ severity = 'WARN'; count = $artifactItems.Count; items = $artifactItems }

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
Write-Section 'edge-quality' $findings['edge-quality'] {
    param($f)
    foreach ($r in $f.items) {
        $color = switch ($r.bucket) {
            'carrier'      { 'Green' }
            'inverse'      { 'Cyan' }
            'noise'        { if ($r.pct -gt 15) { 'Yellow' } else { 'DarkGray' } }
            'unclassified' { if ($r.count -gt 0) { 'Red' } else { 'DarkGray' } }
        }
        Write-Host ("    {0,-14} {1,6}  ({2,5}%)" -f $r.bucket, $r.count, $r.pct) -ForegroundColor $color
    }
    if ($f.unclassified_types -and @($f.unclassified_types).Count -gt 0) {
        Write-Host "    Unclassified types (add to Get-EdgeTaxonomy):" -ForegroundColor Yellow
        foreach ($u in $f.unclassified_types) {
            Write-Host ("      {0,-25} {1,4}" -f $u.type, $u.count) -ForegroundColor Yellow
        }
    }
}
Write-Section 'duplicate-pairs' $findings['duplicate-pairs'] {
    param($f)
    Write-Host ("    Total duplicate pairs:  {0}" -f $f.count) -ForegroundColor DarkGray
    $actColor = if ($f.actionable_count -gt 0) { 'Yellow' } else { 'DarkGray' }
    Write-Host ("    Actionable (noise+carrier): {0}" -f $f.actionable_count) -ForegroundColor $actColor
    $shown = 0
    foreach ($r in $f.items) {
        if ($shown -ge 15) { break }
        $color = switch ($r.class) {
            'noise-over-carrier'   { 'Yellow' }
            'carrier-with-inverse' { 'DarkGray' }
            default                { 'DarkGray' }
        }
        Write-Host ("    [{0}] {1} -> {2}  ({3})" -f $r.class, $r.source, $r.target, $r.types) -ForegroundColor $color
        $shown++
    }
    if ($f.count -gt 15) { Write-Host ("    ... and {0} more" -f ($f.count - 15)) -ForegroundColor DarkGray }
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
Write-Section 'doc-drift' $findings['doc-drift'] {
    param($f) foreach ($r in $f.items) {
        Write-Host ("    [{0}] {1}" -f $r.check, $r.detail) -ForegroundColor DarkGray
        Write-Host ("      Fix: {0}" -f $r.fix) -ForegroundColor DarkYellow
    }
}
Write-Section 'code-coverage' $findings['code-coverage'] {
    param($f)
    $s = $f.stats
    $eligible = $s.total - $s.excluded
    Write-Host ("    Tracked files:  {0}  (excluded: {1}  eligible: {2})" -f $s.total, $s.excluded, $eligible) -ForegroundColor DarkGray
    Write-Host ("    In graph:       {0}  ({1}%)" -f $s.mapped, $f.pct) -ForegroundColor DarkGray
    Write-Host ("    Missing:        {0}" -f $s.missing) -ForegroundColor DarkGray
    if ($s.stale -gt 0) { Write-Host ("    Stale:          {0}  (graph node but file deleted)" -f $s.stale) -ForegroundColor DarkGray }

    # Group missing by category
    $byCategory = $f.items | Where-Object { $_.category -ne 'stale' } | Group-Object category | Sort-Object Count -Descending
    foreach ($grp in $byCategory) {
        Write-Host ("    [{0}] {1} files:" -f $grp.Name, $grp.Count) -ForegroundColor Yellow
        $grp.Group | Select-Object -First 5 | ForEach-Object { Write-Host "      $($_.file)" -ForegroundColor DarkGray }
        if ($grp.Count -gt 5) { Write-Host ("      ... and {0} more" -f ($grp.Count - 5)) -ForegroundColor DarkGray }
    }

    # Stale nodes
    $staleItems = @($f.items | Where-Object { $_.category -eq 'stale' })
    if ($staleItems.Count -gt 0) {
        Write-Host ("    [stale] {0} graph nodes for deleted files:" -f $staleItems.Count) -ForegroundColor Red
        $staleItems | Select-Object -First 5 | ForEach-Object { Write-Host "      $($_.file)" -ForegroundColor DarkGray }
    }
}
Write-Section 'session-artifacts' $findings['session-artifacts'] {
    param($f)
    Write-Host "    Files with no system-layer connection (not reachable from any skill, agent, test, or infra node):" -ForegroundColor DarkGray
    foreach ($r in $f.items) {
        Write-Host ("    {0}" -f $r.file) -ForegroundColor Yellow
        Write-Host ("      Verdict: {0}  (code-edges: {1})" -f $r.verdict, $r.code_edges) -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
$summaryColor = if ($failCount -gt 0) { 'Red' } elseif ($warnCount -gt 0) { 'Yellow' } else { 'Green' }
Write-Host (" Summary: PASS {0} | WARN {1} | FAIL {2}" -f $passCount, $warnCount, $failCount) -ForegroundColor $summaryColor
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($failCount -gt 0) { exit 1 } else { exit 0 }
