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
    isPartialQuery: opts.isPartialQuery !== false
  });
}
