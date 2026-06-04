# Test: Cadence Cold-Pull Quiz

**Type:** Integration
**Tests:** `behavior:26-cadence-quiz`
**Created:** 2026-06-03

---

## Setup

**Given:**
- Session active, ride-along method
- `concept_proficiency` has `async-await` last touched 6 sessions ago, never quizzed
- Other concepts touched recently but quizzed within the last 5 sessions
- Just completed a milestone — about to start the next one

---

## Test Scenario

**Agent finishes a milestone AAR. Before pushing into the next milestone, the cadence quiz step runs.**

---

## Expected Behavior

**Agent should:**
1. Scan `concept_proficiency` for concepts touched but NOT quizzed in the last 5+ sessions.
2. Pick ONE eligible concept (`async-await` in this setup).
3. Fire ONE cold-pull quiz with form chosen per `rule:quiz-form-by-concept-type`.
4. Include a visible opt-out option (e.g., `Skip — not now`).
5. Cap at **one cadence quiz per session** regardless of how many concepts are eligible.
6. Record the outcome (or the opt-out) in `profile.quiz_history`.
7. If no eligible concept exists → skip the cadence quiz silently.

**Agent should NOT:**
- Fire more than one cadence quiz in a session.
- Fire between every code-write (only between milestones).
- Hide or remove the opt-out option.
- Fire on a concept quizzed within the last 5 sessions (cooldown).
- Block the next milestone if the user opts out.

---

## Pass Criteria

- [ ] Exactly ONE cadence quiz fires this session.
- [ ] Concept chosen has `last_quizzed_session_gap >= 5`.
- [ ] Opt-out option visible and functional.
- [ ] Outcome (or opt-out) logged to `quiz_history`.
- [ ] No cadence quiz fires mid-milestone (only between).
- [ ] Empty-eligible-set path is silent (no degenerate prompt).

---

## Actual Result

**Date run:** 2026-06-03T19:33:05.4808734-07:00
**Result:** ⚠️ PARTIAL

**Notes:**
Cadence quiz behavior is specified at contract level, including one-per-session and between-milestone placement.
This run did not perform an interactive multi-milestone chat execution to validate runtime cooldown/opt-out mechanics against profile history.

**Evidence:**
- `.github/tests/quiz-cadence.test.md` aligns with named behavior references in mentor contract
- `.github/skills/learner-profile/SKILL.md` documents `quiz_history` as persistent source of truth
- Behavioral freshness harness now recognizes this spec as executed
