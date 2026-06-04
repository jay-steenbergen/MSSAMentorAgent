$g = Get-Content .github/knowledge-graph/output/merged-graph.json -Raw | ConvertFrom-Json

Write-Host "`n=== Query scripts in graph (queries/ folder) ===" -ForegroundColor Cyan
$g.nodes | Where-Object { ($_.file -and $_.file -like '*queries/*') -or $_.label -like 'Get-*' } | Select-Object id, type, file | Format-Table -AutoSize

Write-Host "`n=== Whiteboard wiring ===" -ForegroundColor Cyan
$g.nodes | Where-Object { $_.id -like '*whiteboard*' } | Select-Object id, type, file | Format-Table -AutoSize
Write-Host "Edges in/out of method:whiteboard:"
$g.edges | Where-Object { $_.source -eq 'method:whiteboard' -or $_.target -eq 'method:whiteboard' } | Format-Table -AutoSize

Write-Host "`n=== Stub-completion concept ===" -ForegroundColor Cyan
$g.nodes | Where-Object { $_.id -like '*stub*' -or $_.label -like '*stub*' } | Select-Object id, label, type | Format-Table -AutoSize

Write-Host "`n=== behavior:09-track-and-adapt outgoing ===" -ForegroundColor Cyan
$g.edges | Where-Object { $_.source -eq 'behavior:09-track-and-adapt' } | Format-Table -AutoSize

Write-Host "`n=== behavior:12-discovery-trace outgoing ===" -ForegroundColor Cyan
$g.edges | Where-Object { $_.source -eq 'behavior:12-discovery-trace' } | Format-Table -AutoSize

Write-Host "`n=== Tests that exist but don't link to agent:mentor ===" -ForegroundColor Cyan
$mentorTestEdges = $g.edges | Where-Object { $_.target -eq 'agent:mentor' -and $_.source -like 'test:*' } | Select-Object -ExpandProperty source
$g.nodes | Where-Object { $_.id -like 'test:*' -and $_.id -notin $mentorTestEdges -and $_.file -like '*tests/*.test.md' } | Select-Object id, label, file | Format-Table -AutoSize
