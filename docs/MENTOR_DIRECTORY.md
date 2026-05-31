# .profiles/ Directory Guide

When you work with the MSSA Mentor agent in a project, the mentor creates a `.profiles/` directory to track learner profiles and progress. This directory is committed to Git so your progress travels with the project.

## Directory Structure

```
your-project/
├── .profiles/
│   └── profiles/
│       ├── mentees/                              ← Learner profiles
│       │   └── {username}/
│       │       ├── profile.json                  ← Identity + projects index
│       │       └── {project-id}.progress.json   ← Per-project progress
│       └── mentors/                              ← Contributor / tester profiles
│           └── {username}/
│               ├── profile.json
│               └── {project-id}.progress.json
├── src/                           ← Your code
└── .git/                          ← Git repository
```

## Your Profile (`profiles/mentees/{username}/profile.json`)

This file is your identity plus a projects index:

- **Learning preferences**: How you like to learn, your pace, what you do when stuck
- **Motivation**: What makes this feel worth doing
- **Military background**: MOS / Rating / AFSC and operational concepts the mentor uses for analogies
- **Projects index**: One entry per project — `last_session`, `current_step`, `status` (`in_progress` / `completed`)

The mentor reads this at the start of every session and adapts its teaching to your style.

## Per-Project Progress (`{project-id}.progress.json`)

One file per project sits beside `profile.json`. It holds the detail:

- `last_used_method` (`ride-along` / `TDD` / `BDD` / `spike-then-refactor`)
- `current_step` and `completed_milestones`
- `session_history` — log of each session for retrospectives

The mentor updates this file after every milestone and commits it.

## Mentors folder

`profiles/mentors/` follows the same shape as `mentees/` and stores profiles for people building or testing the system — not learners. You'll only see it if you're contributing to this repo.

## How Progress Tracking Works

1. **First session**: Mentor interviews you (5 minutes), creates your profile, commits it
2. **Every session**: Mentor loads your profile, greets you by name, offers to continue where you left off
3. **After each milestone**: Mentor updates your progress and commits automatically
4. **Pull before you start**: If you're on a team project, pull first to see teammates' progress

## Team Projects

If multiple people work in the same repo:

- Each person has their own folder under `.profiles/profiles/mentees/`
- The mentor can see everyone's progress
- When someone finishes work you depend on, the mentor will tell you
- Git handles merge conflicts normally — that's part of learning team development

## Privacy

Your profile contains only:
- Your name and GitHub username
- Learning preferences you shared during the interview
- Progress through the projects (which steps you completed)
- Session notes (what you worked on, how long, what was hard)

No credentials, no personal identifiable information beyond name/username.

## Editing Your Profile

You can edit your profile anytime:

1. Open `.profiles/profiles/mentees/{your-username}/profile.json`
2. Change any field (pace preference, motivation, etc.)
3. Commit the change
4. Next session, the mentor will use the updated preferences

Or just tell the mentor: *"I want faster pacing now"* and it will update the file for you.

## Deleting Your Profile

If you want to start fresh or remove your profile:

1. Delete `.profiles/profiles/mentees/{your-username}/` (the whole folder)
2. Commit the deletion
3. Next session, the mentor will run the first-time interview again

Your code and Git history are unaffected — only the profile is removed.

## Questions?

Ask the mentor: *"Tell me about the profile system."*
