# agent-sync.psm1 — patch `skills:` array in a .agent.md file
#
# Public functions:
#   Add-SkillToAgent     -> appends a relative path to the skills: list (idempotent)
#   Remove-SkillFromAgent -> removes a path from the skills: list (no-op if absent)
#
# Strategy: regex-locate the YAML `skills:` block in the frontmatter, mutate the
# list inside, and write the file back. Refuses to write if the block isn't found.

function _Get-AgentFilePath {
    param([Parameter(Mandatory)][string]$AgentName)
    $repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
    $candidate = Join-Path $repoRoot ".github/agents/$AgentName.agent.md"
    if (-not (Test-Path $candidate)) {
        throw "Agent file not found: $candidate"
    }
    $candidate
}

function _Compute-RelativeSkillPath {
    param([Parameter(Mandatory)][string]$NodeFile)
    # NodeFile is repo-relative e.g. .github/skills/bug-triage/SKILL.md
    # Agent file lives at .github/agents/, so prefix is ../skills/...
    if ($NodeFile -match '^\.github/skills/(.+)$') {
        return "../skills/$($matches[1])"
    }
    throw "Cannot compute relative skill path for non-skill file: $NodeFile"
}

function _Edit-SkillsBlock {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][scriptblock]$Mutator    # takes string[] of paths, returns string[]
    )
    # Match the skills: block — starts with `skills:`, then 0+ indented `- "..."` lines.
    # The block ends at the first non-list, non-blank line, or `---`.
    $pattern = '(?m)^skills:\s*\r?\n((?:[ \t]+-\s*"[^"]+"\s*\r?\n)*)'
    $m = [regex]::Match($Content, $pattern)
    if (-not $m.Success) {
        throw "Could not locate skills: block in agent file. Refusing to edit."
    }
    $listBody = $m.Groups[1].Value
    $items = @()
    foreach ($line in ($listBody -split "`r?`n")) {
        if ($line -match '^\s*-\s*"([^"]+)"\s*$') {
            $items += $matches[1]
        }
    }
    $newItems = & $Mutator $items
    if ($null -eq $newItems) { $newItems = @() }
    # Normalize to array
    $newItems = @($newItems)

    $newBlock = "skills:`n"
    foreach ($it in $newItems) {
        $newBlock += "  - `"$it`"`n"
    }
    # Preserve line endings of original file (best-effort: re-emit with `n; PowerShell on write
    # uses platform default unless told otherwise).
    $Content.Substring(0, $m.Index) + $newBlock + $Content.Substring($m.Index + $m.Length)
}

function Add-SkillToAgent {
    param(
        [Parameter(Mandatory)][string]$AgentName,        # e.g. 'Mentor'
        [Parameter(Mandatory)][string]$SkillNodeFile     # repo-relative path
    )
    $relPath = _Compute-RelativeSkillPath -NodeFile $SkillNodeFile
    $path = _Get-AgentFilePath -AgentName $AgentName
    $content = Get-Content $path -Raw
    $new = _Edit-SkillsBlock -Content $content -Mutator {
        param($items)
        if ($items -contains $relPath) {
            Write-Host "  ($relPath already in $AgentName.agent.md skills, skipping)" -ForegroundColor DarkGray
            return $items
        }
        $items + $relPath
    }.GetNewClosure()
    if ($new -ne $content) {
        Set-Content -Path $path -Value $new -Encoding UTF8 -NoNewline
        Write-Host "  appended $relPath to $AgentName.agent.md" -ForegroundColor DarkGreen
    }
}

function Remove-SkillFromAgent {
    param(
        [Parameter(Mandatory)][string]$AgentName,
        [Parameter(Mandatory)][string]$SkillNodeFile
    )
    $relPath = _Compute-RelativeSkillPath -NodeFile $SkillNodeFile
    $path = _Get-AgentFilePath -AgentName $AgentName
    $content = Get-Content $path -Raw
    $new = _Edit-SkillsBlock -Content $content -Mutator {
        param($items)
        if ($items -notcontains $relPath) {
            Write-Host "  ($relPath not present in $AgentName.agent.md, no-op)" -ForegroundColor DarkGray
            return $items
        }
        $items | Where-Object { $_ -ne $relPath }
    }.GetNewClosure()
    if ($new -ne $content) {
        Set-Content -Path $path -Value $new -Encoding UTF8 -NoNewline
        Write-Host "  removed $relPath from $AgentName.agent.md" -ForegroundColor DarkGreen
    }
}

Export-ModuleMember -Function Add-SkillToAgent, Remove-SkillFromAgent
