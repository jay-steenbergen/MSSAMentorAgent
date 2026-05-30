# System Graph — Architecture & Call Flow

Structured map of every piece of the Mentor system as a CONCEPT graph: agent, skills, protocols, decisions, rules, schemas, fields, files, scripts, tests, analogies, and the edges between them.

Companion: [`../code/`](../code/) maps the SOURCE behind these concepts. [`../merge.ps1`](../merge.ps1) ties them together.

---

## Files

| File | What it is |
|---|---|
| [mentor-graph.json](mentor-graph.json) | The graph. Source of truth. |
| [audit.ps1](audit.ps1) | Validate the graph against the live repo. Flags broken file refs, dangling edges, missing methods. |
| README.md | This file. |

---

## How to read it

The graph has five sections:

| Section | What it contains |
|---|---|
| `metadata` | Name, version, root file, schema summary. |
| `clusters` | 9 thematic groupings used to color/lay out the graph. |
| `nodes` | Every entity in the system. Each has `id`, `type`, `label`, `cluster`, `file`, `description`. |
| `edges` | Typed relationships between nodes. Each has `source`, `target`, `type`, optional `label` and `evidence`. |
| `analysis` | The interesting part — duplicates, conflicts, JSON-extraction candidates, orphans, consolidation opportunities, drift-detection checks, agent self-discovery hooks. |

---

## Clusters (9)

| Cluster | What lives there |
|---|---|
| `agent-core` | Mentor identity, core_behavior YAML, audience, enums, top-level docs. |
| `agent-rules` | 10 behaviors, personality + humor rules, anti-patterns, stuck escalation, success calibration. |
| `session-protocols` | Session start, mid-session switching, session end. Pickers and decisions. |
| `profile-system` | learner-profile skill, interview, follow-up, coordination, edge cases. |
| `teaching-methods` | ride-along, TDD, BDD, spike-then-refactor — phases, contexts, anti-patterns. |
| `proficiency-tracking` | 4-level system, indicators, progression signals. |
| `data-layer` | profile.json + progress.json schemas, every field, the actual file paths. |
| `validation-layer` | PowerShell scripts and `.test.md` integration tests. |
| `references-and-analogies` | MOS mappings, branch communication cultures, military→code analogy bank. |

---

## Node types

| Type | Used for |
|---|---|
| `agent` | The Mentor itself. |
| `skill` | A SKILL.md file. |
| `architecture` | A system component, layer, or architectural pattern. |
| `protocol` | A named, ordered sequence of steps (e.g., session start). |
| `phase` | One step inside a protocol or a method cycle. |
| `decision` | A branch point (`if X then Y`). |
| `picker` | A user-facing choice (e.g., method picker). |
| `rule` | An explicit do or don't. |
| `principle` | A philosophical guideline (broader than a rule). |
| `concept` | A named idea (e.g., "move", "altitude", "AAR"). |
| `schema` | A data structure (profile.json, progress.json). |
| `field` | A key inside a schema. |
| `enum` | An enumerated set (methods, tracks). |
| `level` | A proficiency level (Novice / Familiar / Competent / Proficient). |
| `indicator` | A phrase pattern that signals a level. |
| `signal` | A progression marker (Novice → Familiar). |
| `analogy` | A military→code mapping. |
| `reference` | A reference file or entry inside one. |
| `file` | An actual file on disk. |
| `script` | A PowerShell script. |
| `test` | A `.test.md` integration test. |
| `validator` | xUnit test project. |
| `question` | An interview question. |

---

## Edge types

| Type | Meaning |
|---|---|
| `composes` | Agent loads this skill. |
| `embodies` | Agent expresses this core behavior. |
| `follows` | Agent follows this rule/protocol. |
| `implements` | Skill implements this protocol/rule. |
| `has_phase` | Protocol → its phases. |
| `next` | Phase A → Phase B in a cycle. |
| `escalates_to` | Stuck rung N → rung N+1. |
| `routes_to` | Decision branches. |
| `triggers` | One protocol kicks off another. |
| `updates` | Action writes to a file/field. |
| `validates` | Script validates a file/field. |
| `tests` | Test exercises a skill/protocol. |
| `references` | One node cites another. |
| `delegates_to` | Behavior hands off to a skill. |
| `reads_from` / `reads` | Adaptation reads a profile field. |
| `writes_to` | Interview Q writes to a field. |
| `has_field` | Schema → field hierarchy. |
| `instance_of` | File → schema. |
| `constrained_by` | Field value must be in this enum. |
| `progresses_to` | Proficiency level chain. |
| `indicates` / `uses_indicator` / `uses_signal` | Proficiency assessment links. |
| `forbids` | Skill forbids this anti-pattern. |
| `avoids` | Agent avoids this anti-pattern. |
| `enforces` | Skill enforces this rule. |
| `has_decision` / `has_rule` | Skill → its decisions/rules. |
| `defines` | Skill defines this concept. |
| `uses` | Generic dependency. |
| `documents` | Doc file describes the agent. |
| `duplicates` ⚠️ | **Two nodes describe the same rule in different places — drift risk.** |
| `duplicated_in` ⚠️ | Same as above, directed. |
| `fallback_to` | Routing escape hatch. |
| `template_for` | Test template → tests built from it. |
| `optionally_uses` | Conditional dependency. |
| `applies_to` / `example_of` / `operationalizes` / `has_style` / `complemented_by` / `targets` / `enumerates` / `includes` / `contains` / `describes` / `handles` / `appends_to` / `creates` / `loads` / `starts_with` / `ends_with` / `measures_by` / `has_escape_hatch` / `has_fallback` / `adapts_via` / `calls` | Narrower semantic relationships used where they make the graph clearer. |

---

## What the `analysis` section is for

This is the section to read **first** if you want to improve the system.

### `duplicates`
8 places where the same rule lives in two or more files. Highest-severity:
- Stuck escalation ladder (Mentor.agent.md + ride-along/SKILL.md)
- Anti-patterns list (Mentor.agent.md "What you do NOT do" + ride-along "Hard rules")
- Compression resilience pattern (4 files, identical 3-step pattern)

### `conflicts`
5 real contradictions. Highest-severity:
- **Path drift:** Mentor.agent.md uses the OLD `{username}.json` single-file path; learner-profile uses the CURRENT `{username}/profile.json` directory structure.
- **Bad relative path:** Behavior #9 in Mentor.agent.md points at `../skills/methods/learner-profile/SKILL.md` (wrong — learner-profile is not under `methods/`).
- **Method naming inconsistency:** JSON uses `spike_then_refactor` / `ride_along` (underscores); folders + enum + progress files use hyphens.

### `candidate_json_extractions`
8 rules currently in markdown that could be data files. Biggest wins:
- The 10 behavioral rules → `mentor-behaviors.json`
- Anti-patterns → `teaching-anti-patterns.json` (shared across methods)
- Pace × stuck × motivation adaptation → `profile-adaptation.json`
- Branch communication cultures → `branch-cultures.json` (6 branches × 4 fields = clean table)

### `orphans_and_gaps`
- Tracks (cloud-app-dev, server-cloud-admin, cybersecurity-ops) are enumerated but NO track skills exist yet.
- No test verifies branch culture adaptation actually happens.
- No test verifies the agent picks appropriate analogies from `military.extracted_concepts`.
- No rollback path when `validate-profile.ps1` fails after the JSON is written.

### `consolidation_opportunities`
3 architectural simplifications worth considering. Headline: a single `adaptation.json` policy file driving every profile-based behavior switch (pace, when_stuck, motivation, proficiency, branch culture) instead of scattered if/then rules.

### `drift_detection_checks`
8 invariants the graph asserts. `audit.ps1` runs them.

### `self_discovery_hooks`
5 graph queries the agent could run at runtime to figure out what skill to load, which analogy to pick, what files to update at session end, which method to route to, what to build when adding a new method.

---

## When to update this graph

| When you... | Do this |
|---|---|
| Add a new skill | Add a node `skill:<id>` and edges to its phases, anti-patterns, proficiency indicators. |
| Add a new method | Add to `list:methods`, add 4 indicator nodes + 3 signal nodes, add a row to method-routing edges. |
| Add a track skill | Add a node `skill:track-<id>`, create edges from `concept:track-<id>`. |
| Rename a file | Update every node whose `file` field references it. Run `audit.ps1`. |
| Add a behavioral rule | Add a `rule` node in `agent-rules` cluster, edge from `agent:mentor` with type `follows`. Check `analysis.duplicates` — does this overlap an existing rule? |
| Find a contradiction | Add it to `analysis.conflicts` with severity + fix. |
| Extract markdown to JSON | Add a `candidate_json_extractions` entry first as a proposal. After execution, replace nodes' `file` field with the new JSON path. |

---

## Stats (current)

| | Count |
|---|---|
| Nodes | 269 |
| Edges | 385 |
| Clusters | 9 |
| Duplicates flagged | 8 |
| Conflicts flagged | 5 |
| JSON-extraction candidates | 8 |
| Orphans + gaps | 6 |
| Drift-detection checks | 8 |
