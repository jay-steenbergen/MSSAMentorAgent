# MSSA Mentor

A VS Code chat agent for veterans transitioning through the **Microsoft Software & Systems Academy (MSSA)**. Teaches software engineering by building real code alongside you — using analogies from your military background and tracking your progress across sessions.

> Built for the MSSA program. Free, open source, and respects your time.

---

## What you get

- **`@Mentor` chat participant.** Type `@Mentor` in any VS Code chat to start. The agent learns your background (branch, MOS, learning style) in a short interview and adapts how it teaches.
- **Status bar button.** A single button in the bottom-right that knows where you are:
  - First time → **Start MSSA Mentor**
  - Project in flight → **Resume MSSA Mentor**
  - Otherwise → **MSSA Mentor** (opens chat)
- **Project scaffolding.** When you're ready, the agent uses the built-in `scaffoldAndOpen` tool to create a project folder, README, and progress tracking — all in one step.
- **Persistent profile.** Your learning style, military background, and project progress live in `~/.mssa-mentor/profiles/` and survive across sessions.
- **Always-fresh curriculum.** Skills, tracks, and teaching methods are auto-downloaded from the [MSSAMentorAgent repo](https://github.com/jay-steenbergen/MSSAMentorAgent) — no extension reinstall needed when the curriculum updates.

---

## Available tracks

- **Cloud Application Development** — build web apps and APIs.
- **Server & Cloud Administration** — infrastructure and operations.
- **Cybersecurity Operations** — security analysis and defense.

## Teaching methods

- **Ride-along** (default) — build together, the agent explains as you go.
- **TDD** — write tests first, then make them pass.
- **BDD** — start with behavior scenarios, then implement.
- **Spike-then-refactor** — explore freely, then clean up together.

You can switch method or track any time mid-session.

---

## Getting started

### First, you'll need

- **VS Code** installed → [download here](https://code.visualstudio.com/)
- **GitHub Copilot** subscription enabled in VS Code → [setup guide](https://code.visualstudio.com/docs/copilot/setup)
- **PowerShell 7+** → install with `winget install Microsoft.PowerShell` (the extension will warn you if it's missing)

### Install the extension

**Option 1 — From the VS Code Marketplace** (easiest, once published):

1. Open VS Code.
2. Click the **Extensions** icon on the left sidebar (looks like four squares) — or press `Ctrl+Shift+X`.
3. In the search box at the top, type **MSSA Mentor**.
4. Click the **Install** button on the MSSA Mentor card.

**Option 2 — From a `.vsix` file** (for testing / before marketplace):

1. Download `mssa-mentor-0.1.0.vsix` (from a release or build it yourself).
2. Open VS Code.
3. Press `Ctrl+Shift+P` to open the **Command Palette**.
4. Type **Extensions: Install from VSIX...** and press Enter.
5. Pick the `.vsix` file you downloaded.
6. When it finishes, press `Ctrl+Shift+P` again → type **Developer: Reload Window** → Enter.

### Use it

1. After installing, look at the **bottom-right of your VS Code window**. You'll see a button labeled **MSSA Mentor** (or **Start MSSA Mentor** if it's your first time). Click it.
2. Copilot Chat opens on the right with the Mentor ready. Or open Chat yourself (`Ctrl+Alt+I`) and type `@Mentor` followed by your message.
3. Answer the short interview — branch of service, MOS, learning style. Takes about three minutes.
4. The agent proposes a small first build and walks you through it. You stay at the keyboard.

### If something looks off

- **Don't see the status bar button?** Reload the window: `Ctrl+Shift+P` → "Developer: Reload Window".
- **`@Mentor` not showing up in chat?** Make sure Copilot Chat is signed in and working — try just typing a plain message first.
- **Want to see what the extension is doing?** Open the Output panel (`Ctrl+Shift+U`) and pick **Mentor Context Loader** from the dropdown.

---

## Requirements

- VS Code **1.95** or newer.
- **PowerShell 7+** (required by the knowledge-graph CLIs the agent uses for skill loading). The extension checks at startup and tells you how to install if missing.
- **GitHub Copilot** subscription (for the chat agent itself).

---

## Commands

All commands are under the **MSSA Mentor** category in the command palette (`Ctrl+Shift+P`):

| Command | What it does |
|---|---|
| `MSSA Mentor: Open Chat` | Opens chat with `@Mentor` pre-typed. |
| `MSSA Mentor: Welcome / Get Started` | First-run onboarding interview. |
| `MSSA Mentor: Resume or Start` | Picks up your active project, or starts a new one. |
| `MSSA Mentor: New Project` | Walks you through choosing a new project. |

---

## Where your data lives

- **Profiles & progress:** `~/.mssa-mentor/profiles/mentees/{username}/`
- **Curriculum cache:** `~/.mssa-mentor/curriculum/`
- **Override location:** set `MSSA_MENTOR_HOME` env var to point elsewhere.

Nothing is sent to a server you don't already use. The agent runs on your existing Copilot subscription.

---

## Contributing

Source lives at [github.com/jay-steenbergen/MSSAMentorAgent](https://github.com/jay-steenbergen/MSSAMentorAgent). Issues, PRs, and curriculum contributions welcome.
