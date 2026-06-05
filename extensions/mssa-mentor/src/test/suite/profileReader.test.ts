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
    assert.strictEqual(ctx!.preferredName, 'Alex');
    assert.strictEqual(ctx!.activeProjectCount, 0);
    assert.strictEqual(ctx!.lastUsedMethod, 'ride-along');
    assert.strictEqual(ctx!.activeProjectId, undefined);
    assert.strictEqual(ctx!.activeProjectDisplayName, undefined);
    assert.strictEqual(ctx!.activeProgressPath, undefined);
  });

  test('preferredName falls back to name then github_username', async () => {
    seedProfile(tmp, 'noprefer', {
      name: 'Pat Q',
      github_username: 'patq',
      projects: {}
    });
    const noPrefer = await findLearnerProfile('noprefer');
    assert.strictEqual(noPrefer!.preferredName, 'Pat Q');

    seedProfile(tmp, 'noname', {
      github_username: 'just-handle',
      projects: {}
    });
    const noName = await findLearnerProfile('noname');
    assert.strictEqual(noName!.preferredName, 'just-handle');
  });

  test('returns null rather than adopting the only profile on the machine', async () => {
    // Regression: previously a single-profile machine would silently
    // adopt that profile for any caller (e.g. a fresh user inherited
    // a stray test_user folder). Identity must be strict.
    seedProfile(tmp, 'only_user', {
      name: 'Only',
      preferred_name: 'Only',
      github_username: 'only',
      projects: {}
    });
    const ctx = await findLearnerProfile('nonexistent-name');
    assert.strictEqual(
      ctx,
      null,
      'must NOT silently adopt the only profile — caller has to run the interview'
    );
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
    assert.strictEqual(ctx!.activeProjectId, 'weather-api');
    assert.strictEqual(ctx!.activeProjectDisplayName, 'Weather API');
    assert.ok(ctx!.activeProgressPath, 'progress path should resolve when file exists');
    assert.ok(
      ctx!.activeProgressPath!.endsWith('weather-api.progress.json'),
      `progress path should point at the active project; got ${ctx!.activeProgressPath}`
    );
  });

  test('returns null on corrupt profile.json (no throw)', async () => {
    const dir = path.join(tmp, 'profiles', 'mentees', 'alex');
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, 'profile.json'), '{ not json', 'utf8');
    const ctx = await findLearnerProfile('alex');
    assert.strictEqual(ctx, null);
  });
});
