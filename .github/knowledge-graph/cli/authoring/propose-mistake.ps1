#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
Propose canonical mistake:* nodes for frequently minted recurring learner mistakes.

.DESCRIPTION
Stub. Reads pending mints from .github/knowledge-graph/data/mistake-pending.jsonl
(written by behavior:18-log-mistake when a learner repeats a mistake and no
canonical mistake:* node exists in data:mistake-taxonomy). For any mistake-id
that appears 3+ times across distinct learners, prints a JSON node draft ready
to paste into mistake-taxonomy.json.

Mirrors cli-tool:propose-concept (Gap 1) and cli-tool:propose-analogy (Gap 4).
Full implementation lands once mistake-pending accumulates real data from
production sessions.

.NOTES
This file exists as a stub so the graph node cli-tool:propose-mistake resolves
to a real path during graph health checks. Behavior:18 logs mints today; this
script promotes them in a future commit.
#>

[CmdletBinding()]
param(
    [int] $MinMentions = 3
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' '..')
$pendingPath = Join-Path $repoRoot '.github/knowledge-graph/data/mistake-pending.jsonl'
$taxonomyPath = Join-Path $repoRoot '.github/knowledge-graph/data/mistake-taxonomy.json'

Write-Host "propose-mistake.ps1 (stub)" -ForegroundColor Cyan
Write-Host "  Pending mints log: $pendingPath"
Write-Host "  Canonical taxonomy: $taxonomyPath"
Write-Host "  Min distinct learners per mistake-id: $MinMentions"
Write-Host ""
Write-Host "Not yet implemented. Behavior:18-log-mistake will log accepted mints;"
Write-Host "this script will read them, dedupe by mistake-id across distinct learners,"
Write-Host "and emit promotion-ready entries for the mistakes[] array in"
Write-Host "data/mistake-taxonomy.json for review via PR."
Write-Host "See cli-tool:propose-concept and cli-tool:propose-analogy for the canonical"
Write-Host "promotion pattern."
exit 0
