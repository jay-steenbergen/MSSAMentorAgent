import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import { getMenteesDir } from '../paths';
import { getCurrentUsername } from '../profileReader';
import { refreshStatusBar } from '../statusBar';

/** Tool id — must match the `name` declared in package.json languageModelTools contribution.
 *  VS Code requires tool ids match /^[\w-]+$/, so no '.' separators. */
export const SCAFFOLD_AND_OPEN_TOOL = 'mssa_scaffoldAndOpen';

export interface ScaffoldInputs {
  /** Stable folder-safe id, e.g. `todo-api`. */
  projectId: string;
  /** Human label shown in pickers, e.g. `Todo API`. */
  displayName: string;
  /** MSSA track id — one of cloud-app-dev | server-cloud-admin | cybersecurity-ops. */
  track: string;
  /** Teaching method — one of ride-along | TDD | BDD | spike-then-refactor. */
  method: string;
  /** Optional override for the profile username (defaults to current user). */
  username?: string;
}

export interface ScaffoldResult {
  projectPath: string;
  readmePath: string;
  profilePath: string;
  progressPath: string;
}

/**
 * Filesystem ports — overridden in tests.
 *
 * Real ports are wired in `runScaffold`.
 */
export interface ScaffoldDeps {
  workspaceRoot: string;
  menteesDir: string;
  username: string;
  now: () => string;
}

const VALID_TRACKS = new Set([
  'cloud-app-dev',
  'server-cloud-admin',
  'cybersecurity-ops'
]);

const VALID_METHODS = new Set([
  'ride-along',
  'TDD',
  'BDD',
  'spike-then-refactor'
]);

function sanitizeId(raw: string): string {
  return raw
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function validateInputs(inputs: ScaffoldInputs): void {
  if (!inputs.projectId || !sanitizeId(inputs.projectId)) {
    throw new Error('projectId is required and must contain alphanumerics');
  }
  if (!inputs.displayName) {
    throw new Error('displayName is required');
  }
  if (!VALID_TRACKS.has(inputs.track)) {
    throw new Error(`track must be one of: ${Array.from(VALID_TRACKS).join(', ')}`);
  }
  if (!VALID_METHODS.has(inputs.method)) {
    throw new Error(`method must be one of: ${Array.from(VALID_METHODS).join(', ')}`);
  }
}

/**
 * Pure scaffolding — does the disk work, no VS Code dependency.
 *
 * Side effects:
 *   - Creates `{workspaceRoot}/projects/{projectId}/` with a stub README.
 *   - Writes `{menteesDir}/{username}/{projectId}.progress.json`.
 *   - Adds an entry under `projects` in `{menteesDir}/{username}/profile.json`
 *     (creates the profile shell if missing).
 *
 * Idempotent on re-run: refuses to overwrite an existing project folder
 * but updates the profile index entry if it already exists.
 */
export function performScaffold(
  inputs: ScaffoldInputs,
  deps: ScaffoldDeps
): ScaffoldResult {
  validateInputs(inputs);
  const projectId = sanitizeId(inputs.projectId);

  // 1. Create project folder.
  const projectsRoot = path.join(deps.workspaceRoot, 'projects');
  const projectPath = path.join(projectsRoot, projectId);
  if (fs.existsSync(projectPath)) {
    throw new Error(`Project folder already exists: ${projectPath}`);
  }
  fs.mkdirSync(projectPath, { recursive: true });

  // 2. Stub README.
  const readmePath = path.join(projectPath, 'README.md');
  fs.writeFileSync(
    readmePath,
    `# ${inputs.displayName}\n\n` +
      `**Track:** ${inputs.track}\n` +
      `**Method:** ${inputs.method}\n` +
      `**Started:** ${deps.now()}\n\n` +
      `_Created by @Mentor. Open chat with the status bar item to continue._\n`
  );

  // 3. Profile + progress under the mentor home.
  const userDir = path.join(deps.menteesDir, deps.username);
  fs.mkdirSync(userDir, { recursive: true });

  const profilePath = path.join(userDir, 'profile.json');
  const profile = fs.existsSync(profilePath)
    ? (JSON.parse(fs.readFileSync(profilePath, 'utf8')) as Record<string, unknown>)
    : {
        name: deps.username,
        preferred_name: deps.username,
        github_username: deps.username,
        projects: {}
      };

  const projects = (profile.projects as Record<string, unknown>) ?? {};
  projects[projectId] = {
    display_name: inputs.displayName,
    track: inputs.track,
    status: 'in_progress',
    last_session: deps.now(),
    current_step: 0
  };
  profile.projects = projects;
  fs.writeFileSync(profilePath, JSON.stringify(profile, null, 2));

  const progressPath = path.join(userDir, `${projectId}.progress.json`);
  fs.writeFileSync(
    progressPath,
    JSON.stringify(
      {
        project_id: projectId,
        last_used_method: inputs.method,
        track: inputs.track,
        status: 'in_progress',
        current_step: 0,
        completed_milestones: [],
        session_history: [],
        // Event log (Phase 1 of event-log-cutover). Append-only ledger;
        // session_history above is a derived view and will be removed in
        // Phase 4. See docs/design/event-log-design.md and
        // .github/knowledge-graph/cli/append-event.ps1.
        events: []
      },
      null,
      2
    )
  );

  return { projectPath, readmePath, profilePath, progressPath };
}

/**
 * Wire `performScaffold` to real VS Code state + open the README.
 *
 * Returns a tool result the LM can echo back to the learner.
 */
async function runScaffold(inputs: ScaffoldInputs): Promise<string> {
  const folder = vscode.workspace.workspaceFolders?.[0];
  if (!folder) {
    throw new Error('Open a workspace folder first so I can create the project there.');
  }
  const result = performScaffold(inputs, {
    workspaceRoot: folder.uri.fsPath,
    menteesDir: getMenteesDir(),
    username: inputs.username ?? await getCurrentUsername(),
    now: () => new Date().toISOString().slice(0, 10)
  });

  // Open the stub README so the learner sees something immediately.
  const doc = await vscode.workspace.openTextDocument(result.readmePath);
  await vscode.window.showTextDocument(doc);

  // Profile changed — re-render status bar so it flips to Resume state.
  void refreshStatusBar();

  return (
    `Scaffolded **${inputs.displayName}** at \`${result.projectPath}\`.\n\n` +
    `Track: \`${inputs.track}\` · Method: \`${inputs.method}\``
  );
}

/**
 * Register the LM tool. Requires a matching declaration in package.json
 * under `contributes.languageModelTools` — added in step 17.
 */
export function registerScaffoldAndOpenTool(
  context: vscode.ExtensionContext
): void {
  context.subscriptions.push(
    vscode.lm.registerTool<ScaffoldInputs>(SCAFFOLD_AND_OPEN_TOOL, {
      async invoke(options, _token) {
        const message = await runScaffold(options.input);
        return new vscode.LanguageModelToolResult([
          new vscode.LanguageModelTextPart(message)
        ]);
      }
    })
  );
}
