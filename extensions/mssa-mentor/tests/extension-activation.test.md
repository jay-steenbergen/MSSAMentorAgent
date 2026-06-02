# Test: Extension Activation - VSIX → Status Bar → Chat → Commands

**Type:** Integration
**Tests:** Extension packaging + activation
**Created:** 2026-06-02

---

## Setup

**Given:**
- VS Code 1.95+ installed
- GitHub Copilot Chat enabled and signed in
- PowerShell 7+ installed (`winget install Microsoft.PowerShell`)
- Built VSIX at `extensions/mssa-mentor/mssa-mentor-0.1.0.vsix`
- No prior version of `mssa-mentor` extension installed

---

## Test Scenario

**Tester action:**
```powershell
code --install-extension extensions/mssa-mentor/mssa-mentor-0.1.0.vsix --force
```
Then run **Developer: Reload Window** from the command palette (`Ctrl+Shift+P`).

---

## Expected Behavior

**On reload, VS Code should:**
1. Install the extension without errors in the install output
2. Activate `mssa-mentor` (visible in **Output → Mentor Context Loader** channel)
3. Show a status bar item in the bottom-right
4. Register chat participant `@Mentor` (auto-completes when typing `@` in Copilot Chat)
5. Register 4 commands in the command palette (`Ctrl+Shift+P`):
   - `MSSA Mentor: Open Chat`
   - `MSSA Mentor: Welcome / Get Started`
   - `MSSA Mentor: Resume or Start`
   - `MSSA Mentor: New Project`
6. Register language model tool `mssa_scaffoldAndOpen` (visible in chat tool list)
7. Set `MSSA_MENTOR_HOME` env var for the VS Code process (default `~/.mssa-mentor/`)

**VS Code should NOT:**
- Show any error notifications
- Show "Extension cannot be activated" dialog
- Leave the status bar empty
- Block on the PowerShell check (should be fire-and-forget)

---

## Pass Criteria

- [ ] `code --install-extension` exits 0
- [ ] Output channel "Mentor Context Loader" exists and shows `[MentorContext] Extension activated`
- [ ] Status bar item visible in bottom-right
- [ ] Typing `@Me` in chat shows `@Mentor` as a completion
- [ ] All 4 commands appear when searching "MSSA Mentor" in palette
- [ ] `~/.mssa-mentor/` directory exists after activation
- [ ] No red error notifications

---

## Actual Result

**Date run:**
**Result:** ✅ PASS | ❌ FAIL | ⚠️ PARTIAL

**Notes:**

**Evidence:**
