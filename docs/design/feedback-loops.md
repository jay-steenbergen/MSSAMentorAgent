# MSSA Mentor — Feedback Loop Matrix

**Created:** 2026-06-03
**Purpose:** Identify and find gaps in the system's feedback loops. A "loop" here = trigger → signal → sink → closure. A loop is **broken** when the signal is produced but no consumer closes the cycle, or when it should produce a signal but never does.

**Gap-finding lens** — every loop is scored against four failure modes:

| Code | Failure mode | Definition |
|---|---|---|
| `OPEN` | Open loop | Signal produced but nobody reads it |
| `SILENT` | Silent loop | Should fire but no observable signal |
| `LOSSY` | Lossy loop | Signal exists but not persisted (dies with the session) |
| `MANUAL` | Manual loop | Needs human kick; should be automatic |
| `OK` | Closed loop | Trigger fires, signal lands in sink, consumer closes |

---

## The Matrix

| # | Loop | Trigger | Signal | Sink | Closure | Cadence | Owner | Gap |
|---|---|---|---|---|---|---|---|---|
| 1 | **Behavioral spec freshness** | Manual run of `scripts/test.ps1 -Suite behavioral` | `fresh / stale / never-run` counts + spec-by-spec lists | stdout (hashtable return, no file) | Human reads → re-runs spec → stamps `**Date run:**` in spec | Manual / on-demand | Test harness | `MANUAL` + `LOSSY` — never auto-fires on commit; counts not persisted to history, so trend invisible |
| 2 | **Graph path drift** | Pre-commit hook (`.github/hooks/pre-commit.ps1`) | `find-drift.ps1 -Quiet` exit code + `Drift findings: N` count | stderr → blocks commit | Author fixes path or graph and re-commits | Per commit | Pre-commit hook | `OK` — but only fires if hook is installed locally; no CI fallback ([pre-commit.ps1#L392-409](../../.github/hooks/pre-commit.ps1)) |
| 3 | **Graph rebuild-if-stale** | Manual or pre-commit | mtime comparison of source files vs `merged-graph.json` | `merged-graph.json` rewritten + git status | Author commits rebuilt graph | Per commit (if hook installed) | Build script + hook | `OK` for hook users; `SILENT` for everyone else — no CI rebuild ([rebuild-if-stale.ps1](../../.github/knowledge-graph/build/core/rebuild-if-stale.ps1)) |
| 4 | **Profile / progress write-back** | `wrap up` / `I'm done` (session contract step 6) | Updated `progress.json`, appended `session_history` entry, commit | `.profiles/profiles/mentees/{u}/{p}.progress.json` + git | Next session reads it to greet, pick project, resume | Per session | Mentor agent | `LOSSY` — no CLI tool writes `session_history`; only `append-session-plan.ps1` *initializes* it as `[]` then leaves it empty ([append-session-plan.ps1#L174](../../.github/knowledge-graph/cli/session/append-session-plan.ps1)). Mentor must write the array by hand, and there's no validator catching when it doesn't |
| 5 | **Method proficiency tracking** | End of session using a method (TDD/BDD/etc.) | `method_proficiency.{method}` level bumps | `progress.method_proficiency` field | `validate-events.ps1` checks the underlying `field:profile.events` log; method_proficiency itself is now a derived view from `cli-tool:derive-views`. Mentor reads at next session start for beginner-mode trigger | Per session | Mentor agent | `LOSSY` + `SILENT` — no CLI writer exists; validator only confirms shape if the field is present. Mentor's `beginner-mode` trigger (c) depends on this field but nothing populates it. Only `jasteenb.json` has a hand-edited entry |
| 6 | **Build-options cockpit verify** | Start of every code-producing session | `show-profile.ps1 -Json` → `all_set: bool` | stdout JSON to agent | If `false` → re-fire `picker:build-options` for gaps | Per session | Mentor agent + CLI | `OK` — well-formed, tool exists, contract explicit ([show-profile.ps1](../../.github/knowledge-graph/cli/inspect/show-profile.ps1)) |
| 7 | **Planning beats persistence** | After each of 9 planning beats | Beat answer (text or JSON) | `progress.session_plan.{beat}` via `append-session-plan.ps1` | Coding phase reads `session_plan` as running checklist; wrap-up uses `done_when` for celebration | Per turn during planning | Mentor agent + CLI | `OK` — sanctioned single writer, atomic write, schema documented ([append-session-plan.ps1](../../.github/knowledge-graph/cli/session/append-session-plan.ps1)) |
| 8 | **Per-turn teaching loop** (analogy → name → ask → why → celebrate) | Every learner turn that touches a concept | The mentor's actual response shape | None — lives only in the chat transcript | None — no programmatic consumer | Per turn | Mentor agent | `LOSSY` — five-step pattern is contract-only. No counter, no telemetry, no spec that asserts "this turn had an analogy." Drift invisible until a behavioral spec is manually run |
| 9 | **Concept-proficiency / quiz history** | Pre-teach, reappearance, cadence quiz events (3 behaviors documented) | `quiz_history` entry + `concept_proficiency.tier` snapshot recomputed at AAR | `profile.quiz_history` (array), `profile.concept_proficiency.{concept_id}` | Mentor's spaced-recall / cadence-quiz / pre-teach behaviors read it to decide what to ask | Per concept exposure + AAR | Mentor agent | **`SILENT` + `LOSSY` — the biggest gap.** Three behaviors document the signal in detail ([get-behavior.ps1#L778-855](../../.github/knowledge-graph/cli/inspect/get-behavior.ps1)); zero CLI or extension code writes `quiz_history` or `concept_proficiency`; zero profile JSON files contain either field. Whole subsystem is contract-only |
| 10 | **Curriculum fetch (extension → repo)** | VS Code extension activation or chat turn | HTTP GET of `curriculum-manifest.json` from `raw.githubusercontent.com` | Cached locally under `getCurriculumDir()`; refresh every 60 min | Skill loader reads cache | Per hour + on activation | Extension | `OK` for happy path — but no signal back to repo when fetch fails for a real mentee. Errors logged client-side only ([curriculumFetch.ts](../../extensions/mssa-mentor/src/curriculumFetch.ts)) |

---

## Gap Summary (priority order)

| Rank | Gap | Loops affected | Why it matters | Smallest fix |
|---|---|---|---|---|
| 1 | **Quiz / concept-proficiency subsystem has zero machinery** | 9 | Three documented behaviors (`pre-teach-quiz`, `reappearance-quiz`, `cadence-quiz`) all depend on a `quiz_history` field that no code writes and no profile contains. The system can't actually run its own spaced-recall protocol. | Add `append-quiz-result.ps1` CLI alongside `append-session-plan.ps1`, mirror its atomic-write pattern, and initialize `quiz_history: []` + `concept_proficiency: {}` in `scaffoldAndOpen.ts` |
| 2 | **`session_history` is initialized empty and never appended** | 4 | Wrap-up contract says "write progress" — but no CLI tool appends a session entry. Only `jasteenb.json` has hand-edited entries. Resume on next session can't show "what we did last time" because there's no last-time row | Add `append-session.ps1` CLI; call it as the last step of every wrap-up; add a profile validator that warns if a profile has projects but `session_history` is empty for more than 24h |
| 3 | **Behavioral freshness has no history** | 1 | Counts are computed and printed but discarded. No way to see "we had 8 stale specs Monday, 12 today" — trend invisible | Append `{ ts, fresh, stale, never_run }` to a `scripts/test-suites/behavioral-history.jsonl` on every run |
| 4 | **Teaching loop has no observability** | 8 | The 5-step pattern is the *core promise* of the mentor; drift would be invisible until someone manually runs a behavioral spec | Add `behavior:28-teaching-loop` self-check at session wrap-up: mentor logs `{turns: N, analogies_opened: M, celebrations: K}` to session_history |
| 5 | **Method proficiency has no writer** | 5 | Beginner mode trigger (c) reads `method_proficiency.level` — if it's never written, the trigger never fires correctly | Add proficiency update to the same `append-session.ps1` from gap #2 (one writer, multiple fields) |
| 6 | **Graph rebuild / drift only fires for hook users** | 2, 3 | A contributor without the hook installed can land path drift in master. No CI gate | Add a `.github/workflows/graph-check.yml` that runs `find-drift.ps1` + `rebuild-if-stale.ps1` on PR |
| 7 | **Behavioral suite is manual** | 1 | Specs go stale silently between runs | Wire `pwsh scripts/test.ps1 -Suite behavioral` into the same PR workflow; keep `INFO` exit so it never blocks |
| 8 | **Curriculum fetch failures invisible to the maintainer** | 10 | A 404 on a renamed skill is logged client-side, never reaches the repo | Out of scope for v1 per `docs/design/v1-distribution-and-scaffolding.md` ("no telemetry") — leave as known accepted gap |

---

## How to use this matrix

1. **At session wrap-up:** scan the Gap column. Anything new (a loop that was `OK` is now `LOSSY`) signals drift.
2. **Before adding a feature:** if the feature introduces a new signal, add a row. The matrix prevents silently-designed-but-never-built subsystems (gap #1 is exactly this).
3. **At graph audit time:** every `field:profile.*` node in the knowledge graph should appear as the *sink* of some row here. If it doesn't, the field is documented but unfed.

## Update protocol

This file is hand-maintained. When a loop changes status:
1. Update the row.
2. Add a one-line entry below.
3. Commit with `docs: feedback-loop gap update — {loop} {OLD}→{NEW}`.

### Change log

- 2026-06-03 — Initial matrix. 10 loops identified, 8 gaps ranked.
