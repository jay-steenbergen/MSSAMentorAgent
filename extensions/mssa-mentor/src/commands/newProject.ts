import * as vscode from 'vscode';
import { openMentorChat } from '../chatOpener';
import { getCurrentLearnerContext } from '../profileReader';
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
 * When a profile already exists, the kickoff query addresses the
 * learner by name and the profile.json is attached as chat context so
 * the agent can immediately personalize the picker. First-time learners
 * fall through to a generic prompt; the agent runs the interview.
 *
 * Refreshes the status bar after the chat opens so any project state
 * change (e.g. the agent calls the scaffold tool) is reflected when
 * the user returns to the editor.
 */
export function registerNewProjectCommand(
  context: vscode.ExtensionContext,
  outputChannel?: vscode.OutputChannel
): void {
  context.subscriptions.push(
    vscode.commands.registerCommand(NEW_PROJECT_COMMAND, async () => {
      let ctx = null;
      try {
        ctx = await getCurrentLearnerContext();
      } catch (err) {
        outputChannel?.appendLine(
          `[MentorContext] newProject: profile read failed (${err}). Continuing with generic prompt.`
        );
      }

      const query = ctx
        ? `I'm back — I'm ${ctx.preferredName}. Open with a fresh, original military joke about my branch and MOS (read them from the attached profile) — mint a new line every time, no scripted or recycled material — then walk me through picking a new project.`
        : "I want to start a new project. Run the first-time interview, and once you know my service branch and MOS, open with a fresh, original military joke about them (a new line every time, no scripted or recycled material) — then walk me through picking one.";
      const attachFiles = ctx ? [vscode.Uri.file(ctx.profilePath)] : undefined;

      await openMentorChat({ query, isPartialQuery: false, attachFiles });
      void refreshStatusBar();
    })
  );
}
