#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Extracts infrastructure nodes (tests, hooks, extensions, build-scripts, configs) and merges into system graph.

.DESCRIPTION
    Phase 1 infrastructure extraction:
    - Tests (.github/tests/*.test.md)
    - Hooks (.github/hooks/*)
    - Extensions (extensions/*/package.json)
    - Build scripts (.github/knowledge-graph/build/*.ps1)
    - Configs (agent.md files with YAML frontmatter)

    **Merges into mentor-graph.json** instead of creating separate file.
    - Upserts nodes (add if new, update if exists)
    - Preserves existing edges
    - Adds new edges from extraction

.PARAMETER SystemGraph
    Path to system graph to update (default: data/MentorAgent/system/mentor-graph.json)

.EXAMPLE
    .\extract-infrastructure.ps1
    .\extract-infrastructure.ps1 -SystemGraph data/custom-graph.json
#>

param(
    [string]$SystemGraph = "data/MentorAgent/system/mentor-graph.json"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$scriptDir = $PSScriptRoot  # .github/knowledge-graph/build
$kgRoot = Split-Path $scriptDir -Parent  # .github/knowledge-graph
$githubRoot = Split-Path $kgRoot -Parent  # .github
$repoRoot = Split-Path $githubRoot -Parent  # repo root

$systemGraphPath = Join-Path $kgRoot $SystemGraph

Write-Host "🏗️  Extracting infrastructure..." -ForegroundColor Cyan
Write-Host "  Target: $SystemGraph" -ForegroundColor Gray

# ============================================================================
# Load existing system graph
# ============================================================================

if (Test-Path $systemGraphPath) {
    Write-Host "  📖 Loading existing system graph..." -ForegroundColor Gray
    $existingGraph = Get-Content $systemGraphPath -Raw | ConvertFrom-Json -Depth 32
    $script:nodes = @($existingGraph.nodes)
    $script:edges = @($existingGraph.edges)
    $script:nodeIds = @{}
    foreach ($node in $script:nodes) {
        $script:nodeIds[$node.id] = $true
    }
    Write-Host "    Loaded $($script:nodes.Count) nodes, $($script:edges.Count) edges" -ForegroundColor DarkGray
} else {
    Write-Host "  ⚠️  System graph not found, creating new..." -ForegroundColor Yellow
    $script:nodes = @()
    $script:edges = @()
    $script:nodeIds = @{}
}

# ============================================================================
# Node/Edge helpers (upsert semantics)
# ============================================================================

function Add-Node {
    param($node)
    if ($script:nodeIds.ContainsKey($node.id)) {
        # Update existing node
        $index = 0
        for ($i = 0; $i -lt $script:nodes.Count; $i++) {
            if ($script:nodes[$i].id -eq $node.id) {
                $index = $i
                break
            }
        }
        $script:nodes[$index] = $node
    } else {
        # Add new node
        $script:nodes += $node
        $script:nodeIds[$node.id] = $true
    }
}

function Add-Edge {
    param($source, $target, $type, $description = "")
    # Check for duplicates
    $exists = $script:edges | Where-Object {
        $_.source -eq $source -and $_.target -eq $target -and $_.type -eq $type
    }
    if (-not $exists) {
        $script:edges += @{
            source = $source
            target = $target
            type = $type
            description = $description
        }
    }
}

# ============================================================================
# Extract Tests
# ============================================================================

Write-Host "  📋 Extracting tests..." -ForegroundColor Gray

$testDir = Join-Path $repoRoot ".github/tests"
$testCount = 0
if (Test-Path $testDir) {
    Get-ChildItem -Path $testDir -Filter "*.test.md" | ForEach-Object {
        $testFile = $_
        $testName = $testFile.BaseName -replace '\.test$', ''
        $relativePath = $testFile.FullName.Replace("$repoRoot\", "").Replace('\', '/')
        
        $testNode = @{
            id = "test:$testName"
            type = "test"
            label = $testFile.Name
            cluster = "infra-layer"
            file = $relativePath
            description = "Behavioral test for $testName"
        }
        
        Add-Node $testNode
        $testCount++
        
        # Parse test file to find what it tests (look for skill/protocol mentions)
        $content = Get-Content $testFile.FullName -Raw
        
        # Match skill references: skill:name or @skill-name
        if ($content -match 'skill:([a-z-]+)') {
            $skillId = "skill:$($Matches[1])"
            Add-Edge $testNode.id $skillId "tests" "Validates $skillId behavior"
        }
        
        # Match protocol references
        if ($content -match 'protocol:([a-z-]+)') {
            $protocolId = "protocol:$($Matches[1])"
            Add-Edge $testNode.id $protocolId "tests" "Validates $protocolId workflow"
        }
        
        # Match agent references: @AgentName or agent:name
        if ($content -match '@([A-Z][a-z]+)') {
            $agentName = $Matches[1]
            Add-Edge $testNode.id "agent:$agentName" "tests" "Validates $agentName agent behavior"
        }
    }
}

Write-Host "    ✅ $testCount tests extracted" -ForegroundColor Green

# ============================================================================
# Extract Hooks
# ============================================================================

Write-Host "  🪝 Extracting hooks..." -ForegroundColor Gray

$hookDir = Join-Path $repoRoot ".github/hooks"
$hookCount = 0
if (Test-Path $hookDir) {
    Get-ChildItem -Path $hookDir -File | Where-Object { $_.Name -ne 'README.md' -and $_.Name -ne 'install.ps1' } | ForEach-Object {
        $hookFile = $_
        $hookName = $hookFile.Name  # Keep full name including .ps1
        $relativePath = $hookFile.FullName.Replace("$repoRoot\", "").Replace('\', '/')
        
        $language = if ($hookFile.Extension -eq '.ps1') { 'powershell' } else { 'bash' }
        $triggerEvent = if ($hookName -match '^(pre-commit|pre-push|post-merge)') { $Matches[1] } else { 'unknown' }
        
        $hookNode = @{
            id = "hook:$hookName"
            type = "hook"
            label = $hookFile.Name
            cluster = "infra-layer"
            file = $relativePath
            trigger_event = $triggerEvent
            language = $language
            description = "Git $triggerEvent hook"
        }
        
        Add-Node $hookNode
        $hookCount++
        
        # Parse hook file to find what it runs
        $content = Get-Content $hookFile.FullName -Raw
        
        # Look for direct script references in hooks
        # Pattern: .github/knowledge-graph/build/script-name.ps1
        if ($content -match '\.github[/\\]knowledge-graph[/\\]build[/\\]([a-z-]+)\.ps1') {
            foreach ($match in ([regex]::Matches($content, '\.github[/\\]knowledge-graph[/\\]build[/\\]([a-z-]+)\.ps1'))) {
                $scriptName = $match.Groups[1].Value
                $scriptId = "build-script:$scriptName"
                Add-Edge $hookNode.id $scriptId "runs" "Executes $scriptName during $triggerEvent"
            }
        }
        
        # Look for script names in variable assignments and Join-Path calls
        # Pattern: $var = Join-Path ... 'script-name.ps1'
        if ($content -match "Join-Path.*'([a-z-]+)\.ps1'") {
            foreach ($match in ([regex]::Matches($content, "Join-Path.*'([a-z-]+)\.ps1'"))) {
                $scriptName = $match.Groups[1].Value
                $scriptId = "build-script:$scriptName"
                Add-Edge $hookNode.id $scriptId "runs" "Executes $scriptName during $triggerEvent"
            }
        }
        
        # pre-commit (bash) calls pre-commit.ps1
        if ($hookName -eq 'pre-commit' -and $language -eq 'bash') {
            Add-Edge $hookNode.id "hook:pre-commit.ps1" "runs" "Delegates to PowerShell implementation"
        }
    }
}

Write-Host "    ✅ $hookCount hooks extracted" -ForegroundColor Green

# ============================================================================
# Extract Extensions
# ============================================================================

Write-Host "  🔌 Extracting extensions..." -ForegroundColor Gray

$extDir = Join-Path $repoRoot "extensions"
$extCount = 0
if (Test-Path $extDir) {
    Get-ChildItem -Path $extDir -Directory | ForEach-Object {
        $extFolder = $_
        $packageJson = Join-Path $extFolder.FullName "package.json"
        
        if (Test-Path $packageJson) {
            $package = Get-Content $packageJson -Raw | ConvertFrom-Json
            $relativePath = $packageJson.Replace("$repoRoot\", "").Replace('\', '/')
            
            $extNode = @{
                id = "extension:$($extFolder.Name)"
                type = "extension"
                label = $package.displayName ?? $package.name
                cluster = "infra-layer"
                file = $relativePath
                publisher = $package.publisher
                version = $package.version
                description = $package.description
            }
            
            Add-Node $extNode
            $extCount++
            
            # Parse activationEvents to see what it provides
            if ($package.activationEvents) {
                foreach ($event in $package.activationEvents) {
                    if ($event -eq 'onStartupFinished') {
                        Add-Edge $extNode.id "feature:context-preloading" "provides" "Loads context at session start"
                    }
                }
            }
            
            # Find skills the extension uses (look in source files)
            $srcFiles = Get-ChildItem -Path $extFolder.FullName -Recurse -File -Include "*.ts", "*.js"
            foreach ($srcFile in $srcFiles) {
                $content = Get-Content $srcFile.FullName -Raw
                if ($content -match 'skill[s]?[:/]([a-z-]+)') {
                    $skillId = "skill:$($Matches[1])"
                    Add-Edge $extNode.id $skillId "uses" "Pre-loads $skillId"
                }
            }
        }
    }
}

Write-Host "    ✅ $extCount extensions extracted" -ForegroundColor Green

# ============================================================================
# Extract Build Scripts
# ============================================================================

Write-Host "  📜 Extracting build scripts..." -ForegroundColor Gray

$buildDir = Join-Path $kgRoot "build"
$scriptCount = 0
if (Test-Path $buildDir) {
    Get-ChildItem -Path $buildDir -Filter "*.ps1" | ForEach-Object {
        $scriptFile = $_
        $scriptName = $scriptFile.BaseName
        $relativePath = $scriptFile.FullName.Replace("$repoRoot\", "").Replace('\', '/')
        
        # Determine purpose from name
        $purpose = switch -Regex ($scriptName) {
            '^extract-' { 'extract' }
            '^merge' { 'merge' }
            '^health' { 'validate' }
            '^audit' { 'validate' }
            '^fix-' { 'repair' }
            '^scaffold-' { 'generate' }
            '^rebuild' { 'build' }
            default { 'utility' }
        }
        
        $scriptNode = @{
            id = "build-script:$scriptName"
            type = "build-script"
            label = $scriptFile.Name
            cluster = "infra-layer"
            file = $relativePath
            language = "powershell"
            purpose = $purpose
            description = "Knowledge graph $purpose script"
        }
        
        Add-Node $scriptNode
        $scriptCount++
        
        # Parse script to find what it generates/reads
        $content = Get-Content $scriptFile.FullName -Raw
        
        # Look for output files
        if ($content -match '\$Output\s*=\s*"([^"]+)"' -or $content -match 'Out-File\s+([^\s]+)') {
            $outputFile = $Matches[1]
            if ($outputFile -match '([a-z-]+)\.json') {
                $fileType = $Matches[1]
                Add-Edge $scriptNode.id "code-file:$fileType.json" "generates" "Produces $fileType.json"
            }
        }
        
        # Look for module imports
        if ($content -match 'Import-Module.*\\([a-z-]+\.psm1)') {
            $moduleName = $Matches[1] -replace '\.psm1$', ''
            Add-Edge $scriptNode.id "module:$moduleName" "uses" "Imports $moduleName module"
        }
    }
}

Write-Host "    ✅ $scriptCount build scripts extracted" -ForegroundColor Green

# ============================================================================
# Extract Configs (agent.md files)
# ============================================================================

Write-Host "  ⚙️  Extracting configs..." -ForegroundColor Gray

$agentDir = Join-Path $repoRoot ".github/agents"
$configCount = 0
if (Test-Path $agentDir) {
    Get-ChildItem -Path $agentDir -Filter "*.agent.md" | ForEach-Object {
        $configFile = $_
        $agentName = $configFile.BaseName -replace '\.agent$', ''
        $relativePath = $configFile.FullName.Replace("$repoRoot\", "").Replace('\', '/')
        
        $configNode = @{
            id = "config:$agentName-agent"
            type = "config"
            label = $configFile.Name
            cluster = "infra-layer"
            file = $relativePath
            format = "yaml-frontmatter"
            description = "$agentName agent configuration"
        }
        
        Add-Node $configNode
        $configCount++
        
        # Config configures the agent
        Add-Edge $configNode.id "agent:$agentName" "configures" "Defines $agentName agent behavior"
    }
}

Write-Host "    ✅ $configCount configs extracted" -ForegroundColor Green

# ============================================================================
# Output
# ============================================================================

Write-Host "`n📊 Infrastructure Graph Stats:" -ForegroundColor Cyan
Write-Host "  Nodes: $($script:nodes.Count)" -ForegroundColor White
Write-Host "  Edges: $($script:edges.Count)" -ForegroundColor White

# Preserve existing metadata or create new
if ($existingGraph.metadata) {
    # Convert PSCustomObject to hashtable
    $metadata = @{}
    $existingGraph.metadata.PSObject.Properties | ForEach-Object {
        $metadata[$_.Name] = $_.Value
    }
} else {
    $metadata = @{
        generated_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        generated_by = "mentor-graph"
        version = "1.0"
    }
}

# Add infrastructure extraction timestamp
$metadata['infrastructure_updated_at'] = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
$metadata['infrastructure_updated_by'] = "extract-infrastructure.ps1"

$graph = @{
    nodes = $script:nodes
    edges = $script:edges
    metadata = $metadata
}

# Write back to system graph
$graph | ConvertTo-Json -Depth 32 | Set-Content $systemGraphPath -Encoding UTF8
Write-Host "`n✅ System graph updated: $SystemGraph" -ForegroundColor Green
