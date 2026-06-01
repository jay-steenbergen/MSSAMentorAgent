# Experiment — Phase 3: Graph Integrity Gate

**Date:** 2026-06-01
**Cluster:** agent-core
**Session:** session:2026-06-01-graph-driven-setup

## Hypothesis

If `Get-AgentLoadList` can return paths that don't exist on disk, the agent
silently "loads" missing skills — no error, just degraded behavior. A
pre-commit gate that walks every graph node's `file` field and verifies
each resolves to a real file will catch this drift at the only moment it
can be cheaply fixed: before commit.

Phase 2 enforced **graph-first authoring** (file on disk → must have node).
Phase 3 enforces the inverse: **graph integrity** (node → must have real
file). Together they make `file` a verified bidirectional contract.

## Method

1. Build `find-missing-files.ps1` — walk `system.nodes`, filter where
   `file` is non-empty, `Test-Path` each, report misses.
2. Baseline scan — measure how many existing nodes have broken paths.
3. Wire into pre-commit hook as a **blocking** check alongside the Phase 2
   orphan gate.
4. Induce a missing-file scenario (rename one node's `file` field), confirm
   the script returns exit 1 with a useful report, restore the graph.
5. Smoke-test `Get-AgentLoadList` for three known intents and verify every
   returned path resolves on disk.

## Baseline Measurements

| Metric | Value |
|---|---|
| Total nodes in system graph | (whatever's current) |
| Nodes with a `file` field | 306 |
| Missing files at baseline | **0** |
| Smoke test: `Get-AgentLoadList` returns | All paths resolve for 3 tested intents |

The graph started clean — no fix-up needed before wiring the gate.

## What Worked

- **Reused the Phase 2 hook pattern.** Same try/catch shape, same `-Quiet`
  invocation for the hook + full-output invocation for the user. One file
  to read, two gates of the same shape.
- **Surgical smoke test.** Patched a single node's `file` field via
  `ConvertFrom-Json` → swap → `ConvertTo-Json`, then ran the check, then
  restored. Cleaner than regex find/replace which would have hit
  description text too.
- **Baseline came back clean.** 306 file refs all resolve. The Phase 2
  orphan work didn't introduce drift in the reverse direction — confirms
  the `mentor.ps1 add -File` parameter was the right escape hatch.

## What Didn't (Or Surfaced for Later)

- **`Get-AgentLoadList` intent matching is loose.** "build a REST API"
  matched `cad-blob-uploader`, `cad-cicd-pipeline`, `cad-deploy-app-service`
  — none REST-specific. "test first red green refactor" pulled in
  `spike-then-refactor` because "refactor" is in its description. The gate
  catches file integrity, not relevance. Intent quality is a separate
  problem for a later phase.
- **PowerShell backtick-in-string gotcha.** First version of the missing
  file script used `` `file` `` in a `Write-Host` line, which PowerShell
  interpreted as `\f` (form feed). Replaced with single quotes around the
  field name. Same trap likely hides in other scripts — worth a sweep
  someday.

## Outcome

- New script: `.github/knowledge-graph/cli/find-missing-files.ps1`
- Hook update: Step 5b now runs orphan check + missing-files check
  (both blocking) + drift check (advisory)
- Two decisions wired:
  - `decision:2026-06-01-phase-3-integrity-gate-policy`
- Status: passing on the same commit that introduces it.

## Deferred

- Intent-matching quality (false-positive skill recommendations)
- Drift advisory cleanup: 1 known finding around
  `mentors/{username}/profile.json` from Phase 2 still outstanding
- 56 untested skills from Phase 1 — still untested
