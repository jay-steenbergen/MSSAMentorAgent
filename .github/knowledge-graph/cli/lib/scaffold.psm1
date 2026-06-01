# scaffold.psm1 — generate stub files for new graph nodes
#
# Public functions:
#   New-StubFile -Type <agent|skill|track|method|test> -Id <node-id> -Label <str> -Description <str>
#       Creates a stub file at the conventional path for that node type.
#       Returns a hashtable: @{ Path = '...'; Existed = $true/$false }
#
# Layout conventions (from copilot-instructions.md):
#   agent  -> .github/agents/{Name}.agent.md
#   skill  -> .github/skills/{name}/SKILL.md
#   method -> .github/skills/methods/{name}/SKILL.md
#   track  -> .github/skills/tracks/{name}/SKILL.md
#   test   -> .github/tests/{name}.test.md
#
# All stubs include the `_TODO: ask Mentor to help write this._` marker so the
# Mentor agent's stub-completion mode can find them.

$script:RepoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path

function _Slug-FromId {
    param([string]$Id)
    # Strip 'type:' prefix if present.
    if ($Id -match '^[^:]+:(.+)$') { return $matches[1] }
    return $Id
}

function _Stub-Path {
    param(
        [Parameter(Mandatory)][ValidateSet('agent','skill','method','track','test')][string]$Type,
        [Parameter(Mandatory)][string]$Id,
        [string]$Label
    )
    $slug = _Slug-FromId $Id
    switch ($Type) {
        'agent'  { return ".github/agents/$($Label).agent.md" }
        'skill'  { return ".github/skills/$slug/SKILL.md" }
        'method' { return ".github/skills/methods/$slug/SKILL.md" }
        'track'  { return ".github/skills/tracks/$slug/SKILL.md" }
        'test'   { return ".github/tests/$slug.test.md" }
    }
}

function _Stub-Body {
    param(
        [Parameter(Mandatory)][string]$Type,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$Description
    )
    $todo = "_TODO: ask Mentor to help write this._"
    switch ($Type) {
        'agent' {
@"
---
description: "$Description"
name: "$Label"
core_behavior: |
  $todo
skills: []
---

# $Label

$todo
"@
        }
        'skill' {
@"
---
name: $(_Slug-FromId $Label)
description: "$Description"
---

# Skill: $Label

$todo

## When to use

$todo

## Protocol

$todo
"@
        }
        'method' {
@"
---
name: $(_Slug-FromId $Label)
description: "$Description"
---

# Method: $Label

$todo

## The contract

| The mentor does | The learner does |
|---|---|
| $todo | $todo |

## Session shape

$todo
"@
        }
        'track' {
@"
---
name: $(_Slug-FromId $Label)
description: "$Description"
---

# Track: $Label

$todo

## What you build

$todo

## Prerequisites

$todo
"@
        }
        'test' {
@"
# Test: $Label

**Description:** $Description

## Setup

$todo

## Scenario

$todo

## Expected behavior

$todo

## Pass criteria

$todo

## Actual result

_Not yet run._
"@
        }
    }
}

function New-StubFile {
    param(
        [Parameter(Mandatory)][ValidateSet('agent','skill','method','track','test')][string]$Type,
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Label,
        [string]$Description = '_TODO: describe this._'
    )
    $relPath = _Stub-Path -Type $Type -Id $Id -Label $Label
    $abs = Join-Path $script:RepoRoot $relPath
    $existed = Test-Path $abs
    if ($existed) {
        Write-Host "  ($relPath already exists, leaving it alone)" -ForegroundColor DarkGray
        return @{ Path = $relPath; Existed = $true }
    }
    $dir = Split-Path $abs -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $body = _Stub-Body -Type $Type -Label $Label -Description $Description
    Set-Content -Path $abs -Value $body -Encoding UTF8
    Write-Host "  scaffolded $relPath" -ForegroundColor DarkGreen
    @{ Path = $relPath; Existed = $false }
}

Export-ModuleMember -Function New-StubFile
