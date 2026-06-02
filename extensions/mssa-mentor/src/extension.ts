import * as vscode from 'vscode';
import { getCurrentLearnerContext } from './profileReader';
import { getSkillsToPreload, readSkillFile } from './skillLoader';
import { ensureMentorHome, getMentorHome } from './paths';
import { setMentorHomeEnv } from './envSetup';
import { checkPowerShell } from './powershellCheck';
import { fetchCurriculum, hasUsableCache } from './curriculumFetch';
import { createStatusBar } from './statusBar';
import { registerWelcomeCommands } from './commands/welcome';
import { registerResumeOrStartCommand } from './commands/resumeOrStart';
import { registerNewProjectCommand } from './commands/newProject';
import { registerScaffoldAndOpenTool } from './tools/scaffoldAndOpen';

let outputChannel: vscode.OutputChannel;

/**
 * Extension activation - called when @Mentor is first invoked.
 */
export function activate(context: vscode.ExtensionContext) {
  outputChannel = vscode.window.createOutputChannel('Mentor Context Loader');
  outputChannel.appendLine('[MentorContext] Extension activated');

  // Set MSSA_MENTOR_HOME so child pwsh processes (CLIs) inherit it.
  // Honors a pre-existing value (developer override).
  setMentorHomeEnv();
  outputChannel.appendLine(`[MentorContext] MSSA_MENTOR_HOME=${process.env.MSSA_MENTOR_HOME}`);

  // Ensure ~/.mssa-mentor/ tree exists for profiles + curriculum cache.
  // Fire-and-forget — idempotent and safe to fail silently in dev workflows.
  ensureMentorHome()
    .then(() => outputChannel.appendLine(`[MentorContext] Mentor home ready: ${getMentorHome()}`))
    .catch(err => outputChannel.appendLine(`[MentorContext] ensureMentorHome failed: ${err}`));

  // Probe for PowerShell 7+ — required by the knowledge-graph CLIs.
  // Fire-and-forget; checkPowerShell shows a modal on failure.
  // Commands that shell out to pwsh should re-check before running.
  checkPowerShell(outputChannel).catch(err =>
    outputChannel.appendLine(`[MentorContext] checkPowerShell failed: ${err}`)
  );

  // Status bar entry point — visible immediately on activation.
  createStatusBar(context, outputChannel);
  outputChannel.appendLine('[MentorContext] Status bar item registered');

  // Register welcome / open-chat commands (status bar click target + first-run).
  registerWelcomeCommands(context);
  outputChannel.appendLine('[MentorContext] Welcome commands registered');

  // Register smart resume-or-start command.
  registerResumeOrStartCommand(context, outputChannel);
  outputChannel.appendLine('[MentorContext] Resume-or-start command registered');

  // Register new-project command.
  registerNewProjectCommand(context);
  outputChannel.appendLine('[MentorContext] New-project command registered');

  // Register scaffold tool the @Mentor agent invokes once track+method are chosen.
  registerScaffoldAndOpenTool(context);
  outputChannel.appendLine('[MentorContext] Scaffold-and-open LM tool registered');

  // Register chat participant handler
  const participant = vscode.chat.createChatParticipant('Mentor', async (request, chatContext, stream, token) => {
    outputChannel.appendLine('[MentorContext] @Mentor invoked');

    // Pre-load skills if this is a new session
    if (!chatContext.history || chatContext.history.length === 0) {
      await preloadSkillsForSession(stream);
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
  stream: vscode.ChatResponseStream
): Promise<void> {
  try {
    outputChannel.appendLine('[MentorContext] Starting skill pre-load...');

    // 0. Make sure the curriculum cache is present + reasonably fresh.
    try {
      const fetchResult = await fetchCurriculum();
      outputChannel.appendLine(
        `[MentorContext] Curriculum source=${fetchResult.source} fetched=${fetchResult.fetched} failed=${fetchResult.failed}`
      );
    } catch (err) {
      outputChannel.appendLine(`[MentorContext] fetchCurriculum failed: ${err}`);
      if (!hasUsableCache()) {
        stream.markdown('⚠️ *Could not download MSSA Mentor curriculum and no cached copy is available. Check your network and try again.*\n\n');
        return;
      }
    }

    // 1. Get learner context
    const learnerContext = await getCurrentLearnerContext();
    if (!learnerContext) {
      outputChannel.appendLine('[MentorContext] No learner profile found - skipping pre-load');
      stream.markdown('💡 *No learner profile found. Create one with the first-time interview.*\n\n');
      return;
    }

    outputChannel.appendLine(`[MentorContext] Learner: ${learnerContext.username}`);
    outputChannel.appendLine(`[MentorContext] Method: ${learnerContext.lastUsedMethod}`);
    outputChannel.appendLine(`[MentorContext] Track: ${learnerContext.activeTrack || 'none'}`);

    // 2. Determine which skills to load
    const skillsToLoad = getSkillsToPreload(learnerContext);
    outputChannel.appendLine(`[MentorContext] Pre-loading ${skillsToLoad.length} essential skills...`);

    // 3. Load each skill file
    const loadedSkills: string[] = [];
    for (const skill of skillsToLoad) {
      const content = readSkillFile(skill.path);
      if (content) {
        const uri = vscode.Uri.file(skill.path);
        stream.reference(uri);

        loadedSkills.push(`${skill.type}: ${skill.relPath}`);
        outputChannel.appendLine(`[MentorContext] ✓ Loaded: ${skill.relPath}`);
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
