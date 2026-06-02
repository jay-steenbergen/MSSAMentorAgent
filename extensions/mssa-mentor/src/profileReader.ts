import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { execFileSync } from 'child_process';
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
 * Best-effort guess at the current user's profile folder name.
 *
 * Order:
 *   1. `git config --global user.name` (sanitized)
 *   2. OS username (sanitized)
 *
 * Used as the lookup key into ~/.mssa-mentor/profiles/mentees/.
 */
export function getCurrentUsername(): string {
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
  return sanitizeUsername(os.userInfo().username);
}

/**
 * Load a learner profile by username.
 *
 * Falls back to the only profile in ~/.mssa-mentor/profiles/mentees/
 * when an explicit lookup misses — handy when git user.name doesn't
 * match the folder name but the machine only has one learner.
 *
 * Returns null when no profile exists (signals first-time learner —
 * caller should trigger the interview).
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

  // Resolve which folder to load.
  const lookup = identifier ?? getCurrentUsername();
  let username: string | undefined;
  if (userDirs.includes(lookup)) {
    username = lookup;
  } else if (userDirs.length === 1) {
    // Single-user-on-machine fallback.
    username = userDirs[0];
  }

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
