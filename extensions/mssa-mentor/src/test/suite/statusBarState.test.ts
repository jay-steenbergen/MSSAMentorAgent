import * as assert from 'assert';
import {
  computeStatusBarState,
  DEFAULT_STATUS_BAR_CONFIG
} from '../../statusBarState';
import type { LearnerContext } from '../../profileReader';

const baseCtx = (overrides: Partial<LearnerContext> = {}): LearnerContext => ({
  username: 'alex',
  preferredName: 'Alex',
  lastUsedMethod: 'ride-along',
  activeProjectCount: 0,
  profilePath: '/fake/profile.json',
  ...overrides
});

suite('statusBarState.computeStatusBarState', () => {
  test('null context -> Start state routed to welcome', () => {
    const s = computeStatusBarState(null);
    assert.match(s.text, /Start MSSA Mentor/);
    assert.strictEqual(s.command, 'mssa-mentor.welcome');
  });

  test('zero active projects -> default open-chat state', () => {
    const s = computeStatusBarState(baseCtx({ activeProjectCount: 0 }));
    assert.strictEqual(s.text, DEFAULT_STATUS_BAR_CONFIG.text);
    assert.strictEqual(s.command, 'mssa-mentor.openChat');
  });

  test('one active project -> Resume state routed to resumeOrStart', () => {
    const s = computeStatusBarState(baseCtx({ activeProjectCount: 1 }));
    assert.match(s.text, /Resume MSSA Mentor/);
    assert.strictEqual(s.command, 'mssa-mentor.resumeOrStart');
  });

  test('many active projects -> Resume state (resumeOrStart will show picker)', () => {
    const s = computeStatusBarState(baseCtx({ activeProjectCount: 5 }));
    assert.match(s.text, /Resume MSSA Mentor/);
    assert.strictEqual(s.command, 'mssa-mentor.resumeOrStart');
  });

  test('every state has non-empty text, tooltip, and command', () => {
    const inputs: (LearnerContext | null)[] = [
      null,
      baseCtx({ activeProjectCount: 0 }),
      baseCtx({ activeProjectCount: 3 })
    ];
    for (const ctx of inputs) {
      const s = computeStatusBarState(ctx);
      assert.ok(s.text);
      assert.ok(s.tooltip);
      assert.ok(s.command);
    }
  });
});
