#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Knowledge graph query module for the Mentor agent.

.DESCRIPTION
    Runtime graph queries to find skills, dependencies, and relevant context
    based on user intent. Enables the agent to load only what it needs.

.EXAMPLE
    Import-Module .github/knowledge-graph/query.psm1
    $relevant = Get-RelevantSkills -Intent "start learning session" -Graph $graph
#>

# Cache for loaded graph (avoids re-parsing on every query)
$script:GraphCache = $null
$script:GraphCacheTime = $null

function Get-KnowledgeGraph {
    <#
    .SYNOPSIS
        Load and cache the merged knowledge graph.
    #>
    [CmdletBinding()]
    param(
        [switch]$Refresh
    )
    
    $graphPath = Join-Path $PSScriptRoot '../output/merged-graph.json'

    # Check if rebuild needed (best-effort: don't fail graph loads if rebuild is unavailable)
    $rebuildScript = Join-Path $PSScriptRoot '../build/core/rebuild-if-stale.ps1'
    if (Test-Path -LiteralPath $rebuildScript) {
        try { & $rebuildScript -Quiet } catch { Write-Verbose "rebuild-if-stale skipped: $($_.Exception.Message)" }
    }
    
    # Return cached if fresh
    if (-not $Refresh -and $script:GraphCache) {
        $fileTime = (Get-Item $graphPath).LastWriteTime
        if ($script:GraphCacheTime -eq $fileTime) {
            return $script:GraphCache
        }
    }
    
    # Load and cache
    $script:GraphCache = Get-Content $graphPath -Raw | ConvertFrom-Json -Depth 32
    $script:GraphCacheTime = (Get-Item $graphPath).LastWriteTime
    
    return $script:GraphCache
}

function Get-RelevantSkills {
    <#
    .SYNOPSIS
        Find skills relevant to user's stated intent.
    
    .PARAMETER Intent
        User's goal (e.g., "start learning session", "build a REST API")
    
    .PARAMETER Track
        Optional track filter (cloud-app-dev, cybersecurity-ops, etc.)
    
    .PARAMETER MaxResults
        Maximum number of skills to return (default 5)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Intent,
        
        [string]$Track = $null,
        
        [int]$MaxResults = 5
    )
    
    $graph = Get-KnowledgeGraph
    
    # Extract keywords from intent
    $keywords = $Intent.ToLower() -split '\s+' | 
        Where-Object { $_.Length -gt 3 } |
        Where-Object { $_ -notin @('this', 'that', 'with', 'from', 'have', 'want', 'need') }
    
    # Score skills by keyword match
    $scored = @()
    $skills = $graph.nodes | Where-Object { $_.type -eq 'skill' }
    
    foreach ($skill in $skills) {
        $score = 0
        $skillText = "$($skill.label) $($skill.description)" -replace '-', ' '
        
        foreach ($kw in $keywords) {
            if ($skillText -match [regex]::Escape($kw)) { $score += 2 }
            if ($skill.file -match [regex]::Escape($kw)) { $score += 1 }
        }
        
        # Boost if track matches
        if ($Track -and $skill.file -match [regex]::Escape($Track)) {
            $score += 5
        }
        
        if ($score -gt 0) {
            $scored += [PSCustomObject]@{
                Skill = $skill
                Score = $score
            }
        }
    }
    
    # Return top matches
    $results = $scored | Sort-Object Score -Descending | Select-Object -First $MaxResults
    return $results | ForEach-Object { $_.Skill }
}

function Get-SkillDependencies {
    <#
    .SYNOPSIS
        Get all skills that a given skill depends on.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SkillId
    )
    
    $graph = Get-KnowledgeGraph
    
    $deps = @()
    $queue = @($SkillId)
    $visited = @{}
    
    while ($queue.Count -gt 0) {
        $current = $queue[0]
        $queue = $queue[1..($queue.Count-1)]
        
        if ($visited[$current]) { continue }
        $visited[$current] = $true
        
        $edges = $graph.edges | Where-Object { 
            $_.source -eq $current -and $_.type -in @('requires', 'depends_on', 'uses')
        }
        
        foreach ($e in $edges) {
            $target = $graph.nodes | Where-Object { $_.id -eq $e.target }
            if ($target -and $target.type -eq 'skill') {
                $deps += $target
                $queue += $e.target
            }
        }
    }
    
    return $deps
}

function Get-TrackSkills {
    <#
    .SYNOPSIS
        Get all skills for a specific track.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('cloud-app-dev', 'cybersecurity-ops', 'github-copilot', 'server-cloud-admin', 'whiteboarding')]
        [string]$Track
    )
    
    $graph = Get-KnowledgeGraph
    $trackId = "track:$Track"
    
    # Find edges from track to skills
    $edges = $graph.edges | Where-Object { 
        $_.source -eq $trackId -and $_.type -eq 'contains'
    }
    
    $skills = @()
    foreach ($e in $edges) {
        $skill = $graph.nodes | Where-Object { $_.id -eq $e.target -and $_.type -eq 'skill' }
        if ($skill) { $skills += $skill }
    }
    
    return $skills | Sort-Object label
}

function Get-SkillPath {
    <#
    .SYNOPSIS
        Find shortest path from one node to another.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$From,
        
        [Parameter(Mandatory)]
        [string]$To,
        
        [int]$MaxDepth = 5
    )
    
    $graph = Get-KnowledgeGraph
    
    $visited = @{}
    $queue = @(@{ node = $From; path = @($From) })
    
    while ($queue.Count -gt 0) {
        $current = $queue[0]
        $queue = $queue[1..($queue.Count-1)]
        
        if ($current.node -eq $To) { 
            return $current.path 
        }
        
        if ($current.path.Count -ge $MaxDepth) { continue }
        if ($visited[$current.node]) { continue }
        $visited[$current.node] = $true
        
        $edges = $graph.edges | Where-Object { $_.source -eq $current.node }
        foreach ($e in $edges) {
            $newPath = $current.path + @($e.target)
            $queue += @{ node = $e.target; path = $newPath }
        }
    }
    
    return $null
}

function Get-MethodSkills {
    <#
    .SYNOPSIS
        Get skills for a specific teaching method.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('ride-along', 'TDD', 'BDD', 'spike-then-refactor')]
        [string]$Method
    )
    
    $graph = Get-KnowledgeGraph
    $methodId = "skill:$Method"
    
    # Check if method skill exists
    $methodNode = $graph.nodes | Where-Object { $_.id -eq $methodId }
    if (-not $methodNode) { return @() }
    
    return $methodNode
}

function Format-SkillList {
    <#
    .SYNOPSIS
        Format skills as markdown list with file paths (for agent consumption).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]]$Skills
    )
    
    process {
        foreach ($skill in $Skills) {
            "- **$($skill.label)** - $($skill.description) [`$($skill.file)`]"
        }
    }
}

function Get-AgentLoadList {
    <#
    .SYNOPSIS
        Given user intent and method, return prioritized list of skill files to load.
    
    .DESCRIPTION
        This is the main entry point for the agent. Returns an ordered list of
        skill files that should be loaded for the current session.
    
    .PARAMETER Intent
        User's stated goal (e.g., "start learning Python", "build a web API")
    
    .PARAMETER Method
        Teaching method (ride-along, TDD, BDD, spike-then-refactor)
    
    .PARAMETER Track
        Optional track filter
    
    .PARAMETER SkipEssentials
        Skip loading profile/method/track (assume already loaded by extension).
        Use this when the mentor-context-loader extension has pre-loaded essentials.
    
    .OUTPUTS
        Array of file paths (relative to repo root) in load order
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Intent,
        
        [string]$Method = 'ride-along',
        
        [string]$Track = $null,
        
        [switch]$SkipEssentials
    )
    
    $files = @()
    
    if (-not $SkipEssentials) {
        # 1. Load learner-profile (session foundation)
        $files += '.github/skills/learner-profile/SKILL.md'
        
        # 2. Load the method skill
        $methodSkill = Get-MethodSkills -Method $Method
        if ($methodSkill -and $methodSkill.file -notin $files) {
            $files += $methodSkill.file
        }
    }
    
    # 3. Load intent-matched skills (always included)
    $relevant = Get-RelevantSkills -Intent $Intent -Track $Track -MaxResults 3
    foreach ($skill in $relevant) {
        if ($skill.file -notin $files) {
            $files += $skill.file
        }
    }
    
    if (-not $SkipEssentials) {
        # 4. If track specified, load track README
        if ($Track) {
            $trackFile = ".github/skills/tracks/$Track/README.md"
            if ($trackFile -notin $files) {
                $files += $trackFile
            }
        }
    }
    
    return $files
}

function Get-GraphQualityReport {
    <#
    .SYNOPSIS
        Generate a quality report for the knowledge graph.
    
    .DESCRIPTION
        Finds quality issues: orphan skills, dead-end skills, broken references,
        missing descriptions, unclustered nodes, untested skills.
    
    .PARAMETER Category
        Filter to specific category: orphans, dead-ends, broken-refs, no-description,
        unclustered, untested, all (default).
    
    .EXAMPLE
        Get-GraphQualityReport
        Get-GraphQualityReport -Category orphans
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('all', 'orphans', 'dead-ends', 'broken-refs', 'no-description', 'unclustered', 'untested')]
        [string]$Category = 'all'
    )
    
    $graph = Get-KnowledgeGraph
    $report = @{
        orphans = @()
        dead_ends = @()
        broken_refs = @()
        no_description = @()
        unclustered = @()
        untested = @()
    }
    
    # Filter to skill/method/track nodes only
    $checkNodes = $graph.nodes | Where-Object { $_.type -in @('skill', 'method', 'track') }
    
    foreach ($node in $checkNodes) {
        # Check 1: Orphans (no incoming edges - nothing references this skill)
        if ($Category -in @('all', 'orphans')) {
            $incomingEdges = $graph.edges | Where-Object { $_.target -eq $node.id }
            if (-not $incomingEdges) {
                $report.orphans += [PSCustomObject]@{
                    id = $node.id
                    label = $node.label
                    type = $node.type
                    file = $node.file
                    issue = "No incoming edges - nothing references this skill"
                }
            }
        }
        
        # Check 2: Dead-ends (no outgoing edges - skill doesn't reference anything)
        if ($Category -in @('all', 'dead-ends')) {
            $outgoingEdges = $graph.edges | Where-Object { $_.source -eq $node.id }
            if (-not $outgoingEdges) {
                $report.dead_ends += [PSCustomObject]@{
                    id = $node.id
                    label = $node.label
                    type = $node.type
                    file = $node.file
                    issue = "No outgoing edges - skill is isolated"
                }
            }
        }
        
        # Check 3: Broken file references
        # $PSScriptRoot = .github/knowledge-graph/lib  →  three `..` lands at repo root.
        # $node.file is repo-root-relative (e.g. ".github/skills/.../SKILL.md").
        if ($Category -in @('all', 'broken-refs')) {
            if ($node.file) {
                $fullPath = Join-Path $PSScriptRoot ".." ".." ".." $node.file
                if (-not (Test-Path $fullPath)) {
                    $report.broken_refs += [PSCustomObject]@{
                        id = $node.id
                        label = $node.label
                        type = $node.type
                        file = $node.file
                        issue = "File does not exist: $($node.file)"
                    }
                }
            }
        }
        
        # Check 4: Missing description
        if ($Category -in @('all', 'no-description')) {
            if (-not $node.description -or $node.description -match '^\s*$') {
                $report.no_description += [PSCustomObject]@{
                    id = $node.id
                    label = $node.label
                    type = $node.type
                    file = $node.file
                    issue = "No description - makes keyword search ineffective"
                }
            }
        }
        
        # Check 5: Unclustered
        if ($Category -in @('all', 'unclustered')) {
            if (-not $node.cluster -or $node.cluster -match '^\s*$') {
                $report.unclustered += [PSCustomObject]@{
                    id = $node.id
                    label = $node.label
                    type = $node.type
                    file = $node.file
                    issue = "Not assigned to any cluster"
                }
            }
        }
        
        # Check 6: Untested (no test: nodes pointing at this skill)
        if ($Category -in @('all', 'untested')) {
            $testEdges = $graph.edges | Where-Object { 
                $_.target -eq $node.id -and $_.type -eq 'tests'
            }
            if (-not $testEdges) {
                $report.untested += [PSCustomObject]@{
                    id = $node.id
                    label = $node.label
                    type = $node.type
                    file = $node.file
                    issue = "No test coverage"
                }
            }
        }
    }
    
    return $report
}

function Get-SkillImpact {
    <#
    .SYNOPSIS
        Show what depends on this skill (impact analysis).
    
    .DESCRIPTION
        Finds all skills, agents, and workflows that reference this skill.
        Shows what would break if you changed or removed this skill.
    
    .PARAMETER SkillId
        The skill ID to analyze (e.g., "skill:learner-profile").
    
    .PARAMETER IncludeIndirect
        Include indirect dependencies (dependencies of dependencies).
    
    .EXAMPLE
        Get-SkillImpact -SkillId "skill:learner-profile"
        Get-SkillImpact -SkillId "skill:ride-along" -IncludeIndirect
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SkillId,
        
        [switch]$IncludeIndirect
    )
    
    $graph = Get-KnowledgeGraph
    
    # Direct dependents (things that reference this skill)
    $directEdges = $graph.edges | Where-Object { 
        $_.target -eq $SkillId -and 
        $_.type -in @('composes', 'requires', 'depends_on', 'uses', 'references', 'delegates_to')
    }
    
    $impact = @{
        direct = @()
        indirect = @()
        summary = @{
            agents = 0
            skills = 0
            tracks = 0
            behaviors = 0
            total = 0
        }
    }
    
    # Collect direct dependents
    foreach ($e in $directEdges) {
        $source = $graph.nodes | Where-Object { $_.id -eq $e.source }
        if ($source) {
            $impact.direct += [PSCustomObject]@{
                id = $source.id
                label = $source.label
                type = $source.type
                file = $source.file
                edge_type = $e.type
                relationship = "$($source.label) --$($e.type)--> $SkillId"
            }
            
            # Count by type
            switch -Wildcard ($source.type) {
                'agent*' { $impact.summary.agents++ }
                'skill*' { $impact.summary.skills++ }
                'track*' { $impact.summary.tracks++ }
                'behavior*' { $impact.summary.behaviors++ }
            }
            $impact.summary.total++
        }
    }
    
    # Indirect dependents (if requested)
    if ($IncludeIndirect) {
        $visited = @{}
        $queue = @($impact.direct | ForEach-Object { $_.id })
        
        while ($queue.Count -gt 0) {
            $current = $queue[0]
            $queue = $queue[1..($queue.Count-1)]
            
            if ($visited[$current]) { continue }
            $visited[$current] = $true
            
            $indirectEdges = $graph.edges | Where-Object { 
                $_.target -eq $current -and 
                $_.type -in @('composes', 'requires', 'depends_on', 'uses')
            }
            
            foreach ($e in $indirectEdges) {
                $source = $graph.nodes | Where-Object { $_.id -eq $e.source }
                if ($source -and $source.id -ne $SkillId) {
                    $impact.indirect += [PSCustomObject]@{
                        id = $source.id
                        label = $source.label
                        type = $source.type
                        file = $source.file
                        via = $current
                        relationship = "$($source.label) --$($e.type)--> $current (which uses $SkillId)"
                    }
                    $queue += $e.source
                }
            }
        }
    }
    
    return $impact
}

function Get-SkillRecommendations {
    <#
    .SYNOPSIS
        Recommend next skills based on completed skills.
    
    .DESCRIPTION
        Suggests what to learn next by analyzing:
        - Skills directly connected via 'recommends' or 'leads_to' edges
        - Skills in the same cluster
        - Skills required by more advanced skills
        - Skills commonly learned together
    
    .PARAMETER CompletedSkills
        Array of completed skill IDs (e.g., @("skill:learner-profile", "skill:ride-along")).
    
    .PARAMETER Track
        Optional track filter (only recommend skills from this track).
    
    .PARAMETER MaxResults
        Maximum number of recommendations. Default 5.
    
    .EXAMPLE
        Get-SkillRecommendations -CompletedSkills @("skill:cad-hello-console")
        Get-SkillRecommendations -CompletedSkills @("skill:ride-along") -Track "cloud-app-dev"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$CompletedSkills,
        
        [ValidateSet('cloud-app-dev', 'cybersecurity-ops', 'github-copilot', 'server-cloud-admin', 'whiteboarding')]
        [string]$Track,
        
        [int]$MaxResults = 5
    )
    
    $graph = Get-KnowledgeGraph
    $candidates = @{}
    
    foreach ($completedId in $CompletedSkills) {
        $completed = $graph.nodes | Where-Object { $_.id -eq $completedId }
        if (-not $completed) { continue }
        
        # Strategy 1: Direct recommendations (recommends, leads_to edges)
        $directEdges = $graph.edges | Where-Object { 
            $_.source -eq $completedId -and 
            $_.type -in @('recommends', 'leads_to', 'unlocks')
        }
        foreach ($e in $directEdges) {
            $target = $graph.nodes | Where-Object { $_.id -eq $e.target -and $_.type -in @('skill', 'track') }
            if ($target -and $target.id -notin $CompletedSkills) {
                if (-not $candidates[$target.id]) {
                    $candidates[$target.id] = @{ node = $target; score = 0; reasons = @() }
                }
                $candidates[$target.id].score += 50
                $candidates[$target.id].reasons += "Directly recommended after $($completed.label)"
            }
        }
        
        # Strategy 2: Same cluster (related skills)
        if ($completed.cluster) {
            $clusterSkills = $graph.nodes | Where-Object { 
                $_.cluster -eq $completed.cluster -and 
                $_.type -in @('skill', 'track') -and 
                $_.id -ne $completedId -and 
                $_.id -notin $CompletedSkills
            }
            foreach ($cs in $clusterSkills) {
                if (-not $candidates[$cs.id]) {
                    $candidates[$cs.id] = @{ node = $cs; score = 0; reasons = @() }
                }
                $candidates[$cs.id].score += 20
                $candidates[$cs.id].reasons += "In same cluster: $($completed.cluster)"
            }
        }
        
        # Strategy 3: Required by advanced skills
        $advancedEdges = $graph.edges | Where-Object { 
            $_.target -eq $completedId -and 
            $_.type -in @('requires', 'depends_on')
        }
        foreach ($e in $advancedEdges) {
            $advanced = $graph.nodes | Where-Object { $_.id -eq $e.source -and $_.type -eq 'skill' }
            if ($advanced -and $advanced.id -notin $CompletedSkills) {
                if (-not $candidates[$advanced.id]) {
                    $candidates[$advanced.id] = @{ node = $advanced; score = 0; reasons = @() }
                }
                $candidates[$advanced.id].score += 30
                $candidates[$advanced.id].reasons += "Builds on $($completed.label) (next level)"
            }
        }
        
        # Strategy 4: Track progression
        if ($completed.type -eq 'skill') {
            # Find what track contains this skill
            $trackEdges = $graph.edges | Where-Object { 
                $_.target -eq $completedId -and $_.type -eq 'contains'
            }
            foreach ($te in $trackEdges) {
                # Get next skills in same track
                $trackSkills = $graph.edges | Where-Object { 
                    $_.source -eq $te.source -and 
                    $_.type -eq 'contains' -and 
                    $_.target -ne $completedId
                }
                foreach ($ts in $trackSkills) {
                    $trackSkill = $graph.nodes | Where-Object { $_.id -eq $ts.target -and $_.id -notin $CompletedSkills }
                    if ($trackSkill) {
                        if (-not $candidates[$trackSkill.id]) {
                            $candidates[$trackSkill.id] = @{ node = $trackSkill; score = 0; reasons = @() }
                        }
                        $candidates[$trackSkill.id].score += 15
                        $candidates[$trackSkill.id].reasons += "Next in track progression"
                    }
                }
            }
        }
    }
    
    # Filter by track if specified
    if ($Track) {
        $trackId = "track:$Track"
        $trackSkillIds = @($graph.edges | Where-Object { $_.source -eq $trackId -and $_.type -eq 'contains' } | ForEach-Object { $_.target })
        $candidates = $candidates.GetEnumerator() | Where-Object { $_.Key -in $trackSkillIds } | ForEach-Object { @{ $_.Key = $_.Value } }
    }
    
    # Build results
    $results = @()
    foreach ($kvp in $candidates.GetEnumerator()) {
        $results += [PSCustomObject]@{
            id = $kvp.Value.node.id
            label = $kvp.Value.node.label
            type = $kvp.Value.node.type
            file = $kvp.Value.node.file
            description = $kvp.Value.node.description
            cluster = $kvp.Value.node.cluster
            score = $kvp.Value.score
            reasons = $kvp.Value.reasons -join "; "
            priority = if ($kvp.Value.score -ge 50) { "HIGH" }
                      elseif ($kvp.Value.score -ge 30) { "MEDIUM" }
                      else { "LOW" }
        }
    }
    
    return $results | Sort-Object -Property score -Descending | Select-Object -First $MaxResults
}

function Find-SimilarSkills {
    <#
    .SYNOPSIS
        Check if similar skills already exist before creating a new one.
    
    .DESCRIPTION
        Prevents duplicate work by finding existing skills that match
        the proposed name or description. Returns similarity scores.
    
    .PARAMETER Name
        Proposed skill name (e.g., "learn-git-basics").
    
    .PARAMETER Description
        Proposed skill description (e.g., "Teach Git version control fundamentals").
    
    .PARAMETER Threshold
        Minimum similarity score (0-100). Default 30.
    
    .PARAMETER MaxResults
        Maximum number of results to return. Default 10.
    
    .EXAMPLE
        Find-SimilarSkills -Name "git-basics" -Description "learn Git version control"
        Find-SimilarSkills -Name "api-auth" -Threshold 50
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [string]$Description = "",
        
        [ValidateRange(0, 100)]
        [int]$Threshold = 30,
        
        [int]$MaxResults = 10
    )
    
    $graph = Get-KnowledgeGraph
    
    # Normalize search terms
    $nameLower = $Name.ToLower() -replace '[^a-z0-9\s]', ' '
    $nameWords = ($nameLower -split '\s+') | Where-Object { $_.Length -gt 2 }
    
    $descLower = $Description.ToLower() -replace '[^a-z0-9\s]', ' '
    $descWords = ($descLower -split '\s+') | Where-Object { $_.Length -gt 2 }
    
    $allWords = @($nameWords) + @($descWords) | Select-Object -Unique
    
    # Score all skills
    $results = @()
    $skills = $graph.nodes | Where-Object { $_.type -in @('skill', 'track', 'method') }
    
    foreach ($skill in $skills) {
        $score = 0
        
        # Skill label matching (weighted heavily)
        $skillLabelLower = $skill.label.ToLower() -replace '[^a-z0-9\s]', ' '
        foreach ($word in $nameWords) {
            if ($skillLabelLower -match "\b$word\b") {
                $score += 30
            } elseif ($skillLabelLower -match $word) {
                $score += 15
            }
        }
        
        # Skill ID matching
        $skillIdLower = $skill.id.ToLower()
        foreach ($word in $nameWords) {
            if ($skillIdLower -match "\b$word\b") {
                $score += 20
            } elseif ($skillIdLower -match $word) {
                $score += 10
            }
        }
        
        # Description matching
        if ($skill.description) {
            $skillDescLower = $skill.description.ToLower() -replace '[^a-z0-9\s]', ' '
            foreach ($word in $allWords) {
                if ($skillDescLower -match "\b$word\b") {
                    $score += 5
                }
            }
        }
        
        # File path matching
        if ($skill.file) {
            $filePathLower = $skill.file.ToLower()
            foreach ($word in $nameWords) {
                if ($filePathLower -match $word) {
                    $score += 10
                }
            }
        }
        
        if ($score -ge $Threshold) {
            $results += [PSCustomObject]@{
                id = $skill.id
                label = $skill.label
                type = $skill.type
                file = $skill.file
                description = $skill.description
                cluster = $skill.cluster
                score = $score
                recommendation = if ($score -ge 70) { "EXACT MATCH - Don't build, use this" }
                                elseif ($score -ge 50) { "VERY SIMILAR - Review before building" }
                                elseif ($score -ge 30) { "SIMILAR - Check for overlap" }
                                else { "WEAK MATCH - Likely different" }
            }
        }
    }
    
    return $results | Sort-Object -Property score -Descending | Select-Object -First $MaxResults
}

function Get-LearnerProgress {
    <#
    .SYNOPSIS
    Get learner progress across all projects and tracks.
    
    .DESCRIPTION
    Reads learner profile and progress files to calculate:
    - Completion percentage per track
    - Skills completed, in-progress, and recommended
    - Track milestones status
    - Session history summary
    
    .PARAMETER Username
    GitHub username of the learner (maps to profile folder)
    
    .PARAMETER Track
    Optional: Filter to specific track (cloud-app-dev, server-cloud-admin, cybersecurity-ops)
    
    .PARAMETER IncludeRecommendations
    Include skill recommendations based on completed work (default: true)
    
    .EXAMPLE
    Get-LearnerProgress -Username "alex_smith"
    
    .EXAMPLE
    Get-LearnerProgress -Username "alex_smith" -Track "cloud-app-dev"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Username,
        
        [string]$Track,
        
        [switch]$IncludeRecommendations
    )
    
    # Default IncludeRecommendations to true unless explicitly set to false
    if (-not $PSBoundParameters.ContainsKey('IncludeRecommendations')) {
        $IncludeRecommendations = $true
    }
    
    $scriptDir = (Resolve-Path "$PSScriptRoot\..").Path
    $profilePath = Join-Path $scriptDir "..\..\.profiles\profiles\mentees\$Username\profile.json"
    
    if (-not (Test-Path $profilePath)) {
        Write-Error "Profile not found: $profilePath"
        return $null
    }
    
    # Read profile
    $profile = Get-Content $profilePath -Raw | ConvertFrom-Json -Depth 32
    
    # Initialize result
    $result = [ordered]@{
        username = $Username
        name = $profile.name
        preferred_name = $profile.preferred_name
        last_updated = $profile.last_updated
        tracks = [ordered]@{}
        all_projects = @()
        completed_skills = @()
        in_progress = @()
        recommendations = @()
    }
    
    # Process each project
    foreach ($projectId in $profile.projects.PSObject.Properties.Name) {
        $project = $profile.projects.$projectId
        
        # Read progress file if exists
        $progressPath = Join-Path (Split-Path $profilePath) "$projectId.progress.json"
        $progressData = if (Test-Path $progressPath) {
            Get-Content $progressPath -Raw | ConvertFrom-Json -Depth 32
        } else { $null }
        
        # Build project summary
        $projectSummary = [ordered]@{
            project_id = $projectId
            display_name = $project.display_name
            track = $project.track
            status = $project.status
            last_session = if ($project.status -eq 'in_progress') { $project.last_session } else { $project.completed_at }
            current_step = if ($progressData) { $progressData.current_step } else { 0 }
            total_steps = if ($progressData) { $progressData.total_steps } else { 0 }
            milestones = if ($progressData) { $progressData.completed_milestones } else { @() }
            method = if ($progressData) { $progressData.last_used_method } else { 'ride-along' }
            sessions = if ($progressData) { $progressData.session_history.Count } else { 0 }
        }
        
        $result.all_projects += $projectSummary
        
        # Track-level aggregation
        $trackName = $project.track
        if (-not $result.tracks.Contains($trackName)) {
            $result.tracks[$trackName] = [ordered]@{
                name = $trackName
                total_projects = 0
                completed_projects = 0
                in_progress_projects = 0
                total_milestones = 0
                completed_milestones = 0
                projects = @()
            }
        }
        
        $result.tracks[$trackName].projects += $projectSummary
        $result.tracks[$trackName].total_projects++
        
        if ($project.status -eq 'completed') {
            $result.tracks[$trackName].completed_projects++
            $result.completed_skills += $projectId
        } elseif ($project.status -eq 'in_progress') {
            $result.tracks[$trackName].in_progress_projects++
            $result.in_progress += $projectSummary
        }
        
        if ($progressData) {
            $result.tracks[$trackName].total_milestones += $progressData.total_steps
            $result.tracks[$trackName].completed_milestones += $progressData.completed_milestones.Count
        }
    }
    
    # Calculate track completion percentages
    foreach ($trackName in $result.tracks.Keys) {
        $trackData = $result.tracks[$trackName]
        $percentComplete = if ($trackData.total_milestones -gt 0) {
            [math]::Round(100.0 * $trackData.completed_milestones / $trackData.total_milestones, 1)
        } else { 0 }
        $result.tracks[$trackName].percent_complete = $percentComplete
    }
    
    # Get recommendations if requested
    if ($IncludeRecommendations -and $result.completed_skills.Count -gt 0) {
        $completedWithPrefix = $result.completed_skills | ForEach-Object {
            if ($_ -notlike 'skill:*') { "skill:$_" } else { $_ }
        }
        
        $recommendations = Get-SkillRecommendations -CompletedSkills $completedWithPrefix -MaxResults 5
        $result.recommendations = $recommendations
    }
    
    # Filter by track if specified
    if ($Track) {
        if ($result.tracks.Contains($Track)) {
            $filteredTracks = [ordered]@{}
            $filteredTracks[$Track] = $result.tracks[$Track]
            $result.tracks = $filteredTracks
        } else {
            Write-Warning "Track '$Track' not found in learner's projects"
        }
    }
    
    return $result
}

# Export functions
Export-ModuleMember -Function @(
    'Get-KnowledgeGraph'
    'Get-RelevantSkills'
    'Get-SkillDependencies'
    'Get-TrackSkills'
    'Get-SkillPath'
    'Get-MethodSkills'
    'Format-SkillList'
    'Get-AgentLoadList'
    'Get-GraphQualityReport'
    'Find-SimilarSkills'
    'Get-SkillImpact'
    'Get-SkillRecommendations'
    'Get-LearnerProgress'
)
