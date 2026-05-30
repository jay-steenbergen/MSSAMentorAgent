# Test: {Test Name}

**Type:** Unit | Integration | Regression
**Tests:** Agent | Skill | Profile System
**Created:** {date}

---

## Setup

**Given:** {preconditions}
- Profile state: {describe profile if needed}
- Skills loaded: {list skills}
- Session state: {describe context}

---

## Test Scenario

**User prompt:**
```
{exact text user types}
```

**OR user action:**
- {describe UI action, e.g., "Selects 'TDD' from method picker"}

---

## Expected Behavior

**Agent should:**
1. {observable action 1}
2. {observable action 2}
3. {observable outcome}

**Agent should NOT:**
- {anti-pattern 1}
- {anti-pattern 2}

---

## Pass Criteria

- [ ] {specific checkpoint 1}
- [ ] {specific checkpoint 2}
- [ ] {specific checkpoint 3}
- [ ] Output contains: `{expected text or pattern}`
- [ ] File state: {expected file changes}

---

## Actual Result

**Date run:** {fill when running}
**Result:** ✅ PASS | ❌ FAIL | ⚠️ PARTIAL

**Notes:**
{what actually happened}

**Evidence:**
{paste relevant output, screenshots, or file diffs}
