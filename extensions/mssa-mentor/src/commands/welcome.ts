import * as vscode from 'vscode';
import { openMentorChat } from '../chatOpener';
import { OPEN_CHAT_COMMAND, refreshStatusBar } from '../statusBar';

/** First-run / explicit welcome command. */
export const WELCOME_COMMAND = 'mssa-mentor.welcome';

/**
 * Register the entry-point commands the user can invoke.
 *
 * - `mssa-mentor.openChat` — opens chat with `@Mentor` pre-typed but
 *   not submitted. The learner decides what to say.
 * - `mssa-mentor.welcome` — first-run flow. Submits a kickoff prompt
 *   so the Mentor greets the learner without waiting for input.
 *
 * Both refresh the status bar after running so a profile change during
 * the chat session is reflected when the user returns to the editor.
 */
export function registerWelcomeCommands(context: vscode.ExtensionContext): void {
  context.subscriptions.push(
    vscode.commands.registerCommand(OPEN_CHAT_COMMAND, async () => {
      await openMentorChat();
      void refreshStatusBar();
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand(WELCOME_COMMAND, async () => {
      await openMentorChat({
        query:
          "I'm new here. Run the first-time interview to learn my background. " +
          "Once you know my service branch and MOS, open with a fresh, original " +
          "military joke about them — mint a new line every time, no scripted " +
          "or recycled material — then help me pick a track to start.",
        isPartialQuery: false
      });
      void refreshStatusBar();
    })
  );
}
