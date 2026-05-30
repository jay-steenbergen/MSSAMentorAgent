#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Edit learner profiles interactively
.DESCRIPTION
    Loads a learner profile, allows field updates, validates against schema, and commits changes.
.PARAMETER Username
    GitHub username of the learner (defaults to current Git user)
.PARAMETER Field
    Specific field to edit (optional - if omitted, shows menu)
.EXAMPLE
    .\edit-profile.ps1
    .\edit-profile.ps1 -Username jasteenb
    .\edit-profile.ps1 -Username jasteenb -Field "learning_style.pace_preference"
#>

param(
    [string]$Username = (git config user.name),
    [string]$Field
)

$ErrorActionPreference = "Stop"

# Find repo root (look for .profiles directory)
$repoRoot = $PSScriptRoot
while ($repoRoot -and -not (Test-Path (Join-Path $repoRoot ".profiles"))) {
    $repoRoot = Split-Path $repoRoot -Parent
}

if (-not $repoRoot) {
    Write-Host "❌ Could not find repo root (.profiles directory not found)" -ForegroundColor Red
    exit 1
}

# Change to repo root
Push-Location $repoRoot

# Determine if this is a mentor or mentee profile
# Mentors: system developers/testers
# Mentees: actual MSSA learners
$isMentor = $Username -eq "jasteenb"  # Add other mentor usernames as needed
$profileDir = if ($isMentor) { ".profiles/profiles/mentors" } else { ".profiles/profiles/mentees" }
$profilePath = "$profileDir/$Username.json"

# Check if profile exists
if (-not (Test-Path $profilePath)) {
    Write-Host "❌ No profile found for '$Username'" -ForegroundColor Red
    Write-Host ""
    Write-Host "Available profiles:"
    Get-ChildItem $profileDir -Filter "*.json" | ForEach-Object {
        Write-Host "  - $($_.BaseName)"
    }
    exit 1
}

# Load profile
Write-Host "📖 Loading profile: $Username" -ForegroundColor Cyan
$profile = Get-Content $profilePath -Raw | ConvertFrom-Json

# Interactive edit menu
function Show-Menu {
    Write-Host ""
    Write-Host "Profile for $($profile.preferred_name) (@$($profile.github_username))" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host ""
    Write-Host "Learning Style:"
    Write-Host "  1. Prefers: $($profile.learning_style.prefers -join ', ')"
    Write-Host "  2. Pace: $($profile.learning_style.pace_preference)"
    Write-Host "  3. When stuck: $($profile.learning_style.when_stuck)"
    Write-Host ""
    Write-Host "Personality:"
    Write-Host "  4. Self-description: $($profile.personality.self_description)"
    Write-Host "  5. Motivation: $($profile.personality.motivation)"
    Write-Host ""
    Write-Host "Military Background:"
    Write-Host "  6. Branch: $($profile.military.branch)"
    Write-Host "  7. Rank: $($profile.military.rank)"
    Write-Host "  8. MOS: $($profile.military.mos)"
    Write-Host "  9. Job description: $($profile.military.job_description)"
    Write-Host ""
    Write-Host "Progress:"
    Write-Host " 10. Current track: $($profile.progress.current_track)"
    Write-Host " 11. Current project: $($profile.progress.current_project)"
    Write-Host " 12. Current step: $($profile.progress.current_step)"
    Write-Host ""
    Write-Host " v. Validate profile"
    Write-Host " s. Save and exit"
    Write-Host " q. Quit without saving"
    Write-Host ""
}

function Edit-Field {
    param([string]$FieldName, [string]$CurrentValue, [string]$Path)
    
    Write-Host ""
    Write-Host "Editing: $FieldName" -ForegroundColor Yellow
    Write-Host "Current: $CurrentValue" -ForegroundColor DarkGray
    Write-Host ""
    $newValue = Read-Host "New value (or Enter to keep current)"
    
    if ($newValue -and $newValue -ne $CurrentValue) {
        # Update the profile object
        $parts = $Path -split '\.'
        $obj = $profile
        for ($i = 0; $i -lt $parts.Length - 1; $i++) {
            $obj = $obj.($parts[$i])
        }
        $obj.($parts[-1]) = $newValue
        
        Write-Host "✓ Updated" -ForegroundColor Green
        return $true
    }
    return $false
}

function Validate-Profile {
    Write-Host ""
    Write-Host "🔍 Running validation..." -ForegroundColor Cyan
    
    # Save temp file for validation
    $tempPath = "$profilePath.tmp"
    $profile | ConvertTo-Json -Depth 10 | Set-Content $tempPath
    
    # Run xUnit tests
    Push-Location ".profiles/ProfileTests"
    $result = dotnet test --filter "FullyQualifiedName~Profile" 2>&1
    Pop-Location
    
    Remove-Item $tempPath -ErrorAction SilentlyContinue
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Profile is valid" -ForegroundColor Green
        return $true
    } else {
        Write-Host "❌ Validation failed:" -ForegroundColor Red
        $result | Select-String "Assert\." | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Red
        }
        return $false
    }
}

# Main loop
$modified = $false

if ($Field) {
    # Direct field edit mode
    $parts = $Field -split '\.'
    $obj = $profile
    $current = $profile
    foreach ($part in $parts) {
        $current = $current.$part
    }
    $modified = Edit-Field -FieldName $Field -CurrentValue $current -Path $Field
} else {
    # Interactive menu mode
    do {
        Show-Menu
        $choice = Read-Host "Select option"
        
        $changed = $false
        switch ($choice) {
            "1" { $changed = Edit-Field "Prefers" ($profile.learning_style.prefers -join ', ') "learning_style.prefers" }
            "2" { $changed = Edit-Field "Pace" $profile.learning_style.pace_preference "learning_style.pace_preference" }
            "3" { $changed = Edit-Field "When stuck" $profile.learning_style.when_stuck "learning_style.when_stuck" }
            "4" { $changed = Edit-Field "Self-description" $profile.personality.self_description "personality.self_description" }
            "5" { $changed = Edit-Field "Motivation" $profile.personality.motivation "personality.motivation" }
            "6" { $changed = Edit-Field "Branch" $profile.military.branch "military.branch" }
            "7" { $changed = Edit-Field "Rank" $profile.military.rank "military.rank" }
            "8" { $changed = Edit-Field "MOS" $profile.military.mos "military.mos" }
            "9" { $changed = Edit-Field "Job description" $profile.military.job_description "military.job_description" }
            "10" { $changed = Edit-Field "Current track" $profile.progress.current_track "progress.current_track" }
            "11" { $changed = Edit-Field "Current project" $profile.progress.current_project "progress.current_project" }
            "12" { $changed = Edit-Field "Current step" $profile.progress.current_step "progress.current_step" }
            "v" { Validate-Profile }
            "s" {
                if ($modified) {
                    Write-Host ""
                    Write-Host "💾 Saving profile..." -ForegroundColor Cyan
                    
                    # Update timestamp
                    $profile.last_updated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
                    
                    # Save
                    $profile | ConvertTo-Json -Depth 10 | Set-Content $profilePath
                    
                    # Validate
                    if (Validate-Profile) {
                        # Commit
                        git add $profilePath
                        git commit -m "Update learner profile: $($profile.preferred_name)"
                        
                        Write-Host "✓ Profile saved and committed" -ForegroundColor Green
                    } else {
                        Write-Host "⚠️  Profile saved but validation failed" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "No changes to save" -ForegroundColor DarkGray
                }
                break
            }
            "q" {
                if ($modified) {
                    $confirm = Read-Host "Discard changes? (y/n)"
                    if ($confirm -eq "y") { break }
                } else {
                    break
                }
            }
        }
        
        if ($changed) { $modified = $true }
        
    } while ($choice -ne "s" -and $choice -ne "q")
}

# Return to original directory
Pop-Location
