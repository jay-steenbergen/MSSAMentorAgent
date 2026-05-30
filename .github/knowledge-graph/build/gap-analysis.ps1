#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Triage findings from health.ps1: classify each finding as REAL GAP, EXPECTED,
    or NEEDS REVIEW, with suggested fixes.
.DESCRIPTION
    Runs health.ps1 -Json fresh, then applies classification rules to every
    non-INFO finding. Output is grouped by finding type. Exit 1 if any REAL GAP.

    Rule summary:
      ALWAYS REAL GAP — dangling-edges, duplicate-node-ids, stub-nodes,
                        unclustered-nodes, duplicate-edges, dropped-bridges
      CONTEXTUAL     — orphan-nodes, islands (see below)

    Orphan node classification:
      REAL GAP   — type is file/code-file with degree 0
      EXPECTED   — known scaffold pattern (e.g., *.csproj test projects)
      NEEDS REVIEW — anything else

    Island classification (merged layer only — code/system use simpler rules):
      REAL GAP   — island rooted at a SKILL.md with no system-layer bridge
      REAL GAP   — island rooted at a .md doc with no inbound references
      REAL GAP   — schema instance subgraph (.progress.json / .profile.json)
                   not connected via instance_of to its schema
      EXPECTED   — test fixture subgraphs (path contains /tests/ or .test.md)
      NEEDS REVIEW — anything else

.PARAMETER Layer
    Which graph to analyze: code, system, or merged. Default: merged.
.PARAMETER Json
    Emit a single JSON triage report instead of human output.
.EXAMPLE
    pwsh .github/knowledge-graph/gap-analysis.ps1
.EXAMPLE
    pwsh .github/knowledge-graph/gap-analysis.ps1 -Layer system
#>
[CmdletBinding()]
param(
    [ValidateSet('code', 'system', 'merged')]
    [string]$Layer = 'merged',
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
$scriptDir = (Resolve-Path "$PSScriptRoot\..").Path

# ---------- load graph (for richer classification than health.ps1 exposes) ----------
$graphPath = switch ($Layer) {
    'code'   { Join-Path $scriptDir 'data\MentorAgent\code\code-graph.json' }
    'system' { Join-Path $scriptDir 'data\MentorAgent\system\mentor-graph.json' }
    'merged' { Join-Path $scriptDir 'output/merged-graph.json' }
}
if (-not (Test-Path $graphPath)) {
    Write-Host "ERROR: Graph file not found: $graphPath" -ForegroundColor Red
    exit 2
}
$graph = Get-Content $graphPath -Raw | ConvertFrom-Json -Depth 32
$nodes = @($graph.nodes)
$edges = @($graph.edges)
$bridges = if ($graph.PSObject.Properties.Name -contains 'bridges') { @($graph.bridges) } else { @() }

# Index nodes
$nodeById = @{}
foreach ($n in $nodes) { $nodeById[$n.id] = $n }

# ---------- run health.ps1 -Json ----------
$healthScript = Join-Path $scriptDir 'build\health.ps1'
if (-not (Test-Path $healthScript)) {
    Write-Host "ERROR: health.ps1 not found at $healthScript" -ForegroundColor Red
    exit 2
}
$rawJson = & pwsh -NoProfile -File $healthScript -Layer $Layer -Json
if ($LASTEXITCODE -gt 1) {
    Write-Host "ERROR: health.ps1 exited with code $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}
$health = $rawJson -join "`n" | ConvertFrom-Json -Depth 32
$findings = $health.findings

# ---------- recompute full islands (health only stores first 5 nodes per island) ----------
$parent = @{}
foreach ($n in $nodes) { $parent[$n.id] = $n.id }
function Find-Root($id) {
    $cur = $id
    while ($parent[$cur] -ne $cur) {
        $parent[$cur] = $parent[$parent[$cur]]
        $cur = $parent[$cur]
    }
    return $cur
}
foreach ($e in $edges) {
    if (-not $nodeById.ContainsKey($e.source)) { continue }
    if (-not $nodeById.ContainsKey($e.target)) { continue }
    $rs = Find-Root $e.source
    $rt = Find-Root $e.target
    if ($rs -ne $rt) { $parent[$rs] = $rt }
}
$componentsFull = @{}
foreach ($n in $nodes) {
    $r = Find-Root $n.id
    if (-not $componentsFull.ContainsKey($r)) { $componentsFull[$r] = @() }
    $componentsFull[$r] += $n.id
}
# Largest component = "main"; everything else is an island
$mainRoot = ($componentsFull.GetEnumerator() | Sort-Object { $_.Value.Count } -Descending | Select-Object -First 1).Key
$islandsFull = $componentsFull.GetEnumerator() | Where-Object { $_.Key -ne $mainRoot } | ForEach-Object {
    [pscustomobject]@{ root = $_.Key; size = $_.Value.Count; nodes = $_.Value }
} | Sort-Object size -Descending

# ---------- bridged-skill index (merged only) ----------
$bridgedCodeIds = @{}
foreach ($b in $bridges) { $bridgedCodeIds[$b.code] = $true }

# ---------- classification helpers ----------
function Get-NodeType($id) {
    if ($nodeById.ContainsKey($id)) { return $nodeById[$id].type }
    return $null
}
function Get-NodeLabel($id) {
    if ($nodeById.ContainsKey($id)) {
        $n = $nodeById[$id]
        if ($n.PSObject.Properties.Name -contains 'label' -and $n.label) { return $n.label }
    }
    return $id
}
function Is-TestScaffold($id) {
    # build/test scaffold patterns we expect to be isolated
    return ($id -like '*.csproj' -or $id -like '*.sln' -or $id -like '*.test.md' -or `
            $id -like '*/tests/*' -or $id -like '*\tests\*' -or `
            $id -like '*Tests/*' -or $id -like '*Tests\*' -or `
            $id -like '*Tests.cs*' -or $id -like '*Test.cs*')
}

# ---------- classification: ORPHAN NODES ----------
$orphanResults = @()
foreach ($id in $findings.'orphan-nodes'.items) {
    $t = Get-NodeType $id
    $label = Get-NodeLabel $id
    $verdict = 'NEEDS REVIEW'
    $why = ''
    $fix = ''
    if (Is-TestScaffold $id) {
        $verdict = 'EXPECTED'
        $why = 'Test/build scaffold (e.g., .csproj, .test.md) is intentionally isolated from the runtime graph.'
    }
    elseif ($t -eq 'file' -or $t -eq 'code-file') {
        $verdict = 'REAL GAP'
        $why = "Node type '$t' with degree 0 — declared but never referenced or referencing."
        $fix = "(a) Delete the node if obsolete, OR (b) Add at least one edge connecting it (e.g., 'references' from a documenting node)."
    }
    else {
        $verdict = 'NEEDS REVIEW'
        $why = "Node type '$t' with degree 0 — may be intentional (terminal) or a missing edge."
    }
    $orphanResults += [pscustomobject]@{
        id = $id; label = $label; type = $t; verdict = $verdict; why = $why; fix = $fix
    }
}

# ---------- classification: ISLANDS ----------
# Group islands by root cause; produce one finding per group (not per island)
$islandResults = @()
$islandSkillFiles = @()      # SKILL.md islands missing bridges
$islandTestFixtures = @()    # test/scenario islands
$islandSchemaInstances = @() # progress.json / profile.json subgraphs not bridged
$islandOrphanDocs = @()      # standalone .md docs
$islandUnknown = @()

foreach ($island in $islandsFull) {
    $ns = $island.nodes
    # Singletons are reported in the Orphan section already — skip them here to avoid double-counting.
    if ($ns.Count -le 1) { continue }
    $hasSkillFile = $false
    $hasTestFile  = $false
    $hasSchemaInstance = $false
    $hasOrphanDoc = $false
    $skillFileIds = @()

    foreach ($nid in $ns) {
        $node = $nodeById[$nid]
        if (-not $node) { continue }
        if ($node.type -eq 'code-file' -and $nid -like '*SKILL.md') {
            $hasSkillFile = $true
            $skillFileIds += $nid
        }
        if (Is-TestScaffold $nid -or $node.type -eq 'code-scenario' -or $node.type -eq 'code-test') {
            $hasTestFile = $true
        }
        if ($nid -like '*.progress.json*' -or $nid -like '*.profile.json*' -or $node.type -eq 'code-schema') {
            $hasSchemaInstance = $true
        }
        if ($node.type -eq 'code-file' -and $nid -like '*.md' -and -not ($nid -like '*SKILL.md')) {
            $hasOrphanDoc = $true
        }
    }

    if ($hasSkillFile) {
        # Is the SKILL.md bridged from any system-layer node?
        $allBridged = $true
        foreach ($sid in $skillFileIds) {
            if (-not $bridgedCodeIds.ContainsKey($sid)) { $allBridged = $false; break }
        }
        if (-not $allBridged) {
            $islandSkillFiles += $island
            continue
        }
    }
    if ($hasSchemaInstance -and $Layer -eq 'merged') {
        # Schema instance not connected to schema (no instance_of bridge)
        $islandSchemaInstances += $island
        continue
    }
    if ($hasTestFile) {
        $islandTestFixtures += $island
        continue
    }
    if ($hasOrphanDoc) {
        $islandOrphanDocs += $island
        continue
    }
    $islandUnknown += $island
}

if ($islandSkillFiles.Count -gt 0) {
    $files = @()
    foreach ($i in $islandSkillFiles) {
        foreach ($nid in $i.nodes) {
            if ($nid -like '*SKILL.md') { $files += $nid }
        }
    }
    $files = $files | Sort-Object -Unique
    $islandResults += [pscustomobject]@{
        verdict = 'REAL GAP'
        group   = 'unbridged-skill-files'
        count   = $islandSkillFiles.Count
        why     = "$($islandSkillFiles.Count) island(s) rooted at SKILL.md files with no bridge from any system-layer node. The system graph doesn't model these skills/tracks."
        fix     = "Add 'skill:' or 'track:' nodes to system/mentor-graph.json and bridges that connect them to these SKILL.md code-files."
        examples = $files | Select-Object -First 8
    }
}
if ($islandSchemaInstances.Count -gt 0) {
    $islandResults += [pscustomobject]@{
        verdict = 'REAL GAP'
        group   = 'unbridged-schema-instances'
        count   = $islandSchemaInstances.Count
        why     = "$($islandSchemaInstances.Count) island(s) contain schema instance files (*.progress.json / *.profile.json) with no instance_of bridge back to a 'schema:' node."
        fix     = "Add 'instance_of' bridges from each instance file's code-schema node to the matching system-layer 'schema:' node."
        examples = ($islandSchemaInstances | Select-Object -First 5 | ForEach-Object { $_.root })
    }
}
if ($islandOrphanDocs.Count -gt 0) {
    $islandResults += [pscustomobject]@{
        verdict = 'REAL GAP'
        group   = 'standalone-docs'
        count   = $islandOrphanDocs.Count
        why     = "$($islandOrphanDocs.Count) island(s) contain markdown docs with no inbound references from anywhere else in the graph."
        fix     = "Either link from copilot-instructions.md / README.md / a SKILL.md, or remove the doc if obsolete."
        examples = ($islandOrphanDocs | Select-Object -First 5 | ForEach-Object { $_.root })
    }
}
if ($islandTestFixtures.Count -gt 0) {
    $islandResults += [pscustomobject]@{
        verdict = 'EXPECTED'
        group   = 'test-fixtures'
        count   = $islandTestFixtures.Count
        why     = "$($islandTestFixtures.Count) island(s) are test/scenario subgraphs (paths under /tests/ or *.test.md). These are intentionally isolated from the runtime graph."
        fix     = "No action. If you want these wired in, add 'tests' edges from test-target nodes back to the things they test."
        examples = ($islandTestFixtures | Select-Object -First 5 | ForEach-Object { $_.root })
    }
}
if ($islandUnknown.Count -gt 0) {
    $islandResults += [pscustomobject]@{
        verdict = 'NEEDS REVIEW'
        group   = 'unclassified-islands'
        count   = $islandUnknown.Count
        why     = "$($islandUnknown.Count) island(s) didn't match any classification rule."
        fix     = "Inspect each manually. If a new pattern emerges, add a rule to gap-analysis.ps1."
        examples = ($islandUnknown | Select-Object -First 5 | ForEach-Object { $_.root })
    }
}

# ---------- always-real-gap findings ----------
function New-AlwaysGapResult($key, $why, $fix) {
    $f = $findings.$key
    if (-not $f -or $f.count -eq 0) { return $null }
    return [pscustomobject]@{
        verdict = 'REAL GAP'
        group   = $key
        count   = $f.count
        why     = $why
        fix     = $fix
        examples = @($f.items | Select-Object -First 8)
    }
}
$alwaysGaps = @()
$alwaysGaps += New-AlwaysGapResult 'dangling-edges'      'Edge source/target points to a node id that does not exist.' 'Re-run merge.ps1. If still present, remove the offending edge from the source graph file.'
$alwaysGaps += New-AlwaysGapResult 'duplicate-node-ids'  'Same node id declared more than once.' 'Dedupe in the source graph file (system or code) so each id appears in nodes[] exactly once.'
$alwaysGaps += New-AlwaysGapResult 'stub-nodes'          'Nodes with missing:true — extractor created a placeholder for a reference that does not resolve.' 'Tighten the extractor regex OR fix/remove the broken reference at the source.'
$alwaysGaps += New-AlwaysGapResult 'unclustered-nodes'   'Cluster field is empty or points to a cluster id that does not exist.' 'Assign each node to one of the declared clusters in clusters[].'
$alwaysGaps += New-AlwaysGapResult 'duplicate-edges'     'Same (source, target, type) appears more than once.' 'Dedupe edges[] in the source graph file.'
$alwaysGaps += New-AlwaysGapResult 'dropped-bridges'     'Bridge references a system or code node id that does not exist after merge.' 'Fix the bridge endpoint in system/mentor-graph.json bridges[] or remove the bridge.'
$alwaysGaps = $alwaysGaps | Where-Object { $_ }

# ---------- summary counts ----------
$realCount    = ($islandResults | Where-Object verdict -eq 'REAL GAP').Count
$realCount   += ($orphanResults | Where-Object verdict -eq 'REAL GAP').Count
$realCount   += $alwaysGaps.Count
$expectedCount = ($islandResults | Where-Object verdict -eq 'EXPECTED').Count + ($orphanResults | Where-Object verdict -eq 'EXPECTED').Count
$reviewCount   = ($islandResults | Where-Object verdict -eq 'NEEDS REVIEW').Count + ($orphanResults | Where-Object verdict -eq 'NEEDS REVIEW').Count

# ---------- output ----------
if ($Json) {
    $out = [ordered]@{
        layer    = $Layer
        graph    = (Resolve-Path $graphPath).Path
        summary  = @{ real_gap = $realCount; expected = $expectedCount; needs_review = $reviewCount }
        always_gaps = $alwaysGaps
        islands  = $islandResults
        orphans  = $orphanResults
    }
    $out | ConvertTo-Json -Depth 12
    if ($realCount -gt 0) { exit 1 } else { exit 0 }
}

# Human output
function Write-Verdict($v) {
    $color = switch ($v) {
        'REAL GAP'     { 'Red' }
        'EXPECTED'     { 'Green' }
        'NEEDS REVIEW' { 'Yellow' }
        default        { 'Gray' }
    }
    Write-Host -NoNewline "[$v]" -ForegroundColor $color
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Knowledge Graph Gap Analysis: $Layer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ("  Graph:  {0}" -f (Resolve-Path $graphPath).Path) -ForegroundColor DarkGray

# Always-gap findings first
if ($alwaysGaps.Count -gt 0) {
    Write-Host ""
    Write-Host "== Structural defects ==" -ForegroundColor White
    foreach ($g in $alwaysGaps) {
        Write-Host ""
        Write-Verdict $g.verdict; Write-Host (" {0}  ({1})" -f $g.group, $g.count)
        Write-Host "  Why: $($g.why)" -ForegroundColor DarkGray
        Write-Host "  Fix: $($g.fix)" -ForegroundColor DarkGray
        if ($g.examples -and $g.examples.Count -gt 0) {
            Write-Host "  Examples:" -ForegroundColor DarkGray
            foreach ($ex in $g.examples) { Write-Host "    - $ex" -ForegroundColor DarkGray }
            if ($g.count -gt $g.examples.Count) {
                Write-Host ("    ... and {0} more" -f ($g.count - $g.examples.Count)) -ForegroundColor DarkGray
            }
        }
    }
}

# Orphans
if ($orphanResults.Count -gt 0) {
    Write-Host ""
    Write-Host "== Orphan nodes ==" -ForegroundColor White
    foreach ($o in $orphanResults) {
        Write-Host ""
        Write-Verdict $o.verdict; Write-Host (" {0}  (type: {1})" -f $o.id, $o.type)
        if ($o.label -and $o.label -ne $o.id) {
            Write-Host "  Label: $($o.label)" -ForegroundColor DarkGray
        }
        Write-Host "  Why: $($o.why)" -ForegroundColor DarkGray
        if ($o.fix) { Write-Host "  Fix: $($o.fix)" -ForegroundColor DarkGray }
    }
}

# Islands
if ($islandResults.Count -gt 0) {
    Write-Host ""
    Write-Host "== Island groups ==" -ForegroundColor White
    foreach ($i in $islandResults) {
        Write-Host ""
        Write-Verdict $i.verdict; Write-Host (" {0}  ({1} island(s))" -f $i.group, $i.count)
        Write-Host "  Why: $($i.why)" -ForegroundColor DarkGray
        Write-Host "  Fix: $($i.fix)" -ForegroundColor DarkGray
        if ($i.examples -and $i.examples.Count -gt 0) {
            Write-Host "  Examples:" -ForegroundColor DarkGray
            foreach ($ex in $i.examples) { Write-Host "    - $ex" -ForegroundColor DarkGray }
        }
    }
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
$color = if ($realCount -gt 0) { 'Red' } elseif ($reviewCount -gt 0) { 'Yellow' } else { 'Green' }
Write-Host (" Summary: REAL GAP {0} | EXPECTED {1} | NEEDS REVIEW {2}" -f $realCount, $expectedCount, $reviewCount) -ForegroundColor $color
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($realCount -gt 0) { exit 1 } else { exit 0 }
