#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
Enforce MSSA track domain discipline.

.PARAMETER Track
Track name: cloud-app-dev, server-cloud-admin, or cybersecurity-ops

.PARAMETER Intent
What the learner wants to build/do

.OUTPUTS
Object with: Result (IN_DOMAIN/OUT_OF_DOMAIN), Redirect (suggested track if out of domain), Message
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('cloud-app-dev', 'server-cloud-admin', 'cybersecurity-ops')]
    [string]$Track,
    
    [Parameter(Mandatory=$true)]
    [string]$Intent
)

$ErrorActionPreference = 'Stop'

# Track domains and rules
$domains = @{
    'cloud-app-dev' = @{
        Keywords = @('web', 'api', 'rest', 'graphql', 'deploy', 'cloud', 'frontend', 'backend', 'database', 'auth', 'jwt')
        OutOfDomain = @{
            'infrastructure|terraform|ansible|kubernetes|docker' = @{
                Redirect = 'server-cloud-admin'
                Message = "That's infrastructure automation work. For this cloud-app-dev project, we're focusing on the application layer. Want to switch tracks?"
            }
            'threat|vulnerability|pen.?test|security.?scan|intrusion' = @{
                Redirect = 'cybersecurity-ops'
                Message = "That's security analysis work. For this cloud-app-dev project, we're building the app. Security scanning is cybersecurity-ops domain."
            }
        }
        Rules = @(
            @{
                Name = 'CLOUD-FIRST MINDSET'
                Pattern = 'local.?only|localhost.?only|no.?deploy'
                Message = 'How would this work in the cloud? What service would we use?'
            }
            @{
                Name = 'API-DRIVEN ARCHITECTURE'
                Pattern = 'tightly.?coupled|monolith'
                Message = 'How would another app call this?'
            }
        )
    }
    'server-cloud-admin' = @{
        Keywords = @('infrastructure', 'terraform', 'ansible', 'docker', 'kubernetes', 'monitoring', 'automation', 'iac', 'observability')
        OutOfDomain = @{
            'web.?app|api.?endpoint|frontend|react|angular' = @{
                Redirect = 'cloud-app-dev'
                Message = "That's application development. For this server-cloud-admin project, we're managing infrastructure. Want to switch tracks?"
            }
            'threat|exploit|pen.?test|vulnerability.?scan' = @{
                Redirect = 'cybersecurity-ops'
                Message = "That's offensive security work. For server-cloud-admin, we're focused on infrastructure hardening and monitoring."
            }
        }
        Rules = @(
            @{
                Name = 'INFRASTRUCTURE AS CODE'
                Pattern = 'manual.*config|click.?through|console.?only'
                Message = 'How would you automate this?'
            }
            @{
                Name = 'MONITORING & OBSERVABILITY'
                Pattern = 'deploy.*without.*monitor'
                Message = 'How do you know if this breaks?'
            }
        )
    }
    'cybersecurity-ops' = @{
        Keywords = @('threat', 'security', 'vulnerability', 'intrusion', 'defense', 'incident', 'forensics', 'detection')
        OutOfDomain = @{
            'web.?framework|api.?design|database.?model' = @{
                Redirect = 'cloud-app-dev'
                Message = "That's application development. For cybersecurity-ops, we're analyzing threats and defending systems."
            }
            'terraform|ansible|infrastructure.?provision' = @{
                Redirect = 'server-cloud-admin'
                Message = "That's infrastructure automation. For cybersecurity-ops, we're focused on threat detection and response."
            }
        }
        Rules = @(
            @{
                Name = 'ASSUME BREACH'
                Pattern = 'prevent.*only|no.*detection|no.*response'
                Message = 'What happens when this fails? Design for compromise, not just prevention.'
            }
            @{
                Name = 'EVIDENCE OVER ASSUMPTION'
                Pattern = 'assume|probably|might.?be'
                Message = 'Show me the log entry. Evidence, not guesses.'
            }
        )
    }
}

$lowerIntent = $Intent.ToLower()
$trackDomain = $domains[$Track]

# Check if intent is out of domain
foreach ($pattern in $trackDomain.OutOfDomain.Keys) {
    if ($lowerIntent -match $pattern) {
        $violation = $trackDomain.OutOfDomain[$pattern]
        return [PSCustomObject]@{
            Result = 'OUT_OF_DOMAIN'
            Redirect = $violation.Redirect
            Message = $violation.Message
        }
    }
}

# Check for rule violations (warnings, not blockers)
foreach ($rule in $trackDomain.Rules) {
    if ($lowerIntent -match $rule.Pattern) {
        return [PSCustomObject]@{
            Result = 'IN_DOMAIN'
            Redirect = $null
            Message = "$($rule.Name): $($rule.Message)"
        }
    }
}

# In domain, no warnings
return [PSCustomObject]@{
    Result = 'IN_DOMAIN'
    Redirect = $null
    Message = $null
}
