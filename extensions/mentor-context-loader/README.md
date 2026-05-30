# Mentor Context Loader Extension

VS Code extension that pre-loads essential skills into `@Mentor` agent context before the conversation starts.

## What it does

When you invoke `@Mentor` in Copilot Chat, this extension:

1. **Reads your learner profile** (`.profiles/profiles/mentees/{username}/profile.json`)
2. **Identifies essentials:**
   - Last-used teaching method (TDD, ride-along, BDD, etc.)
   - Active project track (cloud-app-dev, server-cloud-admin, etc.)
3. **Pre-loads 3 core skills:**
   - `learner-profile/SKILL.md` (your identity & preferences)
   - `methods/{method}/SKILL.md` (your last-used method)
   - `tracks/{track}/README.md` (your active track overview)

**Result:** Faster session start (3 files loaded automatically), agent loads 2-3 more intent-specific skills on demand.

---

## Installation

### From source (development)

```bash
cd extensions/mentor-context-loader
npm install
npm run compile
```

Press `F5` in VS Code to launch Extension Development Host.

### From VSIX (production)

```bash
cd extensions/mentor-context-loader
npm run vscode:prepublish
vsce package
code --install-extension mentor-context-loader-0.1.0.vsix
```

---

## How it works

### Activation
Extension activates when `@Mentor` is invoked (via `activationEvents: ["onChatParticipant:Mentor"]`).

### Pre-load logic
1. Checks if this is a new chat session (no history)
2. Reads `.profiles/profiles/mentees/` to find learner profile
3. Extracts `last_used_method` from most recent in-progress project
4. Loads 3 skill files and adds them as references to the chat context
5. Displays a notification showing what was loaded

### Dynamic loading (by agent)
After pre-load, the `@Mentor` agent loads 2-3 additional intent-specific skills using:

```powershell
Import-Module .github/knowledge-graph/lib/query.psm1
$skills = Get-AgentLoadList -Intent "{user's goal}" -SkipEssentials
```

The `-SkipEssentials` flag prevents re-loading profile/method/track (already in context).

---

## Requirements

- VS Code 1.85.0 or later
- MSSAMentorAgent workspace open
- Learner profile exists in `.profiles/profiles/mentees/{username}/`

---

## Debugging

View pre-load logs in the **Output** panel → select **Mentor Context Loader** from the dropdown.

Logs show:
- Learner context (username, method, track)
- Skills loaded (success/failure per file)
- Total skills loaded

---

## Configuration

No configuration needed in MVP. Extension auto-discovers:
- Workspace root
- Learner profile (uses first profile found)
- Skill file paths (standard `.github/skills/` structure)

**Future:** Add setting to specify learner username explicitly.

---

## Architecture

```
extension.ts
  → profileReader.ts    (reads .profiles/)
  → skillLoader.ts      (determines which skills to load)
  → VS Code Chat API    (adds skills as references)
```

### Key functions

| Function | Purpose |
|---|---|
| `getCurrentLearnerContext()` | Find learner profile, extract method & track |
| `getSkillsToPreload()` | Determine which 3 skills to load |
| `preloadSkillsForSession()` | Load skills and add to chat context |

---

## Limitations

- **MVP:** Uses first profile found (not user-specific)
- **No retry:** If skill file doesn't exist, skips it (no fallback beyond ride-along)
- **No caching:** Re-reads profile on every session start
- **No intent matching:** Only loads essentials (agent handles intent-specific skills)

---

## Roadmap

- [ ] Map VS Code user → learner profile (via GitHub login or email)
- [ ] Add cache for profile reads (invalidate on file change)
- [ ] Support multiple learners in same workspace (team projects)
- [ ] Add telemetry (track which skills are loaded, how often)
- [ ] Add configuration setting for explicit username override

---

## License

Part of MSSAMentorAgent project.
