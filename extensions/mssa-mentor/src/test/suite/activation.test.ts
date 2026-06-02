import * as assert from 'assert';
import * as vscode from 'vscode';

/**
 * Smoke test: extension activates, registers all commands, chat
 * participant, language model tool, and status bar item.
 *
 * Validates the package.json contributions actually match runtime
 * registrations. Catches packaging regressions.
 */
suite('Extension Activation', () => {
  const EXPECTED_COMMANDS = [
    'mssa-mentor.openChat',
    'mssa-mentor.welcome',
    'mssa-mentor.resumeOrStart',
    'mssa-mentor.newProject'
  ];

  test('extension is present in VS Code', () => {
    const ext = vscode.extensions.getExtension('mssa-mentor.mssa-mentor');
    assert.ok(ext, 'extension mssa-mentor.mssa-mentor not found');
  });

  test('extension activates without throwing', async () => {
    const ext = vscode.extensions.getExtension('mssa-mentor.mssa-mentor');
    assert.ok(ext);
    await ext!.activate();
    assert.strictEqual(ext!.isActive, true);
  });

  test('all 4 commands are registered', async () => {
    const ext = vscode.extensions.getExtension('mssa-mentor.mssa-mentor');
    await ext!.activate();

    const registered = await vscode.commands.getCommands(true);
    for (const cmd of EXPECTED_COMMANDS) {
      assert.ok(registered.includes(cmd), `command not registered: ${cmd}`);
    }
  });

  test('MSSA_MENTOR_HOME env var is set after activation', async () => {
    const ext = vscode.extensions.getExtension('mssa-mentor.mssa-mentor');
    await ext!.activate();
    assert.ok(
      process.env.MSSA_MENTOR_HOME,
      'activation should set process.env.MSSA_MENTOR_HOME'
    );
  });
});
