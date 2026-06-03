#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
Propose canonical concept:* nodes for frequently minted concept slugs.

.DESCRIPTION
Stub. Reads pending mints from .github/knowledge-graph/data/concept-mints.jsonl
(written by behavior:15-track-concept-proficiency when a concept is not in the
registry). For any slug that appears 3+ times across distinct learners, prints a
JSON node draft ready to paste into mentor-graph.json under the concept-proficiency
cluster.

Full implementation lands alongside Gap 4 (propose-analogy.ps1) so both promotion
flows share validation, dedupe, and PR-draft generation.

.NOTES
This file exists as a stub so the graph node cli-tool:propose-concept resolves to a
real path during graph health checks. Behavior:15 logs mints today; this script
promotes them in a future commit.
#>

[CmdletBinding()]
param(
    [int] $MinMentions = 3
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..')
$mintsPath = Join-Path $repoRoot '.github/knowledge-graph/data/concept-mints.jsonl'

Write-Host "propose-concept.ps1 (stub)" -ForegroundColor Cyan
Write-Host "  Mints log: $mintsPath"
Write-Host "  Min mentions: $MinMentions"
Write-Host ""
Write-Host "Not yet implemented. Behavior:15-track-concept-proficiency logs minted slugs;"
Write-Host "this script will read them, dedupe, and emit promotion-ready concept:* node JSON."
Write-Host "See Gap 4 (propose-analogy.ps1) for the canonical promotion pattern."
exit 0
