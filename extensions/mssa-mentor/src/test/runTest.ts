import * as path from 'path';
import { runTests } from '@vscode/test-electron';

/**
 * Entry point for the test runner. Downloads (or reuses) a VS Code
 * instance, points it at the compiled extension, and tells it which
 * test suite to load.
 *
 * Uses VS Code Insiders by default — Insiders has its own Inno Setup
 * mutex namespace, so test runs never collide with the developer's
 * daily-driver stable install (which would otherwise block startup
 * if an installer/update is mid-flight).
 */
async function main(): Promise<void> {
  try {
    const extensionDevelopmentPath = path.resolve(__dirname, '../../');
    const extensionTestsPath = path.resolve(__dirname, './suite/index');

    await runTests({
      version: 'insiders',
      extensionDevelopmentPath,
      extensionTestsPath,
      // Disable other extensions to keep test runs hermetic.
      launchArgs: ['--disable-extensions']
    });
  } catch (err) {
    console.error('Failed to run tests', err);
    process.exit(1);
  }
}

main();
