# Whiteboarding track (bonus — not MSSA-official)

> **Track:** Whiteboarding · **Projects:** 9 · **Total time:** ~11 hours · **Target outcome:** confident at the whiteboard in interviews, architecture reviews, and team design sessions

Whiteboarding is the most under-taught skill in software engineering. Engineers ship code; engineers who can also stand at a whiteboard and explain WHY get promoted, get hired, and get heard. This track drills the visual vocabulary, the live-explanation technique, and the tooling (Mermaid, Draw.io) so the learner can sketch a system in 10 minutes and have anyone in the room follow.

## Why this is here

This is **not part of MSSA's official curriculum.** It's a force-multiplier on top of every MSSA track:

- **CAD** graduates will whiteboard API designs and data models in PR reviews and design discussions.
- **SCA** graduates will whiteboard hybrid identity flows, network topologies, and change-management playbooks.
- **CSO** graduates will whiteboard attack chains, incident timelines, and detection-engineering pipelines.

The skill transfers everywhere. The track uses the same `ride-along` method as the MSSA tracks.

## Stack

| Layer | Tool |
|---|---|
| **Practice surface** | A physical whiteboard + dry-erase markers, OR [Excalidraw](https://excalidraw.com) (free, browser, hand-drawn feel) |
| **Diagrams-as-code** | [Mermaid](https://mermaid.js.org) — text → diagram, version-controllable, renders in GitHub and VS Code |
| **Polished diagrams** | [Draw.io / diagrams.net](https://app.diagrams.net) — free, desktop or browser, exports to PNG/SVG/PDF |
| **Live presentation** | A real audience — a peer, a study partner, or recording yourself |

No certification target — this is a craft skill. The artifact is your ability to walk to a whiteboard and explain a system convincingly.

## Projects

| # | Skill | Time | Theme |
|---|---|---|---|
| 1 | [`wbd-whiteboard-foundations`](wbd-whiteboard-foundations/SKILL.md) | ~60 min | Legibility, layout, the 5 shapes you actually use, what to ditch | **ready** |
| 2 | [`wbd-box-and-arrow-diagrams`](wbd-box-and-arrow-diagrams/SKILL.md) | ~75 min | Architecture diagrams: components, dependencies, data flow direction | **ready** |
| 3 | [`wbd-sequence-diagrams`](wbd-sequence-diagrams/SKILL.md) | ~75 min | Actors, lifelines, messages — the time dimension | **ready** |
| 4 | [`wbd-state-machines-and-flowcharts`](wbd-state-machines-and-flowcharts/SKILL.md) | ~75 min | States vs steps, decisions, terminal nodes — when each wins | **ready** |
| 5 | [`wbd-entity-relationship-diagrams`](wbd-entity-relationship-diagrams/SKILL.md) | ~75 min | ER for data modeling: entities, attributes, cardinality | **ready** |
| 6 | [`wbd-mermaid-as-code`](wbd-mermaid-as-code/SKILL.md) | ~75 min | Mermaid syntax across flowchart/sequence/state/ER — version your diagrams | **ready** |
| 7 | [`wbd-drawio-for-polished-diagrams`](wbd-drawio-for-polished-diagrams/SKILL.md) | ~75 min | Draw.io: when text-to-diagram isn't enough. Stencils, layers, export | **ready** |
| 8 | [`wbd-system-design-interview`](wbd-system-design-interview/SKILL.md) | ~90 min | The classic: design Twitter / URL shortener / chat — time-boxed, walking the framework | **ready** |
| 9 | [`wbd-capstone-present-a-system`](wbd-capstone-present-a-system/SKILL.md) | ~90 min | Capstone — pick a real system, whiteboard end-to-end, present to a human, take feedback | **ready** |

## Lab requirements

| Need | Cost |
|---|---|
| Whiteboard OR Excalidraw (browser) | $0 (Excalidraw) or $20–50 (small dry-erase board + markers) |
| VS Code with Mermaid preview extension | $0 |
| Draw.io desktop app or browser | $0 |
| A human to present to (project #9) | $0 — a peer, mentor, study partner, or family member |

**No cloud bills. No subscriptions. The whole track runs on free tools.**

## Cost discipline

Zero. The most expensive thing in this track is a 4-pack of dry-erase markers. Skip the markers entirely if you use Excalidraw.

## Out of scope

- **UX/visual design** — we're not making pretty diagrams for marketing. We're making clear diagrams for engineers.
- **Specific notations** (UML class diagrams in full, BPMN, ArchiMate) — these exist; this track teaches the 80% used in working engineering teams.
- **Drawing skill** — you do not need to draw well. Boxes and arrows are enough.

## Related material

- [`methods/ride-along/SKILL.md`](../../methods/ride-along/SKILL.md) — the teaching method behind every project.
- [`.copilot/skills/whiteboard/SKILL.md`](../../../../../.copilot/skills/whiteboard/SKILL.md) — Kimberly's whiteboarding skill (Mermaid + Draw.io tooling she uses).
