#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
Show the full blast radius of a file: every graph node that contains it, every behavior that references its path in text, every entry-point that triggers a behavior touching it, and every test that covers any of those nodes.

.DESCRIPTION
Why this exists:
  On 2026-06-04 a "fix" to the greeting behavior touched only the extension's seed
  prompts (entry-point:extension-seed). The same behavior also fires on bare user
  input (entry-point:user-typed). The fix worked for one path and the other shipped
  broken. The agent had no convenient way to ask "what ELSE does this file participate
  in?" — that's the gap this tool closes.

  Run this as the default FIRST move when you're about to edit a behavior-bearing
  file (agent.md, SKILL.md, extension command, picker, chatOpener). The output
  surfaces every other surface the change has to land on.

What it returns (for the input file path):

  1. NODES THAT OWN THIS FILE
     Graph nodes whose `file` property equals the input path. These are the canonical
     "this file IS X" relationships.

  2. NODES THAT REFERENCE THIS FILE IN TEXT
     Behaviors / decisions / rules whose `description` contains the path. These are
     references the extractor doesn't model as edges but still matter for changes.

  3. NEIGHBOR NODES (1-hop)
     Outgoing and incoming edges from the file-owning nodes. Tells you what the file
     depends on and what depends on it.

  4. ENTRY POINTS THAT REACH HERE
     Any entry-point:* node that triggers a behavior the file participates in. THIS
     IS THE CHECK THAT WOULD HAVE CAUGHT THE 2026-06-04 BUG — it would have surfaced
     entry-point:user-typed alongside entry-point:extension-seed.

  5. TESTS THAT COVER THIS BLAST RADIUS
     test:* nodes with [tests] edges to any node in groups 1-3. Lists which tests
     will need updating, and which behaviors are tested by ZERO tests (high-risk
     edit territory).

.PARAMETER File
Repo-relative file path to analyze. Required.

.PARAMETER AsJson
Output structured JSON instead of formatted text. Useful for piping to other tools.

.PARAMETER Quiet
Suppress headers; one node per line. Useful for grep'ing the output.

.EXAMPLE
pwsh .github/knowledge-graph/cli/inspect/blast-radius.ps1 -File extensions/mssa-mentor/src/commands/welcome.ts
pwsh .github/knowledge-graph/cli/inspect/blast-radius.ps1 -File .github/agents/Mentor.agent.md -AsJson
pwsh .github/knowledge-graph/cli/inspect/blast-radius.ps1 -File .github/skills/learner-profile/SKILL.md

.OUTPUTS
Exit code 0 = found at least one connection. Exit code 1 = file is completely
disconnected from the graph (probable wiring gap — surface as a finding).
Exit code 2 = invocation error.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position=0)]
    [string]$File,

    [Parameter()]
    [switch]$AsJson,

    [Parameter()]
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

# Normalize: strip leading `./`, leading slash, repo-root prefix if present.
$File = $File -replace '^\./', '' -replace '^/', ''
$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $scriptDir -Parent) -Parent) -Parent) -Parent
$mergedFile = Join-Path $repoRoot ".github/knowledge-graph/output/merged-graph.json"

if (-not (Test-Path $mergedFile)) {
    Write-Host "Merged graph not found at $mergedFile" -ForegroundColor Red
    Write-Host "Run: pwsh .github/knowledge-graph/build/core/merge.ps1" -ForegroundColor Yellow
    exit 2
}

$graph = Get-Content $mergedFile -Raw | ConvertFrom-Json

# Index helpers.
$nodesById = @{}
foreach ($n in $graph.nodes) { $nodesById[$n.id] = $n }

# 1. NODES THAT OWN THIS FILE
$owningNodes = @($graph.nodes | Where-Object {
    $_.PSObject.Properties.Name -contains 'file' -and $_.file -eq $File
})

# 2. NODES THAT REFERENCE THIS FILE IN TEXT (description field, behaviors and rules)
$referencingNodes = @($graph.nodes | Where-Object {
    $_.PSObject.Properties.Name -contains 'description' -and
    $_.description -and
    $_.description.Contains($File) -and
    $_.id -notin ($owningNodes | ForEach-Object { $_.id })
})

$participatingIds = @($owningNodes + $referencingNodes | ForEach-Object { $_.id })

# 3. NEIGHBOR NODES (1-hop edges from any participating node)
$outgoing = @($graph.edges | Where-Object { $_.source -in $participatingIds })
$incoming = @($graph.edges | Where-Object { $_.target -in $participatingIds })

# 4. ENTRY POINTS that reach here (entry-point:* nodes whose outgoing edges land
#    on any participating node, directly or via one intermediate behavior).
$entryPointNodes = @($graph.nodes | Where-Object { $_.id -like 'entry-point:*' })
$reachingEntryPoints = @()
foreach ($ep in $entryPointNodes) {
    # Direct hit: entry-point -> participating node
    $directHits = @($graph.edges | Where-Object {
        $_.source -eq $ep.id -and $_.target -in $participatingIds
    })
    # 2-hop: entry-point -> behavior -> participating node
    $oneHopTargets = @($graph.edges | Where-Object { $_.source -eq $ep.id } | ForEach-Object { $_.target })
    $twoHopHits = @($graph.edges | Where-Object {
        $_.source -in $oneHopTargets -and $_.target -in $participatingIds
    })
    if ($directHits.Count -gt 0 -or $twoHopHits.Count -gt 0) {
        $reachingEntryPoints += [pscustomobject]@{
            EntryPoint = $ep
            Direct     = $directHits.Count
            ViaBehavior = $twoHopHits.Count
        }
    }
}

# 5. TESTS that cover the blast radius
$testEdges = @($graph.edges | Where-Object {
    $_.type -eq 'tests' -and $_.target -in $participatingIds
})
$coveringTests = @($testEdges | ForEach-Object { $nodesById[$_.source] } | Where-Object { $_ } | Sort-Object id -Unique)

# Identify which participating nodes have NO test coverage (high-risk edit zones).
$testedNodeIds = @($testEdges | ForEach-Object { $_.target } | Sort-Object -Unique)
$untestedParticipatingNodes = @($owningNodes + $referencingNodes | Where-Object {
    $_.id -notin $testedNodeIds
})

# Render.
if ($AsJson) {
    [pscustomobject]@{
        file = $File
        owning_nodes = @($owningNodes | ForEach-Object { @{ id = $_.id; type = $_.type; label = $_.label } })
        referencing_nodes = @($referencingNodes | ForEach-Object { @{ id = $_.id; type = $_.type; label = $_.label } })
        outgoing_edges = @($outgoing | ForEach-Object { @{ from = $_.source; type = $_.type; to = $_.target } })
        incoming_edges = @($incoming | ForEach-Object { @{ from = $_.source; type = $_.type; to = $_.target } })
        entry_points = @($reachingEntryPoints | ForEach-Object {
            @{ id = $_.EntryPoint.id; direct_hits = $_.Direct; via_behavior_hits = $_.ViaBehavior }
        })
        covering_tests = @($coveringTests | ForEach-Object { @{ id = $_.id; label = $_.label } })
        untested_participating_nodes = @($untestedParticipatingNodes | ForEach-Object { @{ id = $_.id; type = $_.type } })
    } | ConvertTo-Json -Depth 10
    if ($owningNodes.Count -eq 0 -and $referencingNodes.Count -eq 0) { exit 1 } else { exit 0 }
}

if ($Quiet) {
    foreach ($n in $owningNodes + $referencingNodes) { Write-Host $n.id }
    if ($owningNodes.Count -eq 0 -and $referencingNodes.Count -eq 0) { exit 1 } else { exit 0 }
}

Write-Host ""
Write-Host "=== BLAST RADIUS: $File ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. NODES OWNING THIS FILE ($($owningNodes.Count))" -ForegroundColor Yellow
if ($owningNodes.Count -eq 0) {
    Write-Host "   (none)" -ForegroundColor DarkGray
    Write-Host "   ⚠ This file is NOT registered in the graph. If it's a capability surface" -ForegroundColor Magenta
    Write-Host "     (skill, agent, behavior, CLI tool), it should have a node." -ForegroundColor Magenta
} else {
    foreach ($n in $owningNodes) {
        Write-Host "   [$($n.type)] $($n.id)" -ForegroundColor White
        Write-Host "     $($n.label)" -ForegroundColor DarkGray
    }
}
Write-Host ""

Write-Host "2. NODES REFERENCING THIS FILE IN TEXT ($($referencingNodes.Count))" -ForegroundColor Yellow
if ($referencingNodes.Count -eq 0) {
    Write-Host "   (none)" -ForegroundColor DarkGray
} else {
    foreach ($n in $referencingNodes) {
        Write-Host "   [$($n.type)] $($n.id)" -ForegroundColor White
        Write-Host "     $($n.label)" -ForegroundColor DarkGray
    }
}
Write-Host ""

Write-Host "3. 1-HOP NEIGHBORS" -ForegroundColor Yellow
Write-Host "   Outgoing ($($outgoing.Count)):" -ForegroundColor Gray
$outGrouped = $outgoing | Group-Object type | Sort-Object Name
foreach ($g in $outGrouped) {
    Write-Host "     [$($g.Name)] -> $($g.Count) target(s)" -ForegroundColor White
    foreach ($e in ($g.Group | Select-Object -First 8)) {
        Write-Host "       $($e.source) -> $($e.target)" -ForegroundColor DarkGray
    }
    if ($g.Count -gt 8) {
        Write-Host "       ... and $($g.Count - 8) more" -ForegroundColor DarkGray
    }
}
Write-Host "   Incoming ($($incoming.Count)):" -ForegroundColor Gray
$inGrouped = $incoming | Group-Object type | Sort-Object Name
foreach ($g in $inGrouped) {
    Write-Host "     [$($g.Name)] from $($g.Count) source(s)" -ForegroundColor White
    foreach ($e in ($g.Group | Select-Object -First 8)) {
        Write-Host "       $($e.source) -> $($e.target)" -ForegroundColor DarkGray
    }
    if ($g.Count -gt 8) {
        Write-Host "       ... and $($g.Count - 8) more" -ForegroundColor DarkGray
    }
}
Write-Host ""

Write-Host "4. ENTRY POINTS REACHING THIS FILE ($($reachingEntryPoints.Count))" -ForegroundColor Yellow
if ($reachingEntryPoints.Count -eq 0) {
    Write-Host "   (none)" -ForegroundColor DarkGray
} else {
    foreach ($ep in $reachingEntryPoints) {
        $modes = @()
        if ($ep.Direct -gt 0) { $modes += "$($ep.Direct) direct" }
        if ($ep.ViaBehavior -gt 0) { $modes += "$($ep.ViaBehavior) via behavior" }
        Write-Host "   [$($ep.EntryPoint.type)] $($ep.EntryPoint.id)" -ForegroundColor Magenta
        Write-Host "     $($ep.EntryPoint.label)  ($($modes -join ', '))" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "   ⚠ If your change only covers ONE of these entry points, the others ship broken." -ForegroundColor Magenta
    Write-Host "     This is the check that would have caught the 2026-06-04 greeting bug." -ForegroundColor Magenta
}
Write-Host ""

Write-Host "5. TESTS COVERING THIS BLAST RADIUS ($($coveringTests.Count))" -ForegroundColor Yellow
if ($coveringTests.Count -eq 0) {
    Write-Host "   (none — no behavioral test covers any of the participating nodes)" -ForegroundColor Red
} else {
    foreach ($t in $coveringTests) {
        Write-Host "   [$($t.type)] $($t.id)" -ForegroundColor White
        if ($t.PSObject.Properties.Name -contains 'file') {
            Write-Host "     $($t.file)" -ForegroundColor DarkGray
        }
    }
}
Write-Host ""

if ($untestedParticipatingNodes.Count -gt 0) {
    Write-Host "⚠  UNTESTED NODES IN THIS BLAST RADIUS ($($untestedParticipatingNodes.Count))" -ForegroundColor Red
    Write-Host "   These nodes participate in the file's surface but have no [tests] edge."
    Write-Host "   Editing without adding a test means future drift will be silent."
    foreach ($n in $untestedParticipatingNodes) {
        Write-Host "     [$($n.type)] $($n.id)" -ForegroundColor White
    }
    Write-Host ""
}

if ($owningNodes.Count -eq 0 -and $referencingNodes.Count -eq 0) {
    exit 1
}
exit 0
