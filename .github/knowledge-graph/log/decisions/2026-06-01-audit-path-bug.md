---
id: 2026-06-01-audit-path-bug
type: decision
description: "query.psm1 Get-GraphQualityReport broken-refs check used Join-Path with two .. levels; should be three. PSScriptRoot=lib/, node.file is repo-root-relative. Fixed by adding one more '..'. Caused 57 false-positive broken refs."
decided_at: 2026-06-01
---

# Decision: audit path bug (off-by-one)

In `.github/knowledge-graph/lib/query.psm1`, the broken-refs check in `Get-GraphQualityReport` was using two `..` segments in `Join-Path`, which resolved to `.github/.github/...` instead of the repo root. Result: every node whose `file` field pointed under `.github/` was reported as missing. 57 false positives in the most recent audit.

## Chose

Add a third `..` to the `Join-Path` call so it climbs from `lib/` up to repo root before joining with `$node.file`.

```powershell
# Before
$fullPath = Join-Path $PSScriptRoot ".." ".." $node.file

# After
$fullPath = Join-Path $PSScriptRoot ".." ".." ".." $node.file
```

Also added a comment block explaining the level count so the next person doesn't have to rediscover it.

## Over

Alternative was using `Resolve-Path` against a repo-root variable computed once at module load. Rejected because it would require touching more of the module than necessary; the off-by-one is a one-character fix.

## Because

- `$PSScriptRoot` is `.github/knowledge-graph/lib` (three levels under repo root).
- `$node.file` is repo-root-relative by convention (verified across all skill, agent, track, method, test nodes).
- `Join-Path` does not resolve away `..` segments; if the inputs disagree, the path silently double-prefixes and `Test-Path` returns `False`.
- A one-line fix with a comment was lower risk than refactoring how paths are computed.

## Affects

- `lib/query.psm1` `Get-GraphQualityReport` (the actual fix).
- `cli/audit-quality.ps1` (consumes the report — no change, just now reports truth).
- Any caller of `Get-GraphQualityReport` that filters on `broken_refs` (none today, but future automation should now be trustworthy).

## Revisit if

- `$PSScriptRoot` for `query.psm1` changes (e.g., if `lib/` moves).
- The convention for `node.file` changes from repo-root-relative to something else.
- A second tool starts checking file existence — extract the path-resolution logic to a shared helper to prevent the same bug recurring.
