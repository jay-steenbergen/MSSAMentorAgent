---
id: 2026-06-01-orphan-md-edge-rule
type: experiment
description: "Replace allow-list-based markdown gate with edge-degree rule: a doc is needed iff its node has at least one edge"
session: 2026-06-01-orphan-md-edge-rule
status: concluded
---

# Experiment: Orphan Markdown — Edge-Degree Rule

**Date:** 2026-06-01
**Session:** 2026-06-01-orphan-md-edge-rule
**Status:** Concluded

---

## Hypothesis

A markdown file's value to the system isn't determined by where it lives, who wrote it, or whether someone *thinks* it's still useful. It's determined by whether the graph connects it to anything. So the gate question "do we need this doc?" can be answered structurally: **does this doc's node have at least one edge in or out?**

Two prior failure modes pointed at the same gap:

1. `find-orphan-markdown.ps1` only checked **node existence**, not connectivity. A registered-but-disconnected node would pass.
2. The check didn't scan `.github/knowledge-graph/**` at all. `health.ps1` even had an explicit regex (`knowledge-graph[/\\][A-Z][A-Z0-9_-]+\.md$`) excluding top-level KG docs from coverage — so 4 stale docs had been sitting there for weeks, invisible to both gates.

The hypothesis is that lifting the rule to "node + ≥1 edge" plus widening the scan path will close both gaps with the same primitive, and the rule will be self-describing enough that future authors don't need to read a policy doc to know why a file got rejected.

## What we measured first

Before changing any code, audited the current state:

| File | Node? | Incoming edges | Outgoing edges | New rule says |
|---|---|---|---|---|
| `AGENT-REDUCTION-SUMMARY.md` | NO | — | — | FAIL (NO-NODE) |
| `AUTO-DISCOVERY.md` | NO | — | — | FAIL (NO-NODE) |
| `GRAPH-GAP-ANALYSIS-2026-05-30.md` | NO | — | — | FAIL (NO-NODE) |
| `INTEGRATION_SUMMARY.md` | NO | — | — | FAIL (NO-NODE) |
| `README.md` | NO | — | — | EXEMPT (implicit entrypoint) |
| `CONTRIBUTING.md` | NO | — | — | EXEMPT (implicit entrypoint) |
| `data/MentorAgent/{code,system}/README.md` × 2 | NO | — | — | EXEMPT (implicit entrypoint) |
| `build/README.md` | NO | — | — | EXEMPT (implicit entrypoint) |
| `queries/README.md` | NO | — | — | EXEMPT (implicit entrypoint) |
| 25 `log/{sessions,experiments,decisions}/*.md` | yes | 0–3 | 0–21 | PASS (have ≥1 edge) |

Notable: `session:2026-06-01-graph-driven-setup` has **0 incoming, 21 outgoing**. If the rule only counted incoming edges, this legitimate session log would fail. Confirmed: the rule must count **in + out**.

## Operations

1. **Extended `find-orphan-markdown.ps1` scan paths.** Added `.github/knowledge-graph` with filter `*.md` to the patterns array. Now covers `agents/skills/tests` + the whole `knowledge-graph` tree.

2. **Built node-degree map.** Walked all edges once, incrementing a counter for both `source` and `target` ids. Hash lookup by node id gives total degree in O(1) per file checked.

3. **Two failure modes, separate reporting.** Classified each file as `NO-NODE` (file on disk, not in graph) or `NO-EDGES` (registered but degree 0). Output groups by reason with per-file detail and a tailored fix instruction. Authors see *why* their file was rejected without guessing.

4. **Implicit-entrypoint exemption by basename.** Hard-coded `README.md` and `CONTRIBUTING.md` as exempt. These are landing pages, not artifacts — adding them as graph nodes would be cargo-cult bookkeeping. Basename match means the rule applies anywhere in the tree (top-level KG, sub-tree READMEs, future folder READMEs all covered automatically).

5. **Mirrored the exemption in `health.ps1`.** Dropped the old `knowledge-graph[/\\][A-Z][A-Z0-9_-]+\.md$` regex (was hiding the same bug from coverage) and added two new entries to `$intentionalExcludes` matching `README.md` and `CONTRIBUTING.md` by basename anywhere in the path. Both gates now answer the question consistently.

6. **End-to-end test.** With current state: ran the check → "Every artifact .md is either an implicit entrypoint OR has a graph node with >=1 edge", exit 0. With a fresh `JUNK-TEST.md` dropped at `.github/knowledge-graph/JUNK-TEST.md`: check reported `NO-NODE` with exit code 1. Removed the junk file, re-ran: exit 0 again.

7. **Cleanup.** Deleted the 4 confirmed orphans. Fixed the stale `INTEGRATION_SUMMARY.md` line in `.github/knowledge-graph/README.md` tree diagram. Staged the deletes.

## What worked

- **Degree map built once, looked up per file.** O(E + F) instead of O(E × F). For the current graph (1300+ edges, ~30 KG-tree md files) the cost is invisible — sub-second.
- **Two failure reasons, one gate.** Authors who see `NO-NODE` know to run `mentor.ps1 add`. Authors who see `NO-EDGES` know they need a relationship — different fix, different message, no ambiguity.
- **Basename exemption.** Zero schema changes. Future folder added with a `README.md`? Already covered. No new policy doc to write.
- **Negative test confirmed the gate fires.** Easy to test in isolation: drop a junk file, run the script, observe exit 1.

## What didn't

- Initial attempt to inline a one-liner audit in the terminal failed twice on PowerShell quoting (heredoc vs single-line). Switched to a `pwsh -NoProfile -Command @'...'@` here-string, which worked. Lesson logged: for non-trivial PowerShell scripted via `run_in_terminal`, write the script into a `.ps1` or use the here-string form.

## Conclusion

The rule is general enough to replace the hand-maintained allow-list everywhere it matters, and the two-failure-mode output is clear enough that an author hitting the gate doesn't have to read a policy doc to fix the problem. The gate now answers the question with one primitive: edge count.

Concluded with [decision:2026-06-01-orphan-md-edge-rule](../decisions/2026-06-01-orphan-md-edge-rule.md).
