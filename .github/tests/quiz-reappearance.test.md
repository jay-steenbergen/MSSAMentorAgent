# Test: Reappearance Quiz (Gates the Callback)

**Type:** Integration
**Tests:** `behavior:25-reappearance-quiz` + `behavior:17-callback-prior-concept`
**Created:** 2026-06-03

---

## Setup

**Given:**
- Session active, method `ride-along`
- `concept_proficiency` has `dependency-injection` at tier `guided` (previously taught, not mastered)
- About to write code that uses dependency-injection (the trigger for `callback-prior-concept`)

---

## Test Scenario

**Agent reaches the about-to-write-code moment where dependency-injection reappears.**

---

## Expected Behavior

**Agent should:**
1. BEFORE the conversational callback fires, fire ONE quiz on `dependency-injection` (form chosen per `rule:quiz-form-by-concept-type`).
2. Quiz outcome **gates** the callback:
   - **Correct** → callback fires normally (`Remember when we used DI for X? Same pattern here.`).
   - **Wrong** → callback SUPPRESSED. Offer a 30-second refresher instead.
3. Record the outcome in `profile.quiz_history`.
4. Update `concept_proficiency.tier` per `rule:proficiency-derived-from-quiz-history`.

**Agent should NOT:**
- Fire the conversational callback BEFORE the quiz.
- Skip the quiz on tier `exposed` or `guided` (this is exactly when it should fire).
- Fire the callback after a wrong answer (suppression is mandatory).
- Move on without offering a refresher when the answer was wrong.
- Skip logging to `quiz_history`.

---

## Pass Criteria

- [ ] Quiz fires BEFORE the callback — never after.
- [ ] Correct → callback fires.
- [ ] Wrong → callback suppressed AND 30-second refresher offered.
- [ ] `quiz_history` entry recorded with timestamp + outcome.
- [ ] Tier in `concept_proficiency` updates based on quiz outcome history.
- [ ] No quiz fires for concepts at tier `independent` (only `exposed`/`guided` trigger it).

---

## Actual Result

**Date run:**
**Result:**

**Notes:**

**Evidence:**
