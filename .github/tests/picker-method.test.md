# Test: Method Picker

**Type:** Integration
**Tests:** `picker:method` behavior
**Created:** 2026-06-03

---

## Setup

**Given:**
- Profile loaded for `alex_smith`
- Active project `cad-rest-api` selected
- No `last_used_method` recorded in progress file (first time on this project)

---

## Test Scenario

**User selects `Start new project` OR a project with no method history. Agent reaches the method-pick step.**

---

## Expected Behavior

**Agent should:**
1. Show the method picker with exactly **4 options**:
   - Ride-along (recommended default)
   - TDD
   - BDD
   - Spike-then-refactor
2. Render as clickable options (not free text).
3. Mark `Ride-along` as the recommended default.
4. Validate the selected method's `SKILL.md` exists via `file_search` BEFORE loading.
5. On missing skill file → fall back to `ride-along` and tell the user explicitly: "Looks like {method} isn't built yet. Starting with ride-along for now."

**Agent should NOT:**
- Show fewer than 4 methods.
- Default to anything other than `ride-along` when no history exists.
- Load a method skill without checking the file first.
- Silently fall back without telling the user.

---

## Pass Criteria

- [ ] All 4 method options appear.
- [ ] `Ride-along` is marked recommended.
- [ ] Validation (`file_search` for `SKILL.md`) runs before load.
- [ ] Missing-file path falls back to `ride-along` with explicit notification.
- [ ] Selected method is written to `last_used_method` at session end.

---

## Actual Result

**Date run:**
**Result:**

**Notes:**

**Evidence:**
