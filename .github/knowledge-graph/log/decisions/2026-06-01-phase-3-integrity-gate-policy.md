# Decision — Phase 3 Graph Integrity Gate Policy

**Date:** 2026-06-01
**Cluster:** agent-core
**Experiment:** experiment:2026-06-01-phase-3-graph-integrity-gate

## Chose

A pre-commit gate (`find-missing-files.ps1`) that walks every node in the
system graph with a non-empty `file` field, verifies each resolves on
disk via `Test-Path`, and exits 1 if any are missing. Wired into the
pre-commit hook as a **blocking** check.

## Over

- **Periodic CI-only check (out-of-band).** Slower feedback, drift can
  pile up between runs, easy to ignore a yellow build.
- **Runtime check inside `Get-AgentLoadList`.** Would silently filter
  missing paths from the returned list, hiding the problem from the
  agent and the author. Phase 2's lesson: gates that don't surface
  violations get bypassed.
- **Validate only "load-list-relevant" nodes** (agents, skills, methods,
  tracks). Tighter blast radius but more rules to remember, and the
  log/decision/experiment nodes are the ones most likely to rot over
  time. Broader gate, simpler rule.

## Because

- File-path resolution is **binary and cheap**. `Test-Path` per node is
  microseconds. 306 nodes resolved in well under a second.
- Phase 2 + Phase 3 together make `file` a **bidirectional contract**:
  every file on disk has a node, every node points at a real file.
  Either direction breaking is now blocked at commit.
- The agent's primary entry point (`Get-AgentLoadList`) is only as good
  as the integrity of `node.file`. Without this gate, the agent loads
  nothing for a missing reference — silent failure, hardest debug.

## Affects

- All future commits — the hook runs on every one.
- Any reorg that moves or renames a tracked file will now block until
  the graph is updated. This is the **intended** outcome.
- Adds ~1 second to pre-commit time for ~300 nodes. Linear in node
  count; not a concern until ~10k nodes.

## Revisit If

- The 1-second cost becomes a friction point as the graph grows past
  ~5k nodes — switch to incremental check (only scan nodes whose `file`
  field changed in the staged diff).
- A legitimate "intentionally missing" case appears (e.g., a node
  referencing a generated file that's gitignored). Add an opt-out
  field like `"file_optional": true` rather than weakening the gate.
- Pattern repeats in other field types (URLs, related nodes, etc.) —
  generalize into a single "graph integrity" check that walks all
  reference-bearing fields.
