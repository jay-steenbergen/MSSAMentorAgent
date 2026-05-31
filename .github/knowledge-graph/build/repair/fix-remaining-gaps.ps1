#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fixes 3 remaining gaps: (1) orphan file:mentors-profiles, (2) unbridged schema instances, (3) standalone docs.
#>
[CmdletBinding()]
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot\..\..").Path
$sysGraphPath = Join-Path $root '.github/knowledge-graph/system/mentor-graph.json'
$extractPath  = Join-Path $root '.github/knowledge-graph/code/extract.ps1'

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Fixing Remaining Gaps" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ========== GAP 1: Wire file:mentors-profiles to file:readme ==========
Write-Host "Gap 1: Wiring file:mentors-profiles to file:readme..." -ForegroundColor Cyan
$sysGraph = Get-Content $sysGraphPath -Raw | ConvertFrom-Json -Depth 32
$existingEdgeKeys = @{}
foreach ($e in $sysGraph.edges) { $existingEdgeKeys["$($e.source)|$($e.target)|$($e.type)"] = $true }

$gap1Edge = [pscustomobject][ordered]@{
    source = 'file:readme'
    target = 'file:mentors-profiles'
    type   = 'references'
}
$gap1Key = "$($gap1Edge.source)|$($gap1Edge.target)|$($gap1Edge.type)"
$gap1New = -not $existingEdgeKeys.ContainsKey($gap1Key)

# ========== GAP 3: Add file nodes + edges for standalone docs ==========
Write-Host "Gap 3: Adding file nodes + edges for standalone docs..." -ForegroundColor Cyan
$existingNodeIds = @{}
foreach ($n in $sysGraph.nodes) { $existingNodeIds[$n.id] = $true }

$docNodes = @(
    @{ id = 'file:profiles-readme'; label = '.profiles/README.md'; file = '.profiles/README.md'; cluster = 'data-layer'; desc = 'Profiles directory structure documentation.' }
    @{ id = 'file:copilot-fundamentals-readme'; label = '.github/copilot-fundamentals/README.md'; file = '.github/copilot-fundamentals/README.md'; cluster = 'agent-core'; desc = 'Copilot fundamentals index.' }
    @{ id = 'file:tracks-readme'; label = '.github/skills/tracks/README.md'; file = '.github/skills/tracks/README.md'; cluster = 'track-curriculum'; desc = 'Tracks directory structure guide.' }
    @{ id = 'file:copilot-01'; label = '.github/copilot-fundamentals/01-instructions-vs-agent-personas.md'; file = '.github/copilot-fundamentals/01-instructions-vs-agent-personas.md'; cluster = 'agent-core'; desc = 'Instructions vs agent personas explainer.' }
    @{ id = 'file:copilot-02'; label = '.github/copilot-fundamentals/02-using-csharp-for-validation.md'; file = '.github/copilot-fundamentals/02-using-csharp-for-validation.md'; cluster = 'validation-layer'; desc = 'Using C# for validation guide.' }
)

$newDocNodes = @()
$newDocEdges = @()
foreach ($d in $docNodes) {
    if (-not $existingNodeIds.ContainsKey($d.id)) {
        $newDocNodes += [pscustomobject][ordered]@{
            id          = $d.id
            type        = 'file'
            label       = $d.label
            cluster     = $d.cluster
            file        = $d.file
            description = $d.desc
        }
    }
    # Add edge from file:readme (or parent) to this doc
    $parentId = if ($d.id -match 'copilot-0[12]') { 'file:copilot-fundamentals-readme' } else { 'file:readme' }
    $ek = "$parentId|$($d.id)|references"
    if (-not $existingEdgeKeys.ContainsKey($ek)) {
        $newDocEdges += [pscustomobject][ordered]@{ source = $parentId; target = $d.id; type = 'references' }
    }
}

$gap3NodesAdded = $newDocNodes.Count
$gap3EdgesAdded = $newDocEdges.Count + $(if ($gap1New) { 1 } else { 0 })

Write-Host "  System graph additions: $gap3NodesAdded nodes, $gap3EdgesAdded edges" -ForegroundColor Green
Write-Host ""

# ========== GAP 2: Modify extract.ps1 to emit instance_of bridges ==========
Write-Host "Gap 2: Patching extract.ps1 to emit instance_of bridges for schema instances..." -ForegroundColor Cyan
$extractContent = Get-Content $extractPath -Raw

# Check if already patched
if ($extractContent -match 'instance_of.*schema:progress-json') {
    Write-Host "  extract.ps1 already patched — skipping." -ForegroundColor Yellow
    $gap2Patched = $false
} else {
    $gap2Patched = $true
    Write-Host "  Will add instance_of bridge logic to extract.ps1" -ForegroundColor Green
}

Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
$gap1Status = if ($gap1New) { 'add edge' } else { 'already fixed' }
$gap1Color  = if ($gap1New) { 'Green' } else { 'Yellow' }
$gap2Status = if ($gap2Patched) { 'patch extract.ps1' } else { 'already fixed' }
$gap2Color  = if ($gap2Patched) { 'Green' } else { 'Yellow' }
Write-Host "  Gap 1 (orphan): $gap1Status" -ForegroundColor $gap1Color
Write-Host "  Gap 2 (schema): $gap2Status" -ForegroundColor $gap2Color
Write-Host "  Gap 3 (docs):   add $gap3NodesAdded nodes, $gap3EdgesAdded edges" -ForegroundColor Green

if ($DryRun) {
    Write-Host ""
    Write-Host "DryRun set — not writing." -ForegroundColor Yellow
    return
}

# Apply mutations
if ($gap1New) { $sysGraph.edges = @($sysGraph.edges) + @($gap1Edge) }
if ($newDocNodes.Count -gt 0) { $sysGraph.nodes = @($sysGraph.nodes) + $newDocNodes }
if ($newDocEdges.Count -gt 0) { $sysGraph.edges = @($sysGraph.edges) + $newDocEdges }

if ($sysGraph.metadata -and ($sysGraph.metadata.PSObject.Properties.Name -contains 'last_updated')) {
    $sysGraph.metadata.last_updated = (Get-Date -Format 'yyyy-MM-dd')
}

$sysGraph | ConvertTo-Json -Depth 32 | Set-Content $sysGraphPath -Encoding utf8 -NoNewline
Write-Host "Wrote $sysGraphPath" -ForegroundColor Green

# Patch extract.ps1 if needed
if ($gap2Patched) {
    $insertPoint = $extractContent.IndexOf('Write-Host "  Bridges: $($bridges.Count) system nodes mapped to code files" -ForegroundColor Green')
    if ($insertPoint -lt 0) {
        Write-Host "  ERROR: Could not find insertion point in extract.ps1" -ForegroundColor Red
        exit 1
    }
    
    $patchCode = @'

    # Emit instance_of bridges for .progress.json and .profile.json files
    foreach ($n in $nodes) {
        if ($n.type -eq 'code-schema') {
            if ($n.id -match '\.progress\.json$') {
                $bridges += [PSCustomObject]@{
                    system = 'schema:progress-json'
                    code   = $n.id
                    type   = 'instance_of'
                }
            } elseif ($n.id -match '\.profile\.json$|/profile\.json$') {
                $bridges += [PSCustomObject]@{
                    system = 'schema:profile-json'
                    code   = $n.id
                    type   = 'instance_of'
                }
            }
        }
    }
'@
    
    $newContent = $extractContent.Insert($insertPoint, $patchCode)
    Set-Content $extractPath -Value $newContent -Encoding utf8 -NoNewline
    Write-Host "Patched $extractPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "Done. Run extract → merge → health → gap-analysis to verify." -ForegroundColor Cyan
