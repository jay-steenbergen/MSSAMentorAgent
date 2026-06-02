#Requires -Version 7.0
<#
.SYNOPSIS
    Profiles suite: xUnit (C#) + PowerShell profile validators.

.DESCRIPTION
    Runs:
      1. dotnet test .profiles/ProfileTests/
      2. .profiles/validate-profile.ps1 -Username for every mentee profile folder
    PASS when both steps exit 0.

.OUTPUTS
    @{ name; result; detail; durationMs }
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = 'Continue'
$start = Get-Date

$details = @()
$anyFail = $false

# --- 1. xUnit ----------------------------------------------------------------
$xunitProject = Join-Path $RepoRoot '.profiles/ProfileTests/ProfileTests.csproj'
if (Test-Path $xunitProject) {
    $xunitOut = & dotnet test $xunitProject --nologo --verbosity quiet 2>&1 | Out-String
    $xunitExit = $LASTEXITCODE

    # Look for "Passed!" or "Passed:  N"
    $passedMatch = [regex]::Match($xunitOut, 'Passed:\s+(\d+)')
    $failedMatch = [regex]::Match($xunitOut, 'Failed:\s+(\d+)')
    $passed = if ($passedMatch.Success) { [int]$passedMatch.Groups[1].Value } else { 0 }
    $failed = if ($failedMatch.Success) { [int]$failedMatch.Groups[1].Value } else { 0 }

    if ($xunitExit -ne 0 -or $failed -gt 0) {
        $anyFail = $true
        $details += "xUnit: $passed pass, $failed FAIL"
    } else {
        $details += "xUnit: $passed pass"
    }
} else {
    $details += "xUnit: project not found (skipped)"
}

# --- 2. PowerShell validators -----------------------------------------------
$validator = Join-Path $RepoRoot '.profiles/validate-profile.ps1'
$menteesDir = Join-Path $RepoRoot '.profiles/profiles/mentees'

if ((Test-Path $validator) -and (Test-Path $menteesDir)) {
    $userDirs = Get-ChildItem -Path $menteesDir -Directory -ErrorAction SilentlyContinue
    $validatorPass = 0
    $validatorFail = 0

    foreach ($u in $userDirs) {
        & pwsh -NoProfile -File $validator -Username $u.Name *>$null
        if ($LASTEXITCODE -eq 0) { $validatorPass++ } else { $validatorFail++ }
    }

    if ($validatorFail -gt 0) {
        $anyFail = $true
        $details += "PS validators: $validatorPass pass, $validatorFail FAIL"
    } else {
        $details += "PS validators: $validatorPass pass"
    }
} else {
    $details += "PS validators: skipped (validator or mentees dir missing)"
}

return @{
    name = 'profiles'
    result = if ($anyFail) { 'FAIL' } else { 'PASS' }
    detail = ($details -join '; ')
    durationMs = [int]((Get-Date) - $start).TotalMilliseconds
}
