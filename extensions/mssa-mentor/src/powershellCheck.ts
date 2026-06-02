import * as vscode from 'vscode';
import { execFile } from 'child_process';

const PS_INSTALL_URL = 'https://aka.ms/install-powershell';

/**
 * Result of a PowerShell 7+ probe.
 */
export interface PowerShellCheckResult {
  available: boolean;
  version?: string;
  reason?: 'not-found' | 'too-old' | 'spawn-failed';
}

/**
 * Detects whether `pwsh` (PowerShell 7+) is on PATH.
 *
 * Spawns `pwsh -NoProfile -Command $PSVersionTable.PSVersion.ToString()`.
 * Treats anything < 7 as missing — Windows PowerShell 5.1 is not enough
 * for the knowledge-graph CLIs (they `#Requires -Version 7.0`).
 */
export async function probePowerShell(): Promise<PowerShellCheckResult> {
  return new Promise(resolve => {
    execFile(
      'pwsh',
      ['-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()'],
      { timeout: 5000 },
      (err, stdout) => {
        if (err) {
          resolve({ available: false, reason: 'spawn-failed' });
          return;
        }
        const version = stdout.trim();
        const major = parseInt(version.split('.')[0], 10);
        if (isNaN(major) || major < 7) {
          resolve({ available: false, version, reason: 'too-old' });
          return;
        }
        resolve({ available: true, version });
      }
    );
  });
}

/**
 * Probes for PowerShell 7+ and, if missing, shows a modal with an
 * install link. Returns true when PS7+ is available, false otherwise.
 *
 * Idempotent enough — calling repeatedly will re-probe and re-show the
 * modal. Caller should gate on the return value.
 */
export async function checkPowerShell(
  output?: vscode.OutputChannel
): Promise<boolean> {
  const result = await probePowerShell();
  output?.appendLine(
    `[PowerShellCheck] available=${result.available} version=${result.version ?? '?'} reason=${result.reason ?? '-'}`
  );

  if (result.available) {
    return true;
  }

  const message =
    result.reason === 'too-old'
      ? `MSSA Mentor needs PowerShell 7 or newer. Found ${result.version}.`
      : 'MSSA Mentor needs PowerShell 7. The `pwsh` command was not found on your PATH.';

  const choice = await vscode.window.showErrorMessage(
    message,
    { modal: true, detail: 'Install PowerShell 7, then reload VS Code.' },
    'Open install page'
  );

  if (choice === 'Open install page') {
    vscode.env.openExternal(vscode.Uri.parse(PS_INSTALL_URL));
  }

  return false;
}
