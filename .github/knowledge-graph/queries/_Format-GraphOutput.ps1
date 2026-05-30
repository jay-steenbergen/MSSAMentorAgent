# Shared formatting functions for graph query scripts
# Dot-source this file to use: . "$PSScriptRoot/_Format-GraphOutput.ps1"

function Write-GraphHeader {
    param(
        [string]$Title,
        [string]$NodeId
    )
    Write-Host "`n=== $Title ===" -ForegroundColor Cyan
    if ($NodeId) {
        Write-Host "Node: $NodeId`n" -ForegroundColor Gray
    }
}

function Write-GraphSection {
    param(
        [string]$Title,
        [object[]]$Items,
        [string]$Direction = "outgoing", # outgoing | incoming
        [switch]$ShowType
    )
    
    $color = if ($Direction -eq "outgoing") { "Green" } else { "Yellow" }
    $arrow = if ($Direction -eq "outgoing") { "→" } else { "←" }
    
    Write-Host "$Title" -ForegroundColor $color
    if ($Items.Count -eq 0) {
        Write-Host "  (none)" -ForegroundColor Gray
    } else {
        foreach ($item in $Items | Sort-Object type, label) {
            $typeInfo = if ($ShowType -and $item.type) { " ($($item.type))" } else { "" }
            Write-Host "  $arrow [$($item.edgeType)] $($item.label)$typeInfo" -ForegroundColor White
        }
    }
    Write-Host ""
}

function Write-GraphPath {
    param(
        [string[]]$Path,
        [object]$Graph
    )
    
    if (-not $Path -or $Path.Count -eq 0) {
        Write-Host "No path found" -ForegroundColor Yellow
        return
    }
    
    Write-Host "=== PATH FOUND ===" -ForegroundColor Green
    for ($i = 0; $i -lt $Path.Count; $i++) {
        $node = $Graph.nodes | Where-Object { $_.id -eq $Path[$i] } | Select-Object -First 1
        $nodeType = if ($node.type) { " ($($node.type))" } else { "" }
        Write-Host "$($i + 1). $($node.label)$nodeType" -ForegroundColor White
        
        if ($i -lt $Path.Count - 1) {
            $edge = $Graph.edges | Where-Object { 
                $_.source -eq $Path[$i] -and $_.target -eq $Path[$i + 1] 
            } | Select-Object -First 1
            $edgeType = if ($edge) { $edge.type } else { "unknown" }
            Write-Host "   └─[$edgeType]→" -ForegroundColor Gray
        }
    }
}

function Write-GraphSuggestions {
    param(
        [string]$Query,
        [object[]]$Suggestions
    )
    
    Write-Host "Could not find node matching: $Query" -ForegroundColor Yellow
    Write-Host "`nSuggestions:" -ForegroundColor Gray
    foreach ($suggestion in $Suggestions | Select-Object -First 5) {
        Write-Host "  - $($suggestion.label) ($($suggestion.id))" -ForegroundColor Gray
    }
}

function ConvertTo-GraphJson {
    param(
        [Parameter(ValueFromPipeline)]
        [object]$Data
    )
    
    return $Data | ConvertTo-Json -Depth 10
}
