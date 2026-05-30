# Test: Profile Load Speed

**Type:** Unit
**Tests:** learner-profile skill - compression resilience
**Created:** 2026-05-29

---

## Setup

**Given:**
- Profile exists at `.profiles/profiles/mentees/alex_smith/profile.json`
- Profile has 2 active projects
- Session context may or may not have profile loaded (simulating compression)

---

## Test Scenario

**User types:**
```
@Mentor load my profile
```

---

## Expected Behavior

**Agent should:**
1. Check if profile already in context
2. If missing → read `.profiles/profiles/mentees/alex_smith/profile.json`
3. If present → skip read, use cached
4. Show project picker (2+ active projects)
5. **Total time < 2 seconds** from command to picker

**Agent should NOT:**
- Read skill documentation first
- Navigate directory tree file by file
- Read profile.json AND progress files before showing picker
- Take >5 seconds

---

## Pass Criteria

- [ ] Profile loads in <2 seconds
- [ ] Compression check executes (verifies profile in context)
- [ ] If missing → re-loads automatically
- [ ] If present → uses cached (no redundant read)
- [ ] No directory tree navigation
- [ ] Project picker appears with correct data

---

## Actual Result

**Date run:** 2026-05-29
**Result:** ✅ PASS

**Notes:**
Compression resilience check works. Profile loaded quickly. Picker showed correct projects.

**Evidence:**
Tested with profile both in and out of context. Auto-reload triggered when missing. Fast when cached.
