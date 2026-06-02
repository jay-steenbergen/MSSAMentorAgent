import * as path from 'path';
import * as fs from 'fs';
import type { LearnerContext } from './profileReader';
import { getCurriculumDir } from './paths';

export interface SkillFile {
  /** Absolute path on disk in the curriculum cache. */
  path: string;
  /** Repo-relative path (e.g. `.github/skills/learner-profile/SKILL.md`). */
  relPath: string;
  type: 'core' | 'method' | 'track';
  reason: string;
}

/**
 * Determine which skill files to pre-load based on learner context.
 *
 * Always loads:
 *   - learner-profile (session foundation)
 *   - last-used method (falls back to ride-along)
 *   - active track README (if any)
 *
 * Reads from the curriculum cache under `~/.mssa-mentor/curriculum/`.
 * Caller is responsible for ensuring the cache is populated
 * (fetchCurriculum) before calling this.
 */
export function getSkillsToPreload(learnerContext: LearnerContext): SkillFile[] {
  const root = getCurriculumDir();
  const skills: SkillFile[] = [];

  const tryAdd = (
    relParts: string[],
    type: SkillFile['type'],
    reason: string
  ): boolean => {
    const relPath = relParts.join('/');
    const abs = path.join(root, ...relParts);
    if (fs.existsSync(abs)) {
      skills.push({ path: abs, relPath, type, reason });
      return true;
    }
    return false;
  };

  // 1. Learner profile skill — session foundation.
  tryAdd(
    ['.github', 'skills', 'learner-profile', 'SKILL.md'],
    'core',
    'Session foundation - learner identity and preferences'
  );

  // 2. Last-used method, fall back to ride-along.
  const method = learnerContext.lastUsedMethod || 'ride-along';
  const methodLoaded = tryAdd(
    ['.github', 'skills', 'methods', method, 'SKILL.md'],
    'method',
    `Last-used teaching method: ${method}`
  );
  if (!methodLoaded && method !== 'ride-along') {
    tryAdd(
      ['.github', 'skills', 'methods', 'ride-along', 'SKILL.md'],
      'method',
      'Default method: ride-along'
    );
  }

  // 3. Active track README.
  if (learnerContext.activeTrack) {
    tryAdd(
      ['.github', 'skills', 'tracks', learnerContext.activeTrack, 'README.md'],
      'track',
      `Active track: ${learnerContext.activeTrack}`
    );
  }

  return skills;
}

/**
 * Read a skill file by absolute path. Returns null on failure.
 */
export function readSkillFile(skillPath: string): string | null {
  try {
    return fs.readFileSync(skillPath, 'utf8');
  } catch (error) {
    console.error(`[MentorContext] Error reading skill file ${skillPath}:`, error);
    return null;
  }
}
