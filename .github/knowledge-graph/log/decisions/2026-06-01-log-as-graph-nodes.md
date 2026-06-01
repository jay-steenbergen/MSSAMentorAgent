---
id: 2026-06-01-log-as-graph-nodes
type: decision
description: "Session/experiment/decision logs are first-class graph nodes with .md body files, not standalone markdown sidecars"
decided_at: 2026-06-01
---

# Decision: 2026-06-01-log-as-graph-nodes

Build-tracking (sessions, experiments, decisions) is captured **inside the knowledge graph** as typed nodes with attached markdown body files — never as standalone markdown sidecars that live next to the graph but not in it.

## Chose

First-class graph nodes (`session:`, `experiment:`, `decision:`) with `.md` body files referenced via the existing `file` field. Identical pattern to `agent:`, `skill:`, `track:`.

## Over

- Standalone markdown files under `.github/knowledge-graph/log/` that no graph node points at.
- A separate sidecar JSON registry just for log entries.
- A single "log-entry" generic node type with a `subtype` field.

## Because

Graph-driven development means every artifact the project produces must be queryable through the graph. If decisions live in markdown files the graph doesn't index, they can't be linked to the code they caused, the experiments that produced them, or the sessions they happened in. That breaks the "why does this code exist?" query — which is the entire point of building this way.

Nodes-with-body-files also preserves the editing experience: humans still write decisions in markdown, just like SKILL.md or agent.md files. No new editing surface to learn.

## Affects

- `mentor.ps1` `Cmd-Add` had to accept three new types (Move 3).
- `scaffold.psm1` had to grow three new body templates (Move 2).
- All future session/experiment/decision authoring goes through `mentor.ps1 add` rather than direct file creation.
- Edge vocabulary gained `has_decision` (already existed, 7→13 uses), `has_experiment` (new), `concluded_with` (new).

## Revisit if

- Body-file management becomes painful (e.g. 200+ decision files with no folder hierarchy).
- A workflow emerges that needs decisions to be sub-records of something other than a session (e.g. attached to a PR or work item directly).
- The `.md` body files start drifting from their graph nodes (orphan files, missing nodes). At that point we need an audit script, not a redesign.
