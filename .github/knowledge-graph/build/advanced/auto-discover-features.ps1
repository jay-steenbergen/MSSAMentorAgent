#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Auto-discover and add new features to the system graph.

.DESCRIPTION
    Scans the repository for new features based on conventions:
    - New CLI tools in .github/knowledge-graph/cli/
    - New PowerShell modules in .github/knowledge-graph/lib/
    - New VS Code extensions in extensions/
    - New major functions (exported by modules)
    
    Idempotent: only adds nodes/edges that don't already exist.
    
.PARAMETER DryRun
    Preview changes without writing to graph.

.EXAMPLE
    pwsh .github/knowledge-graph/build/auto-discover-features.ps1
    pwsh .github/knowledge-graph/build/auto-discover-features.ps1 -DryRun
#>

[CmdletBinding()]
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'

# ---------- paths ----------
$scriptDir = $PSScriptRoot
$repoRoot = (Resolve-Path "$scriptDir\..\..\..\..").Path
$graphPath = Join-Path $repoRoot '.github/knowledge-graph/data/MentorAgent/system/mentor-graph.json'
$cliDir = Join-Path $repoRoot '.github/knowledge-graph/cli'
$libDir = Join-Path $repoRoot '.github/knowledge-graph/lib'
$extDir = Join-Path $repoRoot 'extensions'

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Auto-Discover Features" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ---------- discovery ----------
$plan = @()

# 1. CLI tools
$cliEdges = @()
if (Test-Path $cliDir) {
    $cliScripts = Get-ChildItem $cliDir -Filter *.ps1 | Where-Object { $_.Name -notlike 'add-*.ps1' -and $_.Name -notlike 'auto-*.ps1' }
    foreach ($script in $cliScripts) {
        $basename = $script.BaseName
        $toolId = "cli-tool:$basename"
        
        $plan += [pscustomobject]@{
            Kind = 'cli-tool'
            Id = $toolId
            Label = "$basename.ps1"
            File = ".github/knowledge-graph/cli/$($script.Name)"
            Description = "CLI script from knowledge-graph tooling."
            Cluster = 'profile-system'  # default cluster
        }
        
        # Add bridge to code-file (cross-layer)
        $codeFileId = "code-file:.github/knowledge-graph/cli/$($script.Name)"
        $cliEdges += [pscustomobject]@{
            Source = $toolId
            Target = $codeFileId
            Type = 'defined_in'
            Label = 'defined in'
        }
        
        # Parse script to find module imports only
        # (Function call edges are created by code extraction, not auto-discover)
        $content = Get-Content $script.FullName -Raw
        
        # Find module imports (Import-Module or using module)
        $modulePattern = '(?:Import-Module|using\s+module)\s+[''"]?([^\s''";]+)'
        $moduleMatches = [regex]::Matches($content, $modulePattern)
        foreach ($match in $moduleMatches) {
            $moduleName = $match.Groups[1].Value
            # Infer module path if it's a relative reference
            if ($moduleName -match '^\.|^\.\.') {
                $modulePath = ".github/knowledge-graph/lib/$($moduleName -replace '\.\./lib/', '')"
                if ($modulePath -notmatch '\.psm1$') { $modulePath += '.psm1' }
                
                $cliEdges += [pscustomobject]@{
                    Source = $toolId
                    Target = "code-file:$modulePath"
                    Type = 'imports'
                    Label = "imports module"
                }
            }
        }
    }
}

# 2. PowerShell modules with exported functions
if (Test-Path $libDir) {
    $modules = Get-ChildItem $libDir -Filter *.psm1
    foreach ($mod in $modules) {
        $content = Get-Content $mod.FullName -Raw
        
        # Extract exported functions from Export-ModuleMember
        $exportMatch = [regex]::Match($content, '(?ms)Export-ModuleMember\s+-Function\s+([^\r\n]+)')
        if ($exportMatch.Success) {
            $funcList = $exportMatch.Groups[1].Value -replace '[''"`]', '' -split '\s*,\s*'
            foreach ($func in $funcList) {
                $func = $func.Trim()
                if (-not $func) { continue }
                
                $plan += [pscustomobject]@{
                    Kind = 'code-func'
                    Id = "code-func:$func"
                    Label = $func
                    File = ".github/knowledge-graph/lib/$($mod.Name)"
                    Description = "PowerShell function exported by $($mod.Name)."
                    Cluster = 'scripts-source'
                }
            }
        }
    }
}

# 3. VS Code extensions
$extEdges = @()
if (Test-Path $extDir) {
    $extensions = Get-ChildItem $extDir -Directory
    foreach ($ext in $extensions) {
        $packageJson = Join-Path $ext.FullName 'package.json'
        if (-not (Test-Path $packageJson)) { continue }
        
        $pkg = Get-Content $packageJson -Raw | ConvertFrom-Json -Depth 32
        $extName = $pkg.name
        $extDesc = $pkg.description
        $extId = "extension:$extName"
        
        $plan += [pscustomobject]@{
            Kind = 'extension'
            Id = $extId
            Label = $extName
            File = "extensions/$extName/"
            Description = $extDesc
            Cluster = 'session-protocols'  # extensions manage session behavior
        }
        
        # Discover all files the extension contains and emit `contains` edges
        # to the corresponding code-file nodes (created by extract-code-graph).
        # This bridges the system layer to the code layer so the extension is
        # never an island and its sub-files never get tagged "UNWIRED".
        # Strategy: walk the whole extension folder, skip build outputs and
        # vendor dirs, emit one `contains` edge per real source/config file.
        # The includeExt allowlist MUST mirror extract-code-graph.ps1's -Include
        # filter — otherwise we emit edges to code-file nodes that never exist
        # (e.g. LICENSE, .gitignore) and the dangling-edges health check FAILs.
        $excludeDirs = @('node_modules', 'out', 'dist', '.vsix-temp', 'coverage', '.vscode-test', '.nyc_output', 'tmp', '.git')
        $includeExt  = @('.md', '.ps1', '.psm1', '.json', '.cs', '.csproj', '.ts', '.tsx')
        $allFiles = Get-ChildItem $ext.FullName -Recurse -File | Where-Object {
            $relParts = $_.FullName.Substring($ext.FullName.Length).TrimStart('\','/') -split '[\\/]'
            -not ($excludeDirs | Where-Object { $relParts -contains $_ }) -and
            ($includeExt -contains $_.Extension.ToLower()) -and
            -not ($_.Name.StartsWith('.'))   # skip bare dotfiles (.gitignore etc.); extract-code-graph doesn't node them
        }
        foreach ($f in $allFiles) {
            $rel = ($f.FullName.Substring($repoRoot.Length).TrimStart('\','/')) -replace '\\','/'
            $extEdges += [pscustomobject]@{
                Source = $extId
                Target = "code-file:$rel"
                Type = 'contains'
                Label = 'contains file'
            }
        }
    }
}

Write-Host "Discovered:" -ForegroundColor Cyan
Write-Host "  CLI tools: $($plan.Where({$_.Kind -eq 'cli-tool'}).Count)" -ForegroundColor White
Write-Host "  Functions: $($plan.Where({$_.Kind -eq 'code-func'}).Count)" -ForegroundColor White
Write-Host "  Extensions: $($plan.Where({$_.Kind -eq 'extension'}).Count)" -ForegroundColor White
Write-Host ""

# ---------- load graph ----------
$graph = Get-Content $graphPath -Raw | ConvertFrom-Json -Depth 32

# Index existing
$existingNodeIds = @{}
foreach ($n in $graph.nodes) { $existingNodeIds[$n.id] = $true }

$existingEdgeKeys = @{}
foreach ($e in $graph.edges) { $existingEdgeKeys["$($e.source)|$($e.target)|$($e.type)"] = $true }

# ---------- build additions ----------
$newNodes = @()
$newEdges = @()

foreach ($item in $plan) {
    if ($existingNodeIds.ContainsKey($item.Id)) { continue }
    
    $newNodes += [pscustomobject][ordered]@{
        id = $item.Id
        type = $item.Kind
        label = $item.Label
        cluster = $item.Cluster
        file = $item.File
        description = $item.Description
    }
    
    # Add edges based on type
    if ($item.Kind -eq 'cli-tool') {
        # CLI tools belong to a feature (if we can infer it)
        # For now, just connect to agent:mentor
        $ek = "agent:mentor|$($item.Id)|uses"
        if (-not $existingEdgeKeys.ContainsKey($ek)) {
            $newEdges += [pscustomobject][ordered]@{
                source = 'agent:mentor'
                target = $item.Id
                type = 'uses'
                label = 'uses tool'
            }
        }
    }
    
    if ($item.Kind -eq 'extension') {
        # Extensions implement features (connect to mentor)
        $ek = "$($item.Id)|agent:mentor|extends"
        if (-not $existingEdgeKeys.ContainsKey($ek)) {
            $newEdges += [pscustomobject][ordered]@{
                source = $item.Id
                target = 'agent:mentor'
                type = 'extends'
                label = 'extends agent'
            }
        }
    }
}

# Add CLI edges (function calls and module imports)
foreach ($edge in $cliEdges) {
    $ek = "$($edge.Source)|$($edge.Target)|$($edge.Type)"
    if ($existingEdgeKeys.ContainsKey($ek)) { continue }
    
    # Only add edge if target exists (or will be created)
    # For now, add all — dangling edges will be caught by health check
    $newEdges += [pscustomobject][ordered]@{
        source = $edge.Source
        target = $edge.Target
        type = $edge.Type
        label = $edge.Label
    }
}

# Add extension contains-edges (bridges extension node to its code-file nodes)
foreach ($edge in $extEdges) {
    $ek = "$($edge.Source)|$($edge.Target)|$($edge.Type)"
    if ($existingEdgeKeys.ContainsKey($ek)) { continue }
    
    $newEdges += [pscustomobject][ordered]@{
        source = $edge.Source
        target = $edge.Target
        type = $edge.Type
        label = $edge.Label
    }
}

Write-Host "Will add:" -ForegroundColor Cyan
Write-Host "  Nodes: $($newNodes.Count)" -ForegroundColor White
Write-Host "  Edges: $($newEdges.Count)" -ForegroundColor White
Write-Host ""

if ($newNodes.Count -eq 0 -and $newEdges.Count -eq 0) {
    Write-Host "Nothing to add. Graph is up to date." -ForegroundColor Green
    return
}

if ($DryRun) {
    Write-Host "DryRun set — showing what would be added:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "New Nodes:" -ForegroundColor Yellow
    $newNodes | ForEach-Object { Write-Host "  + $($_.id)" -ForegroundColor DarkGray }
    Write-Host ""
    Write-Host "New Edges:" -ForegroundColor Yellow
    $newEdges | ForEach-Object { Write-Host "  + $($_.source) → $($_.target)" -ForegroundColor DarkGray }
    return
}

# ---------- mutate graph ----------
$nodes = [System.Collections.Generic.List[object]]::new()
$edges = [System.Collections.Generic.List[object]]::new()

foreach ($n in $graph.nodes) { $nodes.Add($n) }
foreach ($e in $graph.edges) { $edges.Add($e) }

foreach ($n in $newNodes) { $nodes.Add($n) }
foreach ($e in $newEdges) { $edges.Add($e) }

$graph.nodes = $nodes.ToArray()
$graph.edges = $edges.ToArray()

# ---------- save ----------
$json = $graph | ConvertTo-Json -Depth 32
$json | Set-Content $graphPath -Encoding UTF8 -NoNewline

Write-Host "System graph updated:" -ForegroundColor Green
Write-Host "  Nodes: $($graph.nodes.Count)" -ForegroundColor White
Write-Host "  Edges: $($graph.edges.Count)" -ForegroundColor White
Write-Host "  Saved to: $graphPath" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Next step: Rebuild merged graph" -ForegroundColor Cyan
Write-Host "  pwsh .github/knowledge-graph/build/core/merge.ps1" -ForegroundColor DarkGray
Write-Host ""
