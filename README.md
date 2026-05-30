# MSSA Mentor Agent

This repository builds a custom GitHub Copilot agent that teaches software engineering to veterans transitioning through the Microsoft Software & Systems Academy (MSSA).

---

## For Learners

**Use `@Mentor` in Copilot Chat.**

That's it. The Mentor will:
- Learn your style through a short interview
- Build real code alongside you (you stay at the keyboard)
- Use analogies from your military background
- Track your progress across projects

See [docs/MENTOR_DIRECTORY.md](docs/MENTOR_DIRECTORY.md) for how the system works.

---

## For Contributors

You're building this system. Here's the architecture:

### Core Concepts

| Concept | What it is | Example |
|---|---|---|
| **Agent** | Personality + orchestration | `Mentor.agent.md` — teaches, celebrates, uses MOS analogies |
| **Skill** | Reusable protocol (portable) | `learner-profile`, `TDD`, `BDD` — how to do something |
| **Track** | What to build (curriculum) | `cloud-app-dev`, `server-cloud-admin` — MSSA tracks |
| **Profile** | Learner identity + progress | `.profiles/mentees/{username}/` — Git-tracked state |
| **Method** | How to teach | `ride-along`, `TDD`, `BDD` — pedagogy approach |

**Key principle:** Agents compose skills. Skills are portable. Profiles persist in Git.

---

### File Organization

```
.github/
├── agents/                    Agent personas
│   └── Mentor.agent.md       MSSA Mentor (composes skills)
│
├── skills/                    Reusable protocols
│   ├── learner-profile/      Profile CRUD + interview
│   ├── references/           Reference data (MOS mappings, proficiency levels)
│   └── methods/              Teaching methods
│       ├── ride-along/       Default: build together, explain as we go
│       ├── TDD/              Test-first workflow
│       ├── BDD/              Behavior-driven development
│       └── spike-then-refactor/  Explore, then clean up
│
└── tests/                     Integration tests
    ├── TEST_TEMPLATE.md       Template for new tests
    ├── session-flow.test.md
    ├── method-switching.test.md
    └── compression-resilience.test.md

.profiles/
└── profiles/
    ├── mentees/              Learner data
    │   └── {username}/
    │       ├── profile.json           Identity + projects index
    │       └── {project-id}.progress.json  Per-project progress
    └── mentors/              Developer/tester profiles
        └── {username}/
            └── profile.json

docs/
├── MENTOR_DIRECTORY.md       System map (start here)
├── CONTRIBUTOR_GUIDE.md      How to add skills/tracks/tests
├── TESTING_GUIDE.md          How to run and write tests
└── ARCHITECTURE.md           Design decisions
```

---

## Design Philosophy

**For the learner:**
- Teach by building real code alongside them
- Never dump finished solutions
- Celebrate small wins loudly
- Use their military background for analogies

**For the contributor:**
- Everything in Git (no external state)
- Portable skills (reusable across agents)
- Fail gracefully (validate before load, fall back to defaults)
- Test via real scenarios (behavioral tests, not unit tests)

## Out of scope

- A web app, RAG pipeline, or hosted service — this ships as a Copilot customization, period.
- Generating MSSA curriculum from scratch — Microsoft Learn and the MSSA program own the curriculum; we mentor *on top of it*.

**Team projects:**
- Multiple learners can work in the same repo
- Each has their own profile and progress tracking
- The mentor coordinates handoffs when one learner finishes work another depends on

## Status

Early development. The mentor persona, pedagogy, and profile system are working. Cohort-specific lesson scaffolds are next.

<!-- Test auto-fix -->

