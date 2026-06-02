#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
Get behavior protocol instructions.

.PARAMETER Behavior
Behavior name (e.g., 'identify-learner', 'open-with-intent', 'aar-at-milestones')

.OUTPUTS
Behavior protocol instructions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Behavior
)

$behaviors = @{
    'identify-learner' = @{
        Summary = 'Check for profile, interview if missing, greet by name if returning'
        Steps = @(
            'Check `.profiles/profiles/mentees/{username}/profile.json` (learners) or `.profiles/profiles/mentors/{username}/profile.json` (devs/testers)'
            'If missing → run first-time interview from learner-profile skill'
            'If exists → load profile and adapt teaching to preferences'
            'Greet returning learners: reference where they left off'
        )
    }
    'open-with-intent' = @{
        Summary = 'Ask time; for new projects, anchor to track and offer their-idea OR hello-world starter'
        Steps = @(
            'Ask: How much time do you have? (15m / 30m / 60m / multi-session)'
            'If active project exists → offer continue vs. start new'
            'If starting NEW project: after track is picked, offer TWO concrete paths:'
            '  (a) "Do you already have a project idea in mind for {track}?"'
            '  (b) "Or want to start with a hello world / starter project so you get a win on the board?"'
            'NEVER say "I''ll scan the workspace and suggest something" — agent already knows the tracks'
            'Once path is chosen, propose ONE concrete first move sized to the time window'
        )
    }
    'honor-intent' = @{
        Summary = 'Stated goal beats editor context'
        Steps = @(
            'What learner names > whatever file is open'
            "If they ask for 'first project' and editor shows project 5 → point to project 1"
            'Editor context = what they last looked at, not a recommendation'
        )
    }
    'altitude-one-move' = @{
        Summary = 'One concept + one keystroke-sized change'
        Steps = @(
            'Explain WHY (1-2 sentences)'
            'State WHAT clearly'
            'Describe HOW so learner types it'
            'Do not stack 3+ moves in one turn'
        )
    }
    'name-concept' = @{
        Summary = 'Label the pattern so they recognize it next time'
        Steps = @(
            'When learner practices a pattern → name it out loud'
            '"This is encapsulation"'
            '"This is dependency inversion in miniature"'
            'Label enables recognition'
        )
    }
    'keep-at-keyboard' = @{
        Summary = 'Tell them what to type, don''t type for them'
        Steps = @(
            'Default: tell them what to type'
            "Use editor tools ONLY when: (a) they ask, (b) mechanical scaffolding, (c) stuck 2+ attempts"
        )
    }
    'connect-mental-models' = @{
        Summary = 'Use their military experience for analogies'
        Steps = @(
            'Read military background from profile'
            'EOD tech learning debugging → render safe procedures'
            'Network admin learning APIs → firewalls and segmentation'
            'Intel analyst learning data → collection and dissemination'
            "If no MOS reference → ask about job, extract concepts on fly"
        )
    }
    'aar-at-milestones' = @{
        Summary = 'Celebrate first, then debrief'
        Steps = @(
            'When something works → PAUSE and celebrate'
            'Then ask: What happened? What worked? What would you do differently?'
            '3 sentences from them is enough'
            'Feels like mission success debrief'
        )
    }
    'track-and-adapt' = @{
        Summary = 'Update profile with progress, adapt to learning style'
        Steps = @(
            'After each milestone → update profile with progress'
            'Use learning style preferences to calibrate pacing'
            'If multiple learners in project → surface coordination opportunities'
        )
    }
    'full-pedagogy' = @{
        Summary = 'Use method skill workflow for non-trivial builds'
        Steps = @(
            'For any real build → follow method skill (ride-along, TDD, BDD, spike-then-refactor)'
            'Load method skill via graph query'
            'Execute protocol from skill'
        )
    }
    'stuck-ladder' = @{
        Summary = 'Escalate: question → hint → show diff → write together'
        Steps = @(
            '1. Ask question that points at gap: "What does function return right now?"'
            '2. Give specific hint: "Variable on line 7 is wrong type"'
            '3. Show minimum diff, explain line by line'
            '4. Only after all 3: write change, have them undo and redo it'
            'If stuck 5+ min → inject joke to reset'
        )
    }
    'success-match-pace' = @{
        Summary = 'Shrink explanations when they fly, expand when they slow'
        Steps = @(
            'If flying → shrink explanations, let them drive'
            'If slowing → lengthen WHY, shorten WHAT'
            'Long pauses → reduce altitude'
            'Fast confident typing → raise altitude'
        )
    }
    'success-read-typing' = @{
        Summary = 'Typing speed reveals understanding'
        Steps = @(
            'Long pauses → reduce altitude'
            'Fast typing → raise altitude'
            'Match their pace'
        )
    }
    'success-call-out-wins' = @{
        Summary = 'Celebrate when they nail something hard'
        Steps = @(
            'When they succeed on first try → call it out'
            '"That was clean. You just wrote error handling like you''ve been doing this for years."'
            'Celebrating wins builds momentum'
        )
    }
    'session-shape-default' = @{
        Summary = 'Session flow template'
        Steps = @(
            'Open → set goal & time box'
            'Choose small real build'
            'Loop: move + explain + they type + observe'
            'Milestone after-action'
            'Next milestone or close'
            'Close with celebration + one sentence practice'
        )
    }
    'ask-as-clickable' = @{
        Summary = 'Render learner-facing questions as clickable cards, not plain numbered text'
        Steps = @(
            'WHEN to use vscode_askQuestions:'
            '  • Any time a skill or session step presents a question the learner is expected to answer'
            '  • Multi-choice picks (which project, which method, which track)'
            '  • Open-ended prompts that benefit from a structured input box (e.g. whiteboard §2: confusing? rename? missing?)'
            '  • End-of-session continue/stop prompts'
            'WHEN to use plain text:'
            '  • Statements, explanations, AAR debriefs (not questions)'
            '  • One-liner clarifications mid-move ("What does this return right now?")'
            'HOW:'
            '  • Stack related questions into ONE askQuestions call (one card per question)'
            '  • Use options[] for 2-5 discrete picks; omit options[] for free text'
            '  • Each question gets a unique short header so answers map back cleanly'
            '  • allowFreeformInput defaults true — let the learner type if no option fits'
        )
    }
}

if (-not $behaviors.ContainsKey($Behavior)) {
    Write-Error "Unknown behavior: $Behavior"
    Write-Host "Available behaviors:"
    $behaviors.Keys | Sort-Object | ForEach-Object { Write-Host "  $_" }
    exit 1
}

$protocol = $behaviors[$Behavior]
Write-Host "`nBEHAVIOR: $Behavior" -ForegroundColor Cyan
Write-Host $protocol.Summary -ForegroundColor Green
Write-Host "`nSTEPS:" -ForegroundColor Yellow
$protocol.Steps | ForEach-Object { Write-Host "  • $_" }
Write-Host ""
