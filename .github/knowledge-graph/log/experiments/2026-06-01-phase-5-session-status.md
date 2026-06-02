# Experiment: Phase 5 — `mentor.ps1 session-status` as graph-rendered Outcome

**Date:** 2026-06-01
**Phase:** 5 of the graph-driven build
**Session:** `session:2026-06-01-graph-driven-setup`

## Hypothesis

The session markdown's Outcome section is duplicate state. The graph already holds every experiment + decision tied to a session via `has_experiment` / `has_decision` edges. If we can render that view from the graph in one command, the markdown becomes optional — the graph is the source of truth.

Move 5 of this session proved the gap by example: the markdown was stale because edges existed in the graph that the doc didn't reflect. Hand-editing markdown to "catch up" with the graph is exactly what we want to eliminate.

## Setup

- Add `session-status <session-id>` verb to `mentor.ps1`.
- Read `system/mentor-graph.json` via existing `Get-MentorGraph`.
- Render: session metadata → experiments (with `concluded_with` decisions inline) → decisions → child sessions.
- Auto-prepend `session:` if the user passes a bare slug.
- Return exit 0 on success, exit 1 if session id not found.
- No write paths — pure read.

## Procedure

1. Added `Cmd-SessionStatus` function and wired it into the verb dispatch.
2. Updated header comment + `Show-Usage` to document the verb.
3. Ran against the real session: `session:2026-06-01-graph-driven-setup` — rendered 5 experiments (with their concluded-with decisions inline) and 13 decisions in order, with descriptions.
4. Smoke-tested error paths:
   - Missing session id → `ERROR: Usage: session-status <session-id>`, exit 1.
   - Non-existent id → `ERROR: Session 'session:does-not-exist' not found in graph.`, exit 1.
   - Bare slug (no `session:` prefix) → auto-prepended, rendered correctly, exit 0.

## Results

- 1 command renders the full session Outcome from the graph in well under a second.
- Output is read-grade: every experiment is followed by its `concluded_with` decisions inline, so the chain of reasoning is visible without follow-up queries.
- Replaces what was a manual ~50-line markdown edit (Move 5/6/7/8/9 sync earlier this session) with a query.

## Findings

- **The graph really is enough.** Everything the doc needed to say about Outcome is already in the edges. The markdown's free-form Notes section is the only part that still has value as prose.
- The `Get-MentorGraph` import path was already wired correctly — no module-loading drama this time. (Contrast Phase 4's `Resolve-Path` workaround for `Import-Module`.)
- One pure-read CLI verb is a much cheaper migration than building a markdown-renderer. The doc's Outcome section can be deleted later; for now both can coexist.

## What this enables

- The session doc's Outcome section becomes redundant. Future sessions can document Goal / Scope / Notes in markdown and let `session-status` carry Outcome.
- Other consumers (CI summary, dashboard, agent context) can shell out to `session-status` to get the same view. No second source of truth.
- Lays the foundation for `experiment-status`, `decision-status`, `node-status` if we want symmetric renderers later (out of scope for Phase 5).
