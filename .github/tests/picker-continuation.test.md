# Test: Continuation Picker

**Type:** Integration
**Tests:** `picker:continuation` behavior
**Created:** 2026-06-03

---

## Setup

**Given:**
- Profile loaded for `alex_smith`
- Project `cad-rest-api` selected from `picker:project`
- Progress file shows: `last_used_method: "tdd"`, `last_used_track: "cloud-app-dev"`, last milestone `M3-handlers-tested`

---

## Test Scenario

**Agent has just loaded the project's progress file and needs to know whether the learner is continuing or changing direction.**

---

## Expected Behavior

**Agent should:**
1. Show the continuation picker with exactly **3 options**:
   - Continue (recommended) — TDD on Cloud App Dev
   - Switch method
   - Switch track
2. Render as clickable options.
3. Each label INCLUDES the current method and track so the learner sees what `Continue` means.
4. On `Continue` → resume at the next step after `M3-handlers-tested`, greeting by name with project + last milestone.
5. On `Switch method` → invoke `picker:method`.
6. On `Switch track` → invoke `picker:track`.

**Agent should NOT:**
- Skip the picker and auto-continue silently.
- Show "Continue" without naming the method + track being continued.
- Forget the last milestone when resuming.

---

## Pass Criteria

- [ ] 3 options appear, in the order above.
- [ ] `Continue` option text names both method and track.
- [ ] `Continue` greeting includes name, project, and last milestone.
- [ ] `Switch method` correctly chains to `picker:method`.
- [ ] `Switch track` correctly chains to `picker:track`.
- [ ] Switching does NOT lose project context.

---

## Actual Result

**Date run:**
**Result:**

**Notes:**

**Evidence:**
