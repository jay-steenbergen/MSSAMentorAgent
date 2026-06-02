# Change Log

All notable changes to the MSSA Mentor extension are documented in this file.

## [0.1.0] — Initial release

- `@Mentor` chat participant with smart context loading — pre-loads the learner profile, last-used teaching method, and active track skill before each session.
- Status bar entry point that adapts to the learner's state:
  - **Start MSSA Mentor** — first-time learner, runs the onboarding interview.
  - **MSSA Mentor** — profile exists but no active project.
  - **Resume MSSA Mentor** — picks up the active project where you left off.
- Four commands available from the command palette under the **MSSA Mentor** category:
  - Open Chat
  - Welcome / Get Started
  - Resume or Start
  - New Project
- `mssa_scaffoldAndOpen` language model tool — the agent invokes this to create a project folder, stub README, profile entry, and progress file in one step.
- Auto-fetches the MSSA curriculum (skills, tracks, methods) into `~/.mssa-mentor/curriculum/` so the agent always has the latest content without reinstalling the extension.
- PowerShell 7+ check at activation (required by the knowledge-graph CLIs).
