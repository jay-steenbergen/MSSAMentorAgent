#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
Handle session protocols (start, end, method/track switching).

.PARAMETER Phase
Session phase: start | end | switch-method | switch-track

.PARAMETER ProfilePath
Path to learner's profile.json

.PARAMETER Context
Additional context (current method, track, project, milestones, etc.)

.OUTPUTS
Protocol instructions or picker options
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('start', 'end', 'switch-method', 'switch-track')]
    [string]$Phase,
    
    [Parameter()]
    [string]$ProfilePath,
    
    [Parameter()]
    [hashtable]$Context = @{}
)

$ErrorActionPreference = 'Stop'

switch ($Phase) {
    'start' {
        if (-not $ProfilePath -or -not (Test-Path $ProfilePath)) {
            return [PSCustomObject]@{
                Action = 'INTERVIEW'
                Message = 'No profile found. Run first-time interview from learner-profile skill.'
            }
        }
        
        $profile = Get-Content $ProfilePath -Raw | ConvertFrom-Json
        
        # Get active projects
        $activeProjects = @()
        foreach ($projectId in $profile.projects.PSObject.Properties.Name) {
            $proj = $profile.projects.$projectId
            if ($proj.status -eq 'in_progress') {
                $activeProjects += [PSCustomObject]@{
                    Id = $projectId
                    DisplayName = $proj.display_name
                    LastSession = $proj.last_session
                    CurrentStep = $proj.current_step
                    Track = $proj.track
                    Method = $proj.last_used_method
                }
            }
        }
        
        if ($activeProjects.Count -eq 0) {
            return [PSCustomObject]@{
                Action = 'START_NEW'
                Message = 'No active projects. Show track picker to start new project.'
            }
        } elseif ($activeProjects.Count -eq 1) {
            $proj = $activeProjects[0]
            return [PSCustomObject]@{
                Action = 'LOAD_PROJECT'
                ProjectId = $proj.Id
                Method = $proj.Method
                Track = $proj.Track
                Message = "Loading project: $($proj.DisplayName)"
            }
        } else {
            return [PSCustomObject]@{
                Action = 'SHOW_PROJECT_PICKER'
                Options = $activeProjects | ForEach-Object {
                    @{
                        Label = $_.DisplayName
                        Description = "In progress • Last: $($_.LastSession) • Step $($_.CurrentStep)"
                        Value = $_.Id
                    }
                }
                Message = 'Multiple active projects. Show picker.'
            }
        }
    }
    
    'end' {
        if (-not $Context.ContainsKey('Username') -or -not $Context.ContainsKey('ProjectId')) {
            return [PSCustomObject]@{
                Action = 'ERROR'
                Message = 'Missing required context: Username, ProjectId'
            }
        }
        
        return [PSCustomObject]@{
            Action = 'UPDATE_FILES'
            Updates = @(
                @{
                    File = ".profiles/profiles/mentees/$($Context.Username)/$($Context.ProjectId).progress.json"
                    Fields = @{
                        last_session = (Get-Date).ToString('yyyy-MM-dd')
                        last_used_method = $Context.Method
                        current_step = $Context.CurrentStep
                    }
                }
                @{
                    File = ".profiles/profiles/mentees/$($Context.Username)/profile.json"
                    Path = "projects.$($Context.ProjectId)"
                    Fields = @{
                        last_session = (Get-Date).ToString('yyyy-MM-dd')
                        current_step = $Context.CurrentStep
                        status = if ($Context.Completed) { 'completed' } else { 'in_progress' }
                    }
                }
            )
            GitCommand = "git add .profiles/profiles/mentees/$($Context.Username)/ && git commit -m 'Update $($Context.Username) progress: $($Context.ProjectName)'"
        }
    }
    
    'switch-method' {
        $methods = @(
            @{ Label = 'Ride-along'; Description = 'Build together, I explain as we go (default)'; Value = 'ride-along' }
            @{ Label = 'TDD'; Description = 'Write tests first, then make them pass'; Value = 'TDD' }
            @{ Label = 'BDD'; Description = 'Start with behavior scenarios, then implement'; Value = 'BDD' }
            @{ Label = 'Spike-then-refactor'; Description = 'Explore freely, then clean up together'; Value = 'spike-then-refactor' }
        )
        
        return [PSCustomObject]@{
            Action = 'SHOW_PICKER'
            Type = 'method'
            Options = $methods
            Message = 'Select teaching method'
        }
    }
    
    'switch-track' {
        $tracks = @(
            @{ Label = 'Cloud Application Development'; Description = 'Build web apps and APIs'; Value = 'cloud-app-dev' }
            @{ Label = 'Server & Cloud Administration'; Description = 'Infrastructure and operations'; Value = 'server-cloud-admin' }
            @{ Label = 'Cybersecurity Operations'; Description = 'Security analysis and defense'; Value = 'cybersecurity-ops' }
        )
        
        return [PSCustomObject]@{
            Action = 'SHOW_PICKER'
            Type = 'track'
            Options = $tracks
            Message = 'Select MSSA track'
        }
    }
}
