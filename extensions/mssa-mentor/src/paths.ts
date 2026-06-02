import * as os from 'os';
import * as path from 'path';
import { promises as fs } from 'fs';

/**
 * Returns the MSSA Mentor home directory.
 *
 * Default: ~/.mssa-mentor/. Honors a pre-existing MSSA_MENTOR_HOME
 * env var so developers (and tests) can redirect the entire tree
 * without touching real learner data.
 *
 * This is where learner profiles, progress files, fetched curriculum,
 * and runtime sentinels live for mentees who installed the extension
 * from the Marketplace.
 */
export function getMentorHome(): string {
  return process.env.MSSA_MENTOR_HOME ?? path.join(os.homedir(), '.mssa-mentor');
}

/**
 * Returns the directory that holds per-learner profile + progress files.
 * Mirrors the layout used by session-protocol.ps1 when MSSA_MENTOR_HOME is set:
 *   {MSSA_MENTOR_HOME}/profiles/mentees/{username}/profile.json
 *   {MSSA_MENTOR_HOME}/profiles/mentees/{username}/{project-id}.progress.json
 */
export function getMenteesDir(): string {
  return path.join(getMentorHome(), 'profiles', 'mentees');
}

/**
 * Returns the directory where fetched curriculum (skills + tracks) is cached.
 */
export function getCurriculumDir(): string {
  return path.join(getMentorHome(), 'curriculum');
}

/**
 * Returns the path to the cross-window pending-greetings sentinel file.
 * (Created on demand; not pre-created by ensureMentorHome.)
 */
export function getPendingGreetingsPath(): string {
  return path.join(getMentorHome(), 'pending-greetings.json');
}

/**
 * Ensures the mentor home directory tree exists.
 *
 * Idempotent — safe to call on every activation. Creates:
 *   ~/.mssa-mentor/
 *   ~/.mssa-mentor/profiles/mentees/
 *   ~/.mssa-mentor/curriculum/
 */
export async function ensureMentorHome(): Promise<void> {
  await fs.mkdir(getMenteesDir(), { recursive: true });
  await fs.mkdir(getCurriculumDir(), { recursive: true });
}
