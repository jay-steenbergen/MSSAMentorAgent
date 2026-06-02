#Requires -Version 7.0
<#
.SYNOPSIS
  Generate .github/curriculum-manifest.json — the file index the
  extension uses to download curriculum from raw.githubusercontent.com.

.DESCRIPTION
  Walks the repo, collects every file the @Mentor agent and CLIs need
  at runtime, writes a single manifest. Mentees never clone this repo;
  they pull curriculum on demand via the manifest.

  Re-run after adding or removing any agent / skill / CLI file.
  CI also re-runs this on push to main (build-graph.yml).

.EXAMPLE
  pwsh ./scripts/generate-curriculum-manifest.ps1
#>
[CmdletBinding()]
param(
  [string]$RepoRoot = (Join-Path $PSScriptRoot '..')
)

$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path $RepoRoot).Path
Write-Host "Scanning $RepoRoot..."

# Glob patterns relative to repo root — anything an active session needs.
$patterns = @(
  '.github/agents/*.agent.md',
  '.github/skills/**/SKILL.md',
  '.github/skills/**/*.md',
  '.github/skills/**/*.json',
  '.github/skills/**/*.ps1',
  '.github/copilot-instructions.md',
  '.github/knowledge-graph/cli/**/*.ps1',
  '.github/knowledge-graph/cli/**/*.psm1',
  '.github/knowledge-graph/lib/**/*.psm1'
)

$files = [System.Collections.Generic.HashSet[string]]::new()
foreach ($pattern in $patterns) {
  Get-ChildItem -Path $RepoRoot -Filter (Split-Path $pattern -Leaf) `
                -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
      $rel = $_.FullName.Substring($RepoRoot.Length + 1) -replace '\\', '/'
      $rel -like ($pattern -replace '\*\*/', '*')  # crude glob
    } | ForEach-Object {
      $rel = $_.FullName.Substring($RepoRoot.Length + 1) -replace '\\', '/'
      [void]$files.Add($rel)
    }
}

# Re-do with proper recursive globbing per pattern (PowerShell's -Filter doesn't do **).
$files.Clear()
function Add-MatchingFiles {
  param([string]$RelGlob)
  $abs = Join-Path $RepoRoot ($RelGlob -replace '/', [IO.Path]::DirectorySeparatorChar)
  Get-ChildItem -Path $abs -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_ -is [System.IO.FileInfo]) {
      $rel = $_.FullName.Substring($RepoRoot.Length + 1) -replace '\\', '/'
      [void]$files.Add($rel)
    }
  }
}

# Resolve each pattern through Get-ChildItem with -Recurse where needed.
function Add-Pattern {
  param([string]$Pattern)
  # Convert glob to PowerShell path. ** means recurse.
  $hasRecurse = $Pattern -like '*`**`**'
  if ($hasRecurse) {
    # Find base dir before the first ** and filename pattern after the last /
    $segments = $Pattern -split '/'
    $baseParts = @()
    foreach ($seg in $segments) {
      if ($seg -eq '**') { break }
      $baseParts += $seg
    }
    $baseRel = ($baseParts -join '/')
    $filter = Split-Path $Pattern -Leaf
    $baseAbs = Join-Path $RepoRoot ($baseRel -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path $baseAbs)) { return }
    Get-ChildItem -Path $baseAbs -Filter $filter -Recurse -File -ErrorAction SilentlyContinue |
      ForEach-Object {
        $rel = $_.FullName.Substring($RepoRoot.Length + 1) -replace '\\', '/'
        [void]$files.Add($rel)
      }
  } else {
    $baseAbs = Join-Path $RepoRoot ($Pattern -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (Test-Path $baseAbs) {
      Get-ChildItem -Path $baseAbs -File -ErrorAction SilentlyContinue |
        ForEach-Object {
          $rel = $_.FullName.Substring($RepoRoot.Length + 1) -replace '\\', '/'
          [void]$files.Add($rel)
        }
    } else {
      # Single-file pattern with wildcard at the end (e.g. .github/agents/*.agent.md)
      $dir = Split-Path $baseAbs -Parent
      $filter = Split-Path $baseAbs -Leaf
      if (Test-Path $dir) {
        Get-ChildItem -Path $dir -Filter $filter -File -ErrorAction SilentlyContinue |
          ForEach-Object {
            $rel = $_.FullName.Substring($RepoRoot.Length + 1) -replace '\\', '/'
            [void]$files.Add($rel)
          }
      }
    }
  }
}

foreach ($p in $patterns) { Add-Pattern -Pattern $p }

$sorted = $files | Sort-Object
$manifest = [ordered]@{
  version   = '1'
  generated = (Get-Date).ToUniversalTime().ToString('o')
  files     = $sorted
}

$manifestPath = Join-Path $RepoRoot '.github/curriculum-manifest.json'
$manifest | ConvertTo-Json -Depth 4 | Set-Content -Path $manifestPath -Encoding UTF8 -NoNewline

Write-Host "Wrote $($sorted.Count) files to $manifestPath"
