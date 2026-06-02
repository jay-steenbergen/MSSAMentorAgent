# Decision: Phase 5 — graph is the source of truth for session Outcome

**Date:** 2026-06-01
**Phase:** 5 of the graph-driven build
**Session:** `session:2026-06-01-graph-driven-setup`
**Concludes:** `experiment:2026-06-01-phase-5-session-status`

## Chose

Render session Outcome **from the graph** via a new `mentor.ps1 session-status <id>` CLI verb. The session markdown keeps Goal / Scope / Done-when / Notes; Outcome becomes a query.

## Over

- **A. Auto-rewrite the session markdown** (Outcome block replaced from edges by a script): rejected — coupling a file generator to commit hooks risks merge conflicts on a doc humans also edit. Pure read-only CLI sidesteps the problem.
- **B. Leave the doc as the source of truth** (status quo): rejected — Move 5 just proved this fails. The doc was stale because no one (including the agent) had a reason to keep it in sync until a human spotted it.
- **C. Render via the merged graph instead of system graph**: rejected for now — system graph already has every node/edge we need, and reading the smaller file is faster. Revisit if code-graph nodes ever start participating in session edges.
- **D. Build a full "node-status" generic renderer for any node type**: rejected — YAGNI. Sessions are the case that bit us today. Experiment + decision + arbitrary node types can come later when they bite.

## Because

- Every Phase 0-4 outcome already lives in the graph as `(session) --has_experiment--> (experiment) --concluded_with--> (decision)` and `(session) --has_decision--> (decision)` edges. The markdown's Outcome list was just a stale projection.
- A read-only CLI verb has near-zero blast radius: no writes, no hook interactions, no schema changes. The graph stays the contract; the verb is a view.
- Inlining `concluded_with` decisions under each experiment in the output mirrors how the reasoning actually flows (experiment → decision), so the rendered view is more useful than the original prose list.
- Symmetry with existing verbs (`add`, `link`, `remove`, `validate`, `types`) — adding one more pure-read verb fits the established CLI surface.

## Affects

- `.github/knowledge-graph/cli/mentor.ps1` — adds `Cmd-SessionStatus` + dispatch entry + Show-Usage update + header comment.
- Future sessions can stop hand-maintaining Outcome blocks. The doc keeps Goal / Scope / Done-when / Notes (prose with judgment) and points at `session-status` for the structured view.
- Other consumers (CI, dashboard, agent context) gain a single source for session state.

## Revisit if

- A session needs to render *historical* state (what the Outcome looked like at a past commit). Current `session-status` reads HEAD. If we need time-travel views, this verb becomes one of many on top of a graph-history layer.
- Experiments or decisions accumulate enough metadata that a flat list becomes hard to read. At that point: add filters (`--phase`, `--since`), or paginate.
- We start using `has_session` (parent → child session edges) frequently — the current renderer surfaces them but doesn't recurse. Recursion is a one-line change if needed.
- Markdown drift between doc and graph becomes a recurring issue → consider Option A (auto-rewrite) at that point, now that the read path is proven.
