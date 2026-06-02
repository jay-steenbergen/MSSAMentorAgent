import * as fs from 'fs';
import { getPendingGreetingsPath } from './paths';

/**
 * Cross-window handoff payload.
 *
 * Written by the agent tool that scaffolds a new project and opens it
 * in a fresh VS Code window. Consumed by the extension's activation
 * code in that fresh window so it can re-open chat with @Mentor and
 * pick up the conversation.
 */
export interface PendingGreeting {
  /** Prompt to seed `@Mentor` with on activation. */
  query: string;
  /** ISO timestamp the sentinel was written. */
  createdAt: string;
  /**
   * Optional workspace scope: when set, only consume the greeting if
   * the active VS Code window's first workspace folder matches this
   * path. Prevents a stale greeting from triggering in unrelated
   * windows.
   */
  workspaceFolder?: string;
}

/** Discard greetings older than this. */
const MAX_AGE_MS = 24 * 60 * 60 * 1000;

/**
 * Persist a pending greeting. Overwrites any existing one — only the
 * most recent handoff matters.
 */
export function writePendingGreeting(payload: Omit<PendingGreeting, 'createdAt'> & { createdAt?: string }): void {
  const full: PendingGreeting = {
    createdAt: payload.createdAt ?? new Date().toISOString(),
    query: payload.query,
    workspaceFolder: payload.workspaceFolder
  };
  fs.writeFileSync(getPendingGreetingsPath(), JSON.stringify(full, null, 2), 'utf8');
}

/**
 * Read and delete the pending greeting if one exists and is valid.
 *
 * Returns null when:
 *   - the sentinel does not exist
 *   - the JSON is unparseable (sentinel is also deleted to recover)
 *   - the greeting is older than MAX_AGE_MS (deleted as stale)
 *   - a `workspaceFolder` scope is set and the active window's first
 *     folder does not match (sentinel kept — wrong window)
 */
export function consumePendingGreeting(opts: {
  currentWorkspaceFolder?: string;
  now?: number;
} = {}): PendingGreeting | null {
  const sentinelPath = getPendingGreetingsPath();
  if (!fs.existsSync(sentinelPath)) return null;

  let payload: PendingGreeting;
  try {
    payload = JSON.parse(fs.readFileSync(sentinelPath, 'utf8')) as PendingGreeting;
  } catch {
    // Corrupt — clear it so we don't keep tripping.
    try { fs.unlinkSync(sentinelPath); } catch { /* ignore */ }
    return null;
  }

  // Stale check.
  const now = opts.now ?? Date.now();
  const createdMs = Date.parse(payload.createdAt);
  if (isNaN(createdMs) || now - createdMs > MAX_AGE_MS) {
    try { fs.unlinkSync(sentinelPath); } catch { /* ignore */ }
    return null;
  }

  // Workspace scope check — leave sentinel in place when the active
  // window isn't the intended target; the right window will pick it up.
  if (payload.workspaceFolder && payload.workspaceFolder !== opts.currentWorkspaceFolder) {
    return null;
  }

  // Consume it.
  try { fs.unlinkSync(sentinelPath); } catch { /* ignore */ }
  return payload;
}
