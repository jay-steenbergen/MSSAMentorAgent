#Requires -Version 7.0

<#
.SYNOPSIS
    Install git hooks for automatic knowledge graph updates.

.DESCRIPTION
    Links .github/hooks/pre-commit into .git/hooks/ so git runs it automatically.
    The hook keeps the knowledge graph synchronized with code changes.

.EXAMPLE
    pwsh .github/hooks/install.ps1
#>

param(
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Get repo root
$repoRoot = git rev-parse --show-toplevel
if (-not $repoRoot) {
    Write-Error "Not in a git repository"
    exit 1
}

$sourceHook = Join-Path $repoRoot '.github' 'hooks' 'pre-commit'
$targetHook = Join-Path $repoRoot '.git' 'hooks' 'pre-commit'
$targetDir = Split-Path $targetHook -Parent

# Ensure .git/hooks exists
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

if ($Uninstall) {
    Write-Host "🗑️  Uninstalling pre-commit hook..." -ForegroundColor Cyan
    
    if (Test-Path $targetHook) {
        Remove-Item $targetHook -Force
        Write-Host "✓ Hook removed" -ForegroundColor Green
    } else {
        Write-Host "  Hook not installed" -ForegroundColor Gray
    }
    
    exit 0
}

# Check if already installed
if (Test-Path $targetHook) {
    # Check if it's a link to our hook
    $item = Get-Item $targetHook
    if ($item.LinkType -eq 'SymbolicLink' -and $item.Target -eq $sourceHook) {
        Write-Host "✓ Hook already installed (symlink)" -ForegroundColor Green
        exit 0
    } elseif ($item.LinkType -eq 'HardLink') {
        Write-Host "✓ Hook already installed (hardlink)" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "⚠️  Existing pre-commit hook found" -ForegroundColor Yellow
        Write-Host "   Location: $targetHook" -ForegroundColor Gray
        $response = Read-Host "   Overwrite? (y/N)"
        if ($response -ne 'y') {
            Write-Host "Cancelled." -ForegroundColor Gray
            exit 0
        }
        Remove-Item $targetHook -Force
    }
}

Write-Host "📦 Installing pre-commit hook..." -ForegroundColor Cyan

try {
    # Try symlink first (requires elevated privileges on Windows)
    New-Item -ItemType SymbolicLink -Path $targetHook -Target $sourceHook -Force -ErrorAction Stop | Out-Null
    Write-Host "✓ Hook installed (symlink)" -ForegroundColor Green
    Write-Host "  Location: $targetHook" -ForegroundColor Gray
    Write-Host "  Target: $sourceHook" -ForegroundColor Gray
} catch {
    # Fallback: Copy the file
    Write-Host "  (Symlink failed, copying instead)" -ForegroundColor Gray
    Copy-Item $sourceHook $targetHook -Force
    Write-Host "✓ Hook installed (copy)" -ForegroundColor Green
    Write-Host "  Location: $targetHook" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Note: Hook is a copy, not a link." -ForegroundColor Yellow
    Write-Host "  Run this script again after modifying .github/hooks/pre-commit" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "What happens now:" -ForegroundColor Cyan
Write-Host "  • When you commit changes to skills, CLI tools, modules, extensions, or code" -ForegroundColor Gray
Write-Host "  • The hook detects what changed" -ForegroundColor Gray
Write-Host "  • Runs minimal graph updates (auto-discover, extract, merge, fix)" -ForegroundColor Gray
Write-Host "  • Stages updated graph files automatically" -ForegroundColor Gray
Write-Host "  • Your commit includes the graph changes" -ForegroundColor Gray
Write-Host ""
Write-Host "To uninstall:" -ForegroundColor Cyan
Write-Host "  pwsh .github/hooks/install.ps1 -Uninstall" -ForegroundColor White
Write-Host ""
