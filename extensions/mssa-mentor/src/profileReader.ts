import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { execFileSync } from 'child_process';
import * as vscode from 'vscode';
import { getMenteesDir } from './paths';

export interface LearnerProfile {
  name: string;
  preferred_name: string;
  github_username: string;
  projects: {
    [key: string]: {
      display_name: string;
      track: string;
      status: 'in_progress' | 'completed';
      last_session?: string;
      completed_at?: string;
      current_step?: number;
    };
  };
}

export interface ProgressFile {
  project_id: string;
  last_used_method: string;
  track: string;
  status: string;
}

export interface LearnerContext {
  username: string;
  lastUsedMethod: string;
  activeTrack?: string;
  activeProjectCount: number;
  profilePath: string;
}

/**
 * Sanitize a name for use as a folder name. Lowercase, alphanumerics
 * and dashes only, collapse runs of dashes, trim.
 */
function sanitizeUsername(raw: string): string {
  return raw
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

/**
 * Best-effort identification of the current user's profile folder name.
 *
 * Order (per protocol:identify-learner in the knowledge graph):
 *   1. VS Code GitHub auth session (silent, never prompts).
 *      The signed-in Copilot account is the source of truth.
 *   2. `git config --global user.name` (sanitized) — fallback for
 *      environments without an active GitHub auth session (CI, tests).
 *   3. OS username (sanitized) — last-resort fallback so a folder name
 *      is always produced.
 *
 * Never prompts the user. Returns a sanitized identifier suitable for
 * use as a directory name under ~/.mssa-mentor/profiles/mentees/.
 */
export async function getCurrentUsername(): Promise<string> {
  // 1. VS Code GitHub authentication provider — silent.
  //    `silent: true` + `createIfNone: false` guarantees no UI prompt.
  //    Wrapped in try/catch because the API may not be available in
  //    every host (e.g. extension host smoke tests without the GitHub
  //    auth provider registered).
  try {
    const session = await vscode.authentication.getSession(
      'github',
      [],
      { silent: true, createIfNone: false }
    );
    if (session?.account.label) {
      return sanitizeUsername(session.account.label);
    }
  } catch {
    // GitHub auth provider missing or denied — fall through.
  }

  // 2. git config --global user.name
  try {
    const gitName = execFileSync('git', ['config', '--global', 'user.name'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore']
    }).trim();
    if (gitName) {
      return sanitizeUsername(gitName);
    }
  } catch {
    // git not installed or no global user.name configured — fall through
  }

  // 3. OS username — last resort.
  return sanitizeUsername(os.userInfo().username);
}

/**
 * Load a learner profile by username.
 *
 * Strict identity match: the sanitized identifier (or the current
 * user's git/OS name) MUST match an existing folder under
 * ~/.mssa-mentor/profiles/mentees/. No fallback to "the only profile
 * on the machine" — that silently adopts whoever's folder happens to
 * be there (e.g. a stray test_user fixture) and is exactly what we
 * do NOT want.
 *
 * Returns null when no matching profile exists (signals first-time
 * learner — caller MUST trigger the interview, not pick a stranger).
 */
export async function findLearnerProfile(
  identifier?: string
): Promise<LearnerContext | null> {
  const profilesDir = getMenteesDir();

  if (!fs.existsSync(profilesDir)) {
    return null;
  }

  const userDirs = fs
    .readdirSync(profilesDir, { withFileTypes: true })
    .filter(d => d.isDirectory())
    .map(d => d.name);

  if (userDirs.length === 0) {
    return null;
  }

  // Resolve which folder to load — strict match only.
  const lookup = identifier ?? await getCurrentUsername();
  const username = userDirs.includes(lookup) ? lookup : undefined;

  if (!username) {
    return null;
  }

  const profilePath = path.join(profilesDir, username, 'profile.json');
  if (!fs.existsSync(profilePath)) {
    return null;
  }

  try {
    const profileData = JSON.parse(
      fs.readFileSync(profilePath, 'utf8')
    ) as LearnerProfile;

    // Find the most recently active project and its method.
    let lastUsedMethod = 'ride-along';
    let activeTrack: string | undefined;
    let mostRecentDate = '';
    let activeProjectCount = 0;

    for (const [projectId, project] of Object.entries(profileData.projects ?? {})) {
      if (project.status !== 'in_progress') continue;
      activeProjectCount += 1;
      const projectDate = project.last_session ?? '';
      if (projectDate <= mostRecentDate) continue;

      mostRecentDate = projectDate;
      activeTrack = project.track;

      const progressPath = path.join(
        path.dirname(profilePath),
        `${projectId}.progress.json`
      );
      if (fs.existsSync(progressPath)) {
        const progressData = JSON.parse(
          fs.readFileSync(progressPath, 'utf8')
        ) as ProgressFile;
        lastUsedMethod = progressData.last_used_method || 'ride-along';
      }
    }

    return {
      username: profileData.github_username || username,
      lastUsedMethod,
      activeTrack,
      activeProjectCount,
      profilePath
    };
  } catch (error) {
    console.error('[MentorContext] Error reading profile:', error);
    return null;
  }
}

/**
 * Load the current user's learner context from ~/.mssa-mentor/.
 *
 * Returns null on first run — caller should kick off the interview.
 */
export async function getCurrentLearnerContext(): Promise<LearnerContext | null> {
  return findLearnerProfile();
}
