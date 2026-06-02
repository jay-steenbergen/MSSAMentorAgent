import * as assert from 'assert';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import {
  getMentorHome,
  getMenteesDir,
  getCurriculumDir,
  getPendingGreetingsPath,
  ensureMentorHome
} from '../../paths';

/**
 * Unit tests for paths.ts. Pure path helpers + one fs side effect.
 * Each test redirects MSSA_MENTOR_HOME to a fresh tmp dir to keep
 * the real home untouched.
 */
suite('paths.ts', () => {
  let tmp: string;
  let savedHome: string | undefined;

  setup(() => {
    savedHome = process.env.MSSA_MENTOR_HOME;
    tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'mssa-paths-'));
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

  test('getMentorHome honors MSSA_MENTOR_HOME override', () => {
    assert.strictEqual(getMentorHome(), tmp);
  });

  test('getMentorHome falls back to ~/.mssa-mentor when env unset', () => {
    delete process.env.MSSA_MENTOR_HOME;
    const expected = path.join(os.homedir(), '.mssa-mentor');
    assert.strictEqual(getMentorHome(), expected);
  });

  test('getMenteesDir composes profiles/mentees under home', () => {
    assert.strictEqual(getMenteesDir(), path.join(tmp, 'profiles', 'mentees'));
  });

  test('getCurriculumDir composes curriculum under home', () => {
    assert.strictEqual(getCurriculumDir(), path.join(tmp, 'curriculum'));
  });

  test('getPendingGreetingsPath composes pending-greetings.json under home', () => {
    assert.strictEqual(
      getPendingGreetingsPath(),
      path.join(tmp, 'pending-greetings.json')
    );
  });

  test('ensureMentorHome creates mentees + curriculum dirs', async () => {
    await ensureMentorHome();
    assert.ok(fs.existsSync(getMenteesDir()), 'mentees dir not created');
    assert.ok(fs.existsSync(getCurriculumDir()), 'curriculum dir not created');
  });

  test('ensureMentorHome is idempotent', async () => {
    await ensureMentorHome();
    await ensureMentorHome();   // must not throw
    assert.ok(fs.existsSync(getMenteesDir()));
  });
});
