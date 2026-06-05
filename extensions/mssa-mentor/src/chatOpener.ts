import * as vscode from 'vscode';

/**
 * Options for opening the chat panel targeted at @Mentor.
 */
export interface OpenMentorChatOptions {
  /**
   * Free-form prompt to seed the chat input. The `@Mentor` mention is
   * prepended automatically — pass only the user-visible text.
   *
   * Empty string opens the chat with just `@Mentor ` ready to type.
   */
  query?: string;

  /**
   * Submit the prompt automatically instead of just placing it in the
   * input box. Use sparingly — the welcome flow places, the resume
   * flow may submit so the conversation starts immediately.
   */
  isPartialQuery?: boolean;

  /**
   * File URIs to attach as first-class chat context (the same surface
   * the user sees when they drag a file onto the chat input). Wired
   * through to `workbench.action.chat.open`'s `attachFiles` option.
   *
   * Use this to put the learner's profile.json + active progress file
   * into the agent's context on the very first turn so it can greet
   * by name and resume without a tool round-trip.
   */
  attachFiles?: vscode.Uri[];
}

/**
 * Open the VS Code Chat panel with @Mentor preselected.
 *
 * Thin wrapper around `workbench.action.chat.open` so callers don't
 * have to remember the command name or argument shape.
 */
export async function openMentorChat(
  opts: OpenMentorChatOptions = {}
): Promise<void> {
  const prefix = '@Mentor';
  const tail = opts.query ? ` ${opts.query}` : ' ';
  const query = `${prefix}${tail}`;

  await vscode.commands.executeCommand('workbench.action.chat.open', {
    query,
    isPartialQuery: opts.isPartialQuery !== false,
    attachFiles: opts.attachFiles
  });
}
