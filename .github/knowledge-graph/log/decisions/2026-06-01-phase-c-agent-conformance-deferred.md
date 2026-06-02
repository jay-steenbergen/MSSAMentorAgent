# Decision (DEFERRED) — Agent Conformance Check

**Date:** 2026-06-01
**Cluster:** agent-core
**Status:** DEFERRED — not yet started, captured to avoid loss
**Session:** session:2026-06-01-graph-driven-setup

## What it is

A future check that verifies the **runtime agent** actually loads what
`Get-AgentLoadList` says it should. The agent (or extension) writes its
actual load list to a session artifact at session start; a separate
check compares that artifact against what `Get-AgentLoadList` would have
returned for the same intent/method/track inputs.

Catches the failure mode: "the oracle says load A, B, C — the agent
loaded A, X, Y instead." Silent, hardest debug class of bug.

## Why deferred (and not built in Phase 4)

- **No telemetry yet.** The agent doesn't currently emit its load list
  to disk. Building that is a separate workstream:
  - VS Code extension change (mentor-context-loader) to write the
    actual file list it pre-loaded
  - Agent-side hook (or session-start protocol) to write the
    intent-specific skills it loaded after extension pre-load
  - Schema for the artifact + location convention
- **Phase 4 (Option A) gives us the prerequisite.** Without a pinned
  baseline of what `Get-AgentLoadList` returns, we have nothing to
  compare the agent's actual loads against.
- **Phase 4 stays on the same shape** as Phases 2/3 (gate-shaped, fast,
  pre-commit). Conformance is a runtime concern — different shape,
  different tooling.

## Prerequisites (must exist before this is buildable)

1. **Phase 4 (Option A) golden tests for `Get-AgentLoadList`** —
   establishes the oracle's expected outputs as a pinned baseline.
2. **Phase B (intent quality improvements, if/when chosen)** — if
   matching changes, the conformance comparator needs to know which
   version of the oracle to compare against.
3. **Session-artifact convention** — where does the agent write its
   actual load list? Proposed: `.session-state/load-list.json`
   (gitignored, written on every session start).
4. **Extension instrumentation** — mentor-context-loader writes its
   pre-load list. Agent writes its intent-load additions.

## What it would look like (sketch)

```
.session-state/load-list.json   # written by extension+agent at session start
  {
    "session_id": "...",
    "inputs": { "intent": "...", "method": "...", "track": "..." },
    "extension_preloaded": [ "...", "...", "..." ],
    "agent_loaded": [ "...", "...", "..." ]
  }

pwsh .github/knowledge-graph/cli/check-load-list-conformance.ps1
  - Reads .session-state/load-list.json
  - Calls Get-AgentLoadList with the same inputs
  - Diffs the two lists
  - Exits 1 if they differ
```

Not a pre-commit gate (runtime artifact, not source). Probably a
session-end check or a periodic CI scan against recent session
artifacts.

## Affects

- Won't block any commit (not a pre-commit concern).
- Closes the loop on the "agent ignored the oracle" failure mode.
- Requires the agent to be honest about what it loaded — depends on
  cooperation, not enforcement. Without runtime instrumentation, this
  is unverifiable.

## Revisit When

- Phase 4 (Option A) has landed and stabilized (gives us the oracle
  baseline).
- A session has surfaced evidence of "agent loaded the wrong thing"
  (today this is invisible — we'd just see degraded teaching quality).
- The mentor-context-loader extension is ready to emit telemetry.
