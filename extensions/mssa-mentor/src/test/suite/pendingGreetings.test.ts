import * as assert from 'assert';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { writePendingGreeting, consumePendingGreeting } from '../../pendingGreetings';

suite('pendingGreetings.ts', () => {
  let tmp: string;
  let savedHome: string | undefined;

  setup(() => {
    savedHome = process.env.MSSA_MENTOR_HOME;
    tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'mssa-greet-'));
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

  test('returns null when sentinel does not exist', () => {
    assert.strictEqual(consumePendingGreeting(), null);
  });

  test('write -> consume returns the payload and deletes the file', () => {
    writePendingGreeting({ query: 'hi' });
    const got = consumePendingGreeting();
    assert.ok(got);
    assert.strictEqual(got!.query, 'hi');
    // Sentinel must be deleted after consume.
    assert.strictEqual(consumePendingGreeting(), null);
  });

  test('stale greetings (older than 24h) are discarded', () => {
    writePendingGreeting({
      query: 'old',
      createdAt: new Date(Date.now() - 25 * 60 * 60 * 1000).toISOString()
    });
    assert.strictEqual(consumePendingGreeting(), null);
  });

  test('workspaceFolder scope: returns null for wrong window', () => {
    writePendingGreeting({ query: 'scoped', workspaceFolder: '/foo' });
    const got = consumePendingGreeting({ currentWorkspaceFolder: '/bar' });
    assert.strictEqual(got, null);
    // Sentinel kept for the right window.
    const got2 = consumePendingGreeting({ currentWorkspaceFolder: '/foo' });
    assert.ok(got2);
    assert.strictEqual(got2!.query, 'scoped');
  });

  test('corrupt JSON is cleared and returns null', () => {
    fs.writeFileSync(
      path.join(tmp, 'pending-greetings.json'),
      '{ not json',
      'utf8'
    );
    assert.strictEqual(consumePendingGreeting(), null);
    // Recovery: sentinel deleted.
    assert.strictEqual(
      fs.existsSync(path.join(tmp, 'pending-greetings.json')),
      false
    );
  });
});
