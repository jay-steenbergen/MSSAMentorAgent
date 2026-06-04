# Test: First-Time Learner Interview

**Type:** Integration
**Tests:** `protocol:interview` + `protocol:followup-interview`
**Created:** 2026-06-03

---

## Setup

**Given:**
- No profile exists at `.profiles/profiles/mentees/{username}/profile.json`
- User signed in as `new_learner_jane` (or any user with no profile)

---

## Test Scenario

**User opens Copilot Chat and types:**
```
@Mentor
```

---

## Expected Behavior

**Agent should:**
1. Detect there is NO profile for this user (no file at expected path).
2. Greet warmly and explain it needs a short interview to personalize teaching.
3. Run `protocol:interview` and ask required fields ONE question at a time:
   - Preferred name
   - Military background (branch + MOS, if any)
   - Prior programming experience
   - Learning style preference
   - Goals (short-term + long-term)
4. After each answer → echo back what was captured before moving on.
5. End with a summary + confirmation prompt (`interview:summary-confirm`).
6. On confirmation → write the profile, run validator, mark required fields complete.
7. If validator flags an incomplete required field → run `protocol:followup-interview` to fill the gap, not block on the rest.

**Agent should NOT:**
- Ask multiple questions in one turn.
- Skip the summary/confirm step.
- Write the profile before confirmation.
- Block the entire session on a single optional field.
- Use the wrong username (must come from Copilot identity, not user-typed).

---

## Pass Criteria

- [ ] Profile file does not exist at start; exists at end.
- [ ] Exactly one question per turn during interview.
- [ ] Summary + explicit confirmation prompt appears before write.
- [ ] Validator runs after write.
- [ ] If any required field missing → followup interview triggers (not session abort).
- [ ] Profile passes `.profiles/validate-profile.ps1`.

---

## Actual Result

**Date run:** 2026-06-03T19:32:20.5707334-07:00
**Result:** ⚠️ PARTIAL

**Notes:**
Identity resolution and first-run null-profile gating are implemented, and profile validation tooling is passing.
This run did not execute a full interactive first-time interview transcript to verify exact one-question cadence and summary-confirm messaging turn by turn.

**Evidence:**
- `extensions/mssa-mentor/src/profileReader.ts` resolves username silently (GitHub auth -> git -> OS) and returns null when no matching profile exists
- `.profiles/validate-profile.ps1` provides the required post-write validation pathway; profile suite currently passes
- `.github/skills/learner-profile/SKILL.md` defines the first-time interview and followup-interview protocol requirements
