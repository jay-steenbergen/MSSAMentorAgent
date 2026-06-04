# Test: PowerShell 7+ Precheck on Activation

**Type:** Integration
**Tests:** `powershellCheck.ts`
**Created:** 2026-06-02

---

## Setup

Run **both** scenarios on machines (or fresh VMs) matching each precondition.

---

## Test Scenario A — PowerShell 7+ present

**Given:**
- `pwsh --version` returns 7.x or higher
- Extension activated

### Expected Behavior

**Extension should:**
1. Invoke `pwsh -NoProfile -Command "$PSVersionTable.PSVersion"` (fire-and-forget)
2. Detect version ≥ 7
3. Log `[MentorContext] PowerShell check passed: 7.x.x` to Output channel
4. Show no notifications

---

## Test Scenario B — Only Windows PowerShell 5.1 present

**Given:**
- `pwsh.exe` is NOT on PATH
- `powershell.exe` (5.1) IS on PATH
- Extension activated

### Expected Behavior

**Extension should:**
1. Detect missing pwsh 7+
2. Show a **modal notification** with:
   - Friendly message explaining MSSA Mentor needs PowerShell 7+
   - The exact install command: `winget install Microsoft.PowerShell`
   - A "Learn More" or "Copy Command" button
3. Log the failure to Output channel
4. NOT crash — extension continues activating; CLIs that need pwsh will re-check before running

**Extension should NOT:**
- Block activation
- Show a stack trace
- Auto-install PowerShell (must be user-initiated)

---

## Pass Criteria

- [ ] pwsh 7 present → silent pass
- [ ] pwsh 7 missing → modal with install command
- [ ] Modal shows actual `winget` command (copyable)
- [ ] Extension activates regardless of pwsh status
- [ ] Output channel logs the check result either way

---

## Actual Result

**Date run:** 2026-06-03T19:29:29.5977005-07:00
**Result:** ❌ FAIL

**Notes:**
Activation is non-blocking and the check is fire-and-forget, but the current implementation does not satisfy this spec's required modal content for the missing-pwsh scenario.
Spec requires showing the exact `winget install Microsoft.PowerShell` command and a copy-style action; implementation shows only an install-page action.

**Evidence:**
- `src/powershellCheck.ts` uses `showErrorMessage(..., 'Open install page')` and opens `https://aka.ms/install-powershell`
- `src/powershellCheck.ts` message text does not include literal `winget install Microsoft.PowerShell`
- `src/extension.ts` runs `checkPowerShell(...)` fire-and-forget, so activation continues regardless of check outcome
