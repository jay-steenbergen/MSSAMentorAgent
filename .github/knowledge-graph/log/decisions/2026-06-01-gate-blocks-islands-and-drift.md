---
id: 2026-06-01-gate-blocks-islands-and-drift
type: decision
description: "Pre-commit hook converts islands and drift from advisory WARN to blocking errors that exit 1"
decided_at: 2026-06-01
---

# Decision: Gate blocks islands and drift

The pre-commit hook treats graph islands (disconnected components) and path drift (text references that don't resolve to real files) as **blocking** failures — `Write-Error` + `exit 1`, no override — rather than advisory `Write-Warning` messages.

## Chose

Both checks are binary gates:

- **Islands** — if `health.ps1 -Layer merged` reports any connected component other than the main one, the hook fails.
- **Drift** — if `find-drift.ps1` reports any path reference in graph text that doesn't resolve on disk, the hook fails.

Implemented in `.github/hooks/pre-commit.ps1` at the islands handler (~line 261) and drift handler (~line 360).

## Over

- **Advisory `Write-Warning`** (the previous behavior) — warnings get buried in noisy commit output and never get acted on.
- **A "block on first occurrence, warn after"** scheme — too clever; either it matters or it doesn't, and the rule is easier to internalize when it's the same every time.
- **A bypass flag** like `--allow-graph-drift` — once an escape hatch exists, it gets used.
- **Block only in CI, warn locally** — by the time CI catches it, the drift is already in a PR with history attached; local gate keeps the radius small.

## Because

Drift accumulates silently. If a check warns instead of blocks, the cost of fixing it gets pushed to "later" (which means "never") and the graph quietly rots. The whole point of the graph-driven workflow is that the graph can be trusted — the moment islands or broken paths are tolerated, every downstream query against the graph has to assume the answer might be wrong, which defeats the purpose.

The cost is paid once: making the gate strict required fixing 7 pre-existing islands and 1 drift in a single cleanup pass (see [experiment:strict-island-drift-gate](../experiments/2026-06-01-strict-island-drift-gate.md)). After that, every commit defends the green baseline. No accumulation.

Jay explicitly rejected the "bypass and fix later" option when offered, choosing "fix first" instead. The fix took one session; the bypass would have meant rebuilding trust in the graph indefinitely.

## Affects

- `.github/hooks/pre-commit.ps1` — islands and drift handlers rewritten to exit 1.
- `.github/knowledge-graph/data/MentorAgent/system/mentor-graph.json` — 4 new nodes + 11 bridge edges added in the same commit to keep the gate green at landing.
- Every future commit — cannot land with new islands or new drift.
- Pre-existing `WARN` for `code-coverage` remained at landing time (handled separately in Phase 4 — see [decision:coverage-counts-any-file-node](2026-06-01-coverage-counts-any-file-node.md)).
- Commit `f5864cb` pushed to master.

## Revisit if

- A legitimate use case appears for transiently-disconnected nodes (e.g. a new cluster being staged across multiple commits). At that point either land the cluster atomically or add a typed "staging" cluster the gate ignores — but **don't** weaken the islands check.
- The "fix first" cost becomes prohibitive on a future cleanup (e.g. 100+ islands at once). At that point pre-clean in a separate session before flipping the gate, same pattern as this one.
- The `drift` check starts producing false positives (e.g. URL fragments interpreted as paths). Fix the false-positive rule before considering downgrading the severity.
