import * as assert from 'assert';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { setMentorHomeEnv } from '../../envSetup';

suite('envSetup.ts', () => {
  let savedHome: string | undefined;

  setup(() => { savedHome = process.env.MSSA_MENTOR_HOME; });
  teardown(() => {
    if (savedHome === undefined) {
      delete process.env.MSSA_MENTOR_HOME;
    } else {
      process.env.MSSA_MENTOR_HOME = savedHome;
    }
  });

  test('sets MSSA_MENTOR_HOME when unset', () => {
    delete process.env.MSSA_MENTOR_HOME;
    setMentorHomeEnv();
    assert.strictEqual(
      process.env.MSSA_MENTOR_HOME,
      path.join(os.homedir(), '.mssa-mentor')
    );
  });

  test('honors pre-existing MSSA_MENTOR_HOME (explicit beats implicit)', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'mssa-env-'));
    try {
      process.env.MSSA_MENTOR_HOME = tmp;
      setMentorHomeEnv();
      assert.strictEqual(process.env.MSSA_MENTOR_HOME, tmp);
    } finally {
      try { fs.rmSync(tmp, { recursive: true, force: true }); } catch { /* ignore */ }
    }
  });

  test('is idempotent across repeated calls', () => {
    delete process.env.MSSA_MENTOR_HOME;
    setMentorHomeEnv();
    const first = process.env.MSSA_MENTOR_HOME;
    setMentorHomeEnv();
    setMentorHomeEnv();
    assert.strictEqual(process.env.MSSA_MENTOR_HOME, first);
  });
});
