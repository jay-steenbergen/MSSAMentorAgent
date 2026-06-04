# End-to-end test for mentor.ps1 CLI.
# Adds a throwaway skill, links it to agent:mentor, then undoes both.
# Asserts: graph file and agent file are byte-identical to start.
$ErrorActionPreference = 'Stop'

$repoRoot   = (Resolve-Path "$PSScriptRoot/../../../..").Path
$graphPath  = Join-Path $repoRoot '.github/knowledge-graph/data/MentorAgent/system/mentor-graph.json'
$agentPath  = Join-Path $repoRoot '.github/agents/Mentor.agent.md'
$cli        = Join-Path $repoRoot '.github/knowledge-graph/cli/authoring/mentor.ps1'
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

    # Round-trip the three log node types (session, experiment, decision).
    # Each: add -> remove -> delete stub file. Graph must end byte-identical.
    $logTypes = @(
        @{ type='session';    slug='_e2e-throwaway-session';    file='.github/knowledge-graph/log/sessions/_e2e-throwaway-session.md' }
        @{ type='experiment'; slug='_e2e-throwaway-experiment'; file='.github/knowledge-graph/log/experiments/_e2e-throwaway-experiment.md' }
        @{ type='decision';   slug='_e2e-throwaway-decision';   file='.github/knowledge-graph/log/decisions/_e2e-throwaway-decision.md' }
    )
    foreach ($t in $logTypes) {
        Write-Host ""
        Write-Host "[log] add $($t.type) $($t.slug)" -ForegroundColor Cyan
        & pwsh -NoProfile -File $cli add $t.type $t.slug -Description "e2e throwaway $($t.type)" -NoValidate
        if ($LASTEXITCODE -ne 0) { throw "add $($t.type) failed" }

        Write-Host "[log] remove $($t.type):$($t.slug)" -ForegroundColor Cyan
        & pwsh -NoProfile -File $cli remove "$($t.type):$($t.slug)" -NoValidate
        if ($LASTEXITCODE -ne 0) { throw "remove $($t.type) failed" }

        $stubFile = Join-Path $repoRoot $t.file
        if (Test-Path $stubFile) {
            Remove-Item $stubFile -Force
            Write-Host "    stub file removed: $($t.file)" -ForegroundColor Green
        }
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
