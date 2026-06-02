import { getCurrentLearnerContext, LearnerContext } from './profileReader';
import { OPEN_CHAT_COMMAND } from './statusBar';
import { WELCOME_COMMAND } from './commands/welcome';
import { RESUME_OR_START_COMMAND } from './commands/resumeOrStart';

/** Visual + behavioral config for the status bar item. */
export interface StatusBarConfig {
  text: string;
  tooltip: string;
  command: string;
}

/** Safe default — used when we have no profile signal yet or computation fails. */
export const DEFAULT_STATUS_BAR_CONFIG: StatusBarConfig = {
  text: '$(mortar-board) MSSA Mentor',
  tooltip: 'Open MSSA Mentor chat',
  command: OPEN_CHAT_COMMAND
};

/**
 * Compute the status bar visual state from learner context.
 *
 * Pure function — no fs, no vscode. Trivially unit-testable.
 *
 * | Input                          | text                              | command                       |
 * |--------------------------------|-----------------------------------|-------------------------------|
 * | null (no profile)              | Start MSSA Mentor                 | mssa-mentor.welcome           |
 * | activeProjectCount === 0       | MSSA Mentor                       | mssa-mentor.openChat          |
 * | activeProjectCount >= 1        | Resume MSSA Mentor                | mssa-mentor.resumeOrStart     |
 */
export function computeStatusBarState(ctx: LearnerContext | null): StatusBarConfig {
  if (ctx === null) {
    return {
      text: '$(mortar-board) Start MSSA Mentor',
      tooltip: 'Start your MSSA mentor onboarding',
      command: WELCOME_COMMAND
    };
  }
  if (ctx.activeProjectCount === 0) {
    return {
      text: '$(mortar-board) MSSA Mentor',
      tooltip: 'Open MSSA Mentor chat',
      command: OPEN_CHAT_COMMAND
    };
  }
  return {
    text: '$(debug-continue) Resume MSSA Mentor',
    tooltip: 'Resume your active project',
    command: RESUME_OR_START_COMMAND
  };
}

/**
 * Async wrapper: load learner context and compute state.
 *
 * Falls back to DEFAULT_STATUS_BAR_CONFIG on any error so the status
 * bar can never be left in a broken state by a profile read failure.
 */
export async function loadStatusBarState(): Promise<StatusBarConfig> {
  try {
    const ctx = await getCurrentLearnerContext();
    return computeStatusBarState(ctx);
  } catch {
    return DEFAULT_STATUS_BAR_CONFIG;
  }
}
