# Experiment: Phase 4 — Get-AgentLoadList golden tests

**Date:** 2026-06-01
**Phase:** 4 of the graph-driven build
**Session:** `session:2026-06-01-graph-driven-setup`

## Hypothesis

Pinning the output of `Get-AgentLoadList` for a small set of canonical `(intent, method, track, skipEssentials)` tuples will catch silent regressions caused by changes to:

- The query module itself (`.github/knowledge-graph/lib/query.psm1`)
- The merged graph (skill nodes added/removed/renamed, descriptions altered)
- The scoring heuristics in `Get-RelevantSkills`

If the gate works, any change that alters the set or order of files the agent loads for a pinned tuple will fail the pre-commit hook with a readable diff and a one-command fix.

## Setup

- Created `test-load-list.goldens.json` next to the test script — pure data, one entry per pinned case with `intent`, `method`, optional `track`, optional `skipEssentials`, and the expected file list in order.
- Created `test-load-list.ps1` that loads the JSON, calls `Get-AgentLoadList` per case, asserts exact ordered match (no extras, no missing, no reorder).
- Flags: `-Quiet` for hook-friendly one-line output, `-UpdateBaseline` to overwrite goldens with current output when a change is intentional.
- Five canonical cases chosen to exercise different code paths:
  1. `ride-along` default, no track, no intent keywords → minimal essentials path
  2. `TDD`, cloud-app-dev, "REST API" intent → track boost + intent matching
  3. `BDD`, cybersecurity-ops, "intrusion detection" intent → different track + method
  4. `spike-then-refactor`, server-cloud-admin, "infrastructure" intent → known gap (method skill not in load list)
  5. `SkipEssentials`, github-copilot, "test generation" intent → SkipEssentials code path

## Procedure

1. Captured baseline by invoking `Get-AgentLoadList` directly for each tuple.
2. Wrote outputs into `test-load-list.goldens.json` with `_baseline_date` and `_baseline_commit` metadata.
3. Ran the test script — all 5 cases pass.
4. Wired the test into `.github/hooks/pre-commit.ps1` Step 5b as a 4th blocking check (after orphan + missing-files, before drift).
5. Smoke-tested the gate two ways:
   a. Added a noise skill node (`skill:cad-fake-rest-api-skill`) with matching keywords. Goldens still passed — noise didn't out-score existing top-3 because it lacked the `+5` track-folder boost (file path wasn't under `.github/skills/tracks/...`). **Useful finding: track boost dominates scoring.**
   b. Mutated the goldens JSON to drop one expected file from case 1. Test correctly failed with diff (`Expected (1)` vs `Actual (2)`) and printed the `-UpdateBaseline` fix command. Restored — green again.

## Results

- 5 cases pinned, 5/5 PASS in ~1s.
- Gate verified to catch a real regression (mutation test).
- Failure output is actionable: shows expected vs actual file lists, explains intentional-vs-unintentional, points at `-UpdateBaseline`.
- Discovered the `+5` track-folder boost dominates `Get-RelevantSkills` scoring — pure intent-keyword matches without a track boost can't displace track-folder skills in the top-3. Noted for future intent-quality work (Phase B).

## Findings

- **Phase 4 gate works as intended.** Any silent change to load-list output is now blocked at commit.
- The `spike-then-refactor` method has no method skill in its load list (pinned as current behavior, explicitly called out in the case label). This is a real gap to revisit — but pinning the *current* behavior is what Phase 4 is for, not fixing it.
- Track-folder path matching is a heavy weight in the scoring. Likely the right default, but worth revisiting when we tackle intent quality.

## What this enables

- Phase 5+ work can change the query module, graph extractor, or scoring with confidence — regressions surface immediately at commit time.
- Future contributors get a readable failure rather than a mysterious mid-session "the agent loaded the wrong files."
