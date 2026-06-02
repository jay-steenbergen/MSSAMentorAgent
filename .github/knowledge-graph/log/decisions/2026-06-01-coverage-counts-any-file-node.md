---
id: 2026-06-01-coverage-counts-any-file-node
type: decision
description: "Health code-coverage check counts any graph node with a .file field, not only type=code-file"
decided_at: 2026-06-01
---

# Decision: Coverage counts any file-owning node

The `code-coverage` check in `health.ps1` compares tracked repo files against the set of graph nodes that own a file. "Owns a file" means **any node with a non-empty `.file` field**, regardless of `type`.

## Chose

```powershell
$graphFilePaths = @($nodes | Where-Object { $_.file } |
    ForEach-Object { $_.file -replace '\\', '/' }) | Sort-Object -Unique
```

Single source of truth: if a node has a `file` field that points at a tracked repo file, that file is "in the graph."

## Over

- **`type -eq 'code-file'`** (the previous behavior) — under-counted by 21 because `session` / `experiment` / `decision` nodes own `.md` body files per [decision:log-as-graph-nodes](2026-06-01-log-as-graph-nodes.md) but aren't `code-file` typed. Same logic applies to `agent:` and `skill:` nodes which would have failed for the same reason if they weren't already getting `code-file` bridges from the extractor.
- **An allow-list of file-owning types** (`code-file`, `session`, `experiment`, `decision`, ...) — fragile. Every new file-owning type would need a separate update to `health.ps1` to keep coverage honest. The `.file` field is the actual contract; checking it directly is the durable rule.
- **Separate coverage check per type** — over-engineering for an audit that's just asking "is every tracked file represented somewhere in the graph?"

## Because

The graph's contract for "this node represents this file" is the `file` field, not the `type` field. Three established node patterns already use this contract:

| Type pattern | Owns file via | Example |
|---|---|---|
| `code-file:` | `.file` field | `.github/skills/learner-profile/SKILL.md` |
| `agent:` / `skill:` / `track:` / `method:` | `.file` field | `.github/agents/Mentor.agent.md` |
| `session:` / `experiment:` / `decision:` | `.file` field | `.github/knowledge-graph/log/sessions/...md` |

The previous check coincidentally worked for case 1 only because the extractor auto-creates a `code-file` bridge for any `.file`-referenced path. It silently broke case 3 because log nodes are pure system-layer (no code extraction).

Checking the `.file` field directly works for all three cases, future-proofs against new file-owning types, and matches how the rest of the graph treats node-to-file mapping. It's the rule that should always have been there.

The diagnosis was confirmed before editing: a throwaway script compared all 21 missing log files against both filter strategies and showed `code-file=False / anyNode=True` for every one. Single-line fix; immediate verification (see [experiment:coverage-counts-log-nodes](../experiments/2026-06-01-coverage-counts-log-nodes.md)).

## Affects

- `.github/knowledge-graph/build/core/health.ps1` — `code-coverage` block now filters on `.file` field instead of `type -eq 'code-file'`.
- Health summary improved from `PASS 10 | WARN 1 | FAIL 0` to `PASS 11 | WARN 0 | FAIL 0`.
- Pre-commit hook header changed from `Graph health: PASS 10 | WARN 1 (non-critical)` to `Graph health: All checks passed`.
- Coverage went from 86.5% (135 / 156) to 100% (156 / 156).
- Commit `ab3204b` pushed to master.

## Revisit if

- A future node type uses `file` to mean something other than "this node represents this on-disk file" (e.g. a foreign-key style reference to another node's file). At that point the contract needs to be more specific — e.g. only count nodes with both `file` AND a specific marker — but until that happens, the simpler rule is correct.
- The coverage check needs to differentiate "tracked but not in graph" from "in graph but not tracked." Right now it only flags the first direction; the second (stale graph nodes pointing at deleted files) is already covered by the `missing-files` check.
