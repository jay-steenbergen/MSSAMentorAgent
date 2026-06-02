# Feature 7: Hybrid Runtime Integration - Setup Guide

## Overview

Two-phase skill loading for faster @Mentor sessions:
- **Phase 1 (Automatic):** VS Code extension pre-loads 3 essentials
- **Phase 2 (Dynamic):** Agent loads 2-3 intent-specific skills on demand

**Result:** 5-6 skills loaded total (was 20+) — 70% reduction in context size.

---

## Installation Steps

### 1. Install Extension Dependencies

```powershell
cd extensions/mssa-mentor
npm install
```

### 2. Compile TypeScript

```powershell
npm run compile
```

### 3. Test Extension (Development Mode)

Press `F5` in VS Code to launch Extension Development Host.

**What happens:**
- New VS Code window opens with extension loaded
- Open MSSAMentorAgent workspace in the new window
- Invoke `@Mentor` in Copilot Chat
- Check Output panel → "Mentor Context Loader" to see pre-load logs

### 4. Package Extension (Production)

```powershell
# Install vsce if not already installed
npm install -g @vscode/vsce

# Package extension
npm run vscode:prepublish
vsce package

# Install in your main VS Code
code --install-extension mssa-mentor-0.1.0.vsix
```

---

## Verification

### Test Pre-Load Works

1. Open MSSAMentorAgent workspace
2. Make sure a learner profile exists (`.profiles/profiles/mentees/test_user/profile.json`)
3. Open Copilot Chat
4. Type `@Mentor hello`
5. Check Output panel → "Mentor Context Loader"

**Expected output:**
```
[MentorContext] Extension activated
[MentorContext] @Mentor invoked
[MentorContext] Starting skill pre-load...
[MentorContext] Learner: test_user
[MentorContext] Method: TDD
[MentorContext] Track: cloud-app-dev
[MentorContext] Pre-loading 3 essential skills...
[MentorContext] ✓ Loaded: .github/skills/learner-profile/SKILL.md
[MentorContext] ✓ Loaded: .github/skills/methods/TDD/SKILL.md
[MentorContext] ✓ Loaded: .github/skills/tracks/cloud-app-dev/README.md
[MentorContext] Pre-load complete: 3/3 skills loaded
```

### Test Dynamic Loading Works

After pre-load, test agent's dynamic loading:

1. In Copilot Chat with `@Mentor`, say: "I want to build a REST API"
2. Agent should run:
   ```powershell
   Get-AgentLoadList -Intent "build a REST API" -SkipEssentials
   ```
3. Agent loads 2-3 API-specific skills
4. Total context: 5-6 skills (3 pre-loaded + 2-3 intent-matched)

### Test Fallback (Without Extension)

Disable extension and test that agent still works:

1. Disable "Mentor Context Loader" extension
2. Reload VS Code
3. Invoke `@Mentor` — should still work
4. Agent loads all 5-6 files dynamically (no pre-load, but functional)

---

## Troubleshooting

### Extension Not Activating

**Symptom:** No output in "Mentor Context Loader" panel when invoking `@Mentor`

**Fixes:**
- Check extension is enabled: Extensions → search "Mentor Context" → Enable
- Check activation events: Should activate on `@Mentor` invocation
- Restart VS Code

### No Learner Profile Found

**Symptom:** Extension logs show "No learner profile found"

**Fixes:**
- Create a test profile: `.profiles/profiles/mentees/test_user/profile.json`
- Check profile format matches schema in `profileReader.ts`
- Ensure workspace root is MSSAMentorAgent

### Skills Not Loading

**Symptom:** Extension activates but logs show "Failed" for skill files

**Fixes:**
- Check skill files exist:
  - `.github/skills/learner-profile/SKILL.md`
  - `.github/skills/methods/{method}/SKILL.md`
  - `.github/skills/tracks/{track}/README.md`
- Check file paths are case-sensitive on Linux/Mac
- Verify workspace root is correct

### Agent Not Using -SkipEssentials

**Symptom:** Agent loads all 6 files even when extension pre-loaded 3

**Fixes:**
- Update `Mentor.agent.md` with new instructions (done in this PR)
- Agent may need to be reminded: "Use -SkipEssentials since extension pre-loaded essentials"
- Check extension actually pre-loaded (see Output panel)

---

## Architecture

```
┌─────────────────────────────────────┐
│  VS Code Copilot Chat               │
│  User invokes @Mentor               │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│  mssa-mentor Extension              │
│  (Phase 1: Pre-Load Essentials)     │
│                                     │
│  1. Read learner profile            │
│  2. Get last method + active track  │
│  3. Load 3 skill files:             │
│     - learner-profile               │
│     - methods/{method}              │
│     - tracks/{track}/README         │
│  4. Add as references to chat       │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│  @Mentor Agent                      │
│  (Phase 2: Dynamic Intent Loading)  │
│                                     │
│  1. Hear user's goal                │
│  2. Run Get-AgentLoadList           │
│     -Intent "..." -SkipEssentials   │
│  3. Load 2-3 intent-matched skills  │
│  4. Total: 5-6 skills               │
└─────────────────────────────────────┘
```

---

## Next Steps

1. **Test in real Mentor sessions**
   - Verify pre-load happens automatically
   - Verify agent uses -SkipEssentials
   - Measure session start time (should be faster)

2. **Add telemetry**
   - Track which skills are pre-loaded
   - Track how often -SkipEssentials is used
   - Track session start time delta

3. **User-specific profile mapping**
   - Map VS Code user → learner username
   - Use GitHub login or email for matching
   - Support multiple learners in same workspace

4. **Caching**
   - Cache profile reads (invalidate on file change)
   - Cache skill file content (invalidate on file change)

5. **Configuration**
   - Add VS Code setting: `mentor.learnerUsername`
   - Add setting: `mentor.preloadEnabled`
   - Add setting: `mentor.debugMode`

---

## Files Created

| File | Purpose |
|---|---|
| `package.json` | Extension manifest |
| `tsconfig.json` | TypeScript config |
| `src/extension.ts` | Main extension entry |
| `src/profileReader.ts` | Read learner profiles |
| `src/skillLoader.ts` | Determine skills to load |
| `README.md` | Extension documentation |
| `.vscodeignore` | Files to exclude from package |
| `SETUP.md` | This file |

---

## Development Workflow

### Make Changes
1. Edit TypeScript files in `src/`
2. Run `npm run compile`
3. Press `F5` to test in Extension Development Host

### Debug
1. Set breakpoints in TypeScript files
2. Press `F5`
3. Breakpoints hit in the Extension Development Host

### Package
```powershell
npm run vscode:prepublish
vsce package
```

### Distribute
```powershell
# Install locally
code --install-extension mssa-mentor-0.1.0.vsix

# Publish to marketplace (future)
vsce publish
```

---

## Status

- [x] Extension scaffold complete
- [x] Profile reader implemented
- [x] Skill loader implemented
- [x] Pre-load logic implemented
- [x] Agent instructions updated
- [x] -SkipEssentials parameter added to Get-AgentLoadList
- [ ] Tested in Extension Development Host
- [ ] Tested in real @Mentor session
- [ ] Packaged as VSIX
- [ ] Installed in production VS Code
- [ ] Telemetry added
- [ ] User-specific mapping added
