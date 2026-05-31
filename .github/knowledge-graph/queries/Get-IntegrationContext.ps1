<#
.SYNOPSIS
Build a token-budgeted integration context pack for an LLM from the knowledge graph.

.DESCRIPTION
Given a seed (node ID, file path, or natural-language intent), walks the merged
knowledge graph N hops out, packs full file contents into a JSON envelope sized
for an LLM context window, and surfaces query hints + ready-to-run follow-up
commands when content had to be pruned.

Use this when you want the LLM to design how to integrate new code: the pack
gives it the conventions, registration points, related skills, and code
context all in one structured blob.

PRUNING POLICY (when over -MaxTokens):
  1. Seeds (distance 0) always keep full content.
  2. Outer-distance nodes are downgraded to metadata-only first.
  3. Each downgrade emits a query_hint so the LLM can ask for it later.
  4. If seeds alone exceed budget, a warning is emitted (no truncation).

.PARAMETER Seed
Starting point. Accepted forms:
  - Node ID: "skill:cad-todo-api" (contains a colon, matches a node)
  - File path: ".github/skills/learner-profile/SKILL.md" (looked up by node.file)
  - Intent: "add a new TDD method" (anything else; scored via Get-RelevantSkills)

.PARAMETER FollowUp
Path to a previous Get-IntegrationContext JSON output. Loads its node IDs as
"previously seen" so the LLM (and this script) don't re-include them. Pair
with -Expand to add new seeds onto that context.

.PARAMETER Expand
Used with -FollowUp. Node IDs (or files / intent strings) to add to the pack.

.PARAMETER Depth
BFS hops from each seed. Default: 2.

.PARAMETER MaxTokens
Target token budget. Default: 16000. Estimation = chars / 4.

.PARAMETER IntentSeedCount
When the seed is interpreted as intent, take this many top-scoring nodes as
seeds. Default: 3.

.PARAMETER NodeTypeFilter
Only include nodes of these types in the subgraph (e.g. "skill","agent").
Edges to filtered-out nodes are dropped.

.PARAMETER OutputPath
Where to write the JSON. If omitted, JSON goes to stdout.

.EXAMPLE
.\Get-IntegrationContext.ps1 -Seed "skill:cad-todo-api"
Pack the neighborhood of cad-todo-api at depth 2, full content where budget allows.

.EXAMPLE
.\Get-IntegrationContext.ps1 -Seed ".github/skills/learner-profile/SKILL.md" -OutputPath pack.json
File-path seed, written to disk.

.EXAMPLE
.\Get-IntegrationContext.ps1 -Seed "add a new TDD method" -IntentSeedCount 5
Intent-driven seed selection.

.EXAMPLE
.\Get-IntegrationContext.ps1 -FollowUp pack.json -Expand "agent:Mentor"
Add Mentor's neighborhood to a prior pack.
#>
[CmdletBinding(DefaultParameterSetName = 'Seed')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Seed', Position = 0)]
    [string]$Seed,

    [Parameter(Mandatory, ParameterSetName = 'FollowUp')]
    [string]$FollowUp,

    [Parameter(ParameterSetName = 'FollowUp')]
    [string[]]$Expand,

    [int]$Depth = 2,
    [int]$MaxTokens = 16000,
    [int]$IntentSeedCount = 3,
    [string[]]$NodeTypeFilter,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $scriptRoot '../..')).Path

Import-Module (Join-Path $scriptRoot 'lib/query.psm1') -Force

# ---------- helpers ----------

function Estimate-Tokens {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    return [int][math]::Ceiling($Text.Length / 4)
}

function Normalize-Path {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path)) { return $null }
    $p = ($Path -replace '\\', '/')
    # Strip leading './' prefix only (TrimStart treats arg as char-set, which would eat '.github')
    while ($p.StartsWith('./')) { $p = $p.Substring(2) }
    return $p
}

function Get-FileIndex {
    param($Graph)
    $idx = @{}
    foreach ($n in $Graph.nodes) {
        if ($n.PSObject.Properties.Match('file').Count -and $n.file) {
            $key = (Normalize-Path $n.file).ToLower()
            if (-not $idx.ContainsKey($key)) { $idx[$key] = $n.id }
        }
    }
    return $idx
}

function Resolve-Seed {
    param(
        [string]$SeedText,
        $Graph,
        [hashtable]$FileIndex,
        [int]$IntentCount
    )

    $result = @{ Input = $SeedText; Mode = $null; NodeIds = @(); Notes = @() }

    # Mode 1: node ID — exact match
    $exact = $Graph.nodes | Where-Object { $_.id -eq $SeedText } | Select-Object -First 1
    if ($exact) {
        $result.Mode = 'node-id'
        $result.NodeIds = @($exact.id)
        return $result
    }

    # Mode 2: file path
    $looksLikePath = ($SeedText -match '[/\\]') -or ($SeedText -match '\.[a-zA-Z0-9]{1,5}$')
    if ($looksLikePath) {
        $normalized = (Normalize-Path $SeedText).ToLower()
        if ($FileIndex.ContainsKey($normalized)) {
            $result.Mode = 'file-path'
            $result.NodeIds = @($FileIndex[$normalized])
            return $result
        }
        # Fuzzy: contains match
        $candidates = $FileIndex.Keys | Where-Object { $_ -like "*$normalized*" -or $normalized -like "*$_*" }
        if ($candidates.Count -ge 1) {
            $result.Mode = 'file-path-fuzzy'
            $result.NodeIds = @($candidates | ForEach-Object { $FileIndex[$_] } | Select-Object -First 3)
            $result.Notes += "File path was matched fuzzily; consider a more specific path."
            return $result
        }
        # Fall through to intent — user might have typed a phrase that contains a slash
    }

    # Mode 3: intent
    try {
        $relevant = Get-RelevantSkills -Intent $SeedText -MaxResults $IntentCount
        if ($relevant -and $relevant.Count -gt 0) {
            $result.Mode = 'intent'
            $result.NodeIds = @($relevant | ForEach-Object { $_.id })
            $result.Notes += "Top $($result.NodeIds.Count) skills scored from intent text."
            return $result
        }
    }
    catch {
        $result.Notes += "Intent matching failed: $($_.Exception.Message)"
    }

    return $result
}

function Get-BfsNeighborhood {
    param(
        $Graph,
        [string[]]$SeedIds,
        [int]$MaxDepth
    )
    $distance = @{}
    foreach ($s in $SeedIds) { $distance[$s] = 0 }
    $queue = [System.Collections.Generic.Queue[string]]::new()
    foreach ($s in $SeedIds) { $queue.Enqueue($s) }

    # Pre-index edges by endpoint for O(1) lookup
    $outAdj = @{}
    $inAdj = @{}
    foreach ($e in $Graph.edges) {
        if (-not $outAdj.ContainsKey($e.source)) { $outAdj[$e.source] = [System.Collections.Generic.List[object]]::new() }
        $outAdj[$e.source].Add($e.target)
        if (-not $inAdj.ContainsKey($e.target)) { $inAdj[$e.target] = [System.Collections.Generic.List[object]]::new() }
        $inAdj[$e.target].Add($e.source)
    }

    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        $d = $distance[$current]
        if ($d -ge $MaxDepth) { continue }
        $neighbors = @()
        if ($outAdj.ContainsKey($current)) { $neighbors += $outAdj[$current] }
        if ($inAdj.ContainsKey($current))  { $neighbors += $inAdj[$current] }
        foreach ($n in ($neighbors | Select-Object -Unique)) {
            if (-not $distance.ContainsKey($n)) {
                $distance[$n] = $d + 1
                $queue.Enqueue($n)
            }
        }
    }
    return $distance
}

function Get-NodeContent {
    param($Node, [string]$RepoRoot)
    if (-not $Node.PSObject.Properties.Match('file').Count -or -not $Node.file) { return $null }
    $rel = Normalize-Path $Node.file
    $full = Join-Path $RepoRoot $rel
    if (-not (Test-Path -LiteralPath $full)) { return $null }
    try { return Get-Content -LiteralPath $full -Raw -ErrorAction Stop } catch { return $null }
}

# ---------- main ----------

# 1. Load graph
$graph = Get-KnowledgeGraph
$fileIndex = Get-FileIndex -Graph $graph

# 2. Handle FollowUp vs fresh seed
$previouslySeen = @()
$inputSeeds = @()
$seedResolution = @{}

if ($PSCmdlet.ParameterSetName -eq 'FollowUp') {
    if (-not (Test-Path -LiteralPath $FollowUp)) {
        Write-Error "FollowUp file not found: $FollowUp"
        exit 2
    }
    $prev = Get-Content -LiteralPath $FollowUp -Raw | ConvertFrom-Json -Depth 32
    $previouslySeen = @($prev.nodes | ForEach-Object { $_.id })
    if (-not $Expand -or $Expand.Count -eq 0) {
        Write-Error "FollowUp requires -Expand with at least one new seed."
        exit 1
    }
    $inputSeeds = $Expand
}
else {
    $inputSeeds = @($Seed)
}

# 3. Resolve every input seed
$allSeedIds = [System.Collections.Generic.List[string]]::new()
$resolutions = [System.Collections.Generic.List[object]]::new()
foreach ($seedText in $inputSeeds) {
    $r = Resolve-Seed -SeedText $seedText -Graph $graph -FileIndex $fileIndex -IntentCount $IntentSeedCount
    $resolutions.Add($r)
    if ($r.NodeIds.Count -eq 0) {
        Write-Host "Could not resolve seed: $seedText" -ForegroundColor Red
        $suggestions = $graph.nodes | Where-Object { $_.id -like "*$seedText*" -or $_.label -like "*$seedText*" } | Select-Object -First 5
        if ($suggestions) {
            Write-Host "Did you mean:" -ForegroundColor Yellow
            $suggestions | ForEach-Object { Write-Host "  - $($_.id) ($($_.type))" -ForegroundColor Gray }
        }
        exit 1
    }
    foreach ($id in $r.NodeIds) { if (-not $allSeedIds.Contains($id)) { $allSeedIds.Add($id) } }
}

# 4. BFS
$distanceMap = Get-BfsNeighborhood -Graph $graph -SeedIds $allSeedIds -MaxDepth $Depth

# 5. Drop previously-seen nodes from this pack
foreach ($prevId in $previouslySeen) { $distanceMap.Remove($prevId) | Out-Null }

# 6. Apply node-type filter
if ($NodeTypeFilter) {
    $allowed = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($t in $NodeTypeFilter) { [void]$allowed.Add($t) }
    $toRemove = @()
    foreach ($id in $distanceMap.Keys) {
        $n = $graph.nodes | Where-Object { $_.id -eq $id } | Select-Object -First 1
        # Keep seeds even if filtered out, otherwise nothing to anchor
        if (-not $allSeedIds.Contains($id) -and -not $allowed.Contains($n.type)) {
            $toRemove += $id
        }
    }
    foreach ($id in $toRemove) { $distanceMap.Remove($id) | Out-Null }
}

# 7. Gather nodes + content + estimate
$nodesWithMeta = @()
foreach ($id in $distanceMap.Keys) {
    $n = $graph.nodes | Where-Object { $_.id -eq $id } | Select-Object -First 1
    if (-not $n) { continue }
    $content = Get-NodeContent -Node $n -RepoRoot $repoRoot
    $hasFile = ($null -ne $n.file -and $n.file -ne '')
    $contentExists = $null -ne $content
    $nodesWithMeta += [PSCustomObject]@{
        Node            = $n
        Distance        = $distanceMap[$id]
        IsSeed          = $allSeedIds.Contains($id)
        HasFile         = $hasFile
        ContentExists   = $contentExists
        Content         = $content
        FullTokens      = if ($contentExists) { Estimate-Tokens $content } else { 0 }
        Tier            = 'pending'
    }
}

# 8. Budget pruning (seeds always full; prune outermost distance first)
$warnings = @()
$queryHints = @()
$totalTokens = 0

# Phase 1: seeds get full content, no matter what
foreach ($entry in ($nodesWithMeta | Where-Object IsSeed)) {
    if ($entry.ContentExists) {
        $entry.Tier = 'full'
        $totalTokens += $entry.FullTokens
    } else {
        $entry.Tier = if ($entry.HasFile) { 'metadata-file-missing' } else { 'metadata' }
        if ($entry.HasFile) { $warnings += "Seed $($entry.Node.id) has file '$($entry.Node.file)' but it could not be read." }
    }
}

if ($totalTokens -gt $MaxTokens) {
    $warnings += "Seed content alone (~$totalTokens tokens) exceeds MaxTokens ($MaxTokens). LLM may truncate."
}

# Phase 2: non-seeds, distance ascending, full content while budget allows
$nonSeeds = $nodesWithMeta | Where-Object { -not $_.IsSeed } | Sort-Object Distance
foreach ($entry in $nonSeeds) {
    if (-not $entry.ContentExists) {
        $entry.Tier = if ($entry.HasFile) { 'metadata-file-missing' } else { 'metadata' }
        continue
    }
    $projected = $totalTokens + $entry.FullTokens
    if ($projected -le $MaxTokens) {
        $entry.Tier = 'full'
        $totalTokens = $projected
    } else {
        $entry.Tier = 'metadata-pruned'
        $queryHints += [PSCustomObject]@{
            node_id            = $entry.Node.id
            reason             = "Pruned from full to metadata to fit budget (would have added $($entry.FullTokens) tokens)."
            suggested_command  = ".github/knowledge-graph/queries/Get-IntegrationContext.ps1 -Seed '$($entry.Node.id)' -Depth 0"
        }
    }
}

# 9. Compute edge subset (both endpoints in our pack OR seed)
$includedIds = [System.Collections.Generic.HashSet[string]]::new()
foreach ($e in $nodesWithMeta) { [void]$includedIds.Add($e.Node.id) }
$edgeSubset = @()
foreach ($edge in $graph.edges) {
    if ($includedIds.Contains($edge.source) -and $includedIds.Contains($edge.target)) {
        $edgeSubset += [PSCustomObject]@{
            from = $edge.source
            to   = $edge.target
            type = $edge.type
        }
    }
}

# 10. Build node output
$nodesOut = @()
foreach ($entry in ($nodesWithMeta | Sort-Object Distance, { $_.Node.id })) {
    $obj = [ordered]@{
        id          = $entry.Node.id
        type        = $entry.Node.type
        label       = $entry.Node.label
        description = $entry.Node.description
        file        = $entry.Node.file
        distance    = $entry.Distance
        is_seed     = $entry.IsSeed
        tier        = $entry.Tier
    }
    if ($entry.Tier -eq 'full') {
        $obj.content = $entry.Content
        $obj.content_tokens = $entry.FullTokens
    }
    $nodesOut += [PSCustomObject]$obj
}

# 11. Suggested next calls (generic + per-hint)
$selfPath = '.github/knowledge-graph/queries/Get-IntegrationContext.ps1'
$suggestedCalls = @()
if ($queryHints.Count -gt 0) {
    $thisOutputName = if ($OutputPath) { $OutputPath } else { '<save this output first>' }
    $suggestedCalls += "# Expand a specific pruned node into a fresh pack:"
    $suggestedCalls += "$selfPath -Seed '$($queryHints[0].node_id)' -Depth 1"
    $suggestedCalls += "# Or add new seeds to THIS pack:"
    $suggestedCalls += "$selfPath -FollowUp '$thisOutputName' -Expand '$($queryHints[0].node_id)'"
}
$suggestedCalls += "# Drill into the call flow for a code file:"
$suggestedCalls += ".github/knowledge-graph/queries/Get-CallFlow.ps1 -NodeName '<file-or-id>'"

# 12. Assemble final output
$output = [ordered]@{
    '$schema'              = 'integration-context-v1'
    generated_at           = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    parameter_set          = $PSCmdlet.ParameterSetName
    seeds_requested        = $inputSeeds
    seed_resolution        = @($resolutions | ForEach-Object {
        [PSCustomObject]@{
            input    = $_.Input
            mode     = $_.Mode
            node_ids = $_.NodeIds
            notes    = $_.Notes
        }
    })
    seed_node_ids          = $allSeedIds
    depth                  = $Depth
    node_type_filter       = $NodeTypeFilter
    previously_seen_nodes  = $previouslySeen
    budget = [ordered]@{
        max_tokens       = $MaxTokens
        estimated_tokens = $totalTokens
        headroom         = $MaxTokens - $totalTokens
    }
    stats = [ordered]@{
        nodes                = $nodesOut.Count
        edges                = $edgeSubset.Count
        nodes_full_content   = ($nodesOut | Where-Object { $_.tier -eq 'full' }).Count
        nodes_metadata_only  = ($nodesOut | Where-Object { $_.tier -ne 'full' }).Count
    }
    nodes                  = $nodesOut
    edges                  = $edgeSubset
    query_hints            = $queryHints
    suggested_next_calls   = $suggestedCalls
    warnings               = $warnings
}

$json = $output | ConvertTo-Json -Depth 20

if ($OutputPath) {
    $json | Set-Content -LiteralPath $OutputPath -Encoding utf8
    Write-Host "Wrote integration context pack to $OutputPath" -ForegroundColor Green
    Write-Host "  Nodes: $($nodesOut.Count) ($($output.stats.nodes_full_content) full, $($output.stats.nodes_metadata_only) metadata)" -ForegroundColor White
    Write-Host "  Edges: $($edgeSubset.Count)" -ForegroundColor White
    Write-Host "  Tokens: ~$totalTokens / $MaxTokens (headroom $($output.budget.headroom))" -ForegroundColor White
    if ($warnings.Count -gt 0)   { Write-Host "  Warnings: $($warnings.Count)" -ForegroundColor Yellow }
    if ($queryHints.Count -gt 0) { Write-Host "  Query hints: $($queryHints.Count) (LLM can re-fetch pruned nodes)" -ForegroundColor Yellow }
} else {
    Write-Output $json
}

# Exit codes: 0 = success, 1 = seed unresolved (handled above), 2 = file missing (handled above)
exit 0
