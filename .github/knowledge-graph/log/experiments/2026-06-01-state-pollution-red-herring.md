---
id: 2026-06-01-state-pollution-red-herring
type: experiment
description: "Test failure during Move 3 GREEN turned out to be orphan stub nodes from prior debug runs, not a code bug"
run_at: 2026-06-01
result: partial  # passed after cleanup, failed on first attempt due to state pollution
---

# Experiment: 2026-06-01-state-pollution-red-herring

During Move 3 (extending `mentor.ps1` to accept session/experiment/decision types) the round-trip end-to-end test failed partway through with `Cannot create a file when that file already exists`. The fix took longer than the underlying code change because the test failure pointed at the wrong layer.

## Hypothesis

Initial hypothesis: a bug in `Cmd-Add` or the scaffold module — file creation logic must be wrong for the new types.

Actual root cause: the test was running against a graph that still contained orphan nodes (`experiment:_debug-*`) and orphan stub files left over from prior `_debug-add.ps1` harness runs. Re-running `add experiment _debug-foo` against a node that already existed tripped the duplicate-file guard, but the error surfaced as if the new code path were broken.

## Operations

```powershell
# What I ran while chasing the wrong layer
pwsh .github/knowledge-graph/cli/tests/test-e2e.ps1   # FAIL (Cannot create...)
# Re-read scaffold.psm1 switch block — looked correct
# Re-read mentor.ps1 Cmd-Add — looked correct
# Added Write-Host probes to scaffold.psm1 — confirmed file already existed

# What actually fixed it
$g = Get-Content .github/knowledge-graph/data/MentorAgent/system/mentor-graph.json -Raw | ConvertFrom-Json -Depth 100
$g.nodes | Where-Object { $_.id -like 'experiment:_debug-*' } | Select-Object -ExpandProperty id
# Manually removed orphan nodes + orphan stub files
pwsh .github/knowledge-graph/cli/tests/test-e2e.ps1   # GREEN, hash-identical round-trip
```

## What worked

- Hash-compare round-trip as the assertion: `add` → `link` → `unlink` → `remove` → delete-stub → assert byte-identical graph and agent file. When this finally passed it gave certainty no other test pattern would have.
- Once we suspected state pollution, dumping nodes by ID prefix made the orphans visible in one command.

## What didn't

- Reading the new code under the assumption it was wrong wasted ~15 minutes. The code was correct from the first try; the environment was dirty.
- The error message `Cannot create a file when that file already exists` is technically accurate but actively misleading because it points at the scaffold layer when the real fault was in the test fixture (uncleaned prior runs).

## Decision / next move

Led to `decision:2026-06-01-clean-state-before-concluding` — when a test fails partway through after passing partway through, suspect state pollution before suspecting code. Hash-compare round-trip tests only work from a clean baseline; the test harness must sweep its own debris before running.

Follow-up not done in this session: make the e2e test self-clean its own orphans on startup (assert clean state, fail loud if not, then proceed). Tracked as a Phase 1 cleanup task.
