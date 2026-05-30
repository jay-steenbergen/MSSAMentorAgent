# .profiles/ Directory Guide

When you work with the MSSA Mentor agent in a project, the mentor creates a `.profiles/` directory to track learner profiles and progress. This directory is committed to Git so your progress travels with the project.

## Directory Structure

```
your-project/
├── .profiles/
│   ├── mentees/
│   │   ├── your_username.json    ← Your profile and progress
│   │   ├── teammate.json         ← Teammate's profile (if team project)
│   │   └── ...
│   └── project.json               ← Optional: shared project state
├── src/                           ← Your code
└── .git/                          ← Git repository
```

## Your Profile (`mentees/{username}.json`)

This file contains:

- **Learning preferences**: How you like to learn, what pace works for you, what you do when stuck
- **Motivation**: What makes this feel worth doing
- **Progress tracking**: Which project you're on, which step, what milestones you've completed
- **Session history**: Log of your sessions for retrospectives

The mentor reads this at the start of every session and adapts its teaching to your style.

## How Progress Tracking Works

1. **First session**: Mentor interviews you (5 minutes), creates your profile, commits it
2. **Every session**: Mentor loads your profile, greets you by name, offers to continue where you left off
3. **After each milestone**: Mentor updates your progress and commits automatically
4. **Pull before you start**: If you're on a team project, pull first to see teammates' progress

## Team Projects

If multiple people work in the same repo:

- Each person has their own profile in `.profiles/mentees/`
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

1. Open `.profiles/mentees/{your-username}.json`
2. Change any field (pace preference, motivation, etc.)
3. Commit the change
4. Next session, the mentor will use the updated preferences

Or just tell the mentor: *"I want faster pacing now"* and it will update the file for you.

## Deleting Your Profile

If you want to start fresh or remove your profile:

1. Delete `.profiles/mentees/{your-username}.json`
2. Commit the deletion
3. Next session, the mentor will run the first-time interview again

Your code and Git history are unaffected — only the profile is removed.

## Questions?

Ask the mentor: *"Tell me about the profile system."*
