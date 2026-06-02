# Test: `mssa_scaffoldAndOpen` Tool — End-to-End Project Creation

**Type:** Integration
**Tests:** `tools/scaffoldAndOpen.ts` + `profileReader.ts` + project on-disk state
**Created:** 2026-06-02

---

## Setup

**Given:**
- Extension activated
- Profile exists at `~/.mssa-mentor/profiles/mentees/{user}/profile.json` with at least name + learning style
- `MSSA_MENTOR_HOME` resolves (default `~/.mssa-mentor/`)
- VS Code chat is open

---

## Test Scenario

**User prompt to `@Mentor`:**
```
@Mentor start a new Cloud App Dev project. Method: ride-along. Track: cloud-app-dev. Call it "weather-api".
```

The `@Mentor` agent should select `#mssa_scaffoldAndOpen` and invoke it with input matching the tool schema (username, projectId, projectName, track, method).

---

## Expected Behavior

**The tool should:**
1. Create project directory under the user's chosen location (or scaffold workspace path documented in tool description)
2. Write `{menteesDir}/{username}/weather-api.progress.json` with starting milestone
3. Append `{ id: "weather-api", name: "weather-api", ... }` to `projects[]` in `{menteesDir}/{username}/profile.json`
4. Open the scaffolded folder in a new VS Code window (or the current one with the project at root)
5. Return a success summary to the chat stream

**The tool should NOT:**
- Overwrite an existing `weather-api.progress.json` without explicit confirmation
- Append a duplicate `projects[]` entry if one with that id already exists
- Crash if profile.json is missing the `projects` field (must initialize it)

---

## Pass Criteria

- [ ] `weather-api.progress.json` exists with valid JSON
- [ ] `profile.json` `projects[]` contains the new entry exactly once
- [ ] VS Code opens the scaffolded folder
- [ ] Tool returns a confirmation message to chat
- [ ] Re-running the same prompt is idempotent (no duplicate entries)
- [ ] No errors in Output → Mentor Context Loader

---

## Actual Result

**Date run:**
**Result:** ✅ PASS | ❌ FAIL | ⚠️ PARTIAL

**Notes:**

**Evidence:**
