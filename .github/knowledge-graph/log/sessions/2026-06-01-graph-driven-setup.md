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
- **Move 5** — Capture the state-pollution red-herring experiment + the log-as-graph-nodes decision as nodes with edges back to this session ⏳

## Notes

Add new entries as the session continues. Move 5 is the proof point — once edges are wired, the full graph-driven loop is demonstrated and Phase 0 is done.
