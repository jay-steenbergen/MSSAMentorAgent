# Test: Welcome Flow on First Run (No Profile)

**Type:** Integration
**Tests:** `commands/welcome.ts` + first-run UX
**Created:** 2026-06-02

---

## Setup

**Given:**
- Extension freshly installed (or `~/.mssa-mentor/` deleted)
- No profile exists for `$env:USERNAME`
- VS Code restarted after install

---

## Test Scenario

Choose one trigger:
- **A** — Click the MSSA Mentor status bar item (should route to welcome based on state)
- **B** — Run `MSSA Mentor: Welcome / Get Started` from the command palette
- **C** — Type `@Mentor` in Copilot Chat for the first time

---

## Expected Behavior

**Extension should:**
1. Open Copilot Chat (if not already open) and focus the input
2. Pre-populate (or otherwise trigger) the `@Mentor` agent to start the first-time interview
3. The Mentor greets the user and starts the profile-creation interview via `skill:learner-profile`
4. On interview completion, profile is written to `~/.mssa-mentor/profiles/mentees/{user}/profile.json`
5. Status bar state transitions from "Start" → "Resume" after profile exists

**Extension should NOT:**
- Crash if `MSSA_MENTOR_HOME` doesn't exist yet (must create it)
- Show technical error messages — first-run UX should be friendly
- Skip the interview if profile is partial or invalid (re-prompt for missing fields)

---

## Pass Criteria

- [ ] Welcome flow reachable from all 3 triggers (A, B, C)
- [ ] Copilot Chat opens and `@Mentor` begins interview
- [ ] Profile file created on disk after interview
- [ ] Profile JSON validates against `learner-profile` schema
- [ ] Status bar reflects new state on next reload
- [ ] No errors in Output channel

---

## Actual Result

**Date run:**
**Result:** ✅ PASS | ❌ FAIL | ⚠️ PARTIAL

**Notes:**

**Evidence:**
