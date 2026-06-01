# End-to-end test for mentor.ps1 CLI.
# Adds a throwaway skill, links it to agent:mentor, then undoes both.
# Asserts: graph file and agent file are byte-identical to start.
$ErrorActionPreference = 'Stop'

$repoRoot   = (Resolve-Path "$PSScriptRoot/../../../..").Path
$graphPath  = Join-Path $repoRoot '.github/knowledge-graph/data/MentorAgent/system/mentor-graph.json'
$agentPath  = Join-Path $repoRoot '.github/agents/Mentor.agent.md'
$cli        = Join-Path $repoRoot '.github/knowledge-graph/cli/mentor.ps1'
$stubDir    = Join-Path $repoRoot '.github/skills/_e2e-throwaway'

Push-Location $repoRoot
try {
    $hashG0 = (Get-FileHash $graphPath).Hash
    $hashA0 = (Get-FileHash $agentPath).Hash
    Write-Host ""
    Write-Host "PRE graph hash:  $hashG0"
    Write-Host "PRE agent hash:  $hashA0"
    Write-Host ""

    Write-Host "[1/4] add skill _e2e-throwaway" -ForegroundColor Cyan
    & pwsh -NoProfile -File $cli add skill _e2e-throwaway -Description "e2e throwaway" -NoValidate
    if ($LASTEXITCODE -ne 0) { throw "add failed" }

    Write-Host ""
    Write-Host "[2/4] link agent:mentor -> skill:_e2e-throwaway (composes)" -ForegroundColor Cyan
    & pwsh -NoProfile -File $cli link agent:mentor skill:_e2e-throwaway composes -NoValidate
    if ($LASTEXITCODE -ne 0) { throw "link failed" }

    # Verify agent file picked it up.
    $agentNow = Get-Content $agentPath -Raw
    if ($agentNow -notmatch '_e2e-throwaway') {
        throw "Agent file did not get the skill link"
    }
    Write-Host "    agent file has the link: OK" -ForegroundColor Green

    Write-Host ""
    Write-Host "[3/4] unlink agent:mentor -> skill:_e2e-throwaway" -ForegroundColor Cyan
    & pwsh -NoProfile -File $cli unlink agent:mentor skill:_e2e-throwaway composes -NoValidate
    if ($LASTEXITCODE -ne 0) { throw "unlink failed" }

    Write-Host ""
    Write-Host "[4/4] remove skill:_e2e-throwaway" -ForegroundColor Cyan
    & pwsh -NoProfile -File $cli remove skill:_e2e-throwaway -NoValidate
    if ($LASTEXITCODE -ne 0) { throw "remove failed" }

    # Delete the stub file we scaffolded.
    if (Test-Path $stubDir) {
        Remove-Item $stubDir -Recurse -Force
        Write-Host "    stub dir removed: OK" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Round-trip hashes:" -ForegroundColor Cyan
    $hashG1 = (Get-FileHash $graphPath).Hash
    $hashA1 = (Get-FileHash $agentPath).Hash
    Write-Host "  POST graph: $hashG1"
    Write-Host "  POST agent: $hashA1"

    $ok = $true
    if ($hashG0 -ne $hashG1) {
        Write-Host "  GRAPH DIFFERS — round-trip failed" -ForegroundColor Red
        $ok = $false
    }
    if ($hashA0 -ne $hashA1) {
        Write-Host "  AGENT DIFFERS — round-trip failed" -ForegroundColor Red
        $ok = $false
    }
    if ($ok) {
        Write-Host ""
        Write-Host "E2E ROUND-TRIP: OK" -ForegroundColor Green
        Write-Host ""
        Write-Host "Now running full validate (rebuild + gap-analysis)..." -ForegroundColor Cyan
        & pwsh -NoProfile -File $cli validate
    } else {
        exit 1
    }
} finally {
    Pop-Location
}
