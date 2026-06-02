---
id: 2026-06-01-coverage-counts-log-nodes
type: experiment
description: "Health code-coverage check was filtering on type=code-file only, undercounting 21 session/experiment/decision nodes that own .md body files"
run_at: 2026-06-01
result: worked
---

# Experiment — Coverage counts log nodes

**Date:** 2026-06-01
**Cluster:** validation-layer
**Session:** [session:2026-06-01-gate-hardening](../sessions/2026-06-01-gate-hardening.md)

## Hypothesis

After Phase 3 the hook still reported `PASS 10 | WARN 1 (non-critical)` instead of all-pass. The remaining WARN was `code-coverage` at 86.5% with exactly 21 files "missing," all of them under `.github/knowledge-graph/log/` — the same 21 markdown bodies that *are* in the graph as `session`, `experiment`, `decision` typed nodes per [decision:log-as-graph-nodes](../decisions/2026-06-01-log-as-graph-nodes.md).

Hypothesis: the coverage check is filtering the graph node set on `type -eq 'code-file'` before comparing against the tracked file list. Log nodes own their files via the `file` field (same as `agent:` and `skill:` nodes) but get a `session` / `experiment` / `decision` type, so they're excluded from the comparison set — even though they're legitimately in the graph.

Expected fix: count any node with a `.file` field, not only `code-file` typed nodes. Should take coverage to 100% without false positives.

## Method

1. Inspect `health.ps1` `code-coverage` block to confirm the filter.
2. Build a one-off script that compares the 21 log files against both filter strategies (`type=code-file` vs `any .file`) to verify the prediction before editing.
3. Change the filter in `health.ps1`.
4. Re-run health and confirm `PASS 11 | WARN 0`.
5. Confirm hook output drops the `(non-critical)` qualifier on next commit.

## Operations

```powershell
# Step 1 — locate the filter
Select-String -Path .github/knowledge-graph/build/core/health.ps1 -Pattern "code-coverage|kg-infra|coverage" -Context 0,2
# Found: line ~381 — $graphFilePaths = @($nodes | Where-Object { $_.type -eq 'code-file' } | ForEach-Object { $_.file -replace '\\','/' })

# Step 2 — verify hypothesis with throwaway script
pwsh .tmp-coverage-check.ps1
# Output for every one of the 21 log files: code-file=False  anyNode=True
# Hypothesis confirmed.

# Step 3 — edit health.ps1 (one-line change)
# OLD: $graphFilePaths = @($nodes | Where-Object { $_.type -eq 'code-file' } | ForEach-Object ...)
# NEW: $graphFilePaths = @($nodes | Where-Object { $_.file } | ForEach-Object ...) | Sort-Object -Unique

# Step 4 — verify
pwsh .github/knowledge-graph/build/core/health.ps1 -Layer merged
# [PASS] code-coverage  (0)
# Summary: PASS 11 | WARN 0 | FAIL 0

# Step 5 — commit
git add .github/knowledge-graph/build/core/health.ps1
git commit -m "Health: count log nodes in code-coverage (was code-file only)"
# Hook output: "Graph health: All checks passed" (no qualifier)
# Commit landed: ab3204b
```

## Baseline measurements

| Metric | Before | After |
|---|---|---|
| Tracked files (eligible) | 156 | 156 |
| Files in graph (per check) | 135 (86.5%) | 156 (100%) |
| Missing log files | 21 | 0 |
| Health summary | PASS 10 \| WARN 1 \| FAIL 0 | PASS 11 \| WARN 0 \| FAIL 0 |
| Hook header line | "Graph health: PASS 10 \| WARN 1 (non-critical)" | "Graph health: All checks passed" |

## What worked

- **Hypothesis-then-verify before editing.** Built `.tmp-coverage-check.ps1` to confirm `code-file=False / anyNode=True` for every log file *before* touching `health.ps1`. The fix was a one-line change because the diagnosis was solid first.
- **Pattern alignment.** The filter change makes the coverage check consistent with how the rest of the graph treats node-owned files: `agent:` nodes own `.agent.md` files, `skill:` nodes own `SKILL.md` files, `session:` / `experiment:` / `decision:` nodes own `.md` body files. All four cases work the same way now.
- **Cleaned up the temp script** before committing — no `.tmp-*` files leaked into the commit.

## What didn't

Nothing. Single-step fix, immediate verification, clean diff.

## Decision / next move

Codified as [decision:2026-06-01-coverage-counts-any-file-node](../decisions/2026-06-01-coverage-counts-any-file-node.md). Closes the last WARN in the health pipeline. Next: capture this whole session as graph nodes (this experiment is part of that).
