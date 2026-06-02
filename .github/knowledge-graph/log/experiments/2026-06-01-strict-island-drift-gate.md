---
id: 2026-06-01-strict-island-drift-gate
type: experiment
description: "Convert pre-commit islands and drift checks from advisory WARN to blocking; required wiring 7 islands and fixing 1 drift before commit could land"
run_at: 2026-06-01
result: worked
---

# Experiment — Strict island+drift gate

**Date:** 2026-06-01
**Cluster:** validation-layer
**Session:** [session:2026-06-01-gate-hardening](../sessions/2026-06-01-gate-hardening.md)

## Hypothesis

If the pre-commit hook's `islands` and `drift` checks emit `Write-Warning` and let the commit succeed, drift accumulates between commits because no one reads warnings in noisy output. Converting them to `Write-Error + exit 1` (blocking) should force every author to leave the graph at least as connected and drift-free as they found it.

The cost is paid up-front: the gate will reject the *current* state if there are pre-existing islands or drift, so we have to clean those up before the new gate can land. The expectation: ~7 islands and ~1 drift (per the last `health.ps1` run before this experiment).

## Method

1. Edit `.github/hooks/pre-commit.ps1` at the islands handler (~line 261) and drift handler (~line 360). Replace `Write-Warning` blocks with `Write-Error` + `exit 1`.
2. Try to commit the change.
3. Observe whether the new gate rejects the commit because of the pre-existing islands/drift.
4. If rejected, fix all islands + drift in the graph, then re-try.
5. Confirm the commit only lands when the graph is clean.

## Operations

```powershell
# Step 1 — make the hook blocking (edited in place)

# Step 2 — try to commit
git add .github/hooks/pre-commit.ps1
git commit -m "Pre-commit: block on islands and drift"
# Hook ran, blocked with WARN 2 — islands=7, drift=1

# Step 3 — diagnose
pwsh .github/knowledge-graph/build/core/health.ps1 -Layer merged
# Islands: 7 (CLI lib modules + test files, all unbridged)
pwsh .github/knowledge-graph/cli/find-drift.ps1
# Drift: 1 (decision:profile-exists description had bare 'mentors/...' path)

# Step 4 — wire islands + fix drift in mentor-graph.json
#   Added: module:graph-writer, module:scaffold, module:agent-sync, test:agent-sync
#   Added 11 bridge edges (modules <-> code-files, tests, cli-tool:mentor)
#   Fixed: description path on decision:profile-exists
pwsh .github/knowledge-graph/build/core/merge.ps1
pwsh .github/knowledge-graph/build/core/health.ps1 -Layer merged
# Result: islands=0, health WARN 1 (code-coverage only, addressed in Phase 4)
pwsh .github/knowledge-graph/cli/find-drift.ps1 -Quiet
# Drift findings: 0

# Step 5 — try commit again
git add .github/hooks/pre-commit.ps1 .github/knowledge-graph/data/MentorAgent/system/mentor-graph.json
git commit -m "Pre-commit: block on islands and drift; wire 7 island modules + fix template drift"
# Commit landed: f5864cb
```

## Baseline measurements

| Metric | Before | After |
|---|---|---|
| Hook severity (islands) | WARN | ERROR (exit 1) |
| Hook severity (drift) | WARN | ERROR (exit 1) |
| Islands at start | 7 | 0 |
| Drift findings at start | 1 | 0 |
| Health summary | PASS 9 \| WARN 2 \| FAIL 0 | PASS 10 \| WARN 1 \| FAIL 0 |

## What worked

- **"Fix first" over bypass.** Jay explicitly rejected the option to land the strict gate with the pre-existing debt still in place. Cleaning up the 7 islands meant the gate had a green baseline from the moment it became strict — no "established noise" the gate has to tolerate forever.
- **Bridge pattern held.** The existing system-layer convention (typed nodes `module:`, `test:`, `cli-tool:` connect to auto-extracted `code-file:` nodes via `related_to` / `tested_by` / `uses`) absorbed all 7 islands cleanly. No new edge types or schema changes needed.
- **Hook is its own dogfood gate.** Running `git commit` after making the hook strict was the test — no separate harness needed.

## What didn't

- **First bridge attempt undershot.** Initial graph edit reduced islands `7 → 4` because the 3 new modules and 1 new test weren't anchored back to anything in the main component (`agent:mentor` reachable cluster). Required a second pass adding `cli-tool:mentor --uses--> module:*` edges and an explicit `test:agent-sync --tests--> code-file:...` edge. Lesson: when adding a new system-layer cluster, it has to anchor to an existing hub or it becomes its own island.

## Decision / next move

Codified as [decision:2026-06-01-gate-blocks-islands-and-drift](../decisions/2026-06-01-gate-blocks-islands-and-drift.md). The gate stays binary. Next move was Phase 4 (count log nodes in coverage) — see [experiment:coverage-counts-log-nodes](2026-06-01-coverage-counts-log-nodes.md).
