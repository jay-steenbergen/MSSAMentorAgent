---
id: 2026-06-01-orphan-md-edge-rule
type: decision
description: "A markdown file under .github/knowledge-graph/ is 'needed' iff its node has at least one edge (in OR out); README.md and CONTRIBUTING.md are implicit entrypoints exempt by basename"
session: 2026-06-01-orphan-md-edge-rule
experiment: 2026-06-01-orphan-md-edge-rule
status: active
---

# Decision: Markdown is "Needed" When Its Graph Node Has Edges

**Date:** 2026-06-01
**Session:** 2026-06-01-orphan-md-edge-rule
**Experiment:** 2026-06-01-orphan-md-edge-rule
**Status:** Active

---

## Rule

A markdown file anywhere under `.github/knowledge-graph/`, `.github/agents/`, `.github/skills/`, or `.github/tests/` is considered "needed" by the system iff **both** of these are true:

1. There is a graph node whose `file` field points to that path.
2. That node has **at least one edge** — incoming OR outgoing — in the merged graph.

**Exemption:** Any file whose basename is `README.md` or `CONTRIBUTING.md` is an *implicit entrypoint* and exempt from both conditions. These are landing pages, not artifacts.

Files failing the rule are blocked at pre-commit by `find-orphan-markdown.ps1` with one of two reasons:

- `NO-NODE` — file on disk, no node references it. Fix: `pwsh .github/knowledge-graph/cli/mentor.ps1 add <type> <slug> -File <path>`.
- `NO-EDGES` — node exists, has zero edges. Fix: `pwsh .github/knowledge-graph/cli/mentor.ps1 link <source-id> <target-id> <edge-type>`.

## Context

Four stale top-level docs (`AGENT-REDUCTION-SUMMARY.md`, `AUTO-DISCOVERY.md`, `GRAPH-GAP-ANALYSIS-2026-05-30.md`, `INTEGRATION_SUMMARY.md`) had been in the repo for weeks. Two gates had been silently allowing them:

- `find-orphan-markdown.ps1` only scanned `agents/skills/tests` — never looked at `.github/knowledge-graph/**`.
- `health.ps1` had an explicit regex exclusion (`knowledge-graph[/\\][A-Z][A-Z0-9_-]+\.md$`) for top-level KG docs, originally added to suppress unrelated noise.

The result: nobody could see the problem from either gate's output, and the only way to find it was to manually `ls` the directory and ask "what is all this?"

## Options considered

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Allow-list of approved KG-tree filenames** | Trivial to implement. | Drifts. New files require a list update. Doesn't catch *connected but useless* docs. | Rejected — same failure mode as today, just relocated. |
| **Incoming-edges only** | Tight: a doc earns its keep by being referenced. | Breaks legitimate session logs (one in this repo has 0 incoming, 21 outgoing). Punishes "source of truth" nodes. | Rejected — false positives on real artifacts. |
| **Outgoing-edges only** | Symmetric to above. | Breaks leaf nodes (decisions, terminal experiments). | Rejected — false positives on real terminals. |
| **Either direction** ✅ | Captures both "node points at others" and "node is pointed at." Self-correcting: orphans surface, connected nodes don't. | A node connected to *anything* survives, even a stale connection. Acceptable: stale edges show up in other gates. | **Selected.** |
| **`entrypoint: true` schema field** | Explicit, queryable, no basename magic. | Requires schema change + node registration for files that exist solely to be landing pages. Doesn't add information the basename doesn't already encode. | Deferred — basename works. Revisit if a non-README landing page ever needs the exemption. |

## Why basename for the exemption

`README.md` and `CONTRIBUTING.md` are universal conventions. Anyone — human or tool — landing in a folder reaches for them without checking a registry. Treating them as graph nodes would add bookkeeping with no semantic gain (no other node would meaningfully link to "this folder's README"; the relationship is implied by the folder containing it).

Mirroring the exemption in both `find-orphan-markdown.ps1` and `health.ps1` keeps the rule consistent in **two** places — single semantic, two enforcement points. Adding a third would mean a real concept worth promoting to the schema. Until then: two scripts, two-line exemption each, easy to grep.

## Implementation

- **`.github/knowledge-graph/cli/find-orphan-markdown.ps1`** — scans extended to `.github/knowledge-graph/**/*.md`; degree map built once; per-file classification into `NO-NODE` / `NO-EDGES`; basename exemption applied first.
- **`.github/knowledge-graph/build/core/health.ps1` (`Test-CodeCoverage`)** — old `knowledge-graph[/\\][A-Z][A-Z0-9_-]+\.md$` exclusion removed; `README.md` / `CONTRIBUTING.md` basename exemptions added to `$intentionalExcludes`.
- **No schema changes** — works against the existing `nodes[].file` + `edges[]` arrays. No migration.

## Consequences

- **Positive:**
  - Orphan files cannot accumulate in `.github/knowledge-graph/` without pre-commit blocking them.
  - Failure messages tell authors exactly which command to run (`mentor.ps1 add` vs `mentor.ps1 link`).
  - Sub-tree READMEs (`build/`, `queries/`, `data/MentorAgent/{code,system}/`) automatically exempt by the same rule — no policy update needed.
  - Both gates now agree on the answer. No "passes one, fails the other" surprises.
- **Negative:**
  - A node connected to a stale edge will still pass. If staleness becomes a problem, add a "last-touched" or "alive" check as a separate gate — don't conflate it with the orphan rule.
  - Adding a new file requires either registering it as a node OR naming it `README.md`. This is intentional friction — exactly the behavior change we wanted.
- **Neutral:**
  - If someone wants a non-README landing page, they must add it as a node with edges, or revisit the exemption design. No current case for this.

## Done-when

- ✅ `find-orphan-markdown.ps1` exits 0 on current state
- ✅ Negative test: junk `.md` under `.github/knowledge-graph/` causes exit 1 with reason `NO-NODE`
- ✅ `health.ps1 -Layer merged` reports `PASS 11 | WARN 0 | FAIL 0`
- ✅ The 4 target orphans deleted and staged

## Revisit triggers

- A non-README landing page ever earns its keep → revisit `entrypoint: true` schema option
- Stale-but-connected nodes become a real problem → add a separate freshness check, do **not** weaken this rule
- Edge-degree map grows large enough to be a perf concern (1000s of files) → switch from hash map to graph-walk on demand
