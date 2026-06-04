# Test: Edit a Single Setting Mid-Session

**Type:** Integration
**Tests:** behavior:32-edit-setting-on-request
**Created:** 2026-06-03

---

## Setup

**Given:**
- Active session with all 7 build options set (project, track, method, mode, comment-depth, time-box, goal)
- Profile: `mentees/test_user/profile.json` exists; active project `cad-02-rest-api` with method = `ride-along`, mode = `standard`, comment-depth = `block`, time-box = `30m`
- Session has passed `protocol:verify-build-settings` (ready_to_plan: true)
- Currently mid-planning, beat 4

---

## Test Scenarios

### Scenario A — switch method
**User says:** `Actually let's try TDD`

**Expected:**
1. Fire ONE `vscode_askQuestions` call with `picker:edit-method` (4 options: ride-along, TDD, BDD, spike-then-refactor)
2. Current value `ride-along` is marked as the default/recommended option
3. User picks TDD
4. Agent runs `pwsh .github/knowledge-graph/cli/session/set-session-setting.ps1 -Username test_user -ProjectId cad-02-rest-api -Field method -Value TDD`
5. Agent echoes exactly one line: `OK: method -> TDD`
6. Planning resumes from the current beat — no restart, no re-greeting

### Scenario B — make comments lighter
**User says:** `Make the comments lighter`

**Expected:**
1. Fire `picker:edit-comment-depth` (3 options: heavy, block, concept-only) with current `block` as default
2. User picks `concept-only`
3. `set-session-setting.ps1 -Field comment_depth -Value concept-only` runs
4. Echo: `OK: comment_depth -> concept-only`

### Scenario C — drop the time-box
**User says:** `No time-box today`

**Expected:**
1. Fire `picker:edit-time-box` (5 options) with current `30m` as default
2. User picks `skip`
3. `set-session-setting.ps1 -Field time_box -Value skip` runs
4. Echo: `OK: time_box -> skip`

---

## Agent should NOT:

- Re-fire `picker:build-options` (the full 7-question cockpit) — that protocol is start-of-session only
- Chain edits across multiple settings in one ask (e.g., do NOT show method + mode + comment-depth pickers in one go)
- Ask follow-up confirmation questions ("are you sure?")
- Re-run `protocol:verify-build-settings`
- Echo a multi-line summary or restate the build options
- Lose planning context — must resume at the same beat

---

## Pass Criteria

- [ ] Exactly ONE `vscode_askQuestions` call per scenario
- [ ] The fired picker matches the named setting (method → picker:edit-method, comments → picker:edit-comment-depth, time-box → picker:edit-time-box)
- [ ] Current value appears as the default/recommended choice
- [ ] `set-session-setting.ps1` runs with correct `-Field` and `-Value`
- [ ] Agent echo is one line, prefixed `OK:`
- [ ] Planning beat resumes (verify by next agent message referencing the same beat)
- [ ] Settings file `cad-02-rest-api.progress.json` reflects the change under `session_plan.settings`

---

## Actual Result

**Date run:** 2026-06-03T19:33:05.4808734-07:00
**Result:** ⚠️ PARTIAL

**Notes:**
Behavior contracts and CLI wiring for single-setting edits are present, including explicit guidance to avoid re-firing the full cockpit.
This run did not execute a live mid-planning transcript to verify one-picker-per-edit and exact `OK:` echo strings end-to-end.

**Evidence:**
- `.github/agents/Mentor.agent.md` defines `behavior:32-edit-setting-on-request` and focused `picker:edit-{setting}` flows
- `.github/skills/learner-profile/SKILL.md` specifies single-setting update protocol and `set-session-setting.ps1` usage
- `scripts/test.ps1 -Suite behavioral` now reports this spec as executed/freshness-tracked
