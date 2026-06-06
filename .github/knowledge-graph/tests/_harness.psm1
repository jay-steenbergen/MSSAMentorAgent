# Test harness for the knowledge graph + tooling test suite.
#
# Provides: graph cache, assertions, per-file Begin/End scaffolding, JSON output.
# Consumed by run-tests.ps1 + every *.test.ps1 file under tests/.

Set-StrictMode -Version Latest

# ---------- Module state ----------

$script:RepoRoot = $null
$script:CachedGraph = $null
$script:CurrentFile = $null
$script:CurrentResults = @()
$script:Quiet = $false
$script:GlobalResults = [System.Collections.Generic.List[object]]::new()

function Get-RepoRoot {
    if ($script:RepoRoot) { return $script:RepoRoot }
    $r = git rev-parse --show-toplevel 2>$null
    if (-not $r -or $LASTEXITCODE -ne 0) {
        throw "Not in a git repository — harness requires repo context."
    }
    $script:RepoRoot = $r.TrimEnd('/', '\')
    return $script:RepoRoot
}

# ---------- Graph cache ----------

function Get-CachedGraph {
    if ($script:CachedGraph) { return $script:CachedGraph }
    $repoRoot = Get-RepoRoot
    $merged = Join-Path $repoRoot ".github/knowledge-graph/output/merged-graph.json"
    if (-not (Test-Path $merged)) {
        throw "Merged graph not found at $merged. Run merge.ps1 first."
    }
    $g = Get-Content $merged -Raw | ConvertFrom-Json
    # Build O(1) lookup index for assertions.
    $byId = @{}
    foreach ($n in $g.nodes) { $byId[$n.id] = $n }
    $script:CachedGraph = [pscustomobject]@{
        Nodes = $g.nodes
        Edges = $g.edges
        NodesById = $byId
    }
    return $script:CachedGraph
}

function Clear-GraphCache {
    $script:CachedGraph = $null
}

# ---------- Test scaffolding ----------

function Begin-TestFile {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter()][switch]$Quiet
    )
    $script:CurrentFile = $Name
    $script:CurrentResults = @()
    $script:Quiet = [bool]$Quiet
    if (-not $script:Quiet) {
        Write-Host ""
        Write-Host "=== $Name ===" -ForegroundColor Cyan
    }
}

function Test-Case {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)][string]$Name,
        [Parameter(Mandatory, Position=1)][scriptblock]$Body
    )
    $passed = $false
    $errMsg = $null
    $startMs = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        & $Body
        $passed = $true
    } catch {
        $errMsg = $_.Exception.Message
    }
    $startMs.Stop()
    $result = [pscustomobject]@{
        File = $script:CurrentFile
        Name = $Name
        Passed = $passed
        ErrorMessage = $errMsg
        DurationMs = $startMs.ElapsedMilliseconds
    }
    $script:CurrentResults += $result
    $script:GlobalResults.Add($result)
    if (-not $script:Quiet) {
        if ($passed) {
            Write-Host ("  PASS  {0,-60} {1,5}ms" -f $Name, $startMs.ElapsedMilliseconds) -ForegroundColor Green
        } else {
            Write-Host ("  FAIL  {0,-60} {1,5}ms" -f $Name, $startMs.ElapsedMilliseconds) -ForegroundColor Red
            Write-Host "        $errMsg" -ForegroundColor DarkRed
        }
    }
}

function End-TestFile {
    $passed = @($script:CurrentResults | Where-Object { $_.Passed }).Count
    $failed = @($script:CurrentResults | Where-Object { -not $_.Passed }).Count
    if (-not $script:Quiet) {
        $color = if ($failed -gt 0) { 'Red' } else { 'Green' }
        Write-Host ("  {0} pass, {1} fail" -f $passed, $failed) -ForegroundColor $color
    }
    # Exit code: 1 if any case failed. The runner reads global results either way.
    if ($failed -gt 0) {
        # Don't exit — the runner will aggregate. But signal via $LASTEXITCODE-ish.
        # When a test file is run standalone, the implicit exit reflects pass/fail.
        $global:LASTEXITCODE = 1
    } else {
        $global:LASTEXITCODE = 0
    }
}

function Get-GlobalTestResults {
    return $script:GlobalResults.ToArray()
}

# ---------- Assertions ----------

function Assert-True {
    param(
        [Parameter(Mandatory, Position=0)]$Condition,
        [Parameter(Position=1)][string]$Message = 'expected true, got false'
    )
    if (-not [bool]$Condition) { throw $Message }
}

function Assert-Equal {
    param(
        [Parameter(Mandatory, Position=0)]$Expected,
        [Parameter(Mandatory, Position=1)]$Actual,
        [Parameter(Position=2)][string]$Message = $null
    )
    if ($Expected -ne $Actual) {
        $msg = if ($Message) { "$Message; expected '$Expected', got '$Actual'" } else { "expected '$Expected', got '$Actual'" }
        throw $msg
    }
}

function Assert-NodeExists {
    param([Parameter(Mandatory)][string]$Id)
    $g = Get-CachedGraph
    if (-not $g.NodesById.ContainsKey($Id)) {
        throw "node not in graph: $Id"
    }
}

function Assert-NodeNotExists {
    param([Parameter(Mandatory)][string]$Id)
    $g = Get-CachedGraph
    if ($g.NodesById.ContainsKey($Id)) {
        throw "node should not exist but does: $Id"
    }
}

function Assert-EdgeExists {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Type,
        [Parameter(Mandatory)][string]$Target
    )
    $g = Get-CachedGraph
    $hit = @($g.Edges | Where-Object {
        $_.source -eq $Source -and $_.type -eq $Type -and $_.target -eq $Target
    })
    if ($hit.Count -eq 0) {
        throw "edge not found: $Source --[$Type]--> $Target"
    }
}

function Assert-AuditRateAtLeast {
    param([Parameter(Mandatory)][double]$MinPercent)
    $repoRoot = Get-RepoRoot
    $auditScript = Join-Path $repoRoot ".github/knowledge-graph/cli/audit/audit-edge-claims.ps1"
    if (-not (Test-Path $auditScript)) { throw "audit script missing: $auditScript" }
    $json = & pwsh -NoProfile -File $auditScript -Json 2>$null | Out-String
    $audit = $json | ConvertFrom-Json
    if ($audit.verification_rate -lt $MinPercent) {
        throw "audit rate $($audit.verification_rate)% is below required $MinPercent%"
    }
}

function Assert-NoIslands {
    $repoRoot = Get-RepoRoot
    $healthScript = Join-Path $repoRoot ".github/knowledge-graph/build/core/health.ps1"
    $out = & pwsh -NoProfile -File $healthScript -Layer merged 2>&1 | Out-String
    if ($out -match '\[WARN\]\s+islands\s+\((\d+)\)' -and [int]$matches[1] -gt 0) {
        throw "graph has $($matches[1]) island(s) — disconnected components"
    }
}

function Assert-NoDanglingEdges {
    $g = Get-CachedGraph
    $dangling = @()
    foreach ($e in $g.Edges) {
        if (-not $g.NodesById.ContainsKey($e.source)) {
            $dangling += "missing source: $($e.source) (edge $($e.source) -> $($e.target))"
        }
        if (-not $g.NodesById.ContainsKey($e.target)) {
            $dangling += "missing target: $($e.target) (edge $($e.source) -> $($e.target))"
        }
    }
    if ($dangling.Count -gt 0) {
        throw "graph has $($dangling.Count) dangling edge endpoint(s); first: $($dangling[0])"
    }
}

function Assert-FileResolves {
    param([Parameter(Mandatory)][string]$Path)
    $repoRoot = Get-RepoRoot
    $abs = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $repoRoot $Path }
    if (-not (Test-Path $abs)) {
        throw "file does not resolve on disk: $Path"
    }
}

function Assert-ScriptExitCode {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string[]]$Arguments = @(),
        [Parameter(Mandatory)][int]$Expected
    )
    $repoRoot = Get-RepoRoot
    $abs = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $repoRoot $Path }
    if (-not (Test-Path $abs)) { throw "script not found: $Path" }
    & pwsh -NoProfile -File $abs @Arguments *>$null
    $actual = $LASTEXITCODE
    if ($actual -ne $Expected) {
        throw "exit code: expected $Expected, got $actual"
    }
}

function Assert-OutputContains {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string[]]$Arguments = @(),
        [Parameter(Mandatory)][string]$Pattern,
        [int]$ExpectedExit = -1
    )
    $repoRoot = Get-RepoRoot
    $abs = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $repoRoot $Path }
    if (-not (Test-Path $abs)) { throw "script not found: $Path" }
    $out = & pwsh -NoProfile -File $abs @Arguments 2>&1 | Out-String
    $actualExit = $LASTEXITCODE
    if ($ExpectedExit -ge 0 -and $actualExit -ne $ExpectedExit) {
        throw "exit code: expected $ExpectedExit, got $actualExit; output:`n$out"
    }
    if ($out -notmatch [regex]::Escape($Pattern)) {
        throw "output did not match pattern '$Pattern'; got:`n$out"
    }
}

Export-ModuleMember -Function Get-RepoRoot, Get-CachedGraph, Clear-GraphCache,
    Begin-TestFile, Test-Case, End-TestFile, Get-GlobalTestResults,
    Assert-True, Assert-Equal,
    Assert-NodeExists, Assert-NodeNotExists, Assert-EdgeExists,
    Assert-AuditRateAtLeast, Assert-NoIslands, Assert-NoDanglingEdges,
    Assert-FileResolves, Assert-ScriptExitCode, Assert-OutputContains
