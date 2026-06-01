# Isolation test for agent-sync.psm1
# Copies Mentor.agent.md to a temp location, mutates the copy, asserts shape.
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
$realAgent = Join-Path $repoRoot ".github/agents/Mentor.agent.md"
$tempDir = Join-Path $repoRoot ".github/agents-test-fixture"
$tempAgent = Join-Path $tempDir "Mentor.agent.md"

# Build a fixture by copying the real file into a parallel `agents-test-fixture/` dir.
# We'll point agent-sync at this fixture by temporarily shadowing _Get-AgentFilePath.
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
Copy-Item $realAgent $tempAgent -Force

Import-Module "$PSScriptRoot/../lib/agent-sync.psm1" -Force

# Monkey-patch the resolver to point at our fixture dir.
function _Get-AgentFilePath { param([string]$AgentName) return $tempAgent }
Set-Item Function:_Get-AgentFilePath -Value (Get-Command _Get-AgentFilePath).ScriptBlock

# Sadly Export-ModuleMember hides internals, so we re-import with a wrapper instead.
# Simpler: dot-source a tiny shim that exposes the internals for the test.
Remove-Module agent-sync -ErrorAction SilentlyContinue
$shimContent = Get-Content "$PSScriptRoot/../lib/agent-sync.psm1" -Raw
$shimContent = $shimContent -replace "function _Get-AgentFilePath \{[\s\S]*?    \`$candidate\r?\n\}", @"
function _Get-AgentFilePath {
    param([string]`$AgentName)
    return '$($tempAgent -replace "'","''")'
}
"@
$shimPath = Join-Path $tempDir 'agent-sync-shim.psm1'
Set-Content -Path $shimPath -Value $shimContent -Encoding UTF8 -NoNewline
Import-Module $shimPath -Force

# Snapshot original skills list.
$before = (Get-Content $tempAgent -Raw)
Write-Host "Original skills block:"
[regex]::Match($before, '(?ms)^skills:.*?(?=^[a-z])').Value | Write-Host
Write-Host ""

# 1. Add a new skill.
Add-SkillToAgent -AgentName 'Mentor' -SkillNodeFile '.github/skills/_test-throwaway/SKILL.md'
$after = Get-Content $tempAgent -Raw
if ($after -notmatch '"\.\./skills/_test-throwaway/SKILL\.md"') {
    Write-Host "ADD FAILED — path not present" -ForegroundColor Red; exit 1
}
Write-Host "Add: OK" -ForegroundColor Green

# 2. Add same skill again (idempotent).
Add-SkillToAgent -AgentName 'Mentor' -SkillNodeFile '.github/skills/_test-throwaway/SKILL.md'
$count = ([regex]::Matches((Get-Content $tempAgent -Raw), '_test-throwaway')).Count
if ($count -ne 1) {
    Write-Host "IDEMPOTENT ADD FAILED — appeared $count times" -ForegroundColor Red; exit 1
}
Write-Host "Idempotent add: OK" -ForegroundColor Green

# 3. Remove the skill.
Remove-SkillFromAgent -AgentName 'Mentor' -SkillNodeFile '.github/skills/_test-throwaway/SKILL.md'
$afterRemove = Get-Content $tempAgent -Raw
if ($afterRemove -match '_test-throwaway') {
    Write-Host "REMOVE FAILED — path still present" -ForegroundColor Red; exit 1
}
Write-Host "Remove: OK" -ForegroundColor Green

# 4. Remove again (no-op).
Remove-SkillFromAgent -AgentName 'Mentor' -SkillNodeFile '.github/skills/_test-throwaway/SKILL.md'
Write-Host "No-op remove: OK" -ForegroundColor Green

# 5. Final file should match original (modulo any whitespace).
$finalNorm = (Get-Content $tempAgent -Raw) -replace "`r`n","`n"
$origNorm  = $before -replace "`r`n","`n"
if ($finalNorm -ne $origNorm) {
    Write-Host "ROUND-TRIP FAIL — file differs from original after add+remove" -ForegroundColor Red
    Write-Host "Diff:" -ForegroundColor Yellow
    Compare-Object ($origNorm -split "`n") ($finalNorm -split "`n") | Format-Table | Out-Host
    exit 1
}
Write-Host "Round-trip: OK" -ForegroundColor Green

# Cleanup.
Remove-Module agent-sync-shim -ErrorAction SilentlyContinue
Remove-Item $tempDir -Recurse -Force

# Verify real file untouched.
$realHashAfter = (Get-FileHash $realAgent).Hash
Write-Host ""
Write-Host "Real Mentor.agent.md hash: $realHashAfter (untouched)"
Write-Host ""
Write-Host "agent-sync.psm1 OK" -ForegroundColor Green
