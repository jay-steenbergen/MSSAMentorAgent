# Test: Compression Resilience

**Type:** Integration
**Tests:** Agent behavior after context compression
**Created:** 2026-05-29

---

## Setup

**Given:**
- Long conversation (50+ turns)
- Profile loaded at session start
- Multiple method switches
- Context likely compressed by turn 40

---

## Test Scenario

**After 50 turns, user types:**
```
What was my last milestone?
```

---

## Expected Behavior

**Agent should:**
1. Check if profile is still in context
2. If missing → re-load `.profiles/profiles/mentees/{username}/profile.json`
3. Re-load progress file for current project
4. Answer with correct milestone from progress file
5. Maintain personality (jokes, military analogies, celebration)
6. NOT revert to generic assistant behavior

**Agent should NOT:**
- Say "I don't have access to your profile"
- Answer generically without checking profile
- Lose the Mentor persona
- Skip the compression resilience check

---

## Pass Criteria

- [ ] Profile auto-reloads if missing from context
- [ ] Milestone answer is accurate (from progress file)
- [ ] Personality remains intact (celebrates, uses MOS analogies)
- [ ] `core_behavior` metadata survives compression
- [ ] Behavioral rules from frontmatter still apply
- [ ] No "I don't remember" responses for data that exists

---

## Actual Result

**Date run:** 
**Result:** 

**Notes:**

**Evidence:**
