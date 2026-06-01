---
id: 2026-06-01-audit-vs-validate-reconciliation
type: experiment
description: "Reconciled audit's 57-broken-refs claim against mentor.ps1 validate's clean result. Found audit path bug; validate was correct; tools are complementary."
run_at: 2026-06-01
result: worked
---

# Experiment: 2026-06-01-audit-vs-validate-reconciliation

Phase 1 of the graph-driven build plan. Move 1 of this session had produced an audit report claiming **57 broken file references** across skills, methods, and tracks. The same graph passed `mentor.ps1 validate` with `PASS 8 | WARN 3 | FAIL 0`. Two tools, two stories. Reconcile before trusting either.

## Hypothesis

One of three possibilities:
1. `mentor.ps1 validate` has a blind spot — it doesn't check file existence.
2. `audit-quality.ps1` has a bug — false positives.
3. Both are right and they answer different questions (different lenses on graph health).

If (1), we have a silent class of breakage. If (2), the Move 1 audit overstated the problem. If (3), we keep both and document when to use which.

## Operations

```powershell
# 1. Spot-check audit's claims against the filesystem
Test-Path '.github/skills/learner-profile/SKILL.md'         # True
Test-Path '.github/skills/methods/ride-along/SKILL.md'      # True
Test-Path '.github/skills/methods/TDD/SKILL.md'             # True
Test-Path '.github/skills/tracks/cloud-app-dev/README.md'   # True

# 2. Read the broken-refs check in lib/query.psm1
#    Found: $fullPath = Join-Path $PSScriptRoot ".." ".." $node.file
#    $PSScriptRoot = .github/knowledge-graph/lib
#    Two `..` lands at .github/, then $node.file is prepended.
#    But $node.file is repo-root-relative and already starts with ".github/" → double-prefix.

# 3. Reproduce the path bug in isolation
$psr = '.github/knowledge-graph/lib'
$bad = Join-Path $psr '..' '..' '.github/skills/learner-profile/SKILL.md'
# .github\knowledge-graph\lib\..\..\.github\skills\learner-profile\SKILL.md
# → resolves to .github/.github/skills/... → fails

# 4. Patch: add one more `..`
$good = Join-Path $psr '..' '..' '..' '.github/skills/learner-profile/SKILL.md'
# → resolves correctly to .github/skills/learner-profile/SKILL.md

# 5. Re-run audit
pwsh .github/knowledge-graph/cli/audit-quality.ps1
# Broken refs: 57 → 0
# Untested:    56 → 56  (still real)
```

## What worked

- Ground-truthing the claim with `Test-Path` on five sample files took ten seconds and immediately told us the audit was lying.
- Reading the actual `Join-Path` line in `query.psm1` made the off-by-one obvious — the bug was visible without running anything.
- Reproducing the bad path in an isolated 4-line PowerShell snippet confirmed the diagnosis before the fix.

## What didn't

- The audit's error message ("File does not exist: .github/skills/...") was technically true but actively misleading — the resolved path it was checking (`.github/.github/skills/...`) wasn't shown. Better diagnostics would have caught this years ago.
- Trusting the audit's headline number (57) without spot-checking would have sent us renaming files that already existed.

## Decision / next move

Two decisions captured:
- `decision:2026-06-01-audit-path-bug` — codifies the fix.
- `decision:2026-06-01-audit-and-validate-are-complementary` — codifies that validate and audit are not redundant; they check different things (structural vs semantic). Both should run.

Residual real finding: **56 skills have no linked `test` node** (the audit's "Untested" category is correct). This is a real coverage gap to address in a later phase. Not blocking Phase 2.

Phase 1 status: complete. Path bug fixed, claims reconciled, lessons captured as graph nodes.
