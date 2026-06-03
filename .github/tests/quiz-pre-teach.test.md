# Test: Pre-Teach Calibration Quiz

**Type:** Integration
**Tests:** `behavior:24-pre-teach-quiz` + `rule:quiz-form-by-concept-type`
**Created:** 2026-06-03

---

## Setup

**Given:**
- Session active, method `ride-along`, track `cloud-app-dev`
- Profile's `concept_proficiency` has NO record for the upcoming concept `async-await` (i.e., never seen this session)
- Agent is about to introduce `async-await` for the first time

---

## Test Scenario

**Agent reaches the moment it would normally introduce `async-await`.**

---

## Expected Behavior

**Agent should:**
1. BEFORE explaining the concept, fire ONE calibration card: `Have you worked with async-await before?` with clickable options (e.g., `Used it`, `Heard of it`, `Brand new`).
2. If user picks `Used it` → fire ONE form-appropriate question chosen via `rule:quiz-form-by-concept-type`:
   - Syntax concept → code-fill
   - Conceptual → multiple-choice
   - Open-ended → short answer
3. If user picks `Brand new` → skip the quiz, teach from scratch.
4. If `concept_proficiency.tier` is already `>= independent` → skip the calibration card entirely.
5. Record the quiz answer + outcome in `profile.quiz_history`.

**Agent should NOT:**
- Fire more than one calibration question per concept introduction.
- Ask the question as free-text when clickable options are appropriate.
- Skip the quiz when tier is `exposed` or `guided` (unless already independent).
- Re-fire calibration for a concept already introduced this session.
- Forget to log the outcome to `quiz_history`.

---

## Pass Criteria

- [ ] Calibration card appears BEFORE any explanation of the concept.
- [ ] Exactly ONE follow-up question fires if user selects `Used it`.
- [ ] Question form matches the concept type per `rule:quiz-form-by-concept-type`.
- [ ] Skip path works correctly when tier `>= independent`.
- [ ] `quiz_history` entry written with concept name, form, outcome.
- [ ] No duplicate calibration if the same concept reappears this session.

---

## Actual Result

**Date run:**
**Result:**

**Notes:**

**Evidence:**
