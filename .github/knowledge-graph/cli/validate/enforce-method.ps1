#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
Enforce teaching method discipline.

.PARAMETER Method
Teaching method: TDD, BDD, spike-then-refactor, or ride-along

.PARAMETER Action
What the learner is trying to do (e.g., "write-implementation", "write-test", "refactor")

.PARAMETER Context
Additional context about current state (e.g., test status, phase)

.OUTPUTS
Object with: Result (STOP/CONTINUE), Violation (rule violated), Message (what to say)
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('TDD', 'BDD', 'spike-then-refactor', 'ride-along')]
    [string]$Method,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet('write-implementation', 'write-test', 'write-scenario', 'refactor', 
                 'spike', 'evaluate', 'rebuild', 'explain-multiple', 'type-for-learner',
                 'skip-concept-name', 'skip-aar', 'commit-spike')]
    [string]$Action,
    
    [Parameter()]
    [hashtable]$Context = @{}
)

$ErrorActionPreference = 'Stop'

# Method enforcement rules
$rules = @{
    TDD = @{
        'write-implementation' = @{
            Check = { -not $Context.ContainsKey('HasFailingTest') -or -not $Context.HasFailingTest }
            Violation = 'RED BEFORE GREEN'
            Message = 'Test first. What behavior are we proving?'
            Stop = $true
        }
        'write-test' = @{
            Check = { $Context.ContainsKey('ExistingTests') -and $Context.ExistingTests -gt 0 -and $Context.ContainsKey('PassingTests') -and $Context.PassingTests -lt $Context.ExistingTests }
            Violation = 'ONE FAILING TEST AT A TIME'
            Message = 'Pick one test. Make it pass. Then write the next.'
            Stop = $true
        }
        'refactor' = @{
            Check = { $Context.ContainsKey('TestStatus') -and $Context.TestStatus -ne 'green' }
            Violation = 'REFACTOR WITH SAFETY NET'
            Message = 'Red means stop. Make it green first.'
            Stop = $true
        }
    }
    BDD = @{
        'write-test' = @{
            Check = { -not $Context.ContainsKey('HasScenario') -or -not $Context.HasScenario }
            Violation = 'SCENARIO BEFORE TEST'
            Message = "What's the user scenario we're implementing? Given/When/Then first."
            Stop = $true
        }
        'write-scenario' = @{
            Check = { $Context.ContainsKey('UsedTechnicalTerms') -and $Context.UsedTechnicalTerms }
            Violation = 'USER-FACING LANGUAGE ONLY'
            Message = 'How would the user describe this in their words?'
            Stop = $true
        }
    }
    'spike-then-refactor' = @{
        'spike' = @{
            Check = { -not $Context.ContainsKey('TimeBoxSet') -or -not $Context.TimeBoxSet }
            Violation = 'TIME-BOX THE SPIKE'
            Message = 'How long are we spiking? Set a timer.'
            Stop = $true
        }
        'commit-spike' = @{
            Check = { $true }  # Always stop
            Violation = 'NEVER SHIP THE SPIKE'
            Message = "That's the prototype. We rebuild clean or refactor ruthlessly."
            Stop = $true
        }
        'rebuild' = @{
            Check = { -not $Context.ContainsKey('Evaluated') -or -not $Context.Evaluated }
            Violation = 'EVALUATE BEFORE REBUILD'
            Message = 'What did we learn? What worked? What didn''t? Write down 3 lessons.'
            Stop = $true
        }
    }
    'ride-along' = @{
        'explain-multiple' = @{
            Check = { $Context.ContainsKey('ConceptCount') -and $Context.ConceptCount -ge 3 }
            Violation = 'ONE MOVE AT A TIME'
            Message = "That's too much. Let's do one thing, see it work, then the next."
            Stop = $true
        }
        'type-for-learner' = @{
            Check = { -not $Context.ContainsKey('IsScaffolding') -or -not $Context.IsScaffolding }
            Violation = 'LEARNER AT KEYBOARD'
            Message = 'Wait, you type it. I''ll tell you what.'
            Stop = $true
        }
        'skip-concept-name' = @{
            Check = { $true }  # Always remind
            Violation = 'NAME CONCEPTS OUT LOUD'
            Message = 'This is [concept name]. You''ll see it again.'
            Stop = $false  # Warning, not blocker
        }
        'skip-aar' = @{
            Check = { $Context.ContainsKey('MilestoneReached') -and $Context.MilestoneReached }
            Violation = 'MILESTONE AFTER-ACTION REVIEW'
            Message = 'What happened? What worked? What would you do differently?'
            Stop = $true
        }
    }
}

# Check rule
$methodRules = $rules[$Method]
if (-not $methodRules.ContainsKey($Action)) {
    # No rule for this action in this method
    return [PSCustomObject]@{
        Result = 'CONTINUE'
        Violation = $null
        Message = $null
    }
}

$rule = $methodRules[$Action]
$violates = & $rule.Check

if ($violates) {
    return [PSCustomObject]@{
        Result = if ($rule.Stop) { 'STOP' } else { 'WARN' }
        Violation = $rule.Violation
        Message = $rule.Message
    }
} else {
    return [PSCustomObject]@{
        Result = 'CONTINUE'
        Violation = $null
        Message = $null
    }
}
