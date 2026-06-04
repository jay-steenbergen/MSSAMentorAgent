#!/usr/bin/env pwsh
# kg.ps1 — Knowledge Graph dispatcher
#
# Single entry point for every script under .github/knowledge-graph/cli/.
# Routes verbs to scripts in inspect/, authoring/, audit/, validate/, session/.
#
# Examples:
#   kg query agent:mentor -Edges
#   kg behavior teaching-loop
#   kg impact skill:learner-profile
#   kg add skill bug-triage -Description "..."
#   kg link agent:mentor skill:bug-triage composes
#   kg propose concept "what-is-a-fn"
#   kg audit
#   kg audit -Category orphan
#   kg find drift
#   kg find missing
#   kg find orphans
#   kg validate events
#   kg validate goal
#   kg validate loadlist
#   kg enforce method
#   kg enforce track
#   kg preflight
#   kg help

param()

# Take verb + remaining args from $args manually so the dispatcher does not
# interfere with each script's own param() block.
$Verb = if ($args.Count -gt 0) { [string]$args[0] } else { '' }
$Rest = if ($args.Count -gt 1) { $args[1..($args.Count - 1)] } else { @() }

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

function Show-Usage {
    Write-Host @"
kg.ps1 — Knowledge Graph dispatcher

USAGE: kg <verb> [args]

INSPECT
  query <id> [-ShowEdges]            inspect a node
  behavior <name>                    expand a behavior to its requires
  impact <skill-id>                  show what depends on a skill
  progress                           render learner progress from events
  profile                            render learner profile from events
  analyze <agent-id>                 size + composition of an agent
  recommend                          recommend next skills to build

AUTHORING (mentor.ps1)
  add <type> <slug> [...]            add node + scaffold stub
  link <src> <dst> <edge>            add edge
  unlink <src> <dst> <edge>          remove edge
  remove <node-id>                   remove node + all edges
  types                              list edge-type vocabulary
  session-status <session-id>        render session outcome from graph
  validate                           rebuild + drift report
  propose <concept|analogy|mistake>  queue a new concept / analogy / mistake
  check <skill-name>                 check if a skill exists

AUDIT
  audit [-Category X]                run all quality checks
  find drift                         find graph<->disk drift
  find missing                       find missing files referenced by graph
  find orphans                       find markdown not referenced by graph

TEST (behavioral *.test.md specs)
  test list [-State fresh|stale|never-run|all]
  test run <slug>                    interactive: copy prompt, prompt for result
  test record <slug> -Result <PASS|PARTIAL|FAIL> -Notes "..." [-Evidence "..."]

VALIDATE
  validate events                    validate events.jsonl streams
  validate goal                      validate a goal node
  validate loadlist                  test load-list against goldens
  enforce method                     enforce method conventions
  enforce track                      enforce track conventions
  preflight                          pre-commit preflight check

HELP
  help | -h | --help                 this message

For verb-specific help: kg <verb> -?  (where supported)
"@
}

function Invoke-Script {
    param([string]$RelativePath, [object[]]$ScriptArgs)
    $path = Join-Path $here $RelativePath
    if (-not (Test-Path $path)) {
        Write-Host "kg: script not found: $RelativePath" -ForegroundColor Red
        exit 2
    }
    & $path @ScriptArgs
    exit $LASTEXITCODE
}

if (-not $Verb -or $Verb -in @('help', '-h', '--help', '-help', '/?')) {
    Show-Usage
    exit 0
}

# Alias for readability; $Rest is already an array (possibly empty).
$rest = @($Rest)

switch -Regex ($Verb) {

    # INSPECT ------------------------------------------------------
    '^query$'      { Invoke-Script 'inspect/query-node.ps1'           $rest }
    '^behavior$'   { Invoke-Script 'inspect/get-behavior.ps1'         $rest }
    '^impact$'     { Invoke-Script 'inspect/show-skill-impact.ps1'    $rest }
    '^progress$'   { Invoke-Script 'inspect/show-progress.ps1'        $rest }
    '^profile$'    { Invoke-Script 'inspect/show-profile.ps1'         $rest }
    '^analyze$'    { Invoke-Script 'inspect/analyze-agent-size.ps1'   $rest }
    '^recommend$'  { Invoke-Script 'inspect/recommend-next-skills.ps1' $rest }

    # AUTHORING ----------------------------------------------------
    '^(add|link|unlink|remove|types|session-status)$' {
        # mentor.ps1 takes the verb as its first positional arg.
        Invoke-Script 'authoring/mentor.ps1' (@($Verb) + $rest)
    }
    '^propose$' {
        $kind = $rest[0]
        $tail = @()
        if ($rest.Count -gt 1) { $tail = $rest[1..($rest.Count - 1)] }
        switch ($kind) {
            'concept' { Invoke-Script 'authoring/propose-concept.ps1' $tail }
            'analogy' { Invoke-Script 'authoring/propose-analogy.ps1' $tail }
            'mistake' { Invoke-Script 'authoring/propose-mistake.ps1' $tail }
            default {
                Write-Host "kg propose: unknown kind '$kind' (want: concept | analogy | mistake)" -ForegroundColor Red
                exit 2
            }
        }
    }
    '^check$' { Invoke-Script 'authoring/check-skill-exists.ps1' $rest }

    # AUDIT --------------------------------------------------------
    '^audit$' { Invoke-Script 'audit/audit-quality.ps1' $rest }
    '^find$' {
        $what = $rest[0]
        $tail = @()
        if ($rest.Count -gt 1) { $tail = $rest[1..($rest.Count - 1)] }
        switch ($what) {
            'drift'   { Invoke-Script 'audit/find-drift.ps1'           $tail }
            'missing' { Invoke-Script 'audit/find-missing-files.ps1'   $tail }
            'orphans' { Invoke-Script 'audit/find-orphan-markdown.ps1' $tail }
            default {
                Write-Host "kg find: unknown target '$what' (want: drift | missing | orphans)" -ForegroundColor Red
                exit 2
            }
        }
    }

    # VALIDATE -----------------------------------------------------
    '^validate$' {
        if (-not $rest -or $rest.Count -eq 0) {
            # bare 'validate' = mentor.ps1 validate (rebuild + drift)
            Invoke-Script 'authoring/mentor.ps1' @('validate')
        }
        $what = $rest[0]
        $tail = @()
        if ($rest.Count -gt 1) { $tail = $rest[1..($rest.Count - 1)] }
        switch ($what) {
            'events'   { Invoke-Script 'validate/validate-events.ps1' $tail }
            'goal'     { Invoke-Script 'validate/validate-goal.ps1'   $tail }
            'loadlist' { Invoke-Script 'validate/test-load-list.ps1'  $tail }
            default {
                Write-Host "kg validate: unknown target '$what' (want: events | goal | loadlist)" -ForegroundColor Red
                exit 2
            }
        }
    }
    '^enforce$' {
        $what = $rest[0]
        $tail = @()
        if ($rest.Count -gt 1) { $tail = $rest[1..($rest.Count - 1)] }
        switch ($what) {
            'method' { Invoke-Script 'validate/enforce-method.ps1' $tail }
            'track'  { Invoke-Script 'validate/enforce-track.ps1'  $tail }
            default {
                Write-Host "kg enforce: unknown target '$what' (want: method | track)" -ForegroundColor Red
                exit 2
            }
        }
    }
    '^preflight$' { Invoke-Script 'validate/preflight.ps1' $rest }

    # TEST (behavioral specs) --------------------------------------
    '^test$' { Invoke-Script 'session/test-runner.ps1' $rest }

    # FALLBACK -----------------------------------------------------
    default {
        Write-Host "kg: unknown verb '$Verb'" -ForegroundColor Red
        Write-Host ""
        Show-Usage
        exit 2
    }
}
