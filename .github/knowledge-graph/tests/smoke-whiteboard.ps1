# Smoke test: whiteboard method integration
# Usage: pwsh -NoProfile -File .github/knowledge-graph/tests/smoke-whiteboard.ps1

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..' '..' '..')

$fail = 0
function Check($name, $ok) {
    if ($ok) { Write-Host "  PASS  $name" -ForegroundColor Green }
    else     { Write-Host "  FAIL  $name" -ForegroundColor Red; $script:fail++ }
}

# 1. Graph node + edge
Write-Host "`nGRAPH" -ForegroundColor Cyan
$graph = Get-Content .github/knowledge-graph/output/merged-graph.json -Raw | ConvertFrom-Json
$node = $graph.nodes | Where-Object { $_.id -eq 'method:whiteboard' }
$edge = $graph.edges | Where-Object { $_.source -eq 'agent:mentor' -and $_.target -eq 'method:whiteboard' -and $_.type -eq 'composes' }
Check "node method:whiteboard exists" ($null -ne $node)
Check "edge agent:mentor --[composes]--> method:whiteboard" ($null -ne $edge)
if ($node) { Write-Host "        type=$($node.type) cluster=$($node.cluster)" -ForegroundColor DarkGray }

# 2. Skill file
Write-Host "`nSKILL FILE" -ForegroundColor Cyan
$skillPath = '.github/skills/methods/whiteboard/SKILL.md'
$exists = Test-Path $skillPath
Check "file exists" $exists
if ($exists) {
    $content = Get-Content $skillPath -Raw
    Check "frontmatter (name: whiteboard)" ($content -match '(?ms)^---\s*\r?\nname:\s*whiteboard')
    Check "## The contract"               ($content -match '## The contract')
    Check "## Session shape"              ($content -match '## Session shape')
    Check "## When to use this method"    ($content -match '## When to use this method')
    Check "## Hard rules"                 ($content -match '## Hard rules')
    Check "## When to break the method"   ($content -match '## When to break the method')
    Check "## Altitude calibration"       ($content -match '## Altitude calibration')
    $lines = (Get-Content $skillPath).Count
    Write-Host "        $lines lines total" -ForegroundColor DarkGray
}

# 3. Mentor.agent.md wiring
Write-Host "`nMENTOR AGENT" -ForegroundColor Cyan
$agent = Get-Content .github/agents/Mentor.agent.md -Raw
Check "skills: array references whiteboard"   ($agent -match 'whiteboard/SKILL\.md')
Check "Methods list includes ``whiteboard``"    ($agent -match '`whiteboard`')
Check "## Stub-completion mode section"       ($agent -match '## Stub-completion mode')
Check "core_behavior names vscode_askQuestions" ($agent -match 'vscode_askQuestions')

# 4. ask-as-clickable behavior wired
Write-Host "`nASK-AS-CLICKABLE BEHAVIOR" -ForegroundColor Cyan
$bNode = $graph.nodes | Where-Object { $_.id -eq 'behavior:11-ask-as-clickable' }
$bEdge = $graph.edges | Where-Object { $_.source -eq 'agent:mentor' -and $_.target -eq 'behavior:11-ask-as-clickable' -and $_.type -eq 'follows' }
Check "node behavior:11-ask-as-clickable exists" ($null -ne $bNode)
Check "edge agent:mentor --[follows]--> behavior:11-ask-as-clickable" ($null -ne $bEdge)
$getBehaviorOut = & pwsh -NoProfile -File .github/knowledge-graph/cli/inspect/get-behavior.ps1 'ask-as-clickable' 2>&1 | Out-String
Check "get-behavior.ps1 returns body"             ($getBehaviorOut -match 'vscode_askQuestions')

# Summary
Write-Host ""
if ($fail -eq 0) { Write-Host "ALL CHECKS PASSED" -ForegroundColor Green; exit 0 }
else             { Write-Host "$fail CHECK(S) FAILED" -ForegroundColor Red; exit 1 }
