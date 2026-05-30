#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Auto-fix dangling edges in the knowledge graph.
.DESCRIPTION
    Detects edges pointing to missing nodes and attempts to fix them automatically:
    
    1. If target is a code-func but uses short ID format (code-func:FunctionName),
       searches for the full ID (code-func:path/to/file::FunctionName) and updates the edge.
    
    2. If target node is completely missing and is a conceptual node (rule, feature, etc.),
       reports it for manual intervention.
    
    3. If source node is missing (rare), reports it as critical.
    
    This runs automatically as part of rebuild-if-stale.ps1 after merge.
.PARAMETER DryRun
    Show what would be fixed without making changes.
.EXAMPLE
    pwsh fix-dangling-edges.ps1
.EXAMPLE
    pwsh fix-dangling-edges.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $PSCommandPath
$graphRoot = Split-Path -Parent $scriptRoot

# ---------- Load graphs ----------
$systemPath = Join-Path $graphRoot 'data\MentorAgent\system\mentor-graph.json'
$codePath = Join-Path $graphRoot 'data\MentorAgent\code\code-graph.json'
$mergedPath = Join-Path $graphRoot 'output/merged-graph.json'

if (-not (Test-Path $mergedPath)) {
    Write-Host "ERROR: Merged graph not found at: $mergedPath" -ForegroundColor Red
    Write-Host "Run merge.ps1 first." -ForegroundColor DarkGray
    exit 1
}

$merged = Get-Content $mergedPath -Raw | ConvertFrom-Json -Depth 32
$system = Get-Content $systemPath -Raw | ConvertFrom-Json -Depth 32
$code = Get-Content $codePath -Raw | ConvertFrom-Json -Depth 32

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Fix Dangling Edges" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ---------- Build node index ----------
$nodeIds = @{}
foreach ($n in $merged.nodes) {
    $nodeIds[$n.id] = $n
}

$codeNodeIndex = @{}
foreach ($n in $code.nodes) {
    $codeNodeIndex[$n.id] = $n
    # Also index by label for function lookups
    if ($n.type -eq 'code-func' -and $n.label) {
        if (-not $codeNodeIndex.ContainsKey("label:$($n.label)")) {
            $codeNodeIndex["label:$($n.label)"] = @()
        }
        $codeNodeIndex["label:$($n.label)"] += $n
    }
}

# ---------- Find dangling edges ----------
$danglingEdges = @()
foreach ($edge in $system.edges) {
    $srcExists = $nodeIds.ContainsKey($edge.source)
    $tgtExists = $nodeIds.ContainsKey($edge.target)
    
    if (-not $srcExists -or -not $tgtExists) {
        $danglingEdges += [PSCustomObject]@{
            Source      = $edge.source
            Target      = $edge.target
            Type        = $edge.type
            Label       = $edge.label
            MissingSide = if (-not $srcExists -and -not $tgtExists) { 'both' } elseif (-not $srcExists) { 'source' } else { 'target' }
        }
    }
}

if ($danglingEdges.Count -eq 0) {
    Write-Host "✓ No dangling edges found" -ForegroundColor Green
    exit 0
}

Write-Host "Found $($danglingEdges.Count) dangling edge(s):" -ForegroundColor Yellow
Write-Host ""

# ---------- Attempt fixes ----------
$fixes = @()
$manualReview = @()

foreach ($dangle in $danglingEdges) {
    $fix = $null
    
    # Case 1: Missing target is a short-form code-func reference
    if ($dangle.MissingSide -eq 'target' -and $dangle.Target -match '^code-func:([^:]+)$') {
        $funcName = $Matches[1]
        $candidates = $codeNodeIndex["label:$funcName"]
        
        if ($candidates -and $candidates.Count -eq 1) {
            # Found exactly one match — safe to auto-fix
            $fix = [PSCustomObject]@{
                Type        = 'update-target'
                EdgeSource  = $dangle.Source
                EdgeType    = $dangle.Type
                OldTarget   = $dangle.Target
                NewTarget   = $candidates[0].id
                Confidence  = 'high'
                Reason      = "Found matching function: $($candidates[0].id)"
            }
        }
        elseif ($candidates -and $candidates.Count -gt 1) {
            # Multiple matches — need manual review
            $manualReview += [PSCustomObject]@{
                Issue       = "Ambiguous function reference"
                Edge        = "$($dangle.Source) --[$($dangle.Type)]--> $($dangle.Target)"
                Candidates  = ($candidates | ForEach-Object { $_.id }) -join ', '
                Action      = "Choose correct function and update edge manually"
            }
        }
        else {
            # No matches — function truly doesn't exist
            $manualReview += [PSCustomObject]@{
                Issue       = "Function not found in code graph"
                Edge        = "$($dangle.Source) --[$($dangle.Type)]--> $($dangle.Target)"
                Candidates  = "None"
                Action      = "Remove edge or implement missing function"
            }
        }
    }
    # Case 2: Missing source (critical — shouldn't happen)
    elseif ($dangle.MissingSide -eq 'source') {
        $manualReview += [PSCustomObject]@{
            Issue       = "Edge source node missing (critical)"
            Edge        = "$($dangle.Source) --[$($dangle.Type)]--> $($dangle.Target)"
            Candidates  = "N/A"
            Action      = "Remove edge — source node doesn't exist"
        }
    }
    # Case 3: Missing target is not a code-func (rule, feature, etc.)
    else {
        $manualReview += [PSCustomObject]@{
            Issue       = "Non-code node missing"
            Edge        = "$($dangle.Source) --[$($dangle.Type)]--> $($dangle.Target)"
            Candidates  = "N/A"
            Action      = "Add missing node to system graph or remove edge"
        }
    }
    
    if ($fix) {
        $fixes += $fix
    }
}

# ---------- Report ----------
if ($fixes.Count -gt 0) {
    Write-Host "🔧 Auto-fixable edges: $($fixes.Count)" -ForegroundColor Green
    Write-Host ""
    foreach ($fix in $fixes) {
        Write-Host "  • $($fix.EdgeSource)" -ForegroundColor White
        Write-Host "    Old: $($fix.OldTarget)" -ForegroundColor Red
        Write-Host "    New: $($fix.NewTarget)" -ForegroundColor Green
        Write-Host "    Reason: $($fix.Reason)" -ForegroundColor Gray
        Write-Host ""
    }
}

if ($manualReview.Count -gt 0) {
    Write-Host "⚠️  Manual review needed: $($manualReview.Count)" -ForegroundColor Yellow
    Write-Host ""
    foreach ($item in $manualReview) {
        Write-Host "  Issue: $($item.Issue)" -ForegroundColor Yellow
        Write-Host "  Edge:  $($item.Edge)" -ForegroundColor Gray
        Write-Host "  Action: $($item.Action)" -ForegroundColor White
        Write-Host ""
    }
}

# ---------- Apply fixes ----------
if ($fixes.Count -eq 0) {
    Write-Host "No auto-fixable edges. Manual intervention required." -ForegroundColor Yellow
    exit 1
}

if ($DryRun) {
    Write-Host "DRY RUN: No changes applied" -ForegroundColor Cyan
    exit 0
}

Write-Host "Applying fixes to system graph..." -ForegroundColor Cyan

$modified = $false
foreach ($fix in $fixes) {
    # Find and update the edge in system graph
    $edge = $system.edges | Where-Object {
        $_.source -eq $fix.EdgeSource -and
        $_.type -eq $fix.EdgeType -and
        $_.target -eq $fix.OldTarget
    } | Select-Object -First 1
    
    if ($edge) {
        $edge.target = $fix.NewTarget
        $modified = $true
        Write-Host "  ✓ Updated: $($fix.EdgeSource) -> $($fix.NewTarget)" -ForegroundColor Green
    }
}

if ($modified) {
    # Save updated system graph
    $system | ConvertTo-Json -Depth 32 | Set-Content $systemPath -Encoding utf8
    Write-Host ""
    Write-Host "✓ System graph updated" -ForegroundColor Green
    Write-Host ""
    Write-Host "Re-running merge..." -ForegroundColor Cyan
    
    # Re-merge to update merged graph
    $mergePath = Join-Path $scriptRoot 'merge.ps1'
    & pwsh -NoProfile -File $mergePath | Out-Null
    
    Write-Host "✓ Merge complete" -ForegroundColor Green
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " Fixed $($fixes.Count) dangling edge(s)" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    exit 0
}
else {
    Write-Host "✗ No edges were modified" -ForegroundColor Red
    exit 1
}
