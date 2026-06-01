# Decision: Phase 2 gate policy — orphan blocks, drift warns

**Date:** 2026-06-01
**Session:** 2026-06-01-graph-driven-setup
**Experiment:** 2026-06-01-phase-2-graph-first-enforcement
**Status:** Active

---

## Chose

Pre-commit hook treats the two new Phase 2 checks differently:

| Check | Severity | Rationale |
|---|---|---|
| `find-orphan-markdown.ps1` | **BLOCKING** (exit 1) | An untracked artifact is by definition a graph-first violation. There's no honest reason to keep both file and absence-of-node. |
| `find-drift.ps1` | **ADVISORY** (warn only) | Drift findings are often deferred-fix items (a description references a future file). Blocking would force premature fixes or `--no-verify` bypasses, training authors to ignore the gate. |

## Over

- **Both blocking.** Would have blocked our own next commit (the known `mentors/{username}/profile.json` drift). Forcing fixes before they're owned just trains people to bypass the hook.
- **Both advisory.** Defeats the purpose of Phase 2. Authors will keep dropping `.md` files outside the graph because nothing stops them.
- **Orphan as warning, drift as blocking.** Backwards — drift findings are looser-edge cases; orphans are a clear contract violation.

## Because

- **Orphans are unambiguous.** A markdown file with no graph node is wrong. There's no maybe.
- **Drift is contextual.** A description that references a file path can legitimately point at an intended future location (template variables, `{username}` placeholders, planned but not yet built). The advisory tells the author "we noticed" without forcing a context switch.
- **The bypass exists** (`--no-verify`) — gates that are routinely bypassed are worse than no gate at all, because they teach the team to bypass on reflex.

## Affects

- `.github/hooks/pre-commit.ps1` — Step 5b runs both checks, hard-fails on orphan, soft-warns on drift.
- `find-orphan-markdown.ps1` — must exit 1 with `-Quiet` when orphans exist (hook reads exit code).
- `find-drift.ps1` — must exit 1 with `-Quiet` when drift exists; hook intentionally ignores exit code and prints warning instead.
- All future commits — `.md` artifacts MUST be registered via `mentor.ps1 add` (or have their node added manually) before they can be committed.

## Revisit if

- **Bypass rate climbs.** If we find ourselves using `--no-verify` more than once a month, the gate is wrong. Either upgrade tooling so the right path is easier, or downgrade orphan to advisory.
- **Drift count grows past ~5.** A growing advisory means it's being ignored. Upgrade drift to blocking or actively clean up the backlog.
- **A type of artifact gets routinely caught as an orphan.** Means the auto-discover step is missing it. Fix discovery, not the gate.
