import * as fs from 'fs';
import * as path from 'path';

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
  profilePath: string;
}

/**
 * Find learner profile by GitHub username or email.
 * Searches .profiles/profiles/mentees/ directory.
 */
export async function findLearnerProfile(
  workspaceRoot: string,
  identifier?: string
): Promise<LearnerContext | null> {
  const profilesDir = path.join(workspaceRoot, '.profiles', 'profiles', 'mentees');
  
  if (!fs.existsSync(profilesDir)) {
    console.log('[MentorContext] Profiles directory not found:', profilesDir);
    return null;
  }

  // If no identifier, try to find the most recent profile
  const userDirs = fs.readdirSync(profilesDir);
  if (userDirs.length === 0) {
    return null;
  }

  // For MVP: use first profile found (in production, would match to VS Code user)
  const username = identifier || userDirs[0];
  const profilePath = path.join(profilesDir, username, 'profile.json');

  if (!fs.existsSync(profilePath)) {
    console.log('[MentorContext] Profile not found:', profilePath);
    return null;
  }

  try {
    const profileData = JSON.parse(fs.readFileSync(profilePath, 'utf8')) as LearnerProfile;
    
    // Find most recently active project
    let lastUsedMethod = 'ride-along'; // default
    let activeTrack: string | undefined;
    let mostRecentDate = '';

    for (const [projectId, project] of Object.entries(profileData.projects)) {
      if (project.status === 'in_progress') {
        const projectDate = project.last_session || '';
        if (projectDate > mostRecentDate) {
          mostRecentDate = projectDate;
          activeTrack = project.track;

          // Try to read progress file for method
          const progressPath = path.join(path.dirname(profilePath), `${projectId}.progress.json`);
          if (fs.existsSync(progressPath)) {
            const progressData = JSON.parse(fs.readFileSync(progressPath, 'utf8')) as ProgressFile;
            lastUsedMethod = progressData.last_used_method || 'ride-along';
          }
        }
      }
    }

    return {
      username: profileData.github_username,
      lastUsedMethod,
      activeTrack,
      profilePath
    };
  } catch (error) {
    console.error('[MentorContext] Error reading profile:', error);
    return null;
  }
}

/**
 * Get learner context for the current VS Code user.
 * In MVP, returns first available profile.
 */
export async function getCurrentLearnerContext(
  workspaceRoot: string
): Promise<LearnerContext | null> {
  return findLearnerProfile(workspaceRoot);
}
