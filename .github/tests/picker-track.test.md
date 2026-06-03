# Test: Track Picker

**Type:** Integration
**Tests:** `picker:track` behavior
**Created:** 2026-06-03

---

## Setup

**Given:**
- Profile loaded for `alex_smith`
- User chose `Start new project` from `picker:project`
- Method picker already completed

---

## Test Scenario

**Agent reaches the track-pick step (after project + method are chosen for a fresh project).**

---

## Expected Behavior

**Agent should:**
1. Show the track picker with the full MSSA track list:
   - Cloud Application Development
   - Server & Cloud Administration
   - Cybersecurity Operations
   - GitHub Copilot
   - Whiteboarding
2. Render as clickable options (not free text).
3. If the profile records a previous `last_used_track`, mark it as recommended.
4. Validate the selected track's `README.md` exists before loading any track skills.
5. After selection → load the track's first skill (or the picker:continuation step if a project already exists on that track).

**Agent should NOT:**
- Show only 3 tracks (the old default — the catalog now has 5).
- Allow track selection without showing the picker.
- Load track skills before validating the track folder exists.

---

## Pass Criteria

- [ ] All 5 tracks appear in the picker.
- [ ] Track names match the labels in `.github/skills/tracks/*/README.md`.
- [ ] Validation runs before any skill load.
- [ ] First load reads the track's `README.md`, not an arbitrary skill.
- [ ] Selected track is written to the new project's progress file.

---

## Actual Result

**Date run:**
**Result:**

**Notes:**

**Evidence:**
