#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
Validate a learner goal record before it is written to profile.goals.

.DESCRIPTION
Stub. Validates one goal record from profile.goals against the schema declared in
field:profile.goals graph nodes:
  - goal_id: matches ^goal:[a-z0-9-]+$
  - label: non-empty string
  - type: one of (concept-mastery, project-completion, method-fluency, time-bound-streak)
  - target: shape matches type (e.g. concept-mastery -> { tier, count })
  - deadline: ISO8601 date or null
  - status: one of (active, achieved, abandoned, paused)
  - related_concepts: each entry must be a real concept:* node (warn-only when minted)
  - related_projects: each entry must be a real project-id in profile.projects (warn-only)

Mirrors validate-profile.ps1 / validate-events.ps1 patterns. Full implementation
lands once behavior:21-elicit-goal starts persisting real goal records.

.NOTES
This file exists as a stub so the graph node cli-tool:validate-goal resolves to a
real path during graph health checks. Behavior:21 will call this in a future commit
once goal records are being written.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $GoalJsonPath
)

$ErrorActionPreference = 'Stop'

Write-Host "validate-goal.ps1 (stub)" -ForegroundColor Cyan
Write-Host "  Goal JSON path: $(if ($GoalJsonPath) { $GoalJsonPath } else { '(none provided)' })"
Write-Host ""
Write-Host "Not yet implemented. Behavior:21-elicit-goal will write goal records to"
Write-Host "profile.goals; this script will validate each record against the field schema"
Write-Host "before commit. See cli-tool:validate-profile for the canonical validator pattern."
exit 0
