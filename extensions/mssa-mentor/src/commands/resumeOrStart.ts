import * as vscode from 'vscode';
import { openMentorChat } from '../chatOpener';
import { getCurrentLearnerContext, LearnerContext } from '../profileReader';
import { refreshStatusBar } from '../statusBar';

/** Smart entry-point command — routes by profile state. */
export const RESUME_OR_START_COMMAND = 'mssa-mentor.resumeOrStart';

/**
 * Pick the kickoff prompt based on the learner's current state.
 *
 * Exported separately so it can be unit-tested without registering
 * a real vscode command.
 */
export function pickResumePrompt(ctx: LearnerContext | null): string {
  if (ctx === null) {
    return "I'm new here — show me around and help me pick a track to start.";
  }
  if (ctx.activeProjectCount === 0) {
    return "I'm ready to start a new project — what's available?";
  }
  if (ctx.activeProjectCount === 1) {
    return "Resume my work on my active project.";
  }
  // 2+ active projects — Mentor agent will show the picker.
  return "Pick up where I left off — I have multiple projects in flight.";
}

/**
 * Register `mssa-mentor.resumeOrStart`.
 *
 * Reads the learner profile and opens chat with `@Mentor` plus a prompt
 * tailored to their state. Auto-submits (isPartialQuery: false) so the
 * Mentor agent can immediately run its session-start flow.
 *
 * On any failure (profile read error, fs error), falls back to a plain
 * "open chat" so this command can safely be wired to the status bar.
 */
export function registerResumeOrStartCommand(
  context: vscode.ExtensionContext,
  outputChannel?: vscode.OutputChannel
): void {
  context.subscriptions.push(
    vscode.commands.registerCommand(RESUME_OR_START_COMMAND, async () => {
      let ctx: LearnerContext | null = null;
      try {
        ctx = await getCurrentLearnerContext();
      } catch (err) {
        outputChannel?.appendLine(
          `[MentorContext] resumeOrStart: profile read failed (${err}). Falling back to plain open.`
        );
        await openMentorChat();
        void refreshStatusBar();
        return;
      }

      const query = pickResumePrompt(ctx);
      await openMentorChat({ query, isPartialQuery: false });
      void refreshStatusBar();
    })
  );
}
