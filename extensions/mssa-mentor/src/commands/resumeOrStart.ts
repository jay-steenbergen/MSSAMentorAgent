import * as vscode from 'vscode';
import { openMentorChat } from '../chatOpener';
import { getCurrentLearnerContext, LearnerContext } from '../profileReader';
import { refreshStatusBar } from '../statusBar';

/** Smart entry-point command — routes by profile state. */
export const RESUME_OR_START_COMMAND = 'mssa-mentor.resumeOrStart';

/**
 * Pick the kickoff prompt based on the learner's current state.
 *
 * When a profile exists, the prompt explicitly names the learner and
 * (if known) the active project — this is what gets the @Mentor agent
 * to greet by name on turn 1 instead of opening with a generic "hello".
 *
 * Exported separately so it can be unit-tested without registering
 * a real vscode command.
 */
export function pickResumePrompt(ctx: LearnerContext | null): string {
  // The seed is an *instruction* to the agent, not a literal greeting.
  // The agent reads `military.branch` and `military.mos` from the attached
  // profile and mints a fresh joke each turn — that's where the
  // never-repeats variability lives. See `humor-serves-mission` and
  // `personality:instructor-buddy` in the graph.
  const jokeRule =
    "open with a fresh, original military joke about my branch and MOS " +
    "(read them from the attached profile) — mint a new line every time, " +
    "no scripted or recycled material";

  if (ctx === null) {
    return (
      "I'm new here. Run the first-time interview to learn my background. " +
      "Once you know my service branch and MOS, " + jokeRule + " — then " +
      "help me pick a track to start."
    );
  }
  const name = ctx.preferredName;
  if (ctx.activeProjectCount === 0) {
    return `I'm back — I'm ${name}. ${capitalize(jokeRule)} — then help me start a new project.`;
  }
  if (ctx.activeProjectCount === 1) {
    const project = ctx.activeProjectDisplayName ?? 'my active project';
    const track = ctx.activeTrack ? ` (${ctx.activeTrack})` : '';
    return `I'm back — I'm ${name}. ${capitalize(jokeRule)} — then resume ${project}${track}.`;
  }
  // 2+ active projects — Mentor agent will show the picker.
  return `I'm back — I'm ${name}. ${capitalize(jokeRule)} — then show me my active projects so I can pick which one to resume.`;
}

function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

/**
 * Build the list of files to attach so the agent has profile + active
 * progress in context on turn 1. Empty when no profile exists yet
 * (first-time learner — interview will create one).
 */
export function pickAttachFiles(ctx: LearnerContext | null): vscode.Uri[] {
  if (!ctx) return [];
  const files: vscode.Uri[] = [vscode.Uri.file(ctx.profilePath)];
  if (ctx.activeProgressPath) {
    files.push(vscode.Uri.file(ctx.activeProgressPath));
  }
  return files;
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
      const attachFiles = pickAttachFiles(ctx);
      await openMentorChat({ query, isPartialQuery: false, attachFiles });
      void refreshStatusBar();
    })
  );
}
