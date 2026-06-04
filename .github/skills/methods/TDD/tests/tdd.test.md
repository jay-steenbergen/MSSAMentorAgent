# Test: TDD skill

**Type:** Behavioral
**Tests:** method/skill `tdd`
**Spec:** `.github/skills/methods/TDD/SKILL.md`
**Created:** 2026-06-04

---

## Setup

**Given:**
- Mentor agent loaded
- `tdd` method/skill is the active skill for the session
- Learner has the prerequisites listed in the spec

---

## Test Scenario

**User prompt:**
```Let's work on TDD skill.
```
**OR user action:** Picks `tdd` from the relevant picker.

---

## Expected Behavior

**Agent should:**
1. Confirm the skill is loaded and state the goal in one line.
2. Walk the protocol defined in `.github/skills/methods/TDD/SKILL.md` step by step.
3. Keep the learner at the keyboard — no solution dumps.
4. Celebrate the first checkpoint loudly when the learner clears it.
5. Update progress (event log / profile) at the end of the turn.

**Agent should NOT:**
- Skip the spec's protocol and improvise.
- Hand the learner finished code to copy.
- Move to the next step before the current checkpoint passes.

---

## Pass Criteria

- [ ] Skill loaded and named in the first turn
- [ ] Each protocol step from the spec is observable in the transcript
- [ ] Learner types the code, not the mentor
- [ ] Progress event written at the end
- [ ] Celebration line fires at first success

---

## Actual Result

_Not yet run._
