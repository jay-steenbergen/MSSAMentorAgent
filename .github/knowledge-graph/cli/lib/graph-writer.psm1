# graph-writer.psm1 — atomic mutations on mentor-graph.json
#
# Public functions:
#   Get-MentorGraph         -> [pscustomobject] (nodes, edges, clusters)
#   Add-MentorNode          -> appends a node; errors on duplicate id
#   Remove-MentorNode       -> removes node + every edge that touches it
#   Add-MentorEdge          -> appends an edge; dedups on (source|target|type)
#   Remove-MentorEdge       -> removes edges matching (source|target|type)
#   Save-MentorGraph        -> atomic write (tmp -> parse-validate -> rename)
#   Get-KnownEdgeTypes      -> distinct edge types currently in the graph (typo guard)
#
# Path resolution: lives at .github/knowledge-graph/cli/lib/, so the graph is
# four levels up + data/MentorAgent/system/mentor-graph.json.

$script:GraphPath = Join-Path $PSScriptRoot '..\..\data\MentorAgent\system\mentor-graph.json' | Resolve-Path | Select-Object -ExpandProperty Path

function Get-GraphPath { $script:GraphPath }

function Get-MentorGraph {
    Get-Content $script:GraphPath -Raw | ConvertFrom-Json -Depth 100
}

function Get-KnownEdgeTypes {
    param([pscustomobject]$Graph = (Get-MentorGraph))
    $Graph.edges | Select-Object -ExpandProperty type -Unique | Sort-Object
}

function Add-MentorNode {
    param(
        [Parameter(Mandatory)][pscustomobject]$Graph,
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Type,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$Cluster,
        [Parameter(Mandatory)][string]$File,
        [string]$Section = 'frontmatter',
        [string]$Description = ''
    )
    if ($Graph.nodes | Where-Object { $_.id -eq $Id }) {
        throw "Node '$Id' already exists in mentor-graph.json."
    }
    $node = [pscustomobject][ordered]@{
        id          = $Id
        type        = $Type
        label       = $Label
        cluster     = $Cluster
        file        = $File
        section     = $Section
        description = $Description
    }
    $Graph.nodes = @($Graph.nodes) + $node
    $Graph
}

function Remove-MentorNode {
    param(
        [Parameter(Mandatory)][pscustomobject]$Graph,
        [Parameter(Mandatory)][string]$Id
    )
    if (-not ($Graph.nodes | Where-Object { $_.id -eq $Id })) {
        throw "Node '$Id' not found in mentor-graph.json."
    }
    $Graph.nodes = @($Graph.nodes | Where-Object { $_.id -ne $Id })
    $Graph.edges = @($Graph.edges | Where-Object { $_.source -ne $Id -and $_.target -ne $Id })
    $Graph
}

function Add-MentorEdge {
    param(
        [Parameter(Mandatory)][pscustomobject]$Graph,
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$EdgeType
    )
    # Verify both endpoints exist.
    if (-not ($Graph.nodes | Where-Object { $_.id -eq $Source })) {
        throw "Edge source '$Source' is not a node in mentor-graph.json."
    }
    if (-not ($Graph.nodes | Where-Object { $_.id -eq $Target })) {
        throw "Edge target '$Target' is not a node in mentor-graph.json."
    }
    # Dedup on (source|target|type).
    $exists = $Graph.edges | Where-Object {
        $_.source -eq $Source -and $_.target -eq $Target -and $_.type -eq $EdgeType
    }
    if ($exists) {
        Write-Host "  (edge $Source --[$EdgeType]--> $Target already exists, skipping)" -ForegroundColor DarkGray
        return $Graph
    }
    $edge = [pscustomobject][ordered]@{
        source = $Source
        target = $Target
        type   = $EdgeType
    }
    $Graph.edges = @($Graph.edges) + $edge
    $Graph
}

function Remove-MentorEdge {
    param(
        [Parameter(Mandatory)][pscustomobject]$Graph,
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$EdgeType
    )
    $before = @($Graph.edges).Count
    $Graph.edges = @($Graph.edges | Where-Object {
        -not ($_.source -eq $Source -and $_.target -eq $Target -and $_.type -eq $EdgeType)
    })
    $after = @($Graph.edges).Count
    if ($before -eq $after) {
        Write-Host "  (edge $Source --[$EdgeType]--> $Target was not present)" -ForegroundColor DarkGray
    }
    $Graph
}

function Save-MentorGraph {
    param(
        [Parameter(Mandatory)][pscustomobject]$Graph,
        [switch]$NoBackup
    )
    $path = $script:GraphPath
    $tmp  = "$path.tmp"
    $bak  = "$path.bak"

    # Serialize with stable formatting.
    $json = $Graph | ConvertTo-Json -Depth 100
    Set-Content -Path $tmp -Value $json -Encoding UTF8 -NoNewline

    # Parse-validate before swap.
    try {
        $null = Get-Content $tmp -Raw | ConvertFrom-Json -Depth 100
    } catch {
        Remove-Item $tmp -ErrorAction SilentlyContinue
        throw "Refused to save mentor-graph.json — serialized output failed JSON parse: $_"
    }

    if (-not $NoBackup -and (Test-Path $path)) {
        Copy-Item $path $bak -Force
    }
    Move-Item $tmp $path -Force
    $path
}

Export-ModuleMember -Function Get-MentorGraph, Get-KnownEdgeTypes, Add-MentorNode, Remove-MentorNode, Add-MentorEdge, Remove-MentorEdge, Save-MentorGraph, Get-GraphPath
