#!/usr/bin/env pwsh
Import-Module (Resolve-Path '.github/knowledge-graph/lib/query.psm1') -Force

$g = Get-KnowledgeGraph

Write-Host ""
Write-Host "=== Edge Check ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "Edges connected to agent:mentor:" -ForegroundColor White
$mentorEdges = $g.edges | Where-Object { $_.source -eq 'agent:mentor' -or $_.target -eq 'agent:mentor' }
$mentorEdges | Select-Object -First 10 | ForEach-Object {
    Write-Host "  $($_.source) --$($_.type)--> $($_.target)" -ForegroundColor DarkGray
}
Write-Host "  Total: $($mentorEdges.Count)" -ForegroundColor White
Write-Host ""

Write-Host "Edges connected to skill:learner-profile:" -ForegroundColor White
$profileEdges = $g.edges | Where-Object { $_.source -eq 'skill:learner-profile' -or $_.target -eq 'skill:learner-profile' }
$profileEdges | ForEach-Object {
    Write-Host "  $($_.source) --$($_.type)--> $($_.target)" -ForegroundColor DarkGray
}
Write-Host "  Total: $($profileEdges.Count)" -ForegroundColor White
Write-Host ""

Write-Host "Edges connected to track:cloud-app-dev:" -ForegroundColor White
$trackEdges = $g.edges | Where-Object { $_.source -eq 'track:cloud-app-dev' -or $_.target -eq 'track:cloud-app-dev' }
$trackEdges | Select-Object -First 10 | ForEach-Object {
    Write-Host "  $($_.source) --$($_.type)--> $($_.target)" -ForegroundColor DarkGray
}
Write-Host "  Total: $($trackEdges.Count)" -ForegroundColor White
Write-Host ""
