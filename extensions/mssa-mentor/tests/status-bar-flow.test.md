# Test: Status Bar Click → Correct Command Based on State

**Type:** Integration
**Tests:** `statusBar.ts` + `statusBarState.ts` + `resumeOrStart.ts`
**Created:** 2026-06-02

---

## Setup

**Given:**
- Extension activated (see `extension-activation.test.md`)
- Status bar item visible

Run **both** scenarios below.

---

## Test Scenario A — No profile exists

**Given:**
- `~/.mssa-mentor/profiles/mentees/` is empty (or `$env:USERNAME` has no profile)

**Tester action:**
- Click the MSSA Mentor status bar item

### Expected Behavior

**Extension should:**
1. Detect no profile via `profileReader.getCurrentLearnerContext()` returning `null`
2. Status bar reflects "Start" state (e.g., `$(rocket) MSSA Mentor`)
3. Click invokes `mssa-mentor.welcome` command
4. Welcome flow opens Copilot Chat with `@Mentor` and a first-time greeting

---

## Test Scenario B — Profile + active project exists

**Given:**
- `~/.mssa-mentor/profiles/mentees/{user}/profile.json` exists
- Profile has at least one project in `projects[]`

**Tester action:**
- Click the MSSA Mentor status bar item

### Expected Behavior

**Extension should:**
1. Detect profile + projects via `profileReader`
2. Status bar reflects "Resume" state
3. Click invokes `mssa-mentor.resumeOrStart` command
4. If exactly 1 active project → resume it directly
5. If 2+ active projects → show QuickPick with project list

---

## Pass Criteria (both scenarios)

- [ ] Status bar label changes between Start and Resume states
- [ ] Click routes to `welcome` when no profile
- [ ] Click routes to `resumeOrStart` when profile exists
- [ ] QuickPick appears for 2+ projects (Scenario B variant)
- [ ] No error notifications

---

## Actual Result

**Date run:** 2026-06-03T19:29:29.5977005-07:00
**Result:** ⚠️ PARTIAL

**Notes:**
Automated tests verify Start/Resume state computation and command routing semantics.
This run did not perform manual status-bar click validation in a live VS Code window for both profile scenarios, so end-to-end click UX remains partially verified.

**Evidence:**
- `src/test/suite/statusBarState.test.ts` verifies null context routes to `mssa-mentor.welcome`
- `src/test/suite/statusBarState.test.ts` verifies profile with active projects routes to `mssa-mentor.resumeOrStart`
- `pwsh -NoProfile -File scripts/test.ps1 -Suite extension` => PASS (`39 pass, 0 fail`)
