---
id: 2026-06-01-gate-hardening
type: session
description: "Make pre-commit gate strict (block islands + drift), fix Mentor opener bug, close coverage check gap"
started_at: 2026-06-01
ended_at: 2026-06-01
goal: "Take the post-Phase-5 graph-driven setup from advisory to enforced — pre-commit hook blocks any commit that introduces graph islands or path drift, and a real Mentor opener bug surfaced by a mentee gets fixed and codified."
phase: hardening
---

# Session: 2026-06-01-gate-hardening

Follow-on to [session:2026-06-01-graph-driven-setup](2026-06-01-graph-driven-setup.md). That session built the workflow; this one tightens it. A mentee triggered a real opener bug ("I'll scan the workspace") which surfaced that the Mentor's track knowledge wasn't being used at session start. While fixing that, a request to strengthen the pre-commit gate forced a "fix first" cleanup of pre-existing graph debt (7 islands + 1 drift) — none of which would have been allowed under the new strict rules.

## Goal

Make the pre-commit hook strict on graph integrity (islands + drift block, not warn), fix the Mentor opener so it offers idea-or-helloworld in the chosen track instead of pretending to scan the workspace, and close the gap where the coverage check missed log-type nodes.

## Scope

- **In:**
  - Phase 1 — Mentor opener fix (`behavior:02-open-with-intent` + matching antipattern)
  - Phase 2 — Convert pre-commit `islands` and `drift` checks from advisory `WARN` to blocking errors
  - Phase 3 — Cleanup required to land Phase 2: bridge 7 island nodes, fix 1 path drift
  - Phase 4 — Fix `health.ps1` `code-coverage` to count any node owning a `.file`, not only `code-file` typed nodes
  - Codify each phase as graph nodes (this session + 2 experiments + 3 decisions, wired with `has_experiment` / `has_decision` / `concluded_with`)
- **Out:**
  - Edge-type renames (`reads-from` vs `reads_from`) — cosmetic, deferred
  - Adding `test:query` for the still-untested `module:query` — deferred
  - Connecting orphan `interview:summary-confirm` phase to a session — cosmetic, deferred
  - Single-edge field/signal/concept nodes review — deferred
- **Done when:**
  - Pre-commit hook produces "Graph health: All checks passed" (no `WARN N (non-critical)` qualifier)
  - `health.ps1 -Layer merged` reports `PASS 11 | WARN 0 | FAIL 0`
  - `find-drift.ps1 -Quiet` reports `Drift findings: 0`
  - Mentor's `behavior:02-open-with-intent` opener forbids "scan the workspace" wording and offers two concrete starters
  - This session, both experiments, and all three decisions exist as graph nodes wired together via the established `log-as-graph-nodes` pattern

## Outcome

- **Phase 1** — Updated `behavior:02-open-with-intent` in three sync'd places (`Mentor.agent.md`, `get-behavior.ps1`, `learner-profile/SKILL.md`). Added explicit antipattern banning "I'll scan the workspace" wording. Mentor now offers (a) your idea or (b) hello world starter in the chosen track. Commit `f0bc55a` pushed to master. ✓
- **Phase 2** — Hook `islands` and `drift` checks rewritten from `Write-Warning` to `Write-Error + exit 1`. Initial run blocked the commit with 7 islands and 1 drift finding, validating the new gate. (See `experiment:strict-island-drift-gate`.) ✓
- **Phase 3** — Wired the 7 pre-existing islands by adding 4 system-layer nodes (`module:graph-writer`, `module:scaffold`, `module:agent-sync`, `test:agent-sync`) plus 11 bridge edges, and fixed the drift by completing the path in `decision:profile-exists` description (`mentors/{username}/...` → `.profiles/profiles/mentors/{username}/...`). Health went `WARN 2 → WARN 1`, drift went `1 → 0`. (See `decision:gate-blocks-islands-and-drift`.) Commit `f5864cb` pushed to master. ✓
- **Phase 4** — Found and fixed root cause of remaining `code-coverage` WARN: `health.ps1` filtered the graph node set on `type -eq 'code-file'`, undercounting 21 `session`/`experiment`/`decision` nodes that own `.md` body files per the `log-as-graph-nodes` policy. Changed filter to "any node with a `.file` field." Coverage went `86.5% → 100%`, health summary went `WARN 1 → WARN 0`. Hook now reports `Graph health: All checks passed`. (See `experiment:coverage-counts-log-nodes` + `decision:coverage-counts-any-file-node`.) Commit `ab3204b` pushed to master. ✓
- **Codification (this move)** — Captured this session and the 5 supporting nodes (2 experiments, 3 decisions) with 7 edges connecting them per the established pattern. Also fixed a latent bug in `scaffold.psm1` where session/experiment/decision body templates used `_Slug-FromId $Label` instead of `_Slug-FromId $Id` for the frontmatter `id:` field — surfaced by passing `-Label` with a human-readable string. ✓

## Done-when verification (2026-06-01)

- ✅ Hook output reads "Graph health: All checks passed" (verified during `ab3204b` commit)
- ✅ `health.ps1 -Layer merged`: `PASS 11 | WARN 0 | FAIL 0` (verified post-Phase 4)
- ✅ `find-drift.ps1 -Quiet`: `Drift findings: 0`
- ✅ `Mentor.agent.md` banned wording verified in `f0bc55a`
- ✅ Session node, 2 experiment nodes, 3 decision nodes, 7 edges all present and validated by `mentor.ps1 validate` (REAL GAP 0)

## Notes

The "fix first" choice on Phase 3 was the right call. Bypassing the gate to land it strict-but-broken would have meant the next commit was free to introduce new islands, and the gate would have just kept failing. Cleaning up first means the gate has a green baseline to defend.

The `scaffold.psm1` bug had been latent since the session/experiment/decision types were added (`b832485`) but never tripped — earlier sessions had `-Label` matching the slug or omitted it entirely. This session's `-Label "Strict island+drift gate"` (a real human label) surfaced it immediately. Fix went in alongside the body content.

Next session candidate: tackle the deferred items (edge-type duplicates, `module:query` test, orphan phase, single-edge audit) as a single graph-cleanup pass.
