---
id: 2026-06-01-markdown-body-files-ok
type: decision
description: "Graph-owned markdown body files (one per node, attached via 'file' field) are consistent with existing agent/skill/track pattern and don't count as 'extra markdown'"
decided_at: 2026-06-01
---

# Decision: 2026-06-01-markdown-body-files-ok

Jay's stance: "everything goes through the graph, no extra markdown files." Clarified mid-session: markdown body files **attached to graph nodes via the `file` field** are not "extra markdown" — they're the body of the node. Forbidding them would also forbid every existing agent.md, SKILL.md, and track README.

## Chose

A1 — graph nodes own their body content via the existing `file` field convention. Body files live where the graph node says they live (e.g. `.github/knowledge-graph/log/decisions/{slug}.md` for decision nodes). The `mentor.ps1 add` verb both writes the node into the graph and scaffolds the body file.

## Over

- A2: keep all body content inside the JSON graph as a `body` field. Rejected because markdown editing in JSON strings is hostile and version-control diffs are unreadable.
- A3: forbid body files entirely; rely on description + edges to convey meaning. Rejected because edges can't carry paragraph-level reasoning (the "because" section of a decision needs prose).

## Because

The project already has the pattern: every `agent:` node points at a `.agent.md`, every `skill:` node points at a `SKILL.md`. The bodies live in markdown for human editing; the entities live in the graph. Sessions, experiments, and decisions follow the same shape — which means we get the existing pattern's tooling (scaffold, file-existence checks, stub cleanup) for free.

The "no extra markdown" rule was always meant to prevent markdown files that exist outside the graph's awareness. Body files attached to nodes are inside the graph's awareness by definition.

## Affects

- Existing build-tracking idea (one giant `tracking.md` outside the graph) is killed.
- All future log entries follow node + body pattern.
- Stub cleanup in `mentor.ps1 remove` still needs to handle body files (currently does not delete them by design — manual decision).

## Revisit if

- The body files grow stale faster than nodes (graph keeps them, bodies become outdated). At that point we need a freshness audit.
- A workflow needs the body content queryable from the graph itself (full-text search across all decision bodies, for example). Either we add a full-text index or move bodies into the graph after all.
