# Test: Curriculum Auto-Fetch on Activation

**Type:** Integration
**Tests:** `curriculumFetch.ts` + curriculum manifest contract
**Created:** 2026-06-02

---

## Setup

**Given:**
- Extension activated for the first time (no curriculum cache yet)
- `~/.mssa-mentor/curriculum/` does NOT exist
- Network is available
- A curriculum manifest is published at the URL `curriculumFetch.ts` resolves (see source for current URL)

Run **both** scenarios.

---

## Test Scenario A — First run (cold cache)

**Tester action:**
- Open Copilot Chat
- Type: `@Mentor hi`

### Expected Behavior

**Extension should:**
1. Detect no cached curriculum via `hasUsableCache()` returning `false`
2. Call `fetchCurriculum()`
3. Download the manifest and skill files to `~/.mssa-mentor/curriculum/`
4. Log `[MentorContext] Curriculum source=remote fetched=N failed=0` in the Output channel
5. Continue with skill pre-load successfully

---

## Test Scenario B — Network unavailable + cold cache

**Given:**
- No `~/.mssa-mentor/curriculum/` directory
- Disable network (e.g., `Disable-NetAdapter`, airplane mode, or block in firewall)

**Tester action:**
- Open Copilot Chat → `@Mentor hi`

### Expected Behavior

**Extension should:**
1. Attempt `fetchCurriculum()` and fail
2. Detect `hasUsableCache()` returns `false`
3. Stream a friendly markdown warning: *"Could not download MSSA Mentor curriculum and no cached copy is available. Check your network and try again."*
4. Return early — do NOT crash

---

## Pass Criteria

- [ ] First run populates `~/.mssa-mentor/curriculum/` from network
- [ ] Output channel shows `source=remote` on first run
- [ ] Subsequent runs use cache (`source=cache fetched=0`)
- [ ] Offline + cold cache shows friendly warning, not a stack trace
- [ ] No silent failures

---

## Actual Result

**Date run:**
**Result:** ✅ PASS | ❌ FAIL | ⚠️ PARTIAL

**Notes:**

**Evidence:**
