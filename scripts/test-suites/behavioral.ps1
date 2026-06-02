#Requires -Version 7.0
<#
.SYNOPSIS
    Behavioral suite: report freshness of every *.test.md spec.

.DESCRIPTION
    "Fresh" is defined mechanically, not by calendar:
      - A spec is NEVER-RUN if its `Actual Result -> Date run` field is empty
      - A spec is STALE if any of its covered files (from the knowledge graph)
        was committed AFTER the spec's last Date run
      - A spec is FRESH otherwise

    Never fails the build — info only. Exits 0 always so the gate is informational.

.OUTPUTS
    @{ name; result; detail; durationMs }
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = 'Continue'
# Don't use StrictMode here — graph nodes have heterogeneous shapes
# (not all have .file), and we'd rather null-check than throw.
$start = Get-Date
Set-StrictMode -Off

# 1. Find every *.test.md spec
$specs = @(
    Get-ChildItem -Path (Join-Path $RepoRoot '.github/tests') -Filter '*.test.md' -ErrorAction SilentlyContinue
    Get-ChildItem -Path (Join-Path $RepoRoot '.github/skills') -Filter '*.test.md' -Recurse -ErrorAction SilentlyContinue
    Get-ChildItem -Path (Join-Path $RepoRoot 'extensions') -Filter '*.test.md' -Recurse -ErrorAction SilentlyContinue
)

if ($specs.Count -eq 0) {
    return @{
        name = 'behavioral'
        result = 'INFO'
        detail = '0 specs found'
        durationMs = [int]((Get-Date) - $start).TotalMilliseconds
    }
}

# 2. Load graph once to look up "what does this test validate?"
$graphPath = Join-Path $RepoRoot '.github/knowledge-graph/data/MentorAgent/system/mentor-graph.json'
$graph = $null
if (Test-Path $graphPath) {
    try {
        $graph = Get-Content $graphPath -Raw | ConvertFrom-Json -Depth 32
    } catch {
        # Bad graph is not our problem here.
    }
}

# Build a quick lookup: test:<name> -> [list of code-file paths it covers]
$coverageMap = @{}
if ($graph) {
    $nodeById = @{}
    foreach ($n in $graph.nodes) { $nodeById[$n.id] = $n }

    foreach ($edge in $graph.edges) {
        if ($edge.source -notlike 'test:*') { continue }
        if ($edge.type -notin @('validates', 'tests')) { continue }

        $covered = @()
        $target = $nodeById[$edge.target]
        if (-not $target) { continue }

        # If target is an extension/agent/etc., expand to its `contains` children
        $children = $graph.edges | Where-Object { $_.source -eq $edge.target -and $_.type -eq 'contains' }
        foreach ($c in $children) {
            $childNode = $nodeById[$c.target]
            if ($childNode -and $childNode.file) {
                $covered += $childNode.file
            }
        }
        # Plus the target's own file if any
        if ($target.file) { $covered += $target.file }

        if (-not $coverageMap.ContainsKey($edge.source)) {
            $coverageMap[$edge.source] = @()
        }
        $coverageMap[$edge.source] += $covered
    }
}

# 3. Parse each spec for "Date run:" and classify
$fresh = @()
$stale = @()
$neverRun = @()

foreach ($spec in $specs) {
    $content = Get-Content $spec.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    $testId = 'test:' + ($spec.BaseName -replace '\.test$', '')

    # Look for "Date run: <something non-empty, not template placeholder>"
    $dateMatch = [regex]::Match(
        $content,
        '(?im)^\*\*Date run:\*\*\s*([^\r\n]+?)\s*$'
    )

    $dateStr = if ($dateMatch.Success) { $dateMatch.Groups[1].Value.Trim() } else { '' }

    # Filter out template placeholders like "{date}" / "{fill when running}"
    $isPlaceholder = $dateStr -match '^\{.*\}$' -or $dateStr -eq ''

    if ($isPlaceholder) {
        $neverRun += $spec.Name
        continue
    }

    # Parse spec date
    $specDate = $null
    try { $specDate = [datetime]::Parse($dateStr) } catch { }

    if (-not $specDate) {
        # We can't parse the date — treat as never-run to be safe
        $neverRun += $spec.Name
        continue
    }

    # Check: any covered file modified in git after $specDate?
    $covered = $coverageMap[$testId]
    if (-not $covered -or $covered.Count -eq 0) {
        # No graph linkage — can't determine staleness; treat as fresh
        $fresh += $spec.Name
        continue
    }

    $isStale = $false
    foreach ($file in ($covered | Sort-Object -Unique)) {
        $fullPath = Join-Path $RepoRoot $file
        if (-not (Test-Path $fullPath)) { continue }

        # Get last commit date for this file
        $lastCommitStr = & git -C $RepoRoot log -1 --format=%cI -- $file 2>$null
        if (-not $lastCommitStr) { continue }

        try {
            $lastCommit = [datetime]::Parse($lastCommitStr)
            if ($lastCommit -gt $specDate) {
                $isStale = $true
                break
            }
        } catch { }
    }

    if ($isStale) {
        $stale += $spec.Name
    } else {
        $fresh += $spec.Name
    }
}

$total = $specs.Count
$detail = "$total specs ($($fresh.Count) fresh, $($stale.Count) stale, $($neverRun.Count) never-run)"

# Behavioral never fails the build
return @{
    name = 'behavioral'
    result = 'INFO'
    detail = $detail
    durationMs = [int]((Get-Date) - $start).TotalMilliseconds
    fresh = $fresh
    stale = $stale
    neverRun = $neverRun
}
