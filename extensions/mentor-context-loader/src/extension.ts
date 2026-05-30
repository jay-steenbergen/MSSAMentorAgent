import * as vscode from 'vscode';
import { getCurrentLearnerContext } from './profileReader';
import { getSkillsToPreload, readSkillFile } from './skillLoader';

let outputChannel: vscode.OutputChannel;

/**
 * Extension activation - called when @Mentor is first invoked.
 */
export function activate(context: vscode.ExtensionContext) {
  outputChannel = vscode.window.createOutputChannel('Mentor Context Loader');
  outputChannel.appendLine('[MentorContext] Extension activated');

  // Register chat participant handler
  const participant = vscode.chat.createChatParticipant('Mentor', async (request, chatContext, stream, token) => {
    outputChannel.appendLine('[MentorContext] @Mentor invoked');

    // Get workspace root
    const workspaceRoot = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    if (!workspaceRoot) {
      outputChannel.appendLine('[MentorContext] No workspace folder found');
      stream.markdown('⚠️ Please open the MSSAMentorAgent workspace folder.\n\n');
      return;
    }

    // Pre-load skills if this is a new session
    if (!chatContext.history || chatContext.history.length === 0) {
      await preloadSkillsForSession(workspaceRoot, stream);
    }

    // Let the main @Mentor agent handle the actual request
    // (This extension only pre-loads context, doesn't respond)
  });

  context.subscriptions.push(participant);
  outputChannel.appendLine('[MentorContext] Chat participant registered');
}

/**
 * Pre-load essential skills into the chat context.
 */
async function preloadSkillsForSession(
  workspaceRoot: string,
  stream: vscode.ChatResponseStream
): Promise<void> {
  try {
    outputChannel.appendLine('[MentorContext] Starting skill pre-load...');

    // 1. Get learner context
    const learnerContext = await getCurrentLearnerContext(workspaceRoot);
    if (!learnerContext) {
      outputChannel.appendLine('[MentorContext] No learner profile found - skipping pre-load');
      stream.markdown('💡 *No learner profile found. Create one with the first-time interview.*\n\n');
      return;
    }

    outputChannel.appendLine(`[MentorContext] Learner: ${learnerContext.username}`);
    outputChannel.appendLine(`[MentorContext] Method: ${learnerContext.lastUsedMethod}`);
    outputChannel.appendLine(`[MentorContext] Track: ${learnerContext.activeTrack || 'none'}`);

    // 2. Determine which skills to load
    const skillsToLoad = getSkillsToPreload(workspaceRoot, learnerContext);
    outputChannel.appendLine(`[MentorContext] Pre-loading ${skillsToLoad.length} essential skills...`);

    // 3. Load each skill file
    const loadedSkills: string[] = [];
    for (const skill of skillsToLoad) {
      const content = readSkillFile(skill.path);
      if (content) {
        // Add skill content to context
        // Note: In VS Code Chat API, we add context via the stream's reference system
        const relativePath = skill.path.replace(workspaceRoot, '').replace(/^[\\\/]/, '');
        const uri = vscode.Uri.file(skill.path);
        
        // Add as reference (this makes it available to the LLM)
        stream.reference(uri);
        
        loadedSkills.push(`${skill.type}: ${relativePath}`);
        outputChannel.appendLine(`[MentorContext] ✓ Loaded: ${relativePath}`);
      } else {
        outputChannel.appendLine(`[MentorContext] ✗ Failed: ${skill.path}`);
      }
    }

    // 4. Notify user what was pre-loaded
    if (loadedSkills.length > 0) {
      stream.markdown(`✨ **Pre-loaded context for ${learnerContext.username}:**\n\n`);
      for (const skill of loadedSkills) {
        stream.markdown(`- ${skill}\n`);
      }
      stream.markdown('\n*Ready to continue your learning journey!*\n\n');
    }

    outputChannel.appendLine(`[MentorContext] Pre-load complete: ${loadedSkills.length}/${skillsToLoad.length} skills loaded`);
  } catch (error) {
    outputChannel.appendLine(`[MentorContext] Error during pre-load: ${error}`);
    console.error('[MentorContext] Pre-load error:', error);
  }
}

/**
 * Extension deactivation.
 */
export function deactivate() {
  if (outputChannel) {
    outputChannel.dispose();
  }
}
