#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
Derive a per-node confidence score for the knowledge graph: high | medium | low. Combines extraction provenance, edge-audit results, and test coverage into a single visibility metric.

.DESCRIPTION
Why this exists:
  On 2026-06-05 we measured that ~46% of behavioral edges have textual
  evidence in source. That tells us the AGGREGATE trust level. It does NOT
  tell us, for any one node we're about to depend on, whether we can trust
  the graph's description of it.

  This tool answers "can I trust this node?" by combining three signals
  into a tier:

  Signals (per node):
    A. PROVENANCE     — auto-extracted from code, hand-authored, or migrated
                        (auto-extracted = inherits code-fidelity; hand-authored
                         = depends on the author having been careful)
    B. EDGE EVIDENCE  — fraction of this node's outgoing claim-edges that
                        have textual evidence (from audit-edge-claims)
    C. TEST COVERAGE  — does any [tests] edge target this node?
                        (executable verification > textual evidence)

  Tier assignment:
    HIGH   — auto-extracted AND has test coverage, OR
             hand-authored AND ALL outgoing claim-edges verified AND has test coverage
    MEDIUM — auto-extracted AND no test, OR
             hand-authored AND most claim-edges verified
    LOW    — hand-authored AND most claim-edges unverified, OR
             orphan node, OR
             explicit `confidence: low` annotation

  These tiers are heuristics, not measurements. They are useful as a
  visibility lens (what should we go fix first?) not as guarantees.

How to use the output:
  - Default report: shows distribution + lists every LOW node so you can
    triage.
  - With -Json: emits structured data for downstream tooling.
  - With -NodeId X: shows the confidence signal trail for one specific node.
  - In blast-radius (future): can color-code nodes by confidence.

.PARAMETER NodeId
Optional. Show signal trail for one specific node id.

.PARAMETER Tier
Optional. Filter to one tier (high|medium|low).

.PARAMETER Json
Emit structured JSON.

.PARAMETER Quiet
Print summary only (one line).

.PARAMETER SkipAudit
Skip the edge-claim audit pass. Faster, but treats edge-evidence as unknown.
Useful when you only care about provenance + test coverage.

.EXAMPLE
pwsh .github/knowledge-graph/cli/inspect/show-confidence.ps1
pwsh .github/knowledge-graph/cli/inspect/show-confidence.ps1 -Tier low
pwsh .github/knowledge-graph/cli/inspect/show-confidence.ps1 -NodeId agent:mentor
pwsh .github/knowledge-graph/cli/inspect/show-confidence.ps1 -Json -Quiet

.OUTPUTS
Exit 0 always. Confidence is informational, not a gate.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$NodeId,

    [Parameter()]
    [ValidateSet('high', 'medium', 'low')]
    [string]$Tier,

    [Parameter()]
    [switch]$Json,

    [Parameter()]
    [switch]$Quiet,

    [Parameter()]
    [switch]$SkipAudit
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot -or $LASTEXITCODE -ne 0) {
    Write-Host "Not in a git repository." -ForegroundColor Red
    exit 2
}
$repoRoot = $repoRoot.TrimEnd('/', '\')

$mergedFile = Join-Path $repoRoot ".github/knowledge-graph/output/merged-graph.json"
if (-not (Test-Path $mergedFile)) {
    Write-Host "Merged graph not found." -ForegroundColor Red
    exit 2
}

$graph = Get-Content $mergedFile -Raw | ConvertFrom-Json

# Index nodes.
$nodesById = @{}
foreach ($n in $graph.nodes) { $nodesById[$n.id] = $n }

# Run the audit (or load cached if -SkipAudit).
$unverifiedEdges = @{}  # key: "source|type|target" -> $true
if (-not $SkipAudit) {
    $auditScript = Join-Path $repoRoot '.github/knowledge-graph/cli/audit/audit-edge-claims.ps1'
    if (Test-Path $auditScript) {
        $auditJson = & pwsh -NoProfile -File $auditScript -Json 2>$null | Out-String
        try {
            $audit = $auditJson | ConvertFrom-Json
            foreach ($u in $audit.unverified) {
                $key = "$($u.source)|$($u.edge_type)|$($u.target)"
                $unverifiedEdges[$key] = $true
            }
        } catch {
            Write-Host "Could not parse audit output; continuing without edge-evidence signal." -ForegroundColor Yellow
        }
    }
}

# Provenance classifier.
# Auto-extracted node types come from extract-code-graph.ps1: code-file, code-func,
# code-import, code-yaml-field, code-section, code-test.
$autoExtractedPrefixes = @('code-file:', 'code-func:', 'code-import:', 'code-yaml-field:', 'code-section:', 'code-test:')
function Get-Provenance {
    param([string]$Id)
    foreach ($p in $autoExtractedPrefixes) {
        if ($Id.StartsWith($p)) { return 'auto-extracted' }
    }
    return 'hand-authored'
}

# Test-coverage check.
$testedNodes = [System.Collections.Generic.HashSet[string]]::new()
foreach ($e in $graph.edges) {
    if ($e.type -eq 'tests') {
        [void]$testedNodes.Add($e.target)
    }
}

# Per-node outgoing claim edges (the ones the audit looks at).
$claimEdgeTypes = @('follows', 'tests', 'implemented_by', 'uses')
$outgoingClaims = @{}
foreach ($e in $graph.edges) {
    if ($claimEdgeTypes -notcontains $e.type) { continue }
    if (-not $outgoingClaims.ContainsKey($e.source)) {
        $outgoingClaims[$e.source] = [System.Collections.Generic.List[object]]::new()
    }
    $outgoingClaims[$e.source].Add($e)
}

function Get-NodeConfidence {
    param($Node)

    $provenance = Get-Provenance -Id $Node.id
    $hasTest = $testedNodes.Contains($Node.id)

    # Compute edge-verification rate for this node's outgoing claims.
    $totalClaims = 0
    $verifiedClaims = 0
    if ($outgoingClaims.ContainsKey($Node.id)) {
        foreach ($e in $outgoingClaims[$Node.id]) {
            $totalClaims++
            $key = "$($e.source)|$($e.type)|$($e.target)"
            if (-not $unverifiedEdges.ContainsKey($key)) {
                $verifiedClaims++
            }
        }
    }
    $edgeRate = if ($totalClaims -gt 0) { $verifiedClaims / $totalClaims } else { $null }

    # Tier assignment.
    $tier = 'medium'
    $reasons = [System.Collections.Generic.List[string]]::new()

    if ($Node.PSObject.Properties.Name -contains 'confidence' -and $Node.confidence) {
        # Explicit annotation wins.
        $tier = $Node.confidence
        $reasons.Add("explicit annotation: $($Node.confidence)")
    } elseif ($provenance -eq 'auto-extracted') {
        if ($hasTest) {
            $tier = 'high'
            $reasons.Add('auto-extracted from source')
            $reasons.Add('has test coverage')
        } else {
            $tier = 'medium'
            $reasons.Add('auto-extracted from source')
            $reasons.Add('no test coverage')
        }
    } else {
        # Hand-authored.
        if ($null -ne $edgeRate -and $edgeRate -ge 0.8 -and $hasTest) {
            $tier = 'high'
            $reasons.Add('hand-authored')
            $reasons.Add("$($verifiedClaims)/$totalClaims claim-edges verified")
            $reasons.Add('has test coverage')
        } elseif ($null -ne $edgeRate -and $edgeRate -ge 0.5) {
            $tier = 'medium'
            $reasons.Add('hand-authored')
            $reasons.Add("$($verifiedClaims)/$totalClaims claim-edges verified")
            if (-not $hasTest) { $reasons.Add('no test coverage') }
        } elseif ($totalClaims -eq 0) {
            # Hand-authored with no outgoing claims — descriptive node (purpose, audience, etc.)
            $tier = 'medium'
            $reasons.Add('hand-authored descriptive node (no outgoing claims to verify)')
            if (-not $hasTest) { $reasons.Add('no test coverage') }
        } else {
            $tier = 'low'
            $reasons.Add('hand-authored')
            $reasons.Add("only $($verifiedClaims)/$totalClaims claim-edges verified")
            if (-not $hasTest) { $reasons.Add('no test coverage') }
        }
    }

    return [pscustomobject]@{
        Id            = $Node.id
        Type          = $Node.type
        Label         = if ($Node.PSObject.Properties.Name -contains 'label') { $Node.label } else { $Node.id }
        Provenance    = $provenance
        HasTest       = $hasTest
        TotalClaims   = $totalClaims
        VerifiedClaims = $verifiedClaims
        EdgeRate      = $edgeRate
        Tier          = $tier
        Reasons       = $reasons -join '; '
    }
}

# Score every node (or one).
$scored = [System.Collections.Generic.List[object]]::new()
if ($NodeId) {
    $node = $nodesById[$NodeId]
    if (-not $node) {
        Write-Host "Node not found: $NodeId" -ForegroundColor Red
        exit 1
    }
    $scored.Add((Get-NodeConfidence -Node $node))
} else {
    foreach ($n in $graph.nodes) {
        $scored.Add((Get-NodeConfidence -Node $n))
    }
}

if ($Tier) {
    $scored = $scored | Where-Object { $_.Tier -eq $Tier }
}

# Summary stats.
$total = $scored.Count
$highCount = @($scored | Where-Object { $_.Tier -eq 'high' }).Count
$medCount  = @($scored | Where-Object { $_.Tier -eq 'medium' }).Count
$lowCount  = @($scored | Where-Object { $_.Tier -eq 'low' }).Count

if ($Json) {
    [pscustomobject]@{
        total = $total
        high = $highCount
        medium = $medCount
        low = $lowCount
        nodes = $scored
    } | ConvertTo-Json -Depth 5
    exit 0
}

if ($Quiet) {
    Write-Host "Confidence: HIGH $highCount | MEDIUM $medCount | LOW $lowCount (of $total nodes)"
    exit 0
}

if ($NodeId) {
    $r = $scored[0]
    Write-Host ""
    Write-Host "=== Confidence: $($r.Id) ===" -ForegroundColor Cyan
    Write-Host "Label      : $($r.Label)"
    Write-Host "Type       : $($r.Type)"
    Write-Host "Tier       : $($r.Tier)" -ForegroundColor $(switch ($r.Tier) { 'high' { 'Green' } 'medium' { 'Yellow' } 'low' { 'Red' } })
    Write-Host "Provenance : $($r.Provenance)"
    Write-Host "Has test   : $($r.HasTest)"
    if ($null -ne $r.EdgeRate) {
        $pct = [math]::Round($r.EdgeRate * 100, 1)
        Write-Host "Claim edges: $($r.VerifiedClaims) / $($r.TotalClaims) verified ($pct%)"
    } else {
        Write-Host "Claim edges: 0 (no outgoing claim edges)"
    }
    Write-Host ""
    Write-Host "Reasons    : $($r.Reasons)"
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Host "=== Graph Confidence Distribution ===" -ForegroundColor Cyan
$highPct = if ($total -gt 0) { [math]::Round(100.0 * $highCount / $total, 1) } else { 0 }
$medPct  = if ($total -gt 0) { [math]::Round(100.0 * $medCount / $total, 1) } else { 0 }
$lowPct  = if ($total -gt 0) { [math]::Round(100.0 * $lowCount / $total, 1) } else { 0 }
Write-Host "HIGH   : $highCount ($highPct%)" -ForegroundColor Green
Write-Host "MEDIUM : $medCount ($medPct%)" -ForegroundColor Yellow
Write-Host "LOW    : $lowCount ($lowPct%)" -ForegroundColor Red
Write-Host "Total  : $total"
Write-Host ""

if ($lowCount -gt 0) {
    Write-Host "LOW-confidence nodes (top 30):" -ForegroundColor Red
    $scored | Where-Object { $_.Tier -eq 'low' } | Select-Object -First 30 | ForEach-Object {
        Write-Host "  $($_.Id)" -ForegroundColor White
        Write-Host "    $($_.Reasons)" -ForegroundColor DarkGray
    }
    if ($lowCount -gt 30) {
        Write-Host "  ... and $($lowCount - 30) more. Use -Tier low -Json for full list." -ForegroundColor DarkGray
    }
    Write-Host ""
}

Write-Host "How to raise a node's confidence:" -ForegroundColor Cyan
Write-Host "  - Add a [tests] edge from a real test to the node."
Write-Host "  - Add textual evidence in source files for each outgoing claim-edge."
Write-Host "  - Set explicit ``confidence: high`` on the node if the heuristic underrates it."
Write-Host ""
exit 0
