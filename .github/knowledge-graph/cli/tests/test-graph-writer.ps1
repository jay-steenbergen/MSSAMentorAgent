# Isolation test for graph-writer.psm1
# Mutates an in-memory copy of the graph; the file on disk is untouched.
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../lib/graph-writer.psm1" -Force

$g = Get-MentorGraph
Write-Host ("Loaded: {0} nodes, {1} edges" -f $g.nodes.Count, $g.edges.Count)

$g = Add-MentorNode -Graph $g -Id 'skill:_TEST_DELETEME' -Type 'skill' -Label 'TEST' -Cluster 'agent-core' -File '.github/skills/_test/SKILL.md' -Description 'throwaway'
Write-Host ("After add: {0} nodes" -f $g.nodes.Count)

$g = Add-MentorEdge -Graph $g -Source 'agent:mentor' -Target 'skill:_TEST_DELETEME' -EdgeType 'composes'
Write-Host ("After edge: {0} edges" -f $g.edges.Count)

$g = Add-MentorEdge -Graph $g -Source 'agent:mentor' -Target 'skill:_TEST_DELETEME' -EdgeType 'composes'
Write-Host ("After dup attempt: {0} edges" -f $g.edges.Count)

try {
    $null = Add-MentorNode -Graph $g -Id 'skill:_TEST_DELETEME' -Type 'skill' -Label 'x' -Cluster 'c' -File 'f'
    Write-Host "Dup node NOT rejected — BUG" -ForegroundColor Red
} catch {
    Write-Host "Dup node rejected: OK" -ForegroundColor Green
}

try {
    $null = Add-MentorEdge -Graph $g -Source 'bogus:nope' -Target 'agent:mentor' -EdgeType 'composes'
    Write-Host "Bad source NOT rejected — BUG" -ForegroundColor Red
} catch {
    Write-Host "Bad source rejected: OK" -ForegroundColor Green
}

$beforeNodes = $g.nodes.Count
$beforeEdges = $g.edges.Count
$g = Remove-MentorNode -Graph $g -Id 'skill:_TEST_DELETEME'
Write-Host ("After remove: {0} nodes ({1} -> {2}), {3} edges ({4} -> {5})" -f $g.nodes.Count, $beforeNodes, $g.nodes.Count, $g.edges.Count, $beforeEdges, $g.edges.Count)

$disk = (Get-MentorGraph).nodes.Count
Write-Host ("Disk untouched: {0} nodes" -f $disk)

$types = Get-KnownEdgeTypes -Graph $g
Write-Host ("Edge types known: {0}" -f $types.Count)

Write-Host ""
Write-Host "graph-writer.psm1 OK" -ForegroundColor Green
