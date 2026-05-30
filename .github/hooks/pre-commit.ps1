#Requires -Version 7.0

<#
.SYNOPSIS
    Git pre-commit hook: Auto-update knowledge graph for staged changes.

.DESCRIPTION
    Detects what files are staged for commit and runs minimal graph updates:
    - New/changed skills → auto-discover
    - New/changed CLI tools → auto-discover
    - New/changed modules → auto-discover
    - New/changed extensions → auto-discover
    - Changed code files → extract
    - Always: merge + fix dangling edges

    Adds updated graph files back to staging automatically.
#>

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Colors
function Write-Header { param($msg) Write-Host "`n$msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "✓ $msg" -ForegroundColor Green }
function Write-Info { param($msg) Write-Host "  $msg" -ForegroundColor Gray }
function Write-Warning { param($msg) Write-Host "⚠ $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "✗ $msg" -ForegroundColor Red }

# Get repo root
$repoRoot = git rev-parse --show-toplevel
if (-not $repoRoot) {
    Write-Error "Not in a git repository"
    exit 1
}
Set-Location $repoRoot

# Get staged files
Write-Header "🔍 Checking staged files..."
$stagedFiles = git diff --cached --name-only --diff-filter=ACM

if (-not $stagedFiles) {
    Write-Info "No staged files. Skipping graph update."
    exit 0
}

# Detect what needs updating
$needsAutoDiscover = $false
$needsExtract = $false
$changedTypes = @()

foreach ($file in $stagedFiles) {
    switch -Regex ($file) {
        # Skills
        '\.github/skills/.*/SKILL\.md$' {
            $needsAutoDiscover = $true
            $changedTypes += "skill"
            break
        }
        # CLI tools
        '\.github/knowledge-graph/cli/.*\.ps1$' {
            $needsAutoDiscover = $true
            $changedTypes += "CLI tool"
            break
        }
        # Modules
        '\.github/knowledge-graph/lib/.*\.psm1$' {
            $needsAutoDiscover = $true
            $needsExtract = $true
            $changedTypes += "module"
            break
        }
        # Extensions
        'extensions/.*/package\.json$' {
            $needsAutoDiscover = $true
            $changedTypes += "extension"
            break
        }
        # Code files (TypeScript, PowerShell, C#)
        '\.(ts|tsx|ps1|psm1|cs)$' {
            $needsExtract = $true
            $changedTypes += "code"
            break
        }
    }
}

if (-not $needsAutoDiscover -and -not $needsExtract) {
    Write-Info "No graph-relevant changes detected. Skipping."
    exit 0
}

# Report what changed
$uniqueTypes = $changedTypes | Select-Object -Unique
Write-Info "Detected changes: $($uniqueTypes -join ', ')"

# Paths
$graphDir = Join-Path $repoRoot '.github' 'knowledge-graph'
$autoDiscoverScript = Join-Path $graphDir 'data' 'system' 'auto-discover-features.ps1'
$extractScript = Join-Path $graphDir 'data' 'code' 'extract.ps1'
$mergeScript = Join-Path $graphDir 'build' 'merge.ps1'
$fixDanglingScript = Join-Path $graphDir 'build' 'fix-dangling-edges.ps1'

$systemGraph = Join-Path $graphDir 'data' 'system' 'mentor-graph.json'
$codeGraph = Join-Path $graphDir 'data' 'code' 'code-graph.json'
$mergedGraph = Join-Path $graphDir 'merged-graph.json'

# Track if we made changes
$graphChanged = $false

# Step 1: Auto-discover (if needed)
if ($needsAutoDiscover) {
    Write-Header "🔎 Running auto-discovery..."
    try {
        $output = & pwsh -NoProfile -File $autoDiscoverScript 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Auto-discover had warnings but completed"
        }
        
        # Check if system graph changed
        $systemStatus = git status --porcelain $systemGraph
        if ($systemStatus) {
            $graphChanged = $true
            Write-Success "System graph updated"
        } else {
            Write-Info "No new features to add"
        }
    } catch {
        Write-Error "Auto-discover failed: $_"
        exit 1
    }
}

# Step 2: Extract code (if needed)
if ($needsExtract) {
    Write-Header "📦 Extracting code artifacts..."
    try {
        & pwsh -NoProfile -File $extractScript | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Extract had warnings but completed"
        }
        
        # Check if code graph changed
        $codeStatus = git status --porcelain $codeGraph
        if ($codeStatus) {
            $graphChanged = $true
            Write-Success "Code graph updated"
        } else {
            Write-Info "No code changes needed"
        }
    } catch {
        Write-Error "Extract failed: $_"
        exit 1
    }
}

# Step 3: Merge (always run if anything changed)
if ($graphChanged) {
    Write-Header "🔗 Merging graph layers..."
    try {
        & pwsh -NoProfile -File $mergeScript | Out-Null
        Write-Success "Graphs merged"
    } catch {
        Write-Error "Merge failed: $_"
        exit 1
    }

    # Step 4: Fix dangling edges
    Write-Header "🔧 Fixing dangling edges..."
    try {
        $fixOutput = & pwsh -NoProfile -File $fixDanglingScript 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Dangling edge fix failed with exit code $LASTEXITCODE"
            Write-Host ""
            Write-Host "Fix output:" -ForegroundColor Yellow
            $fixOutput | Write-Host
            exit 1
        }
        
        if ($fixOutput -match 'Fixed (\d+)') {
            $fixed = $matches[1]
            if ([int]$fixed -gt 0) {
                Write-Success "Fixed $fixed dangling edges"
            } else {
                Write-Info "No dangling edges to fix"
            }
        }
    } catch {
        Write-Error "Dangling edge fix encountered an error: $_"
        exit 1
    }

    # Step 5: Verify graph health
    Write-Header "✅ Verifying graph health..."
    try {
        $healthScript = Join-Path $graphDir 'build' 'health.ps1'
        $healthOutput = & pwsh -NoProfile -File $healthScript -Layer merged -Quiet 2>&1 | Out-String
        
        # Parse health checks for CRITICAL failures only
        # FAIL dangling-edges = BLOCK commit
        # FAIL stub-nodes = ALLOW (expected for build scripts)
        # WARN anything = ALLOW
        $hasDanglingEdges = $healthOutput -match '\[FAIL\]\s+dangling-edges'
        $hasDuplicateIds = $healthOutput -match '\[FAIL\]\s+duplicate-node-ids'
        
        if ($hasDanglingEdges -or $hasDuplicateIds) {
            Write-Error "Graph has CRITICAL failures (connectivity issues)"
            Write-Host ""
            Write-Host "Health output:" -ForegroundColor Yellow
            Write-Host $healthOutput
            Write-Host ""
            Write-Host "Fix these issues before committing:" -ForegroundColor Yellow
            Write-Host "  pwsh .github/knowledge-graph/build/fix-dangling-edges.ps1" -ForegroundColor White
            Write-Host "  pwsh .github/knowledge-graph/build/health.ps1" -ForegroundColor White
            exit 1
        }
        
        # Parse summary line if present
        if ($healthOutput -match 'Summary:\s*PASS\s*(\d+)\s*\|\s*WARN\s*(\d+)\s*\|\s*FAIL\s*(\d+)') {
            $pass = [int]$matches[1]
            $warn = [int]$matches[2]
            $fail = [int]$matches[3]
            Write-Success "Graph health: PASS $pass | WARN $warn | FAIL $fail (non-critical)"
        } else {
            Write-Success "Graph connectivity verified"
        }
    } catch {
        Write-Warning "Health check encountered an error: $_"
        # Don't block commit on health check errors, just warn
    }

    # Step 6: Stage updated graph files
    Write-Header "➕ Staging graph updates..."
    $graphFiles = @($systemGraph, $codeGraph, $mergedGraph) | Where-Object { Test-Path $_ }
    
    foreach ($file in $graphFiles) {
        $status = git status --porcelain $file
        if ($status) {
            git add $file
            Write-Info "Staged: $(Split-Path $file -Leaf)"
        }
    }
    
    Write-Success "Graph is up to date and staged"
} else {
    Write-Info "No graph updates needed"
}

Write-Host ""
exit 0
