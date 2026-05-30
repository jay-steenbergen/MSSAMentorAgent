#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Audit the Mentor knowledge graph against the live repository.
.DESCRIPTION
    Runs the drift_detection_checks declared in mentor-graph.json against the
    actual filesystem and source files. Color-coded output. Non-zero exit on
    any failure so CI can hook it.
.EXAMPLE
    .\.github\knowledge-graph\audit.ps1
.EXAMPLE
    .\.github\knowledge-graph\audit.ps1 -Verbose
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# ---------- bootstrap ----------
$scriptDir = $PSScriptRoot
$graphPath = Join-Path $scriptDir "mentor-graph.json"

# Find repo root (walk up looking for .github)
$repoRoot = $scriptDir
while ($repoRoot -and -not (Test-Path (Join-Path $repoRoot ".github"))) {
    $repoRoot = Split-Path $repoRoot -Parent
}
if (-not $repoRoot) {
    Write-Host "ERROR: Could not find repo root (.github directory)" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $graphPath)) {
    Write-Host "ERROR: mentor-graph.json not found at $graphPath" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " MSSA Mentor Knowledge Graph Audit" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Repo:  $repoRoot" -ForegroundColor DarkGray
Write-Host "Graph: $graphPath" -ForegroundColor DarkGray
Write-Host ""

$graph = Get-Content $graphPath -Raw | ConvertFrom-Json

# ---------- counters ----------
$pass = 0
$warn = 0
$fail = 0
$failures = @()

function Report-Pass($msg) {
    $script:pass++
    Write-Host "  PASS " -NoNewline -ForegroundColor Green
    Write-Host $msg
}
function Report-Warn($msg) {
    $script:warn++
    Write-Host "  WARN " -NoNewline -ForegroundColor Yellow
    Write-Host $msg
}
function Report-Fail($msg) {
    $script:fail++
    $script:failures += $msg
    Write-Host "  FAIL " -NoNewline -ForegroundColor Red
    Write-Host $msg
}

# ============================================================
# CHECK 1: Every node with `file` field must exist on disk
# ============================================================
Write-Host "Check 1: File references resolve" -ForegroundColor Cyan

$fileNodes = $graph.nodes | Where-Object { $_.file -and $_.file -notmatch '\{.*\}' }
$missingFiles = @()
foreach ($node in $fileNodes) {
    # skip path templates like {username}/profile.json
    if ($node.file -match '\{.*\}') { continue }
    $fullPath = Join-Path $repoRoot $node.file
    if (-not (Test-Path $fullPath)) {
        $missingFiles += [PSCustomObject]@{ Id = $node.id; File = $node.file }
    }
}
if ($missingFiles.Count -eq 0) {
    Report-Pass "All $($fileNodes.Count) concrete file references exist"
} else {
    foreach ($m in $missingFiles) {
        Report-Fail "Node '$($m.Id)' references missing file: $($m.File)"
    }
}
Write-Host ""

# ============================================================
# CHECK 2: Every edge's source and target must be a real node id
# ============================================================
Write-Host "Check 2: Edges reference real nodes" -ForegroundColor Cyan

$nodeIds = @{}
foreach ($n in $graph.nodes) { $nodeIds[$n.id] = $true }

$dangling = @()
foreach ($e in $graph.edges) {
    if (-not $nodeIds.ContainsKey($e.source)) {
        $dangling += "edge source '$($e.source)' (→ $($e.target)) is not a node"
    }
    if (-not $nodeIds.ContainsKey($e.target)) {
        $dangling += "edge target '$($e.target)' (from $($e.source)) is not a node"
    }
}
if ($dangling.Count -eq 0) {
    Report-Pass "All $($graph.edges.Count) edges connect real nodes"
} else {
    foreach ($d in $dangling) { Report-Fail $d }
}
Write-Host ""

# ============================================================
# CHECK 3: Agent's `composes` edges match its frontmatter skills:
# ============================================================
Write-Host "Check 3: Agent composes only declared skills" -ForegroundColor Cyan

$agentPath = Join-Path $repoRoot ".github/agents/Mentor.agent.md"
if (-not (Test-Path $agentPath)) {
    Report-Fail "Mentor.agent.md not found — cannot verify"
} else {
    $agentContent = Get-Content $agentPath -Raw
    # Pull skills: block from frontmatter (between --- markers)
    if ($agentContent -match '(?s)^---(.*?)---') {
        $frontmatter = $matches[1]
        $declaredSkills = @()
        if ($frontmatter -match '(?s)skills:\s*((?:\s*-\s*\S+\s*)+)') {
            $skillsBlock = $matches[1]
            $declaredSkills = [regex]::Matches($skillsBlock, '-\s*(\S+)') |
                ForEach-Object { $_.Groups[1].Value }
        }

        $composesEdges = $graph.edges | Where-Object { $_.source -eq 'agent:mentor' -and $_.type -eq 'composes' }
        $composedSkillNodes = $composesEdges | ForEach-Object { $_.target }
        # Map skill node id to a name hint (last segment after :)
        $composedNames = $composedSkillNodes | ForEach-Object { ($_ -split ':')[-1] }

        $missingFromFrontmatter = @()
        foreach ($n in $composedNames) {
            $matchFound = $declaredSkills | Where-Object { $_ -match $n -or $n -match $_ }
            if (-not $matchFound) {
                $missingFromFrontmatter += $n
            }
        }
        if ($missingFromFrontmatter.Count -eq 0) {
            Report-Pass "All graph 'composes' edges align with agent frontmatter ($($declaredSkills.Count) declared)"
        } else {
            foreach ($m in $missingFromFrontmatter) {
                Report-Warn "Graph says agent composes '$m' but frontmatter doesn't list it"
            }
        }
    } else {
        Report-Warn "No YAML frontmatter found in Mentor.agent.md"
    }
}
Write-Host ""

# ============================================================
# CHECK 4: list:methods enum aligns with folders under skills/methods/
# ============================================================
Write-Host "Check 4: Method enum matches folders on disk" -ForegroundColor Cyan

$methodsDir = Join-Path $repoRoot ".github/skills/methods"
if (-not (Test-Path $methodsDir)) {
    Report-Fail "skills/methods directory not found"
} else {
    $folderNames = Get-ChildItem $methodsDir -Directory | ForEach-Object { $_.Name }
    # graph: list:methods includes -> skill:* nodes; we want method names
    $methodEnumEdges = $graph.edges | Where-Object { $_.source -eq 'list:methods' -and $_.type -eq 'includes' }
    $enumMethods = @()
    foreach ($e in $methodEnumEdges) {
        $node = $graph.nodes | Where-Object { $_.id -eq $e.target } | Select-Object -First 1
        if ($node) {
            # extract method name from label (e.g. "TDD skill", "ride-along skill (default method)")
            $name = $node.label -replace ' skill.*$', ''
            $enumMethods += $name
        }
    }

    $missingFolders = $enumMethods | Where-Object { $_ -notin $folderNames }
    $orphanFolders = $folderNames | Where-Object { $_ -notin $enumMethods }

    if ($missingFolders.Count -eq 0 -and $orphanFolders.Count -eq 0) {
        Report-Pass "Method enum aligns with folders: $($folderNames -join ', ')"
    }
    foreach ($m in $missingFolders) {
        Report-Fail "Method enum includes '$m' but no folder .github/skills/methods/$m/"
    }
    foreach ($o in $orphanFolders) {
        Report-Warn "Folder .github/skills/methods/$o/ exists but not in graph enum"
    }
}
Write-Host ""

# ============================================================
# CHECK 5: Every method folder has SKILL.md and a proficiency entry
# ============================================================
Write-Host "Check 5: Method folders are complete" -ForegroundColor Cyan

$proficiencyJsonPath = Join-Path $repoRoot ".github/skills/references/method-proficiency-levels.json"
if (-not (Test-Path $proficiencyJsonPath)) {
    Report-Fail "method-proficiency-levels.json not found"
} else {
    $prof = Get-Content $proficiencyJsonPath -Raw | ConvertFrom-Json
    $profKeys = $prof.PSObject.Properties.Name | Where-Object { $_ -notin @('progression_signals','metadata','$schema') }

    $folders = Get-ChildItem $methodsDir -Directory | ForEach-Object { $_.Name }
    foreach ($f in $folders) {
        $skillFile = Join-Path $methodsDir "$f/SKILL.md"
        if (-not (Test-Path $skillFile)) {
            Report-Fail "Method '$f' missing SKILL.md"
        }
        # Normalize: hyphens in folder may be underscores in JSON keys (known issue, see analysis.conflicts)
        $normalizedFolder = $f -replace '-', '_'
        $hasEntry = ($profKeys -contains $f) -or ($profKeys -contains $normalizedFolder)
        if (-not $hasEntry) {
            Report-Fail "Method '$f' has no entry in method-proficiency-levels.json (looked for '$f' and '$normalizedFolder')"
        }
    }
    if ($script:fail -eq 0 -or ($folders | Where-Object { Test-Path (Join-Path $methodsDir "$_/SKILL.md") }).Count -eq $folders.Count) {
        Report-Pass "All $($folders.Count) method folders have SKILL.md"
    }
}
Write-Host ""

# ============================================================
# CHECK 6: Proficiency level values are valid
# ============================================================
Write-Host "Check 6: Proficiency level values are valid" -ForegroundColor Cyan

$validLevels = @('Novice', 'Familiar', 'Competent', 'Proficient')
$progressFiles = Get-ChildItem -Path (Join-Path $repoRoot ".profiles/profiles") -Recurse -Filter "*.progress.json" -ErrorAction SilentlyContinue

$invalidCount = 0
foreach ($pf in $progressFiles) {
    try {
        $data = Get-Content $pf.FullName -Raw | ConvertFrom-Json
        if ($data.method_proficiency) {
            $data.method_proficiency.PSObject.Properties | ForEach-Object {
                $entry = $_.Value
                if ($entry.level -and $entry.level -notin $validLevels) {
                    Report-Fail "$($pf.Name) → method '$($_.Name)' has invalid level '$($entry.level)'"
                    $invalidCount++
                }
            }
        }
    } catch {
        Report-Warn "Could not parse $($pf.Name): $_"
    }
}
if ($invalidCount -eq 0) {
    if ($progressFiles.Count -eq 0) {
        Report-Pass "No progress files yet — nothing to check"
    } else {
        Report-Pass "All proficiency levels across $($progressFiles.Count) progress files are valid"
    }
}
Write-Host ""

# ============================================================
# CHECK 7: Flag the known method-naming conflict if present
# ============================================================
Write-Host "Check 7: Method ID naming consistency (hyphens vs underscores)" -ForegroundColor Cyan

if (Test-Path $proficiencyJsonPath) {
    $prof = Get-Content $proficiencyJsonPath -Raw | ConvertFrom-Json
    $allKeys = $prof.PSObject.Properties.Name | Where-Object { $_ -notin @('progression_signals','metadata','$schema') }
    $folderNames = if (Test-Path $methodsDir) { Get-ChildItem $methodsDir -Directory | ForEach-Object { $_.Name } } else { @() }

    $mismatches = @()
    foreach ($k in $allKeys) {
        $hyphenated = $k -replace '_', '-'
        if ($k -ne $hyphenated -and $hyphenated -in $folderNames) {
            $mismatches += "JSON key '$k' should be '$hyphenated' to match folder"
        }
    }
    if ($mismatches.Count -eq 0) {
        Report-Pass "All JSON keys match folder naming"
    } else {
        foreach ($m in $mismatches) {
            Report-Warn $m
        }
        Write-Host "         → See analysis.conflicts in mentor-graph.json for fix" -ForegroundColor DarkGray
    }
}
Write-Host ""

# ============================================================
# CHECK 8: Surface declared duplicates so reviewer accepts/resolves
# ============================================================
Write-Host "Check 8: Declared duplicates awaiting reviewer decision" -ForegroundColor Cyan

if ($graph.analysis.duplicates) {
    $highSev = $graph.analysis.duplicates | Where-Object { $_.severity -eq 'high' }
    foreach ($d in $highSev) {
        Report-Warn "[high] $($d.name): $($d.locations.Count) locations"
    }
    $other = $graph.analysis.duplicates | Where-Object { $_.severity -ne 'high' }
    if ($other.Count -gt 0) {
        Write-Host "         (+$($other.Count) lower-severity duplicates — see analysis.duplicates)" -ForegroundColor DarkGray
    }
    if ($highSev.Count -eq 0) {
        Report-Pass "No unresolved high-severity duplicates"
    }
} else {
    Report-Pass "No duplicates declared"
}
Write-Host ""

# ============================================================
# Summary
# ============================================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Passed:  $pass" -ForegroundColor Green
Write-Host "  Warned:  $warn" -ForegroundColor Yellow
Write-Host "  Failed:  $fail" -ForegroundColor Red
Write-Host ""

if ($fail -gt 0) {
    Write-Host "Result: AUDIT FAILED" -ForegroundColor Red
    Write-Host ""
    exit 1
} elseif ($warn -gt 0) {
    Write-Host "Result: AUDIT PASSED WITH WARNINGS" -ForegroundColor Yellow
    Write-Host ""
    exit 0
} else {
    Write-Host "Result: AUDIT PASSED" -ForegroundColor Green
    Write-Host ""
    exit 0
}
