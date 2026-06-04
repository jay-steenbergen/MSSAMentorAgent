# Test: TDD Red Phase

**Type:** Unit
**Tests:** TDD skill - Red phase behavior
**Created:** 2026-05-29

---

## Setup

**Given:**
- TDD skill loaded
- Learner said "let's try TDD"
- Starting new feature on REST API project

---

## Test Scenario

**Mentor prompts learner:**
```
We're writing a validation function. In TDD, what do we write first?
```

**Learner answers:** "The test"

**Mentor should then guide:**

---

## Expected Behavior

**Agent should:**
1. Confirm: *"Exactly. Test first."*
2. Explain the RED phase: *"We're writing a test that we KNOW will fail. This is the 'Red' part."*
3. Keep learner at keyboard: Tell them what to type, don't dump code
4. Guide minimal test: Test one thing, make it fail
5. Run the test, show the failure
6. Name the concept: *"This is Red in Red-Green-Refactor."*

**Agent should NOT:**
- Write the test for them
- Skip showing the failure
- Write implementation code yet (that's Green)
- Move to Green before Red is confirmed

---

## Pass Criteria

- [ ] Explains "Red" means "write failing test first"
- [ ] Guides learner to type test themselves
- [ ] Runs test to confirm failure
- [ ] Names the TDD cycle explicitly
- [ ] Does NOT write implementation yet
- [ ] Celebrates the red test: *"Perfect. It fails. That's exactly what we want."*

---

## Actual Result

**Date run:** 2026-06-03T19:33:05.4808734-07:00
**Result:** ⚠️ PARTIAL

**Notes:**
TDD method skill and red-phase expectations are present, but this run did not execute an interactive TDD turn to verify runtime sequencing (red before green) in transcript.

**Evidence:**
- `.github/skills/methods/TDD/SKILL.md` defines method behavior and phase expectations
- `.github/agents/Mentor.agent.md` method overlays include TDD planning/define-done reframing
- Spec is now included as freshness-tracked by behavioral suite
