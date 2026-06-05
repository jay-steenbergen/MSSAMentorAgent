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

# Step 0a: Source-MD path validation. Runs FIRST so bad paths in agent / skill /
# instruction markdown never reach the extractor. Catches the class of bug
# introduced 2026-06-04 (Mentor.agent.md path edit went the wrong direction;
# stub nodes followed, auto-fix loop failed, revert + retry).
$validatePathsScript = Join-Path $repoRoot '.github' 'knowledge-graph' 'cli' 'validate' 'validate-paths.ps1'
if (Test-Path $validatePathsScript) {
    Write-Header "🛣  Validating source-markdown path references..."
    try {
        $validateOutput = & pwsh -NoProfile -File $validatePathsScript 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Source markdown contains broken path references"
            Write-Host ""
            Write-Host $validateOutput
            Write-Host "Fix the bad paths in the listed file(s) before committing." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Bypass (not recommended): git commit --no-verify" -ForegroundColor DarkGray
            exit 1
        }
        # Suppress noisy success line — validator already printed one.
    } catch {
        Write-Error "Path validation encountered an error: $_"
        exit 1
    }
}

# Step 0b: UX-change verification gate. Any change to user-facing surfaces
# (agent rules, behaviors, skills, extension chat openers / commands) requires
# the commit message to carry a [Verification: ...] tag. Compiles passing or
# unit tests passing does NOT mean the user-visible behavior was checked.
# Filed after 2026-06-04: edited extension seed prompts, declared victory on
# tsc passing, never tested bare `@Mentor hey`. Bug shipped.
$uxPathPatterns = @(
    '^extensions/mssa-mentor/src/commands/',
    '^extensions/mssa-mentor/src/chatOpener\.ts$',
    '^\.github/agents/.*\.agent\.md$',
    '^\.github/skills/.*/SKILL\.md$'
)
$uxFilesTouched = @($stagedFiles | Where-Object {
    $f = $_
    $matched = @($uxPathPatterns | Where-Object { $f -match $_ })
    $matched.Count -gt 0
})
if ($uxFilesTouched.Count -gt 0) {
    Write-Header "🧪 UX-change verification gate..."
    # Pull the prepared commit message. Git places it at .git/COMMIT_EDITMSG
    # by the time pre-commit fires when -m is used. We read it directly to
    # check for the verification tag.
    $commitMsgPath = Join-Path $repoRoot '.git' 'COMMIT_EDITMSG'
    $commitMsg = if (Test-Path $commitMsgPath) { Get-Content $commitMsgPath -Raw } else { '' }
    $hasVerification = ($commitMsg -match '\[Verification:\s*fresh-chat\b') -or
                       ($commitMsg -match '\[Verification:\s*n/a\b')
    if (-not $hasVerification) {
        Write-Error "UX-affecting files staged; commit message lacks a [Verification:] tag"
        Write-Host ""
        Write-Host "Touched UX surfaces:" -ForegroundColor Yellow
        foreach ($f in $uxFilesTouched) { Write-Host "  - $f" -ForegroundColor White }
        Write-Host ""
        Write-Host "Required: add ONE of these to the commit message:" -ForegroundColor Yellow
        Write-Host "  [Verification: fresh-chat] <one line of what you saw in chat>" -ForegroundColor White
        Write-Host "  [Verification: n/a — reason: <why no fresh-chat run was needed>]" -ForegroundColor White
        Write-Host ""
        Write-Host "Why this gate exists: ``tsc`` passing != UX verified. The 2026-06-04" -ForegroundColor DarkGray
        Write-Host "greeting bug shipped because the fix compiled clean and was never run" -ForegroundColor DarkGray
        Write-Host "in a fresh chat. See behavior:34-verify-ux-fix-in-fresh-chat." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Bypass (not recommended): git commit --no-verify" -ForegroundColor DarkGray
        exit 1
    }
    Write-Success "Commit message carries [Verification:] tag"
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

# Paths (needed for health check even if no changes)
$graphDir = Join-Path $repoRoot '.github' 'knowledge-graph'
$autoDiscoverScript = Join-Path $graphDir 'build' 'advanced' 'auto-discover-features.ps1'
$extractScript = Join-Path $graphDir 'build' 'core' 'extract-code-graph.ps1'
$mergeScript = Join-Path $graphDir 'build' 'core' 'merge.ps1'
$fixDanglingScript = Join-Path $graphDir 'build' 'repair' 'fix-dangling-edges.ps1'

$systemGraph = Join-Path $graphDir 'data' 'MentorAgent' 'system' 'mentor-graph.json'
$codeGraph = Join-Path $graphDir 'data' 'MentorAgent' 'code' 'code-graph.json'
$mergedGraph = Join-Path $graphDir 'output' 'merged-graph.json'

# Track if we made changes
$graphChanged = $false

# Report what will be processed
if (-not $needsAutoDiscover -and -not $needsExtract) {
    Write-Info "No graph-relevant changes detected. Running health check only..."
} else {
    $uniqueTypes = $changedTypes | Select-Object -Unique
    Write-Info "Detected changes: $($uniqueTypes -join ', ')"
}

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

# Step 3: Merge (only if something changed)
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
}

# Step 5: ALWAYS verify graph health (runs even if no changes detected)
Write-Header "✅ Verifying graph health..."
try {
    $healthScript = Join-Path $graphDir 'build' 'core' 'health.ps1'
    $healthOutput = & pwsh -NoProfile -File $healthScript -Layer merged 2>&1 | Out-String
        
        # Parse health checks and capture counts immediately
        $hasDanglingEdges = $healthOutput -match '\[FAIL\]\s+dangling-edges\s+\((\d+)\)'
        $danglingCount = if ($hasDanglingEdges) { [int]$matches[1] } else { 0 }
        
        $hasDuplicateIds = $healthOutput -match '\[FAIL\]\s+duplicate-node-ids\s+\((\d+)\)'
        $duplicateCount = if ($hasDuplicateIds) { [int]$matches[1] } else { 0 }
        
        $hasStubNodes = $healthOutput -match '\[FAIL\]\s+stub-nodes\s+\((\d+)\)'
        $stubCount = if ($hasStubNodes) { [int]$matches[1] } else { 0 }
        
        $hasOrphans = $healthOutput -match '\[WARN\]\s+orphan-nodes\s+\((\d+)\)'
        $orphanCount = if ($hasOrphans) { [int]$matches[1] } else { 0 }
        
        $hasIslands = $healthOutput -match '\[WARN\]\s+islands\s+\((\d+)\)'
        $islandCount = if ($hasIslands) { [int]$matches[1] } else { 0 }

        $hasCoverage = $healthOutput -match '\[WARN\]\s+code-coverage\s+\((\d+)\)'
        $coverageCount = if ($hasCoverage) { [int]$matches[1] } else { 0 }

        # CRITICAL: Block commit on connectivity issues
        if ($hasDanglingEdges -or $hasDuplicateIds) {
            Write-Error "Graph has CRITICAL failures (connectivity issues)"
            Write-Host ""
            Write-Host "Health output:" -ForegroundColor Yellow
            Write-Host $healthOutput
            Write-Host ""
            Write-Host "Fix these issues before committing:" -ForegroundColor Yellow
            Write-Host "  pwsh .github/knowledge-graph/build/repair/fix-dangling-edges.ps1" -ForegroundColor White
            Write-Host "  pwsh .github/knowledge-graph/build/health.ps1" -ForegroundColor White
            exit 1
        }
        
        # AUTO-FIX: Stub nodes (files exist but not in graph)
        if ($hasStubNodes) {
            Write-Warning "Found $stubCount stub nodes (files not yet extracted)"
            Write-Header "🔧 Auto-fixing: Re-running extract..."
            
            try {
                & pwsh -NoProfile -File $extractScript | Out-Null
                & pwsh -NoProfile -File $mergeScript | Out-Null
                & pwsh -NoProfile -File $fixDanglingScript | Out-Null
                
                # Re-check health
                $healthOutput2 = & pwsh -NoProfile -File $healthScript -Layer merged 2>&1 | Out-String
                $stillHasStubs = $healthOutput2 -match '\[FAIL\]\s+stub-nodes\s+\((\d+)\)'
                
                if (-not $stillHasStubs) {
                    Write-Success "Stub nodes resolved"
                    $graphChanged = $true
                } else {
                    Write-Warning "Some stub nodes remain (might be intentional)"
                }
            } catch {
                Write-Warning "Auto-fix failed: $_"
            }
        }
        
        # REPORT: Orphan nodes (no edges)
        if ($hasOrphans) {
            Write-Warning "Found $orphanCount orphan nodes (no edges)"
            Write-Info "These may need manual wiring. Run:"
            Write-Info "  pwsh .github/knowledge-graph/build/health.ps1 -Layer merged | Select-String orphan -Context 5"
        }
        
        # REPORT: Islands (disconnected components) — BLOCKING
        if ($hasIslands) {
            Write-Error "Found $islandCount island node(s) (disconnected components)"
            Write-Host ""
            Write-Host "Islands are real wiring gaps. Connect them with edges before committing." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "See the islands:" -ForegroundColor Yellow
            Write-Host "  pwsh .github/knowledge-graph/build/core/health.ps1 -Layer merged" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Bypass (not recommended): git commit --no-verify" -ForegroundColor DarkGray
            exit 1
        }

        # BLOCKING: Code coverage gap — repo files not in graph
        # Every committed file must be wired (system node) or excluded (intentional).
        # Silent drift here is how the graph rots. If a file is non-capability surface
        # (generated artifact, README, etc.), add it to $intentionalExcludes in
        # .github/knowledge-graph/build/core/health.ps1.
        if ($hasCoverage) {
            Write-Error "Found $coverageCount repo file(s) not in the knowledge graph"
            Write-Host ""
            Write-Host "Every code file must be wired (system node) or explicitly excluded." -ForegroundColor Yellow
            Write-Host "Silent drift here is how the graph rots." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "See the missing files:" -ForegroundColor Yellow
            Write-Host "  pwsh .github/knowledge-graph/build/core/health.ps1 -Layer merged" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Two ways to fix:" -ForegroundColor Yellow
            Write-Host "  1. Wire it: add a node + edge in .github/knowledge-graph/data/MentorAgent/system/mentor-graph.json" -ForegroundColor Gray
            Write-Host "  2. Exclude it: add a regex to `$intentionalExcludes in build/core/health.ps1 (only for non-capability surface)" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Bypass (not recommended): git commit --no-verify" -ForegroundColor DarkGray
            exit 1
        }
        
        # Parse summary line
        if ($healthOutput -match 'Summary:\s*PASS\s*(\d+)\s*\|\s*WARN\s*(\d+)\s*\|\s*FAIL\s*(\d+)') {
            $pass = [int]$matches[1]
            $warn = [int]$matches[2]
            $fail = [int]$matches[3]
            
            if ($fail -eq 0 -and $warn -eq 0) {
                Write-Success "Graph health: All checks passed"
            } elseif ($fail -eq 0) {
                Write-Success "Graph health: PASS $pass | WARN $warn (non-critical)"
            } else {
                Write-Success "Graph health: PASS $pass | WARN $warn | FAIL $fail (auto-fixed or non-critical)"
            }
        } else {
            Write-Success "Graph connectivity verified"
        }
    } catch {
        Write-Warning "Health check encountered an error: $_"
        # Don't block commit on health check errors, just warn
}

# Step 5b: Graph-first authoring checks
#   Phase 2:
#     - Orphan markdown (BLOCKING):  every artifact .md must have a graph node first
#   Phase 3:
#     - Missing files (BLOCKING):    every graph file ref must resolve on disk
#   Phase 4:
#     - Load-list goldens (BLOCKING): Get-AgentLoadList output must match pinned baselines
#   Always:
#     - Path drift (ADVISORY):       documented paths should resolve to real files
Write-Header "🧭 Graph-first authoring checks..."
try {
    $orphanScript = Join-Path $graphDir 'cli' 'audit' 'find-orphan-markdown.ps1'
    $orphanOutput = & pwsh -NoProfile -File $orphanScript -Quiet 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Orphan markdown files found (graph-first violation)"
        Write-Host ""
        & pwsh -NoProfile -File $orphanScript 2>&1 | Write-Host
        Write-Host ""
        Write-Host "Phase 2 rule: every artifact .md must be registered in the graph FIRST." -ForegroundColor Yellow
        Write-Host "Register the node, then commit." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Bypass (not recommended): git commit --no-verify" -ForegroundColor DarkGray
        exit 1
    }
    Write-Success "No orphan markdown files"
} catch {
    Write-Warning "Orphan check encountered an error: $_"
    # Hard fail on errors here — silent failure would defeat the gate
    exit 1
}

try {
    $missingScript = Join-Path $graphDir 'cli' 'audit' 'find-missing-files.ps1'
    $missingOutput = & pwsh -NoProfile -File $missingScript -Quiet 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Graph nodes reference missing files on disk (graph integrity violation)"
        Write-Host ""
        & pwsh -NoProfile -File $missingScript 2>&1 | Write-Host
        Write-Host ""
        Write-Host "Phase 3 rule: every node.file in the graph must resolve to a real file." -ForegroundColor Yellow
        Write-Host "Fix the path, restore the file, or remove the node — then commit." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Bypass (not recommended): git commit --no-verify" -ForegroundColor DarkGray
        exit 1
    }
    Write-Success "All graph file refs resolve on disk"
} catch {
    Write-Warning "Missing-files check encountered an error: $_"
    # Hard fail on errors here — silent failure would defeat the gate
    exit 1
}

try {
    $loadListScript = Join-Path $graphDir 'cli' 'validate' 'test-load-list.ps1'
    $loadListOutput = & pwsh -NoProfile -File $loadListScript -Quiet 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Get-AgentLoadList golden tests failed (load-list regression)"
        Write-Host ""
        & pwsh -NoProfile -File $loadListScript 2>&1 | Write-Host
        Write-Host ""
        Write-Host "Phase 4 rule: pinned (intent, method, track) -> load list mappings must not change silently." -ForegroundColor Yellow
        Write-Host "If the change is intentional: pwsh .github/knowledge-graph/cli/validate/test-load-list.ps1 -UpdateBaseline" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Bypass (not recommended): git commit --no-verify" -ForegroundColor DarkGray
        exit 1
    }
    Write-Success "Load-list goldens pass"
} catch {
    Write-Warning "Load-list test encountered an error: $_"
    # Hard fail on errors here — silent failure would defeat the gate
    exit 1
}

try {
    $driftScript = Join-Path $graphDir 'cli' 'audit' 'find-drift.ps1'
    $driftOutput = & pwsh -NoProfile -File $driftScript -Quiet 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        if ($driftOutput -match 'Drift findings:\s*(\d+)') {
            $driftCount = [int]$matches[1]
            Write-Error "Found $driftCount drifted path reference(s) in graph text"
        } else {
            Write-Error "Drift check reported issues"
        }
        Write-Host ""
        & pwsh -NoProfile -File $driftScript 2>&1 | Write-Host
        Write-Host ""
        Write-Host "Fix: update the graph text to match a real path, OR create the missing file." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Bypass (not recommended): git commit --no-verify" -ForegroundColor DarkGray
        exit 1
    }
    Write-Success "No path drift in graph text"
} catch {
    Write-Error "Drift check encountered an error: $_"
    exit 1
}

# Step 5d: Purpose-linkage advisory (WARN ONLY — never blocks commit).
#   decision:2026-06-03-purpose-experiment
#   Rule of thumb: every rule/behavior/skill should eventually trace to a purpose:* node
#   via outgoing edges. We don't block commits because the heuristic is fuzzy and
#   blocking would be hated within a week. But we DO surface the gap on every commit
#   that touches mentor-graph.json so the picture stays visible.
$graphJsonStaged = $stagedFiles | Where-Object { $_ -like '*mentor-graph.json' -or $_ -like '*code-graph.json' }
if ($graphJsonStaged) {
    Write-Header "🎯 Purpose-linkage advisory (warn-only)..."
    try {
        $purposeOutput = & pwsh -NoProfile -Command "Import-Module '$graphDir/lib/query.psm1' -Force; `$r = Get-PurposeLinkageReport; Write-Host (`"PURPOSE_LINKAGE: linked=`$(`$r.linked_count) unlinked=`$(`$r.unlinked_count) checked=`$(`$r.checked_count) purposes=`$(`$r.purpose_count)`")" 2>&1 | Out-String
        if ($purposeOutput -match 'PURPOSE_LINKAGE: linked=(\d+) unlinked=(\d+) checked=(\d+) purposes=(\d+)') {
            $linked = [int]$matches[1]
            $unlinked = [int]$matches[2]
            $checked = [int]$matches[3]
            $purposes = [int]$matches[4]
            if ($purposes -eq 0) {
                Write-Warning "No purpose:* node in the graph. Add one so rules/behaviors/skills can trace to it."
            } elseif ($unlinked -gt 0) {
                $pct = [math]::Round(100.0 * $linked / $checked, 1)
                Write-Warning "Purpose linkage: $linked / $checked nodes reach purpose:* ($pct%). $unlinked unlinked."
                Write-Host "  See: pwsh .github/knowledge-graph/cli/audit/audit-quality.ps1 -Category no-purpose" -ForegroundColor DarkGray
                Write-Host "  Not blocking — heuristic. Fix at your own pace." -ForegroundColor DarkGray
            } else {
                Write-Success "Purpose linkage: $linked / $checked nodes reach purpose:* (100%)"
            }
        } else {
            Write-Info "Purpose-linkage report produced no parseable summary (skipping advisory)"
        }
    } catch {
        # NEVER block on advisory errors.
        Write-Info "Purpose-linkage advisory skipped: $_"
    }
}

# Step 6: Stage updated graph files (if any changed)
if ($graphChanged) {
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
    Write-Info "Graph is clean, no updates to stage"
}

Write-Host ""
exit 0
