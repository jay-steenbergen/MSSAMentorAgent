import * as assert from 'assert';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { findLearnerProfile } from '../../profileReader';

/**
 * Write a profile.json + matching progress.json under the fake mentees dir.
 */
function seedProfile(
  home: string,
  folder: string,
  profile: object,
  progressByProjectId: Record<string, object> = {}
) {
  const dir = path.join(home, 'profiles', 'mentees', folder);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'profile.json'), JSON.stringify(profile, null, 2), 'utf8');
  for (const [id, prog] of Object.entries(progressByProjectId)) {
    fs.writeFileSync(
      path.join(dir, `${id}.progress.json`),
      JSON.stringify(prog, null, 2),
      'utf8'
    );
  }
}

suite('profileReader.ts', () => {
  let tmp: string;
  let savedHome: string | undefined;

  setup(() => {
    savedHome = process.env.MSSA_MENTOR_HOME;
    tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'mssa-prof-'));
    process.env.MSSA_MENTOR_HOME = tmp;
  });

  teardown(() => {
    if (savedHome === undefined) {
      delete process.env.MSSA_MENTOR_HOME;
    } else {
      process.env.MSSA_MENTOR_HOME = savedHome;
    }
    try { fs.rmSync(tmp, { recursive: true, force: true }); } catch { /* ignore */ }
  });

  test('returns null when no profiles directory exists', async () => {
    const ctx = await findLearnerProfile('whoever');
    assert.strictEqual(ctx, null);
  });

  test('returns null when profiles directory is empty', async () => {
    fs.mkdirSync(path.join(tmp, 'profiles', 'mentees'), { recursive: true });
    const ctx = await findLearnerProfile('whoever');
    assert.strictEqual(ctx, null);
  });

  test('loads profile by explicit identifier', async () => {
    seedProfile(tmp, 'alex', {
      name: 'Alex Smith',
      preferred_name: 'Alex',
      github_username: 'alex-smith',
      projects: {}
    });
    const ctx = await findLearnerProfile('alex');
    assert.ok(ctx);
    assert.strictEqual(ctx!.username, 'alex-smith');
    assert.strictEqual(ctx!.activeProjectCount, 0);
    assert.strictEqual(ctx!.lastUsedMethod, 'ride-along');
  });

  test('single-user-on-machine fallback when identifier does not match', async () => {
    seedProfile(tmp, 'only_user', {
      name: 'Only',
      preferred_name: 'Only',
      github_username: 'only',
      projects: {}
    });
    const ctx = await findLearnerProfile('nonexistent-name');
    assert.ok(ctx, 'expected single-user fallback to find the only profile');
    assert.strictEqual(ctx!.username, 'only');
  });

  test('returns null when multiple users and identifier matches none', async () => {
    seedProfile(tmp, 'alice', {
      name: 'Alice', preferred_name: 'Alice', github_username: 'alice', projects: {}
    });
    seedProfile(tmp, 'bob', {
      name: 'Bob', preferred_name: 'Bob', github_username: 'bob', projects: {}
    });
    const ctx = await findLearnerProfile('charlie');
    assert.strictEqual(ctx, null);
  });

  test('counts active projects and reads last-used method from progress file', async () => {
    seedProfile(
      tmp,
      'alex',
      {
        name: 'Alex',
        preferred_name: 'Alex',
        github_username: 'alex',
        projects: {
          'weather-api': {
            display_name: 'Weather API',
            track: 'cloud-app-dev',
            status: 'in_progress',
            last_session: '2026-06-01T10:00:00Z'
          },
          'old-thing': {
            display_name: 'Old', track: 'cloud-app-dev', status: 'completed'
          },
          'second-active': {
            display_name: 'Second',
            track: 'cloud-app-dev',
            status: 'in_progress',
            last_session: '2026-05-30T10:00:00Z'
          }
        }
      },
      {
        'weather-api': {
          project_id: 'weather-api',
          last_used_method: 'TDD',
          track: 'cloud-app-dev',
          status: 'in_progress'
        }
      }
    );

    const ctx = await findLearnerProfile('alex');
    assert.ok(ctx);
    assert.strictEqual(ctx!.activeProjectCount, 2);
    assert.strictEqual(ctx!.activeTrack, 'cloud-app-dev');
    // most recently active is weather-api → its TDD method wins
    assert.strictEqual(ctx!.lastUsedMethod, 'TDD');
  });

  test('returns null on corrupt profile.json (no throw)', async () => {
    const dir = path.join(tmp, 'profiles', 'mentees', 'alex');
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, 'profile.json'), '{ not json', 'utf8');
    const ctx = await findLearnerProfile('alex');
    assert.strictEqual(ctx, null);
  });
});
