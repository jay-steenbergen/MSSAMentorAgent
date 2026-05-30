#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates method_proficiency structure in all learner progress files.

.DESCRIPTION
    Scans .profiles/profiles/mentees/*/*.progress.json files and verifies:
    - method_proficiency object exists (if any methods used)
    - Each method entry has: level, last_updated, notes
    - level is one of: Novice, Familiar, Competent, Proficient
    - last_updated is valid YYYY-MM-DD format
    - notes is non-empty string

.EXAMPLE
    .\validate-proficiency.ps1
    Scans all progress files, reports status

.EXAMPLE
    .\validate-proficiency.ps1 -Username test_user
    Validates only test_user's progress files

.EXAMPLE
    .\validate-proficiency.ps1 -Fix
    Attempts to fix malformed entries (prompts for each fix)
#>

param(
    [string]$Username,
    [switch]$Fix
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$profilesDir = Join-Path $scriptDir "profiles\mentees"

$validLevels = @('Novice', 'Familiar', 'Competent', 'Proficient')
$validMethods = @('TDD', 'BDD', 'spike-then-refactor', 'ride-along')

function Test-ProficiencyEntry {
    param(
        [string]$Method,
        [object]$Entry,
        [string]$FilePath
    )
    
    $errors = @()
    
    if (-not $Entry) {
        $errors += "Method '$Method' exists but entry is null"
        return $errors
    }
    
    # Check required fields
    if (-not $Entry.PSObject.Properties['level']) {
        $errors += "Method '$Method' missing 'level' field"
    } elseif ($Entry.level -notin $validLevels) {
        $errors += "Method '$Method' has invalid level '$($Entry.level)' (expected: $($validLevels -join ', '))"
    }
    
    if (-not $Entry.PSObject.Properties['last_updated']) {
        $errors += "Method '$Method' missing 'last_updated' field"
    } elseif ($Entry.last_updated -notmatch '^\d{4}-\d{2}-\d{2}$') {
        $errors += "Method '$Method' has invalid date format '$($Entry.last_updated)' (expected: YYYY-MM-DD)"
    }
    
    if (-not $Entry.PSObject.Properties['notes']) {
        $errors += "Method '$Method' missing 'notes' field"
    } elseif ([string]::IsNullOrWhiteSpace($Entry.notes)) {
        $errors += "Method '$Method' has empty notes"
    }
    
    return $errors
}

function Get-ProgressFiles {
    param([string]$Username)
    
    if ($Username) {
        $userDir = Join-Path $profilesDir $Username
        if (-not (Test-Path $userDir)) {
            Write-Error "User directory not found: $userDir"
            return @()
        }
        Get-ChildItem -Path $userDir -Filter "*.progress.json"
    } else {
        Get-ChildItem -Path $profilesDir -Recurse -Filter "*.progress.json"
    }
}

# Main validation loop
$progressFiles = Get-ProgressFiles -Username $Username
$totalFiles = $progressFiles.Count
$filesWithProficiency = 0
$filesWithErrors = 0
$totalErrors = 0

Write-Host "Scanning $totalFiles progress files..." -ForegroundColor Cyan
Write-Host ""

foreach ($file in $progressFiles) {
    $relativePath = $file.FullName.Replace("$profilesDir\", "")
    
    try {
        $progress = Get-Content -Raw $file.FullName | ConvertFrom-Json
        
        # Check if method_proficiency exists
        if (-not $progress.PSObject.Properties['method_proficiency']) {
            Write-Host "  $relativePath" -ForegroundColor Gray
            Write-Host "    ℹ No method_proficiency object (no methods used yet)" -ForegroundColor DarkGray
            continue
        }
        
        $filesWithProficiency++
        $fileErrors = @()
        
        # Validate each method entry
        $methodProps = $progress.method_proficiency.PSObject.Properties
        foreach ($prop in $methodProps) {
            $method = $prop.Name
            $entry = $prop.Value
            
            $errors = Test-ProficiencyEntry -Method $method -Entry $entry -FilePath $file.FullName
            $fileErrors += $errors
        }
        
        # Report results for this file
        if ($fileErrors.Count -eq 0) {
            Write-Host "  ✓ $relativePath" -ForegroundColor Green
            Write-Host "    Methods tracked: $($methodProps.Count) ($($methodProps.Name -join ', '))" -ForegroundColor DarkGray
        } else {
            $filesWithErrors++
            $totalErrors += $fileErrors.Count
            Write-Host "  ✗ $relativePath" -ForegroundColor Red
            foreach ($error in $fileErrors) {
                Write-Host "    • $error" -ForegroundColor Yellow
            }
        }
        
    } catch {
        $filesWithErrors++
        Write-Host "  ✗ $relativePath" -ForegroundColor Red
        Write-Host "    • Failed to parse JSON: $_" -ForegroundColor Yellow
    }
}

# Summary
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "Total progress files: $totalFiles"
Write-Host "Files with method proficiency: $filesWithProficiency"
Write-Host "Files with errors: $filesWithErrors"
Write-Host "Total errors: $totalErrors"

if ($filesWithErrors -eq 0) {
    Write-Host ""
    Write-Host "✓ All proficiency data is valid" -ForegroundColor Green
    exit 0
} else {
    Write-Host ""
    Write-Host "✗ Found $totalErrors validation errors" -ForegroundColor Red
    Write-Host ""
    Write-Host "To fix manually:" -ForegroundColor Yellow
    Write-Host "  1. Open the progress file"
    Write-Host "  2. Correct the method_proficiency entry"
    Write-Host "  3. Re-run this script to verify"
    Write-Host ""
    Write-Host "Valid structure example:" -ForegroundColor Yellow
    Write-Host '  "method_proficiency": {' -ForegroundColor Gray
    Write-Host '    "TDD": {' -ForegroundColor Gray
    Write-Host '      "level": "Familiar",' -ForegroundColor Gray
    Write-Host '      "last_updated": "2026-05-29",' -ForegroundColor Gray
    Write-Host '      "notes": "Completed 3 cycles. Names phases independently."' -ForegroundColor Gray
    Write-Host '    }' -ForegroundColor Gray
    Write-Host '  }' -ForegroundColor Gray
    exit 1
}
