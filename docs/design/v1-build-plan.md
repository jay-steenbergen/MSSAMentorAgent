# V1 Build Plan — Concrete

**Status:** Draft v2 (2026-06-01) — revised after graph-based discovery of existing agent ownership.
**Companion to:** [v1-distribution-and-scaffolding.md](v1-distribution-and-scaffolding.md)
**Scope:** Exact files, type signatures, order of operations, and verification gates.

---

## What changed from draft v1 (read this first)

Graph queries against `Mentor.agent.md` showed the agent already owns most of what v1 planned to build in TypeScript. The agent composes 4 skills, invokes 11 PowerShell CLIs, and has 78 inbound rule nodes for behavior. Specifically:

| Concern | Draft v1 plan | Reality (from graph) | This plan |
|---|---|---|---|
| Profile reads | `profileReader.ts` | Agent reads via `query-node.ps1` + `get-behavior.ps1` | Ext does **read-only** for status bar + skill pre-load; agent does the rest |
| Profile writes | `profileReader.ts` write methods | Agent writes via `session-protocol.ps1 -Phase end` → `UPDATE_FILES` directive | Removed from ext |
| Progress reads/writes | `progressReader.ts` | Same as above (one CLI handles both) | Removed from ext |
| Track / project / method pickers | `commands/newProject.ts` quick-picks | Agent renders pickers from `session-protocol.ps1` output via `vscode_askQuestions` tool | Ext command opens chat with a prompt; agent owns the pickers |
| Session-end file writes | (not in v1 draft) | Agent emits `UPDATE_FILES` directive; we honor file paths from script | Agent owns it; ext just provides env |
| Skill pre-load | `skillLoader.ts` | Mode instructions still say extension pre-loads 3 essentials before first reasoning turn | Kept in ext (Phase 1 in mode doc) |

**Three new build concerns surfaced:**

1. **PowerShell 7 is a hard prereq** for every CLI the agent invokes. Ext must check on activation and guide install.
2. **Profile paths are workspace-hardcoded** in the CLIs (`.profiles/profiles/mentees/...`). We're moving profiles to `~/.mssa-mentor/`. Solution: env var `MSSA_MENTOR_HOME` read by every CLI, falling back to workspace path when unset (preserves current dev workflow).
3. **Curriculum fetch scope is larger than just markdown.** Must also fetch `.ps1` CLIs and the pre-built `merged-graph.json` (1.1 MB).

**Three decisions locked (2026-06-01):**

- **PS7:** Required for v1. Ext prompts install with platform-specific link. File v2 issue to port 10 CLIs to TypeScript.
- **Profile path:** Env var `MSSA_MENTOR_HOME`. Default `~/.mssa-mentor/`. Each CLI: `$ProfileRoot = $env:MSSA_MENTOR_HOME ?? <workspace-fallback>`.
- **Track list:** 3 MSSA tracks (matches current `session-protocol.ps1` hardcode). Bonus tracks marked "(coming soon)" in `tracks/README.md`. No code change for tracks.

---

## Final layout (after the build)

```
extensions/mssa-mentor/                  <-- renamed from mentor-context-loader/
  package.json
  tsconfig.json
  .vscodeignore
  README.md
  SETUP.md
  src/
    extension.ts                         <-- refactored activate()
    paths.ts                             [NEW] ~/.mssa-mentor/* helpers
    powershellCheck.ts                   [NEW] verify PS7, prompt install
    envSetup.ts                          [NEW] sets MSSA_MENTOR_HOME for child processes
    profileReader.ts                     <-- READ-ONLY now; repath workspace -> home
    curriculumFetch.ts                   [NEW] raw.githubusercontent.com + cache
    skillLoader.ts                       <-- thin wrapper over curriculumFetch
    pendingGreetings.ts                  [NEW] sentinel file IO
    chatOpener.ts                        [NEW] workbench.action.chat.open wrapper
    statusBar.ts                         [NEW] status bar item lifecycle
    commands/
      newProject.ts                      [NEW] thin: prepares folder + opens chat
      resumeOrStart.ts                   [NEW] thin: opens chat with appropriate prompt
      welcome.ts                         [NEW] webview entry point
    welcome/
      welcome.html                       [NEW] webview content
```

**Removed from draft v1:** `progressReader.ts` (agent owns). Complex picker chain in `newProject.ts` (agent owns).

---

## Type signatures (the contracts)

### `paths.ts`
```ts
export const MENTOR_HOME: string;                          // ~/.mssa-mentor
export function profilePath(username: string): string;     // .../profiles/mentees/{u}/profile.json
export function projectsRootPath(): string;                // .../projects-root (user-chosen dest for new projects)
export function progressPath(u: string, projectId: string): string;  // ↑/{id}.progress.json
export function pendingGreetingsPath(): string;            // .../pending-greetings.json
export function curriculumCacheDir(): string;              // .../cache/curriculum/
export function projectsRootMarker(): string;              // .../projects-root.json (stores user's chosen folder)
export async function ensureMentorHome(): Promise<void>;   // mkdir -p the whole tree
```

### `powershellCheck.ts` (NEW)
```ts
export interface PowerShellStatus {
  installed: boolean;
  version?: string;       // semver string when installed
  invocation: 'pwsh' | 'pwsh.exe' | null;
}

export async function checkPowerShell(): Promise<PowerShellStatus>;

// Shows a blocking modal if PS7+ missing. Buttons: "Install" -> opens platform-specific URL.
// Returns true if the user can proceed (PS7 found OR they explicitly chose to continue without it).
export async function ensurePowerShellOrPrompt(): Promise<boolean>;
```

Install link routing (in the prompt):
- **Windows:** `https://aka.ms/install-powershell` (winget command shown in webview, copy-to-clipboard)
- **macOS:** `https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-macos`
- **Linux:** `https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux`

### `envSetup.ts` (NEW)
```ts
// Sets MSSA_MENTOR_HOME into the extension's environment so any process the
// extension or chat host spawns inherits it. CLIs read $env:MSSA_MENTOR_HOME.
export function applyEnvDefaults(): void;
```

Implementation:
```ts
process.env.MSSA_MENTOR_HOME = paths.MENTOR_HOME;
```
Called once at the top of `activate()`.

### `profileReader.ts` (refactor — READ-ONLY)
```ts
// Interfaces unchanged from current extension.
export interface LearnerProfile { /* unchanged */ }
export interface LearnerContext { /* unchanged */ }
export interface ProgressIndexEntry {
  status: 'in_progress' | 'completed';
  current_step: number;
  last_session?: string;
  last_used_method?: 'ride-along' | 'TDD' | 'BDD' | 'spike-then-refactor';
  track?: 'cloud-app-dev' | 'server-cloud-admin' | 'cybersecurity-ops';
}

// CHANGE 1: read from paths.profilePath() instead of workspace.
// CHANGE 2: no write functions. Agent owns writes via session-protocol.ps1.
export async function readProfile(username: string): Promise<LearnerProfile | null>;
export async function getCurrentUsername(): Promise<string>;   // git config user.name fallback to os.userInfo().username
export async function getLearnerContext(): Promise<LearnerContext | null>;
```

### `curriculumFetch.ts` (NEW — broader scope than v1 draft)
```ts
export interface CurriculumSource {
  owner: string;   // default: 'mssa-mentor'
  repo: string;    // default: 'MSSAMentorAgent'
  ref: string;     // default: 'main' (v1) — later a pinned tag
}

export const DEFAULT_SOURCE: CurriculumSource = {
  owner: 'mssa-mentor',
  repo: 'MSSAMentorAgent',
  ref: 'main',
};

// Fetches a curriculum-relative file (markdown, .ps1, or .json) and returns
// the LOCAL cached URI. Files cached in paths.curriculumCacheDir().
//
// Examples:
//   fetchCurriculumFile('.github/skills/tracks/cloud-app-dev/cad-todo-cli/SKILL.md')
//   fetchCurriculumFile('.github/knowledge-graph/cli/session/session-protocol.ps1')
//   fetchCurriculumFile('.github/knowledge-graph/output/merged-graph.json')
export async function fetchCurriculumFile(
  relPath: string,
  source?: CurriculumSource,
): Promise<vscode.Uri>;

// Pre-warms cache with the files the agent needs at session start.
// Call once on activate() so the first chat turn doesn't pay the HTTPS cost.
export async function warmCache(): Promise<void>;

// What gets warmed:
//   - .github/agents/Mentor.agent.md
//   - .github/skills/learner-profile/SKILL.md
//   - .github/knowledge-graph/cli/session/session-protocol.ps1
//   - .github/knowledge-graph/cli/inspect/query-node.ps1
//   - .github/knowledge-graph/cli/inspect/get-behavior.ps1
//   - .github/knowledge-graph/output/merged-graph.json   (1.1 MB)
//   - All 4 method SKILL.md files (small)
//   - All 3 track README.md files (small)

// Cache policy (v1): persistent on disk, no TTL, single ref ('main').
// Eviction: command 'mssa-mentor.clearCache' wipes curriculumCacheDir().
export async function clearCache(): Promise<void>;
```

### `skillLoader.ts` (refactor — thinner)
```ts
import { LearnerContext } from './profileReader';

export interface SkillRef {
  curriculumPath: string;   // e.g. '.github/skills/learner-profile/SKILL.md'
  type: 'core' | 'method' | 'track';
  reason: string;
}

// Returns the 3 essentials per the Mentor mode doc:
//   - .github/skills/learner-profile/SKILL.md
//   - .github/skills/methods/{lastMethod}/SKILL.md  (fallback: ride-along)
//   - .github/skills/tracks/{track}/README.md       (fallback: cloud-app-dev)
export function getSkillsToPreload(ctx: LearnerContext | null): SkillRef[];

export async function resolveSkills(refs: SkillRef[]): Promise<vscode.Uri[]>;
```

### `pendingGreetings.ts` (NEW — cross-window handoff)
```ts
export interface PendingGreeting {
  workspaceFolderPath: string;    // matched against vscode.workspace.workspaceFolders[0]
  projectId: string;
  query: string;                  // pre-built '@mentor ...' text to submit
  attachSkills: string[];         // curriculum-relative paths
  createdAt: string;              // ISO date — for stale-entry cleanup
}

export async function queueGreeting(g: PendingGreeting): Promise<void>;
export async function takeGreetingForFolder(folderPath: string): Promise<PendingGreeting | null>;  // reads + removes
export async function purgeStale(olderThanHours?: number): Promise<void>;       // default 24h
```

### `chatOpener.ts` (NEW — the verified workaround)
```ts
export interface OpenChatOptions {
  query: string;
  attachFiles?: vscode.Uri[];
  mode?: 'ask' | 'agent' | 'edit';   // defaults to 'agent'
  autoSubmit?: boolean;              // defaults to true (isPartialQuery=false)
}

export async function openMentorChat(opts: OpenChatOptions): Promise<void>;
```

Implementation:
```ts
await vscode.commands.executeCommand('workbench.action.chat.open', {
  query: opts.query,
  isPartialQuery: !(opts.autoSubmit ?? true),
  mode: opts.mode ?? 'agent',
  attachFiles: opts.attachFiles,
});
```

### `statusBar.ts` (NEW)
```ts
export function registerStatusBar(ctx: vscode.ExtensionContext): vscode.Disposable;
// Behavior:
//   - Reads profile (read-only) + most recent in_progress project from profile.projects index
//   - Text: `$(mortar-board) MSSA: <project-id>` OR `$(mortar-board) MSSA: ready`
//   - Tooltip: short summary (track, method, last session date)
//   - Click -> command 'mssa-mentor.resumeOrStart'
//   - Refresh: fs.watch(paths.profilePath(username)) — best effort
```

### `commands/newProject.ts` (THIN — agent owns pickers)
```ts
export async function newProjectCommand(): Promise<void>;
// Steps:
//   1. Ensure PS7 (powershellCheck.ensurePowerShellOrPrompt) — abort if user declines.
//   2. Ensure projectsRoot is chosen (showOpenDialog if first time, persist to projects-root.json).
//   3. Open chat with prompt: '@mentor I want to start a new project. Show me my options.'
//      (Agent runs session-protocol.ps1 -Phase start -> SHOW_TRACK_PICKER -> SHOW_PROJECT_PICKER.)
//   4. The agent, after the mentee picks, calls a chat tool that asks the extension to:
//      a. mkdir {projectsRoot}/{projectId}
//      b. queueGreeting({ projectId, query: '@mentor I just opened {projectId}, Phase 1', attachSkills: [...] })
//      c. vscode.openFolder(folderUri, { forceNewWindow: true })
//   5. NEW WINDOW activates -> takeGreetingForFolder -> openMentorChat fires.
```

> **Note on 4a-c:** The agent already calls extension-side tools via the chat participant API. The new pieces are `mkdir`, `queueGreeting`, and `openFolder`. We expose these as a **single tool** the agent invokes: `mssa_scaffoldAndOpen({ projectId, attachSkills })`. Build step 17 wires this tool.

### `commands/resumeOrStart.ts` (THIN)
```ts
export async function resumeOrStartCommand(): Promise<void>;
// Steps:
//   1. Ensure PS7.
//   2. Open chat with prompt: '@mentor I'm back. What were we working on?'
//   3. Agent runs session-protocol.ps1 -Phase start, which decides:
//        INTERVIEW | START_NEW | LOAD_PROJECT | SHOW_PROJECT_PICKER
//      and proceeds accordingly. Extension stays out of it.
```

### `commands/welcome.ts` (NEW)
```ts
export async function welcomeCommand(ctx: vscode.ExtensionContext): Promise<void>;
// vscode.window.createWebviewPanel — welcome.html loaded once at activate, cached.
// Message-passing:
//   webview -> ext: 'start-first-session'
//     -> ensurePowerShellOrPrompt (gate)
//     -> openMentorChat({ query: '@mentor I just installed MSSA Mentor', mode: 'agent' })
//   webview -> ext: 'install-powershell-{platform}'
//     -> vscode.env.openExternal(<platform URL>)
```

### `extension.ts` (refactored shape)
```ts
export async function activate(ctx: vscode.ExtensionContext) {
  await paths.ensureMentorHome();
  envSetup.applyEnvDefaults();             // sets MSSA_MENTOR_HOME for child processes
  await pendingGreetings.purgeStale();
  curriculumFetch.warmCache().catch(err => console.warn('warm cache failed', err));  // best-effort

  // 1. Cross-window handoff
  const wsFolder = vscode.workspace.workspaceFolders?.[0];
  if (wsFolder) {
    const g = await pendingGreetings.takeGreetingForFolder(wsFolder.uri.fsPath);
    if (g) {
      const skillUris = await Promise.all(
        g.attachSkills.map(s => curriculumFetch.fetchCurriculumFile(s)),
      );
      await chatOpener.openMentorChat({ query: g.query, attachFiles: skillUris });
    }
  }

  // 2. First-time install check (independent of PS7 — that fires on first action)
  const username = await profileReader.getCurrentUsername();
  const profile = await profileReader.readProfile(username);
  if (!profile) {
    await welcomeCommand(ctx);
  }

  // 3. Always-on registrations
  ctx.subscriptions.push(
    statusBar.registerStatusBar(ctx),
    vscode.commands.registerCommand('mssa-mentor.newProject', newProjectCommand),
    vscode.commands.registerCommand('mssa-mentor.resumeOrStart', resumeOrStartCommand),
    vscode.commands.registerCommand('mssa-mentor.welcome', () => welcomeCommand(ctx)),
    vscode.commands.registerCommand('mssa-mentor.clearCache', curriculumFetch.clearCache),
    vscode.chat.createChatParticipant('Mentor', chatHandler),
  );
}
```

### `package.json` deltas
```jsonc
{
  "name": "mssa-mentor",
  "displayName": "MSSA Mentor",
  "publisher": "<TBD-marketplace-handle>",
  "activationEvents": [
    "onStartupFinished",
    "onChatParticipant:Mentor"
  ],
  "contributes": {
    "commands": [
      { "command": "mssa-mentor.newProject",     "title": "MSSA: Start a New Project" },
      { "command": "mssa-mentor.resumeOrStart",  "title": "MSSA: Resume or Start" },
      { "command": "mssa-mentor.welcome",        "title": "MSSA: Show Welcome" },
      { "command": "mssa-mentor.clearCache",     "title": "MSSA: Clear Curriculum Cache" }
    ],
    "chatParticipants": [
      { "id": "Mentor", "name": "mentor", "description": "MSSA Mentor — teaches by building" }
    ]
  }
}
```

---

## CLI patches required (separate gate before extension build)

These are **service code changes** to existing `.ps1` files. I will not edit them without explicit "go" per the Gate Protocol. Listing here so they're visible.

| File | Patch | Why |
|---|---|---|
| `.github/knowledge-graph/cli/session/session-protocol.ps1` | Add `$ProfileRoot = $env:MSSA_MENTOR_HOME ?? (Join-Path $PSScriptRoot '../../../.profiles')` at top. Replace all `.profiles/profiles/mentees/...` literals with `Join-Path $ProfileRoot 'profiles/mentees/...'`. Gate `GitCommand` field: `if ($env:MSSA_MENTOR_HOME) { $update.GitCommand = $null }`. | Profile location depends on caller (dev vs mentee). |
| Other CLIs that read/write `.profiles/` | Same env-var pattern. | Same reason. (Enumerate in step 0 below.) |
| `.github/skills/tracks/README.md` | Mark `github-copilot` and `whiteboarding` as "(coming soon)". | Picker only offers 3 MSSA tracks; README must not promise more. |

---

## Pre-build step 0 (CLI audit)

Before any extension code changes, enumerate which CLIs touch profile paths. One command:

```pwsh
Select-String -Path .github/knowledge-graph/cli/*.ps1 -Pattern '\.profiles' |
  Select-Object Path, LineNumber, Line
```

Output goes into a small TODO list (in this doc, replacing this section once done) of the exact files + line numbers needing the env-var patch.

---

## Pre-build step 1 (CI for graph)

Add `.github/workflows/build-graph.yml`:

```yaml
name: Build knowledge graph
on:
  push:
    branches: [main]
    paths:
      - '.github/agents/**'
      - '.github/skills/**'
      - '.github/knowledge-graph/data/**'
      - '.github/knowledge-graph/build/**'
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - shell: pwsh
        run: |
          pwsh .github/knowledge-graph/build/core/extract-code-graph.ps1
          pwsh .github/knowledge-graph/build/core/merge.ps1
      - name: Commit if changed
        run: |
          git config user.name 'mssa-mentor-bot'
          git config user.email 'bot@users.noreply.github.com'
          git add .github/knowledge-graph/output/merged-graph.json
          git diff --cached --quiet || git commit -m 'chore(graph): rebuild on main' && git push
```

Verifies: on each push to `main` that touches graph inputs, the graph is rebuilt and committed. Extension fetches the committed JSON via `curriculumFetch`.

---

## Build order (each step must verify before next)

Each step is a separate "go" gate. I do not move to step N+1 without verifying step N.

| # | Step | Verification | Touches |
|---|---|---|---|
| 0 | CLI audit (run grep, list files) | Output replaces "Pre-build step 0" section above | none (read-only) |
| 1 | Patch session-protocol.ps1 + other CLIs to read MSSA_MENTOR_HOME | Run with env set; verify writes go to temp dir; run without env; verify workspace fallback | listed CLIs |
| 2 | Update tracks/README.md (bonus tracks → "coming soon") | Visual diff | tracks/README.md |
| 3 | CI: add build-graph.yml | Push to a test branch; workflow runs green; merged-graph.json regenerates | .github/workflows |
| 4 | Rename folder + update `package.json` name/publisher | `npm run compile` clean | folder, package.json |
| 5 | Add `paths.ts` + `ensureMentorHome` | Launch ext host; check `~/.mssa-mentor/` tree exists | paths.ts, extension.ts |
| 6 | Add `envSetup.ts` + wire into activate() | In ext host, spawn `pwsh -c '$env:MSSA_MENTOR_HOME'` from a temp command, confirm value | envSetup.ts |
| 7 | Add `powershellCheck.ts` | Test 1: PS7 present → silent pass. Test 2: rename pwsh on PATH → modal fires | powershellCheck.ts |
| 8 | Refactor `profileReader.ts` to read-only + home path | Drop sample `profile.json` in `~/.mssa-mentor/profiles/mentees/<u>/`, log on activation | profileReader.ts |
| 9 | Add `curriculumFetch.ts` + cache + `warmCache` | Fetch one .md, one .ps1, the graph JSON; second fetch is cache hit | curriculumFetch.ts |
| 10 | Refactor `skillLoader.ts` to use curriculumFetch | Existing chat handler still injects via stream.reference | skillLoader.ts, extension.ts |
| 11 | Add `chatOpener.ts` | Temp command calls it with hardcoded query; observe chat opens & auto-submits | chatOpener.ts, package.json |
| 12 | Add `pendingGreetings.ts` | Unit-style: write + read + delete round-trip | pendingGreetings.ts |
| 13 | Wire cross-window handoff in `activate()` | Manually queue greeting, open folder in new window, confirm chat fires | extension.ts |
| 14 | Add `statusBar.ts` | Profile with/without active project → correct text | statusBar.ts, extension.ts |
| 15 | Add `commands/welcome.ts` + webview HTML | Fresh install (delete `~/.mssa-mentor/`) shows welcome on activate | welcome.ts, welcome.html |
| 16 | Add `commands/resumeOrStart.ts` | Profile present + active project → chat opens with right prompt | resumeOrStart.ts |
| 17 | Add `commands/newProject.ts` + agent-callable tool `mssa_scaffoldAndOpen` | Pick track → pick project (via agent) → folder picker (first time) → new window opens → Mentor greets | newProject.ts |
| 18 | Marketplace `vsce package` dry run | `.vsix` builds; install locally; run smoke test from step 17 | none |

---

## Tests (smallest-first)

| Test | Type | When |
|---|---|---|
| `paths.test.ts` — ensureMentorHome creates dir tree, idempotent | Unit (node fs) | Step 5 |
| `envSetup.test.ts` — applyEnvDefaults sets process.env correctly | Unit | Step 6 |
| `powershellCheck.test.ts` — pwsh missing → returns false; pwsh 7.x → returns true | Unit (mock spawn) | Step 7 |
| `pendingGreetings.test.ts` — queue/take/purge round-trip | Unit | Step 12 |
| `curriculumFetch.test.ts` — fetch returns valid URI, cache hit on second call, graph.json fetches correctly | Unit (mock https) | Step 9 |
| **CLI integration test** — invoke `session-protocol.ps1 -Phase start` with `MSSA_MENTOR_HOME` set to temp dir, assert no `.profiles/` paths in output | Integration (real pwsh) | Step 1 |
| `manual smoke: PS7 install prompt` | Manual | Step 7 |
| `manual smoke: first-install flow` | Manual | Step 15 |
| `manual smoke: new project flow` | Manual | Step 17 |
| `manual smoke: resume flow` | Manual | Step 17 |

---

## Open items the build will surface (escalate to Jay when reached)

- **`mssa_scaffoldAndOpen` tool surface.** This is a new chat tool the agent calls. Need to design its exact JSON-RPC contract (what fields the agent passes back from picker output). Reach this at step 17.
- **Caching + versioning policy.** Currently "always `main`, persistent disk cache, no TTL, manual `clearCache` command." Need to decide: pin to tags for production rollouts? Per-mentee version override (`MSSA_MENTOR_REF` env var)? How to roll out breaking curriculum changes without re-installs?
- **Welcome webview copy.** Need the actual 3 track descriptions, the PS7 install pitch, and the "start session" CTA written out before step 15.
- **Marketplace publisher account.** Natural alignment: `mssa-mentor` (same as org). Confirm before step 18.
- **v2 issue: port 10 CLIs to TypeScript.** File now (~1500 LOC, eliminates PS7 dep). Track via GitHub issue, link from `extensions/mssa-mentor/README.md`.

---

## What this plan does NOT do (v1 boundary)

- No tests for `chatOpener.ts` (thin wrapper; manual verify in step 11)
- No `git init` in scaffolded folder
- No telemetry hooks
- No webview for project list (status bar + command palette + agent-driven pickers)
- No bundling/minification (`tsc` straight to `out/`)
- No CI publishing (manual `vsce publish` v0.1.0)
- No port of CLIs to TS (deferred to v2 — see open items)
- No bonus tracks (`github-copilot`, `whiteboarding`) — deferred to v2; README marks "coming soon"
