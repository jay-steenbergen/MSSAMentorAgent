# Isolation test for scaffold.psm1
# Scaffolds one stub of each type to a sandbox dir, asserts shape, then cleans up.
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../lib/scaffold.psm1" -Force

# We'll generate all eight types into a sandbox prefix so we don't pollute real dirs.
# Trick: pass a slug that begins with `_test-stub-` and we'll grep+delete that pattern after.
$cases = @(
    @{ Type='agent';      Id='agent:_test-stub-agent';           Label='_TestStubAgent';        Desc='throwaway agent' },
    @{ Type='skill';      Id='skill:_test-stub-skill';           Label='_test-stub-skill';      Desc='throwaway skill' },
    @{ Type='method';     Id='method:_test-stub-method';         Label='_test-stub-method';     Desc='throwaway method' },
    @{ Type='track';      Id='track:_test-stub-track';           Label='_test-stub-track';      Desc='throwaway track' },
    @{ Type='test';       Id='test:_test-stub-test';             Label='_test-stub-test';       Desc='throwaway test' },
    @{ Type='session';    Id='session:_test-stub-session';       Label='_test-stub-session';    Desc='throwaway session' },
    @{ Type='experiment'; Id='experiment:_test-stub-experiment'; Label='_test-stub-experiment'; Desc='throwaway experiment' },
    @{ Type='decision';   Id='decision:_test-stub-decision';     Label='_test-stub-decision';   Desc='throwaway decision' }
)

$repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
$created = @()

foreach ($c in $cases) {
    $res = New-StubFile -Type $c.Type -Id $c.Id -Label $c.Label -Description $c.Desc
    $abs = Join-Path $repoRoot $res.Path
    if (-not (Test-Path $abs)) {
        Write-Host "FAIL: $($c.Type) stub not created at $($res.Path)" -ForegroundColor Red; exit 1
    }
    $content = Get-Content $abs -Raw
    if ($content -notmatch '_TODO: ask Mentor to help write this\._') {
        Write-Host "FAIL: $($c.Type) stub missing TODO marker" -ForegroundColor Red; exit 1
    }
    Write-Host "  $($c.Type) stub OK: $($res.Path)" -ForegroundColor Green
    $created += $abs
}

# Idempotency: re-scaffold should not overwrite.
$existingPath = (New-StubFile -Type 'skill' -Id 'skill:_test-stub-skill' -Label '_test-stub-skill' -Description 'x').Path
$absExisting = Join-Path $repoRoot $existingPath
$contentBefore = Get-Content $absExisting -Raw
if ($contentBefore -notmatch 'throwaway skill') {
    Write-Host "FAIL: existing stub was overwritten" -ForegroundColor Red; exit 1
}
Write-Host "Idempotency: OK" -ForegroundColor Green

# Cleanup — remove each stub file AND its parent dir if newly created and empty.
foreach ($abs in $created) {
    Remove-Item $abs -Force
    $parent = Split-Path $abs -Parent
    # Only remove parent if it's a stub-test-prefixed leaf dir and empty.
    if ((Split-Path $parent -Leaf) -match '^_test-stub-' -and -not (Get-ChildItem $parent -Force)) {
        Remove-Item $parent -Force
    }
}
# The agent file scaffold dir is .github/agents/ (shared) — file deleted, dir stays.
# Same for .github/tests/.

Write-Host ""
Write-Host "scaffold.psm1 OK" -ForegroundColor Green
