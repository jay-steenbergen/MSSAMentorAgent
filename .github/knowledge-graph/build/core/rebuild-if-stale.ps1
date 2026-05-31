#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Self-healing graph rebuild — detects staleness and auto-rebuilds if needed.

.DESCRIPTION
    Checks if the knowledge graph is stale by comparing source file timestamps
    against the graph's last_updated metadata. If stale (or forced), runs:
    extract → merge → health → gap-analysis.

    Staleness triggers:
    - Any .md/.json file under .github/skills/, .github/agents/, .profiles/ newer than graph
    - Any build script (extract.ps1, merge.ps1) modified after graph
    - Graph doesn't exist or has no last_updated timestamp
    - -Force flag

.PARAMETER Force
    Force rebuild even if graph is fresh.

.PARAMETER SkipValidation
    Skip health/gap-analysis after rebuild (faster, but less safe).

.PARAMETER Quiet
    Suppress progress output (only show errors + final status).

.EXAMPLE
    .\rebuild-if-stale.ps1
    # Auto-rebuilds only if graph is stale

.EXAMPLE
    .\rebuild-if-stale.ps1 -Force
    # Always rebuild regardless of freshness

.EXAMPLE
    .\rebuild-if-stale.ps1 -Quiet
    # Silent mode — only output if rebuild needed
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SkipValidation,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
# Script lives at .github/knowledge-graph/build/core/ — repo root is 4 levels up.
$root = (Resolve-Path "$PSScriptRoot\..\..\..\..").Path
$mergedGraphPath = Join-Path $root '.github/knowledge-graph/output/merged-graph.json'

function Write-Progress($msg, $color = 'Cyan') {
    if (-not $Quiet) { Write-Host $msg -ForegroundColor $color }
}

function Write-Detail($msg) {
    if (-not $Quiet) { Write-Host "  $msg" -ForegroundColor DarkGray }
}

# ========== Check freshness ==========

Write-Progress "========================================" 
Write-Progress " Knowledge Graph Self-Healing Check"
Write-Progress "========================================" 
Write-Progress ""

$needsRebuild = $false
$reason = $null

if ($Force) {
    $needsRebuild = $true
    $reason = "Force flag set"
    Write-Progress "Force rebuild requested." 'Yellow'
} elseif (-not (Test-Path $mergedGraphPath)) {
    $needsRebuild = $true
    $reason = "Graph does not exist"
    Write-Progress "Graph missing: $mergedGraphPath" 'Yellow'
} else {
    # Load graph metadata
    $graphContent = Get-Content $mergedGraphPath -Raw
    $graphJson = $graphContent | ConvertFrom-Json -Depth 5
    
    if (-not $graphJson.metadata -or -not $graphJson.metadata.last_updated) {
        $needsRebuild = $true
        $reason = "Graph has no last_updated timestamp"
        Write-Progress "Graph metadata incomplete — forcing rebuild." 'Yellow'
    } else {
        $graphDate = [DateTime]::ParseExact($graphJson.metadata.last_updated, 'yyyy-MM-dd', $null)
        Write-Detail "Graph last updated: $($graphJson.metadata.last_updated)"
        
        # Find newest source file
        $sourceDirs = @(
            '.github/skills'
            '.github/agents'
            '.profiles/profiles'
            '.github/copilot-fundamentals'
        )
        
        $newestFile = $null
        $newestTime = $null
        
        foreach ($dir in $sourceDirs) {
            $dirPath = Join-Path $root $dir
            if (-not (Test-Path $dirPath)) { continue }
            
            $files = Get-ChildItem $dirPath -Recurse -File -Include '*.md','*.json','*.agent.md' -ErrorAction SilentlyContinue
            foreach ($f in $files) {
                if ($null -eq $newestTime -or $f.LastWriteTime -gt $newestTime) {
                    $newestTime = $f.LastWriteTime
                    $newestFile = $f.FullName -replace [regex]::Escape($root), '' -replace '^\\', ''
                }
            }
        }
        
        # Check build scripts
        $buildScripts = @(
            '.github/knowledge-graph/build/core/extract-code-graph.ps1'
            '.github/knowledge-graph/build/core/merge.ps1'
        )
        
        foreach ($script in $buildScripts) {
            $scriptPath = Join-Path $root $script
            if (Test-Path $scriptPath) {
                $scriptTime = (Get-Item $scriptPath).LastWriteTime
                if ($null -eq $newestTime -or $scriptTime -gt $newestTime) {
                    $newestTime = $scriptTime
                    $newestFile = $script
                }
            }
        }
        
        if ($null -ne $newestTime) {
            Write-Detail "Newest source: $newestFile ($($newestTime.ToString('yyyy-MM-dd HH:mm:ss')))"
            
            # Compare dates (day-level precision to avoid false positives from clock skew)
            $newestDate = $newestTime.Date
            if ($newestDate -gt $graphDate) {
                $needsRebuild = $true
                $reason = "Source files modified after graph ($($newestDate.ToString('yyyy-MM-dd')) > $($graphDate.ToString('yyyy-MM-dd')))"
                Write-Progress "Graph is STALE — source files modified after last build." 'Yellow'
            } else {
                Write-Progress "Graph is FRESH — no rebuild needed." 'Green'
            }
        } else {
            Write-Progress "No source files found — assuming fresh." 'Yellow'
        }
    }
}

if (-not $needsRebuild) {
    Write-Progress ""
    Write-Progress "✓ Graph is up to date." 'Green'
    exit 0
}

# ========== Rebuild ==========

Write-Progress ""
Write-Progress "Rebuilding graph..." 'Cyan'
Write-Progress "  Reason: $reason" 'Yellow'
Write-Progress ""

$rebuildStart = Get-Date

try {
    # Step 0: Auto-discover new features (system graph)
    Write-Progress "[0/6] Auto-discovering features..." 'Cyan'
    $discoverPath = Join-Path $root '.github/knowledge-graph/build/advanced/auto-discover-features.ps1'
    if (Test-Path $discoverPath) {
        $discoverOutput = & pwsh -NoProfile -File $discoverPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Auto-discover failed (non-fatal):" -ForegroundColor Yellow
            $discoverOutput | Write-Host
        } else {
            $addedNodes = ($discoverOutput | Select-String -Pattern 'Nodes:\s+(\d+)').Matches
            if ($addedNodes.Count -gt 0) {
                Write-Detail "Added $($addedNodes[-1].Groups[1].Value) new nodes"
            }
        }
    }
    
    # Step 1: Extract code graph
    Write-Progress "[1/6] Extracting code graph..." 'Cyan'
    $extractOutput = & pwsh -NoProfile -File (Join-Path $root '.github/knowledge-graph/build/core/extract-code-graph.ps1') 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Extract failed:" -ForegroundColor Red
        $extractOutput | Write-Host
        exit 1
    }
    Write-Detail "Extracted $(($extractOutput | Select-String -Pattern 'Nodes:\s+(\d+)').Matches.Groups[1].Value) nodes"
    
    # Step 2: Merge layers
    Write-Progress "[2/6] Merging layers..." 'Cyan'
    $mergeOutput = & pwsh -NoProfile -File (Join-Path $root '.github/knowledge-graph/build/core/merge.ps1') 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Merge failed:" -ForegroundColor Red
        $mergeOutput | Write-Host
        exit 1
    }
    $bridgeCount = ($mergeOutput | Select-String -Pattern 'Resolved: (\d+)').Matches.Groups[1].Value
    Write-Detail "Resolved $bridgeCount bridges"
    
    # Step 3: Fix dangling edges (auto-repair)
    Write-Progress "[3/6] Checking for dangling edges..." 'Cyan'
    $fixPath = Join-Path $root '.github/knowledge-graph/build/repair/fix-dangling-edges.ps1'
    if (Test-Path $fixPath) {
        $fixOutput = & pwsh -NoProfile -File $fixPath 2>&1
        if ($LASTEXITCODE -eq 0) {
            $fixCount = ($fixOutput | Select-String -Pattern 'Fixed (\d+)').Matches
            if ($fixCount.Count -gt 0) {
                Write-Detail "Fixed $($fixCount[0].Groups[1].Value) dangling edges"
            } else {
                Write-Detail "No dangling edges"
            }
        } elseif ($LASTEXITCODE -eq 1) {
            # Exit code 1 = manual review needed (not fatal)
            Write-Detail "Manual review needed (see fix-dangling-edges.ps1 output)"
        }
    } else {
        Write-Detail "Skipped: fix-dangling-edges.ps1 not found at $fixPath"
    }
    
    if (-not $SkipValidation) {
        # Step 4: Health check
        Write-Progress "[4/6] Running health check..." 'Cyan'
        $healthOutput = & pwsh -NoProfile -File (Join-Path $root '.github/knowledge-graph/build/core/health.ps1') -Layer merged -Quiet 2>&1
        $healthMatch = $healthOutput | Select-String -Pattern 'Summary: (.+)$' | Select-Object -First 1
        $healthStatus = if ($healthMatch) { $healthMatch.Matches[0].Groups[1].Value } else { 'no summary' }
        Write-Detail $healthStatus

        # Step 5: Gap analysis
        Write-Progress "[5/6] Running gap analysis..." 'Cyan'
        $gapPath = Join-Path $root '.github/knowledge-graph/build/advanced/gap-analysis.ps1'
        if (Test-Path $gapPath) {
            $gapOutput = & pwsh -NoProfile -File $gapPath -Layer merged 2>&1
            $gapMatch = $gapOutput | Select-String -Pattern 'Summary: (.+)$' | Select-Object -First 1
            $gapStatus = if ($gapMatch) { $gapMatch.Matches[0].Groups[1].Value } else { 'no summary' }
        } else {
            $gapStatus = "skipped (gap-analysis.ps1 not found at $gapPath)"
        }
        Write-Detail $gapStatus

        # Check for critical failures
        if ($healthStatus -match 'FAIL \d+[^0]' -or $gapStatus -match 'NEEDS REVIEW \d+[^0]') {
            Write-Host ""
            Write-Host "WARNING: Rebuild completed but health/gap-analysis found issues." -ForegroundColor Yellow
            Write-Host "Run 'health.ps1' and 'gap-analysis.ps1' manually for details." -ForegroundColor Yellow
        }
    } else {
        Write-Detail "Skipped validation (SkipValidation flag set)"
    }
    
    $rebuildEnd = Get-Date
    $elapsed = ($rebuildEnd - $rebuildStart).TotalSeconds
    
    Write-Progress ""
    Write-Progress "✓ Graph rebuilt successfully in $([math]::Round($elapsed, 1))s" 'Green'
    exit 0
    
} catch {
    Write-Host ""
    Write-Host "✗ Rebuild failed: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}
