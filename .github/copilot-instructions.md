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

### Graph-First Analysis (read this before doing anything else)

**The knowledge graph is the source of truth. Code, agent files, skills, and design docs are derived from it — and are often stubs.** We are building the graph first, not the code.

When asked to **analyze, review, audit, or reason about** any part of the Mentor system — behaviors, rules, skills, tracks, methods, pickers, protocols, fields, CLIs, decisions, feedback loops — query the graph FIRST. Do **not** open `.agent.md` files, skill markdown, design docs, or extension source as a way to discover what the system does. Those are bodies attached to nodes. The graph is the map.

**Concrete commands (run these instead of reading files):**

```powershell
# What exists for a node, and what does it connect to?
pwsh .github/knowledge-graph/cli/inspect/query-node.ps1 "agent:mentor" -ShowEdges
pwsh .github/knowledge-graph/cli/inspect/query-node.ps1 "skill:learner-profile" -ShowEdges
pwsh .github/knowledge-graph/cli/inspect/query-node.ps1 "rule:events-are-source-of-truth" -ShowEdges

# What does a behavior actually require?
pwsh .github/knowledge-graph/cli/inspect/get-behavior.ps1 "teaching-loop"
pwsh .github/knowledge-graph/cli/inspect/get-behavior.ps1 "planning"

# What depends on this? What does it depend on?
pwsh .github/knowledge-graph/queries/Get-Dependents.ps1   -NodeId "skill:learner-profile"
pwsh .github/knowledge-graph/queries/Get-Dependencies.ps1 -NodeId "agent:mentor"

# Where does a value flow through the system?
pwsh .github/knowledge-graph/queries/Get-CallFlow.ps1 -StartNode "picker:build-options"

# Quality / drift / health
pwsh .github/knowledge-graph/cli/audit/audit-quality.ps1
pwsh .github/knowledge-graph/cli/audit/find-drift.ps1
pwsh .github/knowledge-graph/build/core/health.ps1
```

**Tag every discovery operation:**
- `[Discovery: graph]` — found via `query-node` / `get-behavior` / `Get-*` queries.
- `[Discovery: filesystem — reason: ...]` — fell back to `read_file` / `grep_search` / `file_search`. Must state why the graph couldn't answer.

**Anti-patterns (don't do these):**

| Anti-pattern | Why it's wrong | Do this instead |
|---|---|---|
| Read `Mentor.agent.md` to learn what the agent does | Frontmatter is irreducible identity; behavior lives in graph nodes | `query-node.ps1 "agent:mentor" -ShowEdges` |
| Read a skill's `SKILL.md` to understand its protocol | Markdown body is often a stub pointing back to the graph | `query-node.ps1 "skill:{name}"` + `get-behavior.ps1` |
| Read `docs/design/*.md` to discover system architecture | Design docs document *changes*; the graph holds the current state | Query the relevant nodes (`decision:*`, `rule:*`, `field:*`) |
| Grep for "where is X implemented" | Filesystem is the escape hatch, not the first move | `query-node.ps1 X -ShowEdges` then follow `implemented_by` edges |
| Open extension TypeScript to understand what the extension does | Use the code graph: `query-node.ps1 "code-file:..."` | Same |

**When the graph is genuinely insufficient** (you queried, the node doesn't exist or has no edges), surface that as a finding: "the graph has no `{node-type}:{name}` — this is either a gap to file or a stub to fill." Then fall back to filesystem with the `[Discovery: filesystem]` tag.

**Why this rule exists:** the system is designed graph-first. Reading files to understand the mentor produces analysis grounded in stubs and stale prose, not the actual current contract. Every node in the graph has typed edges that capture relationships markdown can't. Use them.

### Core Concepts

| Concept | What it is | Example |
|---|---|---|
| **Agent** | Personality + orchestration | `Mentor.agent.md` — teaches, celebrates, uses MOS analogies |
| **Skill** | Reusable protocol (portable) | `learner-profile`, `TDD`, `BDD` — how to do something |
| **Track** | What to build (curriculum) | `cloud-app-dev`, `server-cloud-admin`, `cybersecurity-ops`, `github-copilot`, `whiteboarding` |
| **Profile** | Learner/contributor identity + progress | `.profiles/profiles/mentees/{username}/` — Git-tracked state |
| **Method** | How to teach | `ride-along`, `TDD`, `BDD`, `spike-then-refactor` |

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
│   ├── knowledge-graph-management/  Graph health & queries
│   ├── references/           Reference data (MOS mappings, proficiency levels)
│   ├── methods/              Teaching methods
│   │   ├── ride-along/       Default: build together, explain as we go
│   │   ├── TDD/              Test-first workflow
│   │   ├── BDD/              Behavior-driven development
│   │   └── spike-then-refactor/  Explore, then clean up
│   └── tracks/               MSSA curriculum tracks
│       ├── cloud-app-dev/    Cloud Application Development
│       ├── server-cloud-admin/  Server & Cloud Administration
│       ├── cybersecurity-ops/   Cybersecurity Operations
│       ├── github-copilot/      GitHub Copilot fluency
│       └── whiteboarding/       Architecture & system design
│
├── knowledge-graph/           Queryable repo map (see its README)
│
└── tests/                     Integration tests
    ├── TEST_TEMPLATE.md       Template for new tests
    ├── session-flow.test.md
    ├── method-switching.test.md
    ├── compression-resilience.test.md
    └── mentor-cad-first-project.md

.profiles/
└── profiles/
    ├── mentees/              Learner data
    │   └── {username}/
    │       ├── profile.json                  Identity + projects index
    │       └── {project-id}.progress.json    Per-project progress
    └── mentors/              Contributor / tester profiles
        └── {username}/
            ├── profile.json
            └── {project-id}.progress.json

docs/
└── MENTOR_DIRECTORY.md       Profile system guide (for learners)
```

---

### How to Add New Components

#### Add a new teaching method

1. Create `.github/skills/methods/{method-name}/SKILL.md`
2. Add method to "Available methods" list in `Mentor.agent.md`
3. Create tests in `.github/skills/methods/{method-name}/tests/`
4. Validate: Session start picker should show new method

#### Add a new track

1. Create `.github/skills/tracks/{track-name}/SKILL.md`
2. Add track to "Available tracks" list in `Mentor.agent.md`
3. Validate: Track picker should show new track

#### Add a new agent

1. Create `.github/agents/{AgentName}.agent.md`
2. Follow YAML frontmatter structure (see `Mentor.agent.md`)
3. List which skills it composes in `skills:` array
4. Test invocation: `@AgentName` in Copilot Chat

#### Add a behavioral test

1. Copy `.github/tests/TEST_TEMPLATE.md`
2. Name: `{feature-under-test}.test.md`
3. Fill in: Setup, Scenario, Expected Behavior, Pass Criteria
4. Run: Paste scenario into Copilot Chat, observe behavior
5. Document result in "Actual Result" section

---

### Testing

| Test Type | Location | Run Method |
|---|---|---|
| **Integration tests** | `.github/tests/*.test.md` | Paste scenario into `@Mentor` chat |
| **Skill unit tests** | `.github/skills/{skill}/tests/*.test.md` | Paste with skill loaded |
| **Profile validation** | `.profiles/ProfileTests/` | `Invoke-Pester .profiles/ProfileTests/` |

---

### Key Design Patterns

**Pattern 1: Skills are method-agnostic**
- Track skills define WHAT to build (e.g., "Build a REST API")
- Method skills define HOW to teach (e.g., "Test-first with Red-Green-Refactor")
- Agent composes them: method + track = session

**Pattern 2: Profile = identity + index**
- `profile.json` = stable identity (name, learning style, military background, projects index)
- `{project-id}.progress.json` = detailed project progress (milestones, session history)
- Fast session start (index lookup) + rich detail (progress file)

**Pattern 3: Compression resilience**
- Essential behavior in YAML frontmatter (`core_behavior`)
- Skills self-heal: check if profile in context, re-load if missing
- Metadata doesn't compress

**Pattern 4: Validation before loading**
- Check skill file exists before loading
- Fall back to safe defaults (e.g., `ride-along` method)
- Never crash on missing files

---

### Common Tasks

**Run behavioral tests:**
```powershell
# Open Copilot Chat
# Paste test scenario from .github/tests/*.test.md
# Observe behavior
# Document result in test file
```

**Validate a profile:**
```powershell
.\.profiles\validate-profile.ps1 -Username alex_smith
```

**Create a new learner:**
- Profile created automatically on first `@Mentor` session
- Interview runs, profile saved to `.profiles/profiles/mentees/{username}/`

**Check system health:**
- Run integration tests in `.github/tests/`
- Verify profile validation passes
- Test compression resilience (long conversation, check behavior retention)

---

### Getting Help

- **File structure:** See [docs/MENTOR_DIRECTORY.md](docs/MENTOR_DIRECTORY.md)
- **Bug reports:** File as issue with test case that reproduces it

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
