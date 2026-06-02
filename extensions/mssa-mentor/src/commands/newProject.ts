import * as vscode from 'vscode';
import { openMentorChat } from '../chatOpener';
import { refreshStatusBar } from '../statusBar';

/** Explicit "start a new project" entry point. */
export const NEW_PROJECT_COMMAND = 'mssa-mentor.newProject';

/**
 * Register the new-project command.
 *
 * Opens chat with a submitted kickoff query — the Mentor agent then
 * drives track + method + project picking via its own chat pickers.
 * We deliberately do NOT show a native VS Code quick-pick wizard here;
 * the agent owns that UX so it can adapt to the learner's profile.
 *
 * Refreshes the status bar after the chat opens so any project state
 * change (e.g. the agent calls the scaffold tool) is reflected when
 * the user returns to the editor.
 */
export function registerNewProjectCommand(context: vscode.ExtensionContext): void {
  context.subscriptions.push(
    vscode.commands.registerCommand(NEW_PROJECT_COMMAND, async () => {
      await openMentorChat({
        query: "I want to start a new project — walk me through picking one.",
        isPartialQuery: false
      });
      void refreshStatusBar();
    })
  );
}
