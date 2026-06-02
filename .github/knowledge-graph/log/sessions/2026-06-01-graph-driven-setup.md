---
id: 2026-06-01-graph-driven-setup
type: session
description: "Verify mentor agent setup is sound and codify graph-driven build workflow"
started_at: 2026-06-01
ended_at:
goal: "Validate the graph-driven build workflow by recording this session's decisions and experiments as graph nodes."
phase: tracking-infrastructure
---

# Session: 2026-06-01-graph-driven-setup

Eat our own dogfood. Before building anything else on top of the Mentor agent, prove that the graph can carry not just code and skills but the *story* of how the build happened — decisions, experiments, sessions — as first-class nodes.

## Goal

Validate the graph-driven build workflow by recording this session's decisions and experiments as graph nodes.

## Scope

- **In:**
  - Phase 0 — tracking infrastructure
  - Extend `scaffold.psm1` and `mentor.ps1` to support `session`, `experiment`, `decision` node types
  - Create the first real session, experiment, and decision nodes
  - Wire them together with edges (`contains`, `produced`, `learned`)
  - Prove the round-trip end-to-end (add → graph clean → remove → graph clean)
- **Out:**
  - Phase 1 — graph health audit (reconcile "57 broken refs" claim, run validate + find-drift)
  - Phase 2 — knowledge graph cluster routing verification (test `Get-AgentLoadList` against representative intents)
  - Phase 3 — MOS analogy library expansion (broaden military → software translation table)
  - Phase 4 — end-to-end Mentor agent verification (fresh-chat learner walkthrough)
  - Phase 5 — distill the graph-driven workflow itself into a reusable skill or method (cuttable if MSSAMentorAgent stays one-of-a-kind)
- **Done when:**
  - `mentor.ps1 add {session,experiment,decision}` works end-to-end
  - This session node exists in the graph
  - At least one `experiment` and one `decision` node exist, attached to this session via edges
  - `mentor.ps1 validate` passes clean (rebuild + gap-analysis OK)

## Outcome

- **Move 1** — Audited graph state, surfaced "57 broken refs" claim for Phase 1 investigation ✓
- **Move 2** — Extended `scaffold.psm1` to scaffold stubs for 3 new node types (TDD: RED → GREEN) ✓
- **Move 3** — Extended `mentor.ps1` CLI to accept 3 new node types in `$validTypes` + file-path switch (TDD: RED → GREEN, hash-identical round-trip) ✓
- **Move 4** — Created this session node as the first real graph-tracked session ✓
- **Move 5** — Captured `experiment:state-pollution-red-herring` + `decision:log-as-graph-nodes` as nodes wired to this session (`has_experiment` + `has_decision`), plus `experiment --concluded_with--> decision:clean-state-before-concluding` and `cli-tool:mentor --implements--> decision:log-as-graph-nodes`. Phase 0 loop proven end-to-end. ✓
- **Move 6 (Phase 2)** — Built `find-orphan-markdown.ps1` (every artifact `.md` must have a graph node first), wired as blocking pre-commit check. Codified as `experiment:phase-2-graph-first-enforcement` + `decision:phase-2-gate-policy` + `decision:mentor-add-file-override`. ✓
- **Move 7 (Phase 3)** — Built `find-missing-files.ps1` (every `node.file` must resolve on disk), wired as second blocking pre-commit check. Codified as `experiment:phase-3-graph-integrity-gate` + `decision:phase-3-integrity-gate-policy`. ✓
- **Move 8 (Phase 4)** — Built `test-load-list.ps1` + sibling `test-load-list.goldens.json` (5 canonical `(intent, method, track, skipEssentials)` tuples pinned with order-sensitive exact-match). Wired as third blocking pre-commit check. Smoke-tested with golden mutation — gate caught it with diff + `-UpdateBaseline` instruction. Codified as `experiment:phase-4-load-list-goldens` + `decision:phase-4-golden-tests-policy`. ✓
- **Move 9 (Phase C — deferred)** — Captured runtime-conformance check (agent's actual session load list vs `Get-AgentLoadList` output) as `decision:phase-c-agent-conformance-deferred`. Blocked on session telemetry infrastructure. ✓ recorded

## Done-when verification (2026-06-01)

- ✅ `mentor.ps1 add {session,experiment,decision}` works (Move 3 confirmed hash-identical round-trip)
- ✅ This session node exists in the graph (`session:2026-06-01-graph-driven-setup`)
- ✅ Multiple experiment + decision nodes attached via edges (5 experiments, 13 decisions wired to this session)
- ✅ `mentor.ps1 validate` passes clean: PASS 8 | WARN 3 | FAIL 0, exit 0

## Notes

Phase 0 done. Pre-commit hook now enforces graph-first authoring across three blocking checks (orphan, missing-files, load-list goldens) + one advisory (drift). The graph carries the full story of the build: every phase has its experiment + decision + edges to this session.

Open follow-ups (out of scope here):
- Phase 1 — graph health audit (reconcile "57 broken refs" claim)
- Phase 2 — `Get-AgentLoadList` cluster routing across more intents
- Phase 3 — MOS analogy library expansion
- Phase 4 (original) — fresh-chat end-to-end Mentor agent verification
- Phase 5 — distill graph-driven workflow into reusable skill/method
- Phase B — intent quality (loosen track-folder boost dominance)
- Phase C — runtime conformance (needs session telemetry first)
- Sync-from-graph: the existence of this hand-edit step is the cue — a `pwsh mentor.ps1 session-status` that prints Outcome from graph edges would close the loop.
