#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
Propose canonical analogy:* nodes for frequently minted military-to-software analogies.

.DESCRIPTION
Stub. Reads pending mints from .github/knowledge-graph/data/analogy-pending.jsonl
(written by behavior:19-mint-analogy-on-demand when a learner is introduced to a
concept and no analogy:* node exists for their role-tag). For any (role_tag, concept)
pair that appears 2+ times across distinct learners, prints a JSON node draft ready
to paste into mentor-graph.json under the references-and-analogies cluster.

Mirrors cli-tool:propose-concept (Gap 1). Full implementation lands once analogy-pending
accumulates real data from production sessions.

.NOTES
This file exists as a stub so the graph node cli-tool:propose-analogy resolves to a
real path during graph health checks. Behavior:19 logs mints today; this script
promotes them in a future commit.
#>

[CmdletBinding()]
param(
    [int] $MinMentions = 2
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..')
$pendingPath = Join-Path $repoRoot '.github/knowledge-graph/data/analogy-pending.jsonl'

Write-Host "propose-analogy.ps1 (stub)" -ForegroundColor Cyan
Write-Host "  Pending mints log: $pendingPath"
Write-Host "  Min mentions per (role_tag, concept): $MinMentions"
Write-Host ""
Write-Host "Not yet implemented. Behavior:19-mint-analogy-on-demand logs accepted analogies;"
Write-Host "this script will read them, dedupe by (role_tag, concept), and emit promotion-ready"
Write-Host "analogy:<role-tag>-<concept> node JSON for review via PR."
Write-Host "See cli-tool:propose-concept for the canonical promotion pattern."
exit 0
