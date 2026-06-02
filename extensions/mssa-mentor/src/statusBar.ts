import * as vscode from 'vscode';
import {
  StatusBarConfig,
  DEFAULT_STATUS_BAR_CONFIG,
  loadStatusBarState
} from './statusBarState';

/**
 * Default command — used as a fallback constant for places that need
 * "the dumb open chat command" (e.g. keybindings).
 *
 * The actual command bound to the status bar item is dynamic — see
 * `applyConfig` below.
 */
export const OPEN_CHAT_COMMAND = 'mssa-mentor.openChat';

let item: vscode.StatusBarItem | undefined;
let outputChannel: vscode.OutputChannel | undefined;

function applyConfig(target: vscode.StatusBarItem, cfg: StatusBarConfig): void {
  target.text = cfg.text;
  target.tooltip = cfg.tooltip;
  target.command = cfg.command;
}

/**
 * Create the persistent status bar item and wire it up.
 *
 * - Starts with a safe default so the bar appears instantly.
 * - Kicks off an async `loadStatusBarState()` to set the real state.
 * - Listens to window-focus changes — when the user returns to VS Code
 *   we re-read the profile in case a previous chat updated it.
 */
export function createStatusBar(
  context: vscode.ExtensionContext,
  out?: vscode.OutputChannel
): vscode.StatusBarItem {
  outputChannel = out;
  item = vscode.window.createStatusBarItem(
    vscode.StatusBarAlignment.Right,
    100
  );
  applyConfig(item, DEFAULT_STATUS_BAR_CONFIG);
  item.show();
  context.subscriptions.push(item);

  // Auto-refresh when the window regains focus (cheap, no watcher needed).
  context.subscriptions.push(
    vscode.window.onDidChangeWindowState((s) => {
      if (s.focused) {
        void refreshStatusBar();
      }
    })
  );

  // Initial async load — set real state ASAP.
  void refreshStatusBar();

  return item;
}

/**
 * Re-compute status bar state and apply it.
 *
 * Safe to call from anywhere. Never throws — on failure, logs and
 * leaves the existing state in place.
 *
 * Callers: command handlers (after a profile-changing action),
 * window-focus listener, and the initial activation.
 */
export async function refreshStatusBar(): Promise<void> {
  if (!item) return;
  try {
    const cfg = await loadStatusBarState();
    applyConfig(item, cfg);
  } catch (err) {
    outputChannel?.appendLine(
      `[MentorContext] refreshStatusBar failed: ${err}`
    );
    // Leave previous state in place.
  }
}
