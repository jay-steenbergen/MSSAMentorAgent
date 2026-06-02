# V1 Design — Distribution & Project Scaffolding

**Status:** Approved by Jay (2026-06-01). Spike verified the chat-open API (2026-06-01). Build plan pending separate approval.
**Author:** Mentor (interview session with Jay)
**Scope:** How mentees get the Mentor, how they start projects, where their data lives.
**Out of scope (v1):** Profile sync across machines, repo-per-project, webview UIs, team coordination, telemetry.

## Spike result (2026-06-01)

Both integration unknowns confirmed:
1. **Programmatic chat open** — `vscode.commands.executeCommand('workbench.action.chat.open', { query, isPartialQuery: false, mode, attachFiles })` works. Source: `src/vs/workbench/contrib/chat/browser/actions/chatActions.ts` interface `IChatViewOpenOptions`. VS Code uses this internally (e.g. `/init` command).
2. **Cross-window handoff** — write a sentinel JSON in `~/.mssa-mentor/pending-greetings.json` from the old window; new window's extension activation reads + acts + deletes the entry.

Design unchanged. The architecture below already assumed these would work; we now know they do.

---

## The Shape

A VS Code Marketplace extension called **MSSA Mentor**. Install once. Auto-updates via marketplace. Always serves the latest curriculum because skill files are fetched live from this repo's `main` branch on every chat turn.

```
+-------------------------------------+
|  MSSAMentorAgent (this repo)        |   <-- source of truth: curriculum
|    .github/agents/Mentor.agent.md   |       (markdown only, no code ships)
|    .github/skills/**                |
+-------------------------------------+
              |
              | raw.githubusercontent.com fetch on every chat turn
              v
+-------------------------------------+
|  MSSA Mentor VS Code extension      |   <-- thin: registers chat participant,
|    (mentee installs once)           |       fetches skills, manages UI
+-------------------------------------+
              |
              | reads/writes
              v
+-------------------------------------+
|  ~/.mssa-mentor/                    |   <-- mentee-local: profile + progress
|    profile.json                     |
|    {project-id}.progress.json       |
|    projects-root                    |
+-------------------------------------+
```

## Decisions (Locked)

| # | Decision | Why |
|---|---|---|
| 1 | VS Code Marketplace extension | Only "$0 + always latest" path (extension auto-updates) |
| 2 | Skill files fetched from `raw.githubusercontent.com/{owner}/MSSAMentorAgent/main/.github/` at chat-turn time | Zero version drift; mentee never has stale curriculum |
| 3 | Profile + progress live in `~/.mssa-mentor/` as plain JSON | Local, hand-editable, zero hosting cost, no backend |
| 4 | "Where do you want your MSSA work to live?" asked once on first project, saved to `~/.mssa-mentor/projects-root` | One folder picker per mentee, not per project |
| 5 | New project = empty folder + new VS Code window | Maximum "I built it from nothing" moment; mentee runs `dotnet new` themselves |
| 6 | First-time install opens a full Welcome tab with track overview + "Start your first session" button | Discoverable, polished, matches Python/Copilot extension pattern |
| 7 | Returning mentee sees status bar item `MSSA: cad-todo-api - Phase 3`; click to resume | Always visible, low intrusion |

## Flows

### First-time install
1. Mentee installs **MSSA Mentor** from VS Code Marketplace.
2. Extension activates on VS Code startup. Detects no `~/.mssa-mentor/profile.json`.
3. Opens a Welcome tab (webview): "Welcome to MSSA Mentor" + 3 track cards + "Start your first session" button.
4. Click button → opens Copilot Chat with `@mentor`. Mentor runs the interview (name, MOS, learning style).
5. Mentor creates `~/.mssa-mentor/profile.json` with the answers.
6. Mentor offers: "Want to start your first project?" → flow goes to "Start a new project."

### Returning mentee opens VS Code
1. Extension activates on startup. Reads `~/.mssa-mentor/profile.json`.
2. Status bar shows `MSSA: {active-project-id} - {current-phase}` (or `MSSA: ready` if no active project).
3. Mentee clicks status bar → opens Copilot Chat with `@mentor`. Mentor greets by name, references last session, offers resume or new project.

### Start a new project
1. Mentee in chat: "let's start a new project" (or clicks status bar → Mentor offers it).
2. Mentor shows track picker (`vscode_askQuestions`) → project picker (lists projects for that track from the curriculum).
3. **If this is mentee's first project ever:** Mentor asks "Where do you want your MSSA work to live?" → folder picker → saves chosen path to `~/.mssa-mentor/projects-root`.
4. Extension creates `{projects-root}/{project-id}/` — **empty folder**.
5. Extension opens that folder in a **new VS Code window** (`vscode.openFolder` with `forceNewWindow=true`).
6. In the new window, Copilot Chat opens automatically. Mentor greets: "Alex! Empty folder, fresh start. Phase 1 — open a terminal and type `dotnet new console`. Tell me what happens."
7. Mentee types. Mentor walks them through the project skill phase by phase.

### Resume a project
1. Mentee clicks status bar OR types "resume" in chat.
2. Mentor reads `~/.mssa-mentor/{project-id}.progress.json` → knows current phase + last session notes.
3. Greets by name, summarizes where they left off, asks "Pick up where we left off, or do something different?"

## File Layout (Mentee's Machine)

```
~/.mssa-mentor/
  profile.json                       <-- identity, learning style, military, projects index
  projects-root                      <-- one-line file: the path mentee picked in step 3 above
  cad-todo-cli.progress.json         <-- per-project progress
  cad-todo-api.progress.json
  cso-kql-foundations.progress.json
```

Mentee's actual project code lives wherever `projects-root` points, e.g.:
```
C:\Users\alex\MSSA\
  cad-todo-cli\
    Program.cs
    cad-todo-cli.csproj
  cad-todo-api\
    ...
```

## What This Repo Becomes

**This repo (`MSSAMentorAgent`) becomes the curriculum source of truth, period.**

- `.github/agents/Mentor.agent.md` — agent prompt, fetched live by extension
- `.github/skills/**` — all skill markdown, fetched live by extension
- `.github/knowledge-graph/` — graph + queries (used by you, not shipped to mentees in v1)
- `.profiles/` — **your test profiles only**, not real mentee data
- `extensions/mentor-context-loader/` — gets renamed/expanded into the shipping extension

## Open Questions (Defer to Build Plan)

- **Q1:** Caching strategy for fetched skills. Cache for the chat turn? Cache for 5 min? Always fetch fresh? (Tradeoff: stale curriculum vs API rate limits.)
- **Q2:** Versioning. If you push a breaking change to a skill, how does the extension cope? Pin to a Git tag? Always `main`?
- **Q3:** Telemetry. Do you want to know how many mentees are using it, which tracks are popular? V1 says no — confirm.
- **Q4:** Marketplace publisher account. Personal vs Microsoft-affiliated. Free either way.

## What V1 Explicitly Does NOT Do

- No GitHub repo creation for the mentee's project
- No `git init` in the scaffolded folder
- No webview project-card pane (deferred to v2)
- No cross-machine profile sync (mentee copies `~/.mssa-mentor/` manually)
- No team / multi-mentor coordination
- No usage telemetry
- No offline mode (extension requires GitHub raw fetch to work)
