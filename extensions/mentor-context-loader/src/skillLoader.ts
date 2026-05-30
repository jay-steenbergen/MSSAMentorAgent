import * as path from 'path';
import * as fs from 'fs';
import type { LearnerContext } from './profileReader';

export interface SkillFile {
  path: string;
  type: 'core' | 'method' | 'track';
  reason: string;
}

/**
 * Determine which skill files to pre-load based on learner context.
 * 
 * Always loads:
 * - learner-profile (session foundation)
 * - Last-used method (from profile)
 * - Track README (if active project exists)
 * 
 * These are the "essentials" that make session start fast.
 * Intent-specific skills are loaded dynamically by the agent later.
 */
export function getSkillsToPreload(
  workspaceRoot: string,
  learnerContext: LearnerContext
): SkillFile[] {
  const skills: SkillFile[] = [];

  // 1. Always load learner-profile (core)
  const profileSkill = path.join(workspaceRoot, '.github', 'skills', 'learner-profile', 'SKILL.md');
  if (fs.existsSync(profileSkill)) {
    skills.push({
      path: profileSkill,
      type: 'core',
      reason: 'Session foundation - learner identity and preferences'
    });
  }

  // 2. Load last-used method
  const methodSkill = path.join(
    workspaceRoot,
    '.github',
    'skills',
    'methods',
    learnerContext.lastUsedMethod,
    'SKILL.md'
  );
  if (fs.existsSync(methodSkill)) {
    skills.push({
      path: methodSkill,
      type: 'method',
      reason: `Last-used teaching method: ${learnerContext.lastUsedMethod}`
    });
  } else {
    // Fallback to ride-along if method file not found
    const fallbackMethod = path.join(
      workspaceRoot,
      '.github',
      'skills',
      'methods',
      'ride-along',
      'SKILL.md'
    );
    if (fs.existsSync(fallbackMethod)) {
      skills.push({
        path: fallbackMethod,
        type: 'method',
        reason: 'Default method: ride-along'
      });
    }
  }

  // 3. Load track README if learner has active project
  if (learnerContext.activeTrack) {
    const trackReadme = path.join(
      workspaceRoot,
      '.github',
      'skills',
      'tracks',
      learnerContext.activeTrack,
      'README.md'
    );
    if (fs.existsSync(trackReadme)) {
      skills.push({
        path: trackReadme,
        type: 'track',
        reason: `Active track: ${learnerContext.activeTrack}`
      });
    }
  }

  return skills;
}

/**
 * Read skill file content.
 */
export function readSkillFile(skillPath: string): string | null {
  try {
    return fs.readFileSync(skillPath, 'utf8');
  } catch (error) {
    console.error(`[MentorContext] Error reading skill file ${skillPath}:`, error);
    return null;
  }
}
