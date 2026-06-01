---
id: 2026-06-01-three-log-node-types
type: decision
description: "Use 3 specific types (session, experiment, decision) instead of one generic log-entry type — typed queries are worth the schema cost"
decided_at: 2026-06-01
---

# Decision: 2026-06-01-three-log-node-types

The build-tracking layer uses three distinct node types — `session`, `experiment`, `decision` — rather than a single generic `log-entry` type with a `subtype` field.

## Chose

Three concrete types, each with its own body-file template (different frontmatter fields, different sections):
- `session`: goal, phase, started_at, ended_at, scope, outcome.
- `experiment`: hypothesis, operations, run_at, result, what-worked, what-didn't.
- `decision`: chose, over, because, affects, revisit-if.

## Over

- One generic `log-entry` type with a `subtype: session|experiment|decision` field.
- Three free-form notes-style nodes that share a template.

## Because

Query precision. "Show me every decision this session produced" becomes one edge type (`has_decision`) and one node type. With a generic `log-entry`, the same query needs `WHERE subtype = 'decision'` everywhere, and edge types either flatten (`contains` for everything) or have to encode the subtype themselves.

The three concepts also have genuinely different body shapes. A session is a container with start/end; an experiment is a hypothesis with a result; a decision is a choice with rationale. Forcing them into one template either bloats every entry with empty sections or strips out the structure that makes each useful.

## Affects

- 3 new node types in the graph (was 8, now 11 if we count the new ones plus existing).
- 3 new scaffold templates in `scaffold.psm1`.
- 3 new branches in `mentor.ps1` `Cmd-Add` file-path switch.
- Future tooling can build type-specific reports (e.g. "all experiments that failed last week").

## Revisit if

- A fourth log shape appears that doesn't fit any of the three. Then either add a fourth type or reconsider whether the generic-with-subtype approach scales better.
- 90%+ of log entries are decisions and the other two types stay near-empty. That would mean the distinction isn't pulling weight in practice.
