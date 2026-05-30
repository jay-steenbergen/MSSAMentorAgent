#!/usr/bin/env pwsh
Import-Module (Resolve-Path '.github/knowledge-graph/lib/query.psm1') -Force

$g = Get-KnowledgeGraph

Write-Host ""
Write-Host "=== Node Types in Graph ===" -ForegroundColor Cyan
Write-Host ""

$g.nodes | Group-Object type | Sort-Object Count -Descending | ForEach-Object {
    Write-Host "$($_.Name): $($_.Count)" -ForegroundColor White
}

Write-Host ""
Write-Host "=== Sample Skill Nodes ===" -ForegroundColor Cyan
Write-Host ""

$g.nodes | Where-Object { $_.id -like 'skill:*' } | Select-Object -First 5 | ForEach-Object {
    Write-Host "ID: $($_.id)" -ForegroundColor White
    Write-Host "  Type: $($_.type)" -ForegroundColor DarkGray
    Write-Host "  Label: $($_.label)" -ForegroundColor DarkGray
    Write-Host ""
}
