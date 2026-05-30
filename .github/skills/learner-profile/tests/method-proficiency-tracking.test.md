# Test: Method Proficiency Tracking

**Test Type:** Integration
**Created:** 2026-05-29
**Purpose:** Verify that proficiency levels are assessed, stored, loaded, and updated correctly across sessions.

---

## Scenario 1: First-time TDD session (no prior proficiency)

### Setup
- Learner: `test_user`
- Project: `cad-02-rest-api` (exists with milestones, no TDD proficiency)
- Progress file: `.profiles/profiles/mentees/test_user/cad-02-rest-api.progress.json`
- Initial state: `method_proficiency` object does NOT contain `TDD` key

### Session Flow

**Learner:** `@Mentor I want to try test-driven development for this REST API`

**Expected Mentor Behavior:**

1. **Load profile & progress** — finds no `method_proficiency.TDD` entry
2. **Reference JSON** — loads `.github/skills/references/method-proficiency-levels.json`
3. **Assess proficiency** — asks:
   > "Before we start TDD, quick check: have you done test-driven development before?"
4. **Match to indicators:**
   - If learner says "What's TDD?" → Novice
   - If learner says "I've tried it once or twice" → Familiar
   - If learner says "I've done several TDD sessions" → Competent
   - If learner says "I use it regularly" → Proficient
5. **Adapt teaching** — uses `teaching_approach` from JSON for determined level
6. **Run TDD session** — full Red-Green-Refactor cycle
7. **Assess progression** — at session end, check if learner showed signals for level-up
8. **Update progress file** — write proficiency to `method_proficiency.TDD`

### Expected Progress File After Session

If learner was **Novice** and completed 1 Red-Green-Refactor cycle:

```json
{
  "project_id": "cad-02-rest-api",
  "method_proficiency": {
    "TDD": {
      "level": "Novice",
      "last_updated": "2026-05-29",
      "notes": "First TDD session. Completed 1 Red-Green-Refactor cycle. Needed prompting on test structure. Named phases with help."
    }
  },
  "milestones": [ /* ... existing milestones ... */ ]
}
```

### Verification Steps

**Manual verification:**
1. Open `.profiles/profiles/mentees/test_user/cad-02-rest-api.progress.json`
2. Confirm `method_proficiency.TDD` exists
3. Confirm `level` is one of: `Novice`, `Familiar`, `Competent`, `Proficient`
4. Confirm `last_updated` is today's date in `YYYY-MM-DD` format
5. Confirm `notes` is non-empty string describing session

**Automated verification (future):**
```powershell
# PowerShell validation script
$progress = Get-Content -Raw ".profiles/profiles/mentees/test_user/cad-02-rest-api.progress.json" | ConvertFrom-Json
$tdd = $progress.method_proficiency.TDD

# Validate structure
if (-not $tdd) { throw "TDD proficiency not found" }
if ($tdd.level -notin @('Novice', 'Familiar', 'Competent', 'Proficient')) { 
    throw "Invalid level: $($tdd.level)" 
}
if ($tdd.last_updated -notmatch '^\d{4}-\d{2}-\d{2}$') { 
    throw "Invalid date format: $($tdd.last_updated)" 
}
if ([string]::IsNullOrWhiteSpace($tdd.notes)) { 
    throw "Notes are empty" 
}
Write-Host "✓ TDD proficiency structure valid"
```

---

## Scenario 2: Second TDD session (existing proficiency)

### Setup
- Same learner, same project
- Progress file now contains `method_proficiency.TDD` from Scenario 1
- Initial state: `TDD.level = "Novice"`

### Session Flow

**Learner:** `@Mentor let's do more TDD`

**Expected Mentor Behavior:**

1. **Load profile & progress** — finds `method_proficiency.TDD.level = "Novice"`
2. **Acknowledge prior experience:**
   > "I see you've done TDD before (Novice level, last session 2026-05-29). Let's continue building that skill."
3. **Adapt teaching** — uses Novice teaching approach (no re-assessment needed)
4. **Run TDD session** — Red-Green-Refactor with Novice-level support
5. **Assess progression** — check for Novice→Familiar signals:
   - Did learner name phases independently?
   - Did learner write a test without full dictation?
6. **Update progress file** — if progression detected, update to `Familiar`

### Expected Progress File After Session

If learner showed progression to **Familiar**:

```json
{
  "method_proficiency": {
    "TDD": {
      "level": "Familiar",
      "last_updated": "2026-05-29",
      "notes": "Second TDD session. Named Red-Green-Refactor phases independently. Wrote one test with minimal prompting. Still needs guidance on test scope."
    }
  }
}
```

If learner stayed at **Novice**:

```json
{
  "method_proficiency": {
    "TDD": {
      "level": "Novice",
      "last_updated": "2026-05-29",
      "notes": "Second TDD session. Completed 2 more cycles. Gaining confidence with test structure. Not yet ready for Familiar."
    }
  }
}
```

---

## Scenario 3: Multi-method tracking

### Setup
- Same learner completes sessions in multiple methods
- Expected state: Progress file contains proficiency for multiple methods

### Expected Progress File After 3 Sessions (TDD, BDD, spike)

```json
{
  "project_id": "cad-02-rest-api",
  "method_proficiency": {
    "TDD": {
      "level": "Familiar",
      "last_updated": "2026-05-29",
      "notes": "Completed 3 cycles. Names phases independently."
    },
    "BDD": {
      "level": "Novice",
      "last_updated": "2026-05-29",
      "notes": "First BDD session. Wrote 1 scenario with heavy guidance."
    },
    "spike-then-refactor": {
      "level": "Familiar",
      "last_updated": "2026-05-29",
      "notes": "Second spike. Comfortable exploring. Refactored without guilt."
    },
    "ride-along": {
      "level": "Competent",
      "last_updated": "2026-05-21",
      "notes": "Default method. Strong fundamentals."
    }
  }
}
```

---

## Pass Criteria

### ✅ Assessment works
- [ ] Mentor asks proficiency question when `method_proficiency.{method}` is missing
- [ ] Mentor references JSON indicators to determine level
- [ ] Mentor does NOT ask proficiency question when level already exists

### ✅ Teaching adapts
- [ ] Mentor behavior matches proficiency level (full guidance for Novice, hints for Familiar, etc.)
- [ ] Mentor references JSON `teaching_approach` and `mentor_behavior` fields

### ✅ Progress persists
- [ ] After session end, progress file contains new `method_proficiency.{method}` entry
- [ ] Entry has all required fields: `level`, `last_updated`, `notes`
- [ ] `level` is one of the four valid values
- [ ] `last_updated` is in `YYYY-MM-DD` format
- [ ] `notes` describe session progress

### ✅ Progress loads
- [ ] Next session in same method loads existing proficiency
- [ ] Mentor acknowledges prior experience
- [ ] Mentor does NOT re-assess proficiency

### ✅ Progression updates
- [ ] If learner shows progression signals, level updates to next tier
- [ ] If learner does not progress, level stays same but `notes` and `last_updated` refresh
- [ ] Progression signals match those in JSON `progression_signals`

### ✅ Multi-method tracking
- [ ] Progress file can hold proficiency for multiple methods simultaneously
- [ ] Each method has independent proficiency level
- [ ] Switching methods mid-project works correctly

---

## Failure Modes to Test

### Missing JSON file
**Setup:** Rename `method-proficiency-levels.json`
**Expected:** Mentor falls back to asking direct question: "How familiar are you with TDD on a scale of Novice/Familiar/Competent/Proficient?"

### Malformed progress file
**Setup:** Delete `method_proficiency.TDD.level` field
**Expected:** Mentor treats as missing proficiency, re-assesses

### Invalid level value
**Setup:** Manually set `level: "Expert"` (not in valid set)
**Expected:** Mentor treats as corrupted, re-assesses

### Missing notes
**Setup:** Progress file has `level` and `last_updated` but no `notes`
**Expected:** Mentor loads level, continues normally (notes are for human reference)

---

## Integration with Session Protocols

### Session Start (from method skills)
1. Load learner profile via `learner-profile` skill
2. Load progress file for current project
3. Check `method_proficiency.{current_method}`
4. If missing → assess via JSON indicators
5. If present → acknowledge + adapt teaching

### Session End (from method skills)
1. Assess progression using JSON `progression_signals`
2. Determine final level (progressed or stayed)
3. Call `learner-profile` Session End Update Protocol
4. Learner-profile skill writes to progress file
5. Verify write succeeded (read back and confirm)

---

## Automation Opportunities

**Validation script:** `.profiles/validate-proficiency.ps1`
- Scans all progress files
- Checks `method_proficiency` structure
- Reports malformed entries
- Suggests fixes

**Dashboard:** (future)
- Visualize proficiency across all learners
- Show progression timelines
- Identify common bottlenecks (e.g., "Most learners stuck at Novice→Familiar in TDD")

**Auto-leveling:** (future)
- LLM reads session transcript
- Matches learner behavior to progression signals
- Suggests level update to mentor for confirmation
