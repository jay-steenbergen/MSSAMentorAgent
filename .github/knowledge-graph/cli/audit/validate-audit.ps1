#!/usr/bin/env pwsh
Import-Module (Resolve-Path '.github/knowledge-graph/lib/query.psm1') -Force

$report = Get-GraphQualityReport
$g = Get-KnowledgeGraph

Write-Host ""
Write-Host "=== Validation Check ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total nodes in graph: $($g.nodes.Count)" -ForegroundColor White
Write-Host "Total edges in graph: $($g.edges.Count)" -ForegroundColor White
Write-Host ""

$skillNodes = @($g.nodes | Where-Object { $_.type -in @('skill', 'method', 'track') })
Write-Host "Skill/method/track nodes checked: $($skillNodes.Count)" -ForegroundColor White
Write-Host ""

Write-Host "Issues found:" -ForegroundColor Yellow
Write-Host "  Orphans: $($report.orphans.Count)" -ForegroundColor White
Write-Host "  Dead-ends: $($report.dead_ends.Count)" -ForegroundColor White
Write-Host "  Broken refs: $($report.broken_refs.Count)" -ForegroundColor White
Write-Host "  No description: $($report.no_description.Count)" -ForegroundColor White
Write-Host "  Unclustered: $($report.unclustered.Count)" -ForegroundColor White
Write-Host "  Untested: $($report.untested.Count)" -ForegroundColor White
Write-Host ""

# Sample a few nodes to verify they have the fields we expect
Write-Host "=== Sample Nodes (First 3 Skills) ===" -ForegroundColor Cyan
Write-Host ""
$skillNodes | Select-Object -First 3 | ForEach-Object {
    Write-Host "  $($_.id)" -ForegroundColor White
    Write-Host "    Type: $($_.type)" -ForegroundColor DarkGray
    Write-Host "    Label: $($_.label)" -ForegroundColor DarkGray
    Write-Host "    Cluster: $($_.cluster)" -ForegroundColor DarkGray
    Write-Host "    Has description: $($null -ne $_.description -and $_.description -ne '')" -ForegroundColor DarkGray
    Write-Host "    File: $($_.file)" -ForegroundColor DarkGray
    
    $incoming = @($g.edges | Where-Object { $_.target -eq $_.id })
    $outgoing = @($g.edges | Where-Object { $_.source -eq $_.id })
    Write-Host "    Incoming edges: $($incoming.Count)" -ForegroundColor DarkGray
    Write-Host "    Outgoing edges: $($outgoing.Count)" -ForegroundColor DarkGray
    Write-Host ""
}
