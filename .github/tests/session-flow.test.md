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

**Date run:** 
**Result:** 

**Notes:**

**Evidence:**
