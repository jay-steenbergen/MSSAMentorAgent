---
id: 2026-06-01-orphan-md-edge-rule
type: session
description: "Make the orphan-markdown gate graph-driven: a .md file is 'needed' only if its node has at least one edge"
started_at: 2026-06-01
ended_at: 2026-06-01
goal: "Stop relying on hand-maintained allow-lists to decide whether a stray .md file under .github/knowledge-graph/ should be kept. Let the graph decide — by counting edges."
phase: hardening
---

# Session: 2026-06-01-orphan-md-edge-rule

Follow-on to [session:2026-06-01-gate-hardening](2026-06-01-gate-hardening.md). Four stale top-level docs (`AGENT-REDUCTION-SUMMARY.md`, `AUTO-DISCOVERY.md`, `GRAPH-GAP-ANALYSIS-2026-05-30.md`, `INTEGRATION_SUMMARY.md`) had been sitting in `.github/knowledge-graph/` for weeks. Jay asked: "do we need these? The graph should be able to tell us." Turned out two gates were silently letting them through — `find-orphan-markdown.ps1` only scanned `agents/skills/tests`, and `health.ps1` had an explicit regex exclusion for top-level KG docs. The fix lets the graph's edge topology answer the question.

## Goal

Replace the manual question "is this doc still useful?" with a graph-derived one: "does this doc's node have at least one edge?" Apply that rule across the whole `.github/knowledge-graph/` tree, with `README.md` and `CONTRIBUTING.md` as implicit entrypoints.

## Scope

- **In:**
  - Extend `find-orphan-markdown.ps1` to scan `.github/knowledge-graph/**/*.md` and enforce the edge-degree rule
  - Mirror the implicit-entrypoint exemption in `health.ps1`'s `code-coverage` check (drop the old top-level-KG-docs regex)
  - Delete the four orphan files
  - Fix the stale `INTEGRATION_SUMMARY.md` reference in `.github/knowledge-graph/README.md` tree diagram
  - Codify the rule as graph nodes (this session + experiment + decision)
- **Out:**
  - Promoting README/CONTRIBUTING to first-class graph nodes — implicit-entrypoint exemption is intentional, they are navigation not artifacts
  - Restructuring the `auto-discover-features.ps1` doc into the README — content was stale enough that it's better gone than salvaged
  - Adding an `entrypoint: true` node field — covered cleanly by the basename exemption, no schema change needed
- **Done when:**
  - `find-orphan-markdown.ps1` exits 0 on current state with new rule active
  - Negative test: a fresh untracked `JUNK.md` under `.github/knowledge-graph/` causes exit 1 with reason `NO-NODE`
  - `health.ps1 -Layer merged` reports `PASS 11 | WARN 0 | FAIL 0`
  - The four target files no longer exist on disk and deletes are staged
  - This session, the experiment, and the decision exist as graph nodes wired via `has_experiment` / `has_decision` / `concluded_with`

## Outcome

- **Audit first.** Built an ad-hoc audit listing every `.md` under `.github/knowledge-graph/` against the system graph. 8 had no node (the 4 known orphans + README/CONTRIBUTING + 2 sub-tree READMEs). 25 had nodes; all had at least 1 edge except `session:2026-06-01-graph-driven-setup` which had 0 incoming but 21 outgoing — confirming the rule must count edges in **either** direction. ✓
- **Rule extension.** Rewrote the orphan check to (a) add `.github/knowledge-graph/**/*.md` to its scan paths, (b) build a node-degree map (in + out), (c) report two distinct failure reasons — `NO-NODE` and `NO-EDGES` — with per-file detail and tailored fix instructions. `README.md` / `CONTRIBUTING.md` exempt by basename. ✓
- **Health coverage parity.** Dropped the `knowledge-graph[/\\][A-Z][A-Z0-9_-]+\.md$` exclusion in `health.ps1` (it was hiding the same bug from the coverage check) and added an explicit `README.md` / `CONTRIBUTING.md` basename exemption to match the orphan-md rule. Single source of truth for "what's an implicit entrypoint." ✓
- **Cleanup.** Deleted the 4 files. Fixed the `INTEGRATION_SUMMARY.md` reference in the top-level README tree diagram. Staged the deletes. ✓
- **Verification.** `find-orphan-markdown.ps1` → exit 0 on current state. `JUNK.md` negative test → exit 1 with `NO-NODE`. `health.ps1 -Layer merged` → `PASS 11 | WARN 0 | FAIL 0`. ✓

## Done-when verification (2026-06-01)

- ✅ `find-orphan-markdown.ps1` exits 0 — verified post-deletion
- ✅ Negative test: junk `.md` flagged with reason `NO-NODE`, exit code 1 — verified
- ✅ `health.ps1 -Layer merged`: `PASS 11 | WARN 0 | FAIL 0` — verified
- ✅ All 4 target files removed (`git status` shows `D ` for each, staged)
- ✅ Session node, experiment node, decision node all present, validated by `mentor.ps1 validate`

## Notes

The clearer the rule, the less reading anyone has to do. Before: "I think these docs are stale because of X, Y, Z." After: "the graph says these docs have no edges." Removing the human judgment removes a future correction round when memory of "why is this doc here?" is gone.

The previous gate-hardening session had set up the right enforcement scaffolding (Phase 2's orphan check). All this session did was widen its reach and add a stronger semantic check on top. The pattern composes — the same `find-orphan-markdown.ps1` now answers two questions instead of one without doubling the code.

Two follow-ups worth mentioning but deferred:
- The 2 sub-tree READMEs (`data/MentorAgent/code/README.md`, `data/MentorAgent/system/README.md`, `build/README.md`, `queries/README.md`) are exempt by the same rule — they're landing pages too. No action needed.
- If someone wants to formalize the "implicit entrypoint" concept later, adding `entrypoint: true` to the node schema would let the rule lift it out of the script. Not needed yet — basename works.
