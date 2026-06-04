# Event Log Design — Cutover from Snapshot Fields to Append-Only Ledger

**Status:** Phase 1 (foundation) landed. Phases 2–4 pending.
**Decision node:** `decision:event-log-cutover`
**Motivating doc:** [feedback-loops.md](./feedback-loops.md) — surfaced four broken loops (L4, L5, L8, L9) sharing the same failure mode.

---

## The Problem

The agent has working loops where each persistent write happens at a **named call site**: `cli-tool:append-session-plan` is invoked by the agent at the start of every session, so the session plan reliably lands on disk.

It also has four broken loops where the soft contract says "persist this" but no mechanical call site enforces it:

| Loop | Field that doesn't get written | Failure |
|---|---|---|
| L4 quiz cadence | `progress.quiz_history` | Quizzes happen verbally; rarely recorded |
| L5 quiz pre-teach | `progress.quiz_history` (tier evidence) | No structured proof of pre-teach quiz |
| L8 concept proficiency | `progress.concept_proficiency.tier` | Manually maintained snapshot drifts |
| L9 method proficiency | `progress.method_proficiency.{method}` | Hand-edited or absent |

The root cause is one shape, not four: agent forms intent → soft contract says "persist" → no mechanical call site → intent dies in conversation.

## The Fix

Single append-only **event log** as the source of truth, plus a **pure-function reader** that derives every snapshot view on demand. Three CLI tools enforce the contract:

| Tool | Role |
|---|---|
| `cli-tool:append-event` | Single writer. Validates type. Atomic append. |
| `cli-tool:derive-views` | Pure function. Reads events → emits snapshot JSON. |
| `cli-tool:close-session` | Wrap-up gate. Verifies invariants before emitting `session_ended`. |

This generalizes the working pattern from `append-session-plan.ps1`: each write goes through a named, scripted call site that the agent (and the pre-commit hook, and any reviewer) can audit.

## Invariants

Codified as `rule:events-are-source-of-truth`:

1. `field:profile.events` is the only authoritative record of what happened.
2. Only `append-event.ps1` may write to `events`.
3. Only `close-session.ps1` may emit `session_ended` events.
4. Every other progress field that summarizes activity (`session_history`, `method_proficiency`, `quiz_history`, `concept_proficiency`) is a **derived view** computed by `derive-views.ps1`.
5. Hand-edits to derived fields are forbidden — they will be silently overwritten on the next read-through-derive cycle.
6. Events are append-only. No deletes. No in-place mutation. Corrections come in as new events (`concept_calibrated`).

## Event Schema

Every event has this envelope:

```json
{
  "ts":         "ISO 8601 UTC",
  "type":       "<enum>",
  "session_id": "<uuid>",
  "project_id": "<slug>",
  "data":       { ... type-specific ... }
}
```

### Event Types

| Type | When emitted | `data` shape (example) |
|---|---|---|
| `session_started` | Beginning of a mentor session | `{ method?, track?, opening_prompt? }` |
| `session_ended` | After AAR, via `close-session.ps1` | `{ outcome, reason?, event_count, concept_taught_count, quiz_answered_count, method_used_count }` |
| `concept_taught` | A concept is introduced or re-introduced | `{ concept_id, analogy_used, method }` |
| `concept_calibrated` | Explicit tier correction (manual override) | `{ concept_id, tier, reason }` |
| `quiz_asked` | Quiz prompt presented to learner | `{ concept_id, trigger, form, question }` |
| `quiz_answered` | Learner responded | `{ concept_id, trigger, form, question, answer, correct }` |
| `method_used` | Method invoked in service of a teaching beat | `{ method, tier, success }` |
| `analogy_offered` | Analogy delivered (military or otherwise) | `{ concept_id, analogy_id, reception }` |
| `callback_made` | Concept resurfaced unprompted by learner | `{ concept_id, success }` |
| `celebration` | Win acknowledged (per `rule:celebrate-small-wins`) | `{ milestone, magnitude }` |

`trigger` values: `cadence` (every-N-concepts pacing), `reappearance` (concept resurfaced), `pre-teach` (before a new concept), `on-demand` (learner-initiated).

`form` values: `oral-recall`, `code-fill`, `predict-output`, `find-the-bug`, `explain-back`.

## Derived Views

`derive-views.ps1` is a pure function from the events array to a bundle of snapshot views. No view is ever written back to disk in Phase 1; readers either render to stdout or pipe through `jq`.

| View | Derived from | Notes |
|---|---|---|
| `session_history` | `session_started` ⨝ `session_ended` on `session_id` | Unclosed sessions still listed (`ended_at: null`) so wrap-up gates can spot them. |
| `method_proficiency` | `method_used` aggregated by `data.method` | `used_count`, `last_used`. |
| `quiz_history` | `quiz_answered` | Mirrors the legacy snapshot shape exactly so Phase 2 readers can switch with zero behavior change. |
| `concept_proficiency` | `concept_taught` + `concept_calibrated` + `quiz_answered` + `callback_made` | Applies tier-bump rules from `rule:proficiency-derived-from-quiz-history`. |

### Tier-bump rules (encoded in `Get-ConceptProficiency`)

- `concept_taught` seeds a concept at tier `exposed`.
- `concept_calibrated` sets the tier explicitly (manual override).
- `quiz_answered` with `correct=true`: counts toward `correct_quizzes` and `distinct_sessions`. If `correct_quizzes ≥ 3` across `distinct_sessions ≥ 2`, bump tier one step.
- `callback_made` with `success=true`: if current tier is `guided`, bump to `independent`.
- Incorrect answers never downgrade — they just delay the next bump.
- Tiers, in order: `unknown → exposed → guided → independent → teach-back`.

## Migration Plan (Four Phases)

### Phase 1 — Foundation (THIS COMMIT)

Additive only. Nothing breaks.

- ✅ Add `events: []` to `progress.json` on scaffold (`scaffoldAndOpen.ts`).
- ✅ Ship `append-event.ps1`, `derive-views.ps1`, `close-session.ps1`.
- ✅ Add nine graph nodes + ~15 edges (`decision:event-log-cutover`, `field:profile.events` + 4 subfields, 3 cli-tools, 1 rule).
- ✅ Amend `field:profile.quiz_history` description: still in use; deprecation Phase 2.
- ✅ Write this doc.

Old snapshot fields keep working. Old readers keep working. Agent behavior unchanged.

### Phase 2 — Cutover (next commit batch)

Switch readers from snapshot fields to derived views.

- Rewrite quiz protocols in `get-behavior.ps1` to call `append-event -Type quiz_asked` / `quiz_answered` instead of mutating `quiz_history` directly.
- Update `Mentor.agent.md` beginner-trigger logic to call `derive-views -View concept_proficiency` instead of reading `progress.concept_proficiency`.
- Rename `validate-proficiency.ps1` → `validate-events.ps1`; reframe checks against the event log.
- Mark old field nodes (`field:profile.session_history`, `field:profile.method_proficiency`, `field:profile.quiz_history`, `field:profile.concept_proficiency`) with `derived: true` in the graph.

### Phase 3 — Backfill (next commit batch)

Build `migrate-profile-to-events.ps1` and run it against live profiles.

- For each profile with a non-empty snapshot field, synthesize the minimum events that would derive the same snapshot.
- Migrate `jasteenb`'s mentor profile and `test_user`'s mentee profile.
- Verify: `derive-views` output matches the pre-migration snapshot byte-for-byte.

### Phase 4 — Removal + Tightening

- Delete the old snapshot field initializations from `scaffoldAndOpen.ts`.
- Delete the old field nodes from the graph.
- Rewrite behavioral specs: `quiz-cadence`, `quiz-pre-teach`, `quiz-reappearance`, `method-proficiency-tracking`, `profile-load`.
- Update `MENTOR_DIRECTORY.md` and `feedback-loops.md` change log marking L4/L5/L8/L9 as OK.
- Tighten `close-session.ps1` requirements: non-trivial sessions must have `concept_taught ≥ 1` and `method_used ≥ 1`.

## Rollback Strategy

Phase 1 is rollback-trivial: `git revert` removes the three scripts and the `events: []` field. Nothing depends on them.

Phase 2 is rollback-painful but bounded: revert restores the snapshot writers, and any events captured during the cutover window are abandoned (not corrupted — just unused). Behavioral specs would need to be re-pointed at the snapshot fields.

Phase 3 is rollback-trivial again: the snapshot fields are still present; backfilled events become orphaned but harmless.

Phase 4 burns the bridge. Before Phase 4, take a tagged backup of every live profile. After Phase 4, the event log is the only record.

## How To Use (Phase 1 Cookbook)

```powershell
# Start a session — mints a session_id and prints it for capture.
& .github/knowledge-graph/cli/append-event.ps1 `
  -Username alex_smith -ProjectId weather-api -Type session_started
# OK: type=session_started session_id=6db8... -> ...progress.json

$sid = '6db8...'  # capture from the line above

# Log a teach event.
$d = @{ concept_id='for-loop'; analogy_used=$true; method='ride-along' } | ConvertTo-Json -Compress
& .github/knowledge-graph/cli/append-event.ps1 `
  -Username alex_smith -ProjectId weather-api `
  -Type concept_taught -SessionId $sid -Data $d

# Log a quiz round.
$d = @{ concept_id='for-loop'; trigger='reappearance'; form='code-fill';
        question='fill the hole'; answer='i'; correct=$true } | ConvertTo-Json -Compress
& .github/knowledge-graph/cli/append-event.ps1 `
  -Username alex_smith -ProjectId weather-api `
  -Type quiz_answered -SessionId $sid -Data $d

# AAR: render the derived views for the wrap-up message.
& .github/knowledge-graph/cli/derive-views.ps1 `
  -Username alex_smith -ProjectId weather-api

# Close the session via the gate.
& .github/knowledge-graph/cli/close-session.ps1 `
  -Username alex_smith -ProjectId weather-api `
  -SessionId $sid -Outcome completed -Reason 'AAR complete'
```

## Related

- `decision:event-log-cutover`
- `decision:feedback-loops` — the matrix that surfaced the gap
- `rule:events-are-source-of-truth`
- `rule:proficiency-derived-from-quiz-history` — special case this generalizes
- `rule:goal-progress-derived-not-stored` — sibling pattern in the goal system
- `cli-tool:append-session-plan` — working precedent for "scripted call site" enforcement
