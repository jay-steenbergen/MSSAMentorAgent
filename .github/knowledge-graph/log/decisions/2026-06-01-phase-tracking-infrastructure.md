---
id: 2026-06-01-phase-tracking-infrastructure
type: decision
description: "This session's phase value is 'tracking-infrastructure' — Phase 0 of the 5-phase plan"
decided_at: 2026-06-01
---

# Decision: 2026-06-01-phase-tracking-infrastructure

The phase value chosen for this session — `tracking-infrastructure`. Captured as its own decision so the choice is queryable and revisable independent of the session it labels.

## Chose

`tracking-infrastructure` as the named phase value for session `2026-06-01-graph-driven-setup`.

## Over

- `phase-0` (numeric — see `decision:2026-06-01-named-phase-field` for why named won).
- `bootstrap` (too generic — could mean repo bootstrap, agent bootstrap, anything).
- `meta-tooling` (accurate but boring; doesn't say what's being built).
- `eating-our-own-dogfood` (catchy but not searchable; doesn't survive month-from-now scanning).

## Because

`tracking-infrastructure` names what's actually being built: the infrastructure for tracking the build itself. Future sessions in the same phase will share this label (e.g. if Move 6 turns out to need new extensions to the tracking system).

This is intentionally a micro-decision. The honest reason it exists as its own node: thoroughness was the chosen mode. If we ever fold the micro-decisions, this one and `named-phase-field` merge into the `log-as-graph-nodes` decision as detail sections.

## Affects

- Session `2026-06-01-graph-driven-setup` body frontmatter gets `phase: tracking-infrastructure`.
- No graph changes beyond the node itself.

## Revisit if

- Phase labels stop being useful and we move to numeric or edge-based phases. Then this decision and `named-phase-field` get superseded together.
- We realize the session was actually in two phases (tracking + skill-authoring) and need to split it.
