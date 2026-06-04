# Test: Project Picker

**Type:** Integration
**Tests:** `picker:project` behavior
**Created:** 2026-06-03

---

## Setup

**Given:**
- Profile exists at `.profiles/profiles/mentees/alex_smith/profile.json`
- Profile index lists 3 projects:
  - `cad-rest-api` (last_session: 2026-06-02)
  - `sca-powershell` (last_session: 2026-05-28)
  - `ghc-skills-playground` (last_session: 2026-04-10)
- User signed in as `alex_smith`

---

## Test Scenario

**User opens Copilot Chat and types:**
```
@Mentor
```

(No project hint — agent must show the project picker.)

---

## Expected Behavior

**Agent should:**
1. Load the profile index (NOT every progress file).
2. Render the project picker as **clickable options** (not free text).
3. Sort options by `last_session` descending.
4. Mark the most recent (`cad-rest-api`) as **recommended**.
5. Always include `Start new project` as the final option.
6. Wait for selection before loading the corresponding `.progress.json`.

**Agent should NOT:**
- Auto-load the most recent project without asking.
- Hide `Start new project` when projects exist.
- Re-sort by alphabetical or creation date.
- Read every `*.progress.json` upfront (only the chosen one loads).

---

## Pass Criteria

- [ ] Picker renders 4 options (3 projects + `Start new project`).
- [ ] `cad-rest-api` appears first, labelled recommended.
- [ ] `sca-powershell` appears second, `ghc-skills-playground` third.
- [ ] `Start new project` is last and always present.
- [ ] Only ONE `*.progress.json` is read after selection.
- [ ] If profile has 0 active projects → picker shows only `Start new project`.

---

## Actual Result

**Date run:** 2026-06-03T19:30:57.7889641-07:00
**Result:** ⚠️ PARTIAL

**Notes:**
The learner-profile skill defines project-picker construction rules: in-progress first, most recent recommended, and always include `Start new project`.
This run did not execute an interactive `@Mentor` chat turn to validate exact rendered order and single-progress-file load behavior in live runtime.

**Evidence:**
- `.github/skills/learner-profile/SKILL.md` includes the project-selection `vscode_askQuestions` example and option requirements
- `.github/skills/learner-profile/SKILL.md` states sorting/display rules (in-progress first, most recent recommended)
- `.github/agents/Mentor.agent.md` session contract requires clickable project selection before planning
