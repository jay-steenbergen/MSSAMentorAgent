---
id: 2026-06-01-named-phase-field
type: decision
description: "Session 'phase' field is a free-form named string (option beta), not numeric or edge-based — easier to read in body frontmatter"
decided_at: 2026-06-01
---

# Decision: 2026-06-01-named-phase-field

Sessions carry a `phase` field in their body frontmatter (not in the graph node) as a free-form named string like `tracking-infrastructure`, `graph-health-audit`, `skill-authoring-loop`.

## Chose

Option β — free-form named string in frontmatter. Values are documented elsewhere (the 5-phase plan); validation is by social convention not schema.

## Over

- Option α: numeric phase (`phase: 0`, `phase: 1`...). Rejected because readers can't tell what phase 0 means without looking it up.
- Option γ: graph edge from session to a `phase:` node (e.g. `session --[in_phase]--> phase:tracking-infrastructure`). Rejected as premature — we don't yet know if phases will need cross-session aggregation queries, and adding the edge type now is reversible later.

## Because

Named strings are self-documenting in the body file. A reader opening `2026-06-01-graph-driven-setup.md` sees `phase: tracking-infrastructure` and immediately knows what context they're in. Numeric phases require the 5-phase plan as a Rosetta stone.

Keeping `phase` in body frontmatter (not graph node) avoids polluting the graph node schema with a field most queries won't need. If queries against `phase` get common, promote it later.

## Affects

- Session body template gets a `phase:` field. Decision/experiment templates do not.
- No graph node schema change. No edge vocabulary change.

## Revisit if

- We start asking "show me every session in phase X" frequently enough that scanning body files becomes annoying. Then either add a graph field or build an indexer.
- Phases proliferate beyond ~10 named values and consistency suffers. At that point a controlled vocabulary (enum) is worth the schema cost.
