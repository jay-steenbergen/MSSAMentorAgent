# Test: Mid-Session Method Switching

**Type:** Integration
**Tests:** Agent method switching + skill loading
**Created:** 2026-05-29

---

## Setup

**Given:**
- Session active with `ride-along` method loaded
- Working on REST API project, step 3
- Profile has `last_used_method: "ride-along"`

---

## Test Scenario

**User types mid-session:**
```
Let's try TDD
```

---

## Expected Behavior

**Agent should:**
1. Recognize method switch request
2. Show method picker with 4 options (Ride-along, TDD, BDD, Spike-then-refactor)
3. User selects "TDD"
4. Validate TDD skill exists via `file_search`
5. If exists → load `.github/skills/methods/TDD/SKILL.md`
6. If missing → fall back to `ride-along`, notify user
7. Continue session with new method
8. At session end → update progress file with `last_used_method: "TDD"`

**Agent should NOT:**
- Require session restart
- Lose project context
- Skip validation step
- Crash if skill file doesn't exist

---

## Pass Criteria

- [ ] Method picker appears with all 4 options
- [ ] Skill validation runs before load attempt
- [ ] Fallback to ride-along if TDD missing (graceful degradation)
- [ ] Session continues without restart
- [ ] Progress file updates with new method at session end
- [ ] Profile index updates with new method

---

## Actual Result

**Date run:** 2026-05-29
**Result:** ✅ PASS

**Notes:**
Tested with TDD skill missing. Agent fell back to ride-along with notification: "Looks like TDD isn't built yet. Starting with ride-along for now."

**Evidence:**
Validation ran, fallback triggered, session continued smoothly.
