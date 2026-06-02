import { getMentorHome } from './paths';

/**
 * Sets process.env.MSSA_MENTOR_HOME for the extension host process.
 *
 * Any child process spawned by the extension (e.g. pwsh CLIs from the
 * knowledge-graph/cli/ tree) will inherit this env var, which the CLIs
 * (notably session-protocol.ps1) use to root profile + progress writes
 * at ~/.mssa-mentor/ instead of the workspace .profiles/ directory.
 *
 * If MSSA_MENTOR_HOME is already set (e.g. a developer running locally
 * who wants the workspace to win), we leave it alone — explicit beats
 * implicit.
 *
 * Idempotent. Safe to call on every activation.
 */
export function setMentorHomeEnv(): void {
  if (!process.env.MSSA_MENTOR_HOME) {
    process.env.MSSA_MENTOR_HOME = getMentorHome();
  }
}
