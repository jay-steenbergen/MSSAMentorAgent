# Test: Session Flow - Profile Load to Session End

**Type:** Integration
**Tests:** Agent + learner-profile skill
**Created:** 2026-05-29

---

## Setup

**Given:**
- Profile exists at `.profiles/profiles/mentees/alex_smith/profile.json`
- Profile has 2 active projects (REST API, PowerShell)
- User signed in as `alex_smith` in Copilot

---

## Test Scenario

**User opens Copilot Chat and types:**
```
@Mentor load my profile
```

---

## Expected Behavior

**Agent should:**
1. Read `.profiles/profiles/mentees/alex_smith/profile.json`
2. Detect 2 active projects
3. Show project picker with:
   - REST API Project (CAD) - recommended
   - PowerShell Automation (SCA)
   - Start new project
4. After user selects project → load corresponding `.progress.json`
5. Show method/track continuation picker
6. After user selects "Continue" → load method and track skills
7. Greet by name with project context

**Agent should NOT:**
- Read skill documentation before executing
- Navigate directory tree one file at a time
- Skip project picker when 2+ active projects exist
- Load wrong progress file

---

## Pass Criteria

- [ ] Profile loads in <2 seconds (no excessive file reads)
- [ ] Project picker appears with correct display names
- [ ] Most recent project marked as recommended
- [ ] Selected progress file loads correctly
- [ ] Greeting includes: name, project name, last milestone
- [ ] Method and track skills load without errors

---

## Actual Result

**Date run:** 2026-06-03T19:32:20.5707334-07:00
**Result:** ⚠️ PARTIAL

**Notes:**
Profile discovery, active-project counting, and last-used-method extraction are implemented and covered by automated profile/extension tests.
This run did not execute an interactive chat session to validate the full picker chain and greeting text composition in one live end-to-end flow.

**Evidence:**
- `extensions/mssa-mentor/src/profileReader.ts` loads profile context, counts in-progress projects, and reads selected progress metadata
- `pwsh -NoProfile -File scripts/test.ps1 -Suite profiles` => PASS (`xUnit: 10 pass; PS validators: 1 pass`)
- `.github/skills/learner-profile/SKILL.md` defines project picker and continuation flow expectations for multi-project sessions
