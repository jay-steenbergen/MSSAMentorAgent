---
id: 2026-06-01-audit-and-validate-are-complementary
type: decision
description: "mentor.ps1 validate checks STRUCTURAL health (dangling edges, duplicate IDs, stub nodes); audit-quality.ps1 checks SEMANTIC health (orphans, broken refs, untested). Both should run; neither replaces the other. They do not contradict — they answer different questions."
decided_at: 2026-06-01
---

# Decision: audit and validate are complementary

During Phase 1 reconciliation we initially treated `mentor.ps1 validate` and `audit-quality.ps1` as competing answers to the same question ("is the graph healthy?"). They are not. They look at different layers of health. Both stay.

## Chose

Keep both tools. Document explicitly what each one checks. Run both in the pre-commit hook (validate is already wired; audit is candidate for Phase 2).

| Tool | Lens | Checks | Blocks commit? |
|---|---|---|---|
| `mentor.ps1 validate` | **Structural** | dangling edges, duplicate node IDs, stub nodes, doc drift, code coverage, dropped bridges, session artifacts | Yes (via pre-commit hook) |
| `audit-quality.ps1` | **Semantic** | orphans (no incoming edges), dead-ends (no outgoing), broken file refs, missing descriptions, unclustered, untested skills | No (advisory) |

## Over

Two rejected alternatives:
1. **Delete `audit-quality.ps1`** because validate already runs. Rejected: validate doesn't check file existence, orphans, or test coverage. We'd lose visibility into a real class of drift.
2. **Merge audit into validate** so there's one tool. Rejected for now: the two tools have different blocking semantics (validate blocks commits; audit is advisory). Merging would force a choice about which findings block. Defer until we have data on how often audit-only findings should block.

## Because

- The two tools answered different questions, but the reports looked similar enough that we treated them as duplicates and got confused when they disagreed.
- `validate` runs every commit (hook); `audit` runs on demand. Different cadences imply different purposes.
- Removing either tool would lose information. Cost of keeping both is one extra command in the workflow.
- This is the kind of design clarity that pays off the third time someone gets confused — capture it now so we don't relitigate.

## Affects

- Documentation: future skill that explains "how to check graph health" should reference both tools and their lenses.
- Phase 2 candidate: wire `audit-quality.ps1` into the pre-commit hook as a warning (does not block, but surfaces findings).
- Future tooling: any new health check should declare which lens it sits in (structural vs semantic), and whether it blocks.

## Revisit if

- We get tired of running two commands and want one unified `mentor.ps1 health` that wraps both.
- The blocking semantics change (e.g., audit findings start being treated as commit blockers).
- A third tool emerges (e.g., performance audit, security audit) and the lens taxonomy needs to expand.
