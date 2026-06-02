# Decision: Phase 4 — golden tests for Get-AgentLoadList

**Date:** 2026-06-01
**Phase:** 4 of the graph-driven build
**Session:** `session:2026-06-01-graph-driven-setup`
**Concludes:** `experiment:2026-06-01-phase-4-load-list-goldens`

## Chose

Pin `Get-AgentLoadList` behavior with **order-sensitive exact-match golden tests** stored in a sibling JSON file, enforced as a **blocking** pre-commit check. Five canonical tuples cover the main code paths. Updates require an intentional `-UpdateBaseline` invocation and committing the changed goldens.

## Over

- **B. Snapshot-style fuzzy match** (assert files contain the expected set, allow ordering and extras): rejected — silently allows the agent to load more or different files than designed. Defeats the point of pinning.
- **C. Runtime conformance** (Phase C, captured separately as deferred): compare what the agent actually loaded in a session against what `Get-AgentLoadList` says. Rejected for now — requires telemetry infrastructure we don't have yet.
- **In-script golden literals** instead of a sibling JSON: rejected — JSON diffs are reviewable, mutation requires editing data not code, and `-UpdateBaseline` is a clean one-line write.
- **Advisory-only check**: rejected — silent regressions in agent loading are exactly what we just spent three phases preventing on the graph side.

## Because

- The agent's behavior is now graph-driven. A silent change to the merged graph, the query module, or the scoring heuristics can quietly change which files the agent loads at session start. Without a gate, that drift won't surface until a learner sees the wrong thing in chat.
- Phases 2 and 3 lock down graph integrity (orphans, missing files). Phase 4 locks down **load-list output** — the actual contract the agent depends on.
- Order matters: `Get-AgentLoadList` returns files in dependency order (essentials → method → intent → track README). Reordering would change what the agent reads first and how context is loaded. Order-sensitive match catches this.
- A JSON sibling file (`test-load-list.goldens.json`) makes the contract reviewable in PRs — anyone reading a diff can see exactly which `(intent, method, track)` tuples produce which file lists.
- The `-UpdateBaseline` escape hatch keeps the workflow practical: intentional changes are one command + one commit. No need to bypass the hook for legitimate updates.

## Affects

- `.github/hooks/pre-commit.ps1` — Step 5b now has 3 blocking checks (orphan, missing-files, load-list) + 1 advisory (drift).
- `.github/knowledge-graph/cli/test-load-list.ps1` (new) — the test runner.
- `.github/knowledge-graph/cli/test-load-list.goldens.json` (new) — the pinned contracts.
- All future changes to `lib/query.psm1`, the graph extractors, or skill nodes must either preserve the goldens or update them intentionally.

## Revisit if

- We change the load-list contract on purpose (e.g., add new ordering categories, change SkipEssentials behavior). At that point: update goldens via `-UpdateBaseline`, review diff, commit.
- We add coverage for new methods, tracks, or intent shapes that aren't in the current 5 cases.
- The 5 cases stop representing real session starts (some intent or method falls out of use, or a new one becomes common).
- Phase C lands (runtime conformance) — at that point we may want to align the two checks so the runtime never tests against a tuple that isn't pinned.

## Known limitation pinned as-is

Case 4 (`spike-then-refactor`, server-cloud-admin) returns no method skill — `Get-MethodSkills -Method 'spike-then-refactor'` produces nothing. The golden expectation reflects this current behavior with an explicit note in the case label. Phase 4 pins **what is**, not what should be. The gap is real and worth a future fix, but Phase 4 isn't the venue.
