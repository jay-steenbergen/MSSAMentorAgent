#!/usr/bin/env pwsh
# mentor.ps1 — graph-first authoring CLI
#
# Verbs:
#   add <type> <slug> [--label LABEL] [--description DESC] [--cluster CLUSTER] [--no-stub]
#       Add a node and (by default) scaffold its stub file.
#       <type> = agent | skill | method | track | test
#
#   link <source-id> <target-id> <edge-type>
#       Add an edge between two existing nodes.
#       If source is an agent and edge-type is 'composes', also patch the agent's
#       skills: YAML list.
#
#   remove <node-id>
#       Remove a node and every edge that touches it.
#       Does NOT delete the body file (manual decision).
#
#   unlink <source-id> <target-id> <edge-type>
#       Remove a single edge. Patches agent skills: list if applicable.
#
#   validate
#       Run the rebuild pipeline and report drift / REAL GAP status.
#
#   types
#       Print the edge-type vocabulary currently in use (typo guard).
#
# All write operations:
#   - print a dry-run summary before mutating
#   - back up mentor-graph.json to mentor-graph.json.bak
#   - parse-validate the JSON before atomic rename
#   - by default rebuild the graph after the change (skip with --no-validate)

[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Verb,
    [Parameter(Position = 1)][string]$Arg1,
    [Parameter(Position = 2)][string]$Arg2,
    [Parameter(Position = 3)][string]$Arg3,
    [string]$Label,
    [string]$Description = '_TODO: describe this._',
    [string]$Cluster = 'agent-core',
    [switch]$NoStub,
    [switch]$NoValidate,
    [switch]$NoBackup
)

$ErrorActionPreference = 'Stop'

# Load library modules.
$libDir = Join-Path $PSScriptRoot 'lib'
Import-Module (Join-Path $libDir 'graph-writer.psm1') -Force
Import-Module (Join-Path $libDir 'agent-sync.psm1') -Force
Import-Module (Join-Path $libDir 'scaffold.psm1') -Force

$repoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path

function Show-Usage {
    Write-Host @"
mentor.ps1 — graph-first authoring CLI

Usage:
  mentor.ps1 add <type> <slug> [-Label L] [-Description D] [-Cluster C] [-NoStub]
  mentor.ps1 link <source-id> <target-id> <edge-type>
  mentor.ps1 remove <node-id>
  mentor.ps1 unlink <source-id> <target-id> <edge-type>
  mentor.ps1 validate
  mentor.ps1 types

Types: agent | skill | method | track | test

Examples:
  mentor.ps1 add skill bug-triage -Description "Help learner diagnose runtime errors"
  mentor.ps1 link agent:mentor skill:bug-triage composes
  mentor.ps1 unlink agent:mentor skill:bug-triage composes
  mentor.ps1 remove skill:bug-triage
"@
}

function Invoke-Rebuild {
    if ($NoValidate) {
        Write-Host "  (skipping rebuild, --no-validate set)" -ForegroundColor DarkGray
        return
    }
    Write-Host ""
    Write-Host "Rebuilding graph..." -ForegroundColor Cyan
    $rebuild = Join-Path $repoRoot ".github/knowledge-graph/build/core/rebuild-if-stale.ps1"
    & pwsh -NoProfile -File $rebuild -Force
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARN: rebuild exited with code $LASTEXITCODE" -ForegroundColor Yellow
    }
}

function Build-NodeId {
    param([string]$Type, [string]$Slug)
    if ($Slug -match '^[^:]+:') { return $Slug }   # already qualified
    return "$Type`:$Slug"
}

function Resolve-NodeType {
    param([string]$Id)
    if ($Id -match '^([^:]+):') { return $matches[1] }
    throw "Node id '$Id' is missing a type prefix (e.g. 'skill:foo')."
}

function Cmd-Types {
    $g = Get-MentorGraph
    $counts = $g.edges | Group-Object type | Sort-Object Count -Descending
    Write-Host ""
    Write-Host ("Edge types in use ({0}):" -f $counts.Count) -ForegroundColor Cyan
    $counts | Select-Object -First 30 | ForEach-Object {
        "  {0,4}  {1}" -f $_.Count, $_.Name | Write-Host
    }
    if ($counts.Count -gt 30) {
        Write-Host "  ... and $($counts.Count - 30) more" -ForegroundColor DarkGray
    }
}

function Cmd-Validate {
    Invoke-Rebuild
    $gap = Join-Path $repoRoot ".github/knowledge-graph/build/core/gap-analysis.ps1"
    if (Test-Path $gap) {
        Write-Host ""
        Write-Host "Running gap analysis..." -ForegroundColor Cyan
        & pwsh -NoProfile -File $gap
    }
}

function Cmd-Add {
    param([string]$Type, [string]$Slug)
    if (-not $Type -or -not $Slug) {
        throw "Usage: add <type> <slug>"
    }
    $validTypes = 'agent','skill','method','track','test','session','experiment','decision'
    if ($Type -notin $validTypes) {
        throw "Invalid type '$Type'. Must be one of: $($validTypes -join ', ')"
    }
    $id = Build-NodeId -Type $Type -Slug $Slug
    $labelEff = if ($Label) { $Label } else { $Slug }

    # Determine file path the node will reference (matches scaffold layout).
    $file = switch ($Type) {
        'agent'      { ".github/agents/$labelEff.agent.md" }
        'skill'      { ".github/skills/$Slug/SKILL.md" }
        'method'     { ".github/skills/methods/$Slug/SKILL.md" }
        'track'      { ".github/skills/tracks/$Slug/SKILL.md" }
        'test'       { ".github/tests/$Slug.test.md" }
        'session'    { ".github/knowledge-graph/log/sessions/$Slug.md" }
        'experiment' { ".github/knowledge-graph/log/experiments/$Slug.md" }
        'decision'   { ".github/knowledge-graph/log/decisions/$Slug.md" }
    }

    Write-Host ""
    Write-Host "Plan:" -ForegroundColor Cyan
    Write-Host "  + node $id (type=$Type, cluster=$Cluster)"
    Write-Host "  + file path: $file"
    if (-not $NoStub) { Write-Host "  + scaffold stub at $file (if missing)" }
    Write-Host ""

    $g = Get-MentorGraph
    $g = Add-MentorNode -Graph $g -Id $id -Type $Type -Label $labelEff -Cluster $Cluster -File $file -Description $Description
    Save-MentorGraph -Graph $g -NoBackup:$NoBackup | Out-Null
    Write-Host "  + node written" -ForegroundColor DarkGreen

    if (-not $NoStub) {
        New-StubFile -Type $Type -Id $id -Label $labelEff -Description $Description | Out-Null
    }

    Invoke-Rebuild
}

function Cmd-Link {
    param([string]$Source, [string]$Target, [string]$EdgeType)
    if (-not $Source -or -not $Target -or -not $EdgeType) {
        throw "Usage: link <source-id> <target-id> <edge-type>"
    }

    $g = Get-MentorGraph
    $known = Get-KnownEdgeTypes -Graph $g
    if ($EdgeType -notin $known) {
        Write-Host ""
        Write-Host "Note: '$EdgeType' is a NEW edge type (not currently in graph)." -ForegroundColor Yellow
        Write-Host "Existing types include: $($known -join ', ')" -ForegroundColor DarkGray
        Write-Host "Continuing — but double-check it isn't a typo." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Plan:" -ForegroundColor Cyan
    Write-Host "  + edge $Source --[$EdgeType]--> $Target"

    $isAgentComposes = ((Resolve-NodeType $Source) -eq 'agent' -and $EdgeType -eq 'composes')
    if ($isAgentComposes) {
        $targetNode = $g.nodes | Where-Object { $_.id -eq $Target }
        if ($targetNode) {
            $agentName = ($g.nodes | Where-Object { $_.id -eq $Source }).label
            Write-Host "  + patch $agentName.agent.md skills: list with $($targetNode.file)"
        }
    }
    Write-Host ""

    $g = Add-MentorEdge -Graph $g -Source $Source -Target $Target -EdgeType $EdgeType
    Save-MentorGraph -Graph $g -NoBackup:$NoBackup | Out-Null
    Write-Host "  + edge written" -ForegroundColor DarkGreen

    if ($isAgentComposes) {
        $targetNode = $g.nodes | Where-Object { $_.id -eq $Target }
        $agentName = ($g.nodes | Where-Object { $_.id -eq $Source }).label
        Add-SkillToAgent -AgentName $agentName -SkillNodeFile $targetNode.file
    }

    Invoke-Rebuild
}

function Cmd-Unlink {
    param([string]$Source, [string]$Target, [string]$EdgeType)
    if (-not $Source -or -not $Target -or -not $EdgeType) {
        throw "Usage: unlink <source-id> <target-id> <edge-type>"
    }

    $g = Get-MentorGraph
    Write-Host ""
    Write-Host "Plan:" -ForegroundColor Cyan
    Write-Host "  - edge $Source --[$EdgeType]--> $Target"

    $isAgentComposes = ((Resolve-NodeType $Source) -eq 'agent' -and $EdgeType -eq 'composes')
    if ($isAgentComposes) {
        $targetNode = $g.nodes | Where-Object { $_.id -eq $Target }
        if ($targetNode) {
            $agentName = ($g.nodes | Where-Object { $_.id -eq $Source }).label
            Write-Host "  - remove $($targetNode.file) from $agentName.agent.md skills: list"
        }
    }
    Write-Host ""

    if ($isAgentComposes) {
        $targetNode = $g.nodes | Where-Object { $_.id -eq $Target }
        $agentName = ($g.nodes | Where-Object { $_.id -eq $Source }).label
        if ($targetNode) {
            Remove-SkillFromAgent -AgentName $agentName -SkillNodeFile $targetNode.file
        }
    }

    $g = Remove-MentorEdge -Graph $g -Source $Source -Target $Target -EdgeType $EdgeType
    Save-MentorGraph -Graph $g -NoBackup:$NoBackup | Out-Null
    Write-Host "  - edge removed" -ForegroundColor DarkGreen

    Invoke-Rebuild
}

function Cmd-Remove {
    param([string]$Id)
    if (-not $Id) { throw "Usage: remove <node-id>" }

    $g = Get-MentorGraph
    $node = $g.nodes | Where-Object { $_.id -eq $Id }
    if (-not $node) { throw "Node '$Id' not found." }

    $touchingEdges = $g.edges | Where-Object { $_.source -eq $Id -or $_.target -eq $Id }
    Write-Host ""
    Write-Host "Plan:" -ForegroundColor Cyan
    Write-Host "  - node $Id ($($node.type))"
    Write-Host "  - $($touchingEdges.Count) edge(s) that touch it"
    Write-Host "  ! body file NOT deleted: $($node.file)"
    Write-Host "    (delete manually if you really want it gone)"
    Write-Host ""

    # If any incoming 'composes' from an agent, unwire the agent first.
    $agentComposes = $touchingEdges | Where-Object {
        $_.target -eq $Id -and $_.type -eq 'composes' -and (Resolve-NodeType $_.source) -eq 'agent'
    }
    foreach ($e in $agentComposes) {
        $agentNode = $g.nodes | Where-Object { $_.id -eq $e.source }
        if ($agentNode) {
            Remove-SkillFromAgent -AgentName $agentNode.label -SkillNodeFile $node.file
        }
    }

    $g = Remove-MentorNode -Graph $g -Id $Id
    Save-MentorGraph -Graph $g -NoBackup:$NoBackup | Out-Null
    Write-Host "  - node removed" -ForegroundColor DarkGreen

    Invoke-Rebuild
}

# --- main ---
if (-not $Verb -or $Verb -in @('-h','--help','help')) {
    Show-Usage; exit 0
}

try {
    switch ($Verb) {
        'add'      { Cmd-Add      -Type $Arg1 -Slug $Arg2 }
        'link'     { Cmd-Link     -Source $Arg1 -Target $Arg2 -EdgeType $Arg3 }
        'unlink'   { Cmd-Unlink   -Source $Arg1 -Target $Arg2 -EdgeType $Arg3 }
        'remove'   { Cmd-Remove   -Id $Arg1 }
        'validate' { Cmd-Validate }
        'types'    { Cmd-Types }
        default    { Show-Usage; exit 1 }
    }
} catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
