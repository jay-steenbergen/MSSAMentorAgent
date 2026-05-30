#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validate a learner profile against the schema
.DESCRIPTION
    Runs xUnit validation tests against a specified profile or all profiles
.PARAMETER Username
    GitHub username to validate (optional - validates all if omitted)
.EXAMPLE
    .\validate-profile.ps1
    .\validate-profile.ps1 -Username jasteenb
#>

param(
    [string]$Username
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

# Check if tests exist
if (-not (Test-Path ".profiles/ProfileTests/ProfileTests.csproj")) {
    Pop-Location
    Write-Host "❌ Test project not found at .profiles/ProfileTests/" -ForegroundColor Red
    exit 1
}

# Build test project (suppress output unless it fails)
Write-Host "🔨 Building validation tests..." -ForegroundColor Cyan
$buildOutput = dotnet build .profiles/ProfileTests --nologo --verbosity quiet 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed:" -ForegroundColor Red
    Write-Host $buildOutput
    exit 1
}

# Run tests
if ($Username) {
    Write-Host "🔍 Validating profile: $Username" -ForegroundColor Cyan
    $filter = "FullyQualifiedName~$Username"
} else {
    Write-Host "🔍 Validating all profiles..." -ForegroundColor Cyan
    $filter = $null
}

Push-Location .profiles/ProfileTests
if ($filter) {
    $testResult = dotnet test --no-build --nologo --verbosity quiet --filter $filter 2>&1
} else {
    $testResult = dotnet test --no-build --nologo --verbosity quiet 2>&1
}
$exitCode = $LASTEXITCODE
Pop-Location

# Return to original directory
Pop-Location

if ($exitCode -eq 0) {
    Write-Host "✓ All profiles valid" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ Validation failed:" -ForegroundColor Red
    Write-Host ""
    
    # Parse and display failures
    $testResult | Select-String "Profile_" | ForEach-Object {
        $line = $_.Line
        if ($line -match '\[FAIL\]') {
            $testName = ($line -split '\(')[0] -replace '.*Profile_', ''
            Write-Host "  ✗ $testName" -ForegroundColor Red
        }
    }
    
    # Show assertion details
    $testResult | Select-String "Assert\.|is required|Failure:" | ForEach-Object {
        Write-Host "    $_" -ForegroundColor DarkRed
    }
    
    exit 1
}
