---
name: learner-profile
description: "Manage learner profiles and progress tracking. Use when: starting a session with a new or returning learner, detecting who the current learner is, tracking progress across sessions, adapting teaching style to individual preferences, coordinating multi-learner projects. Handles profile creation via interview, automatic validation via PowerShell scripts, progress persistence to Git, and teaching style adaptation."
---

# Skill: Learner Profile Management

This skill manages learner identity, preferences, and progress across sessions. It enables the mentor to adapt to each learner's style and coordinate team projects where multiple learners work in the same repository.

**Related reference:** `.github/skills/references/method-proficiency-levels.json` contains structured proficiency level definitions for all teaching methods (indicators, teaching approaches, progression signals). Load when assessing or explaining proficiency levels.

## Compression resilience (check at every invocation)

**Before executing any protocol step:**
1. Check if the learner's profile data is in your loaded context
2. If missing (due to compression): Re-load `.profiles/profiles/mentees/{username}/profile.json` or `.profiles/profiles/mentors/{username}/profile.json`
3. Then proceed with the protocol

This makes the skill self-healing — it doesn't assume the profile survived compression, it verifies and restores if needed.

## Architecture

```
project-repo/
├── .profiles/
│   └── profiles/
│       ├── mentees/
│       │   ├── alex_smith/
│       │   │   ├── profile.json                    ← Identity + projects index
│       │   │   ├── cad-01-hello-csharp.progress.json
│       │   │   ├── cad-02-rest-api.progress.json
│       │   │   └── cad-03-database.progress.json
│       │   └── sarah_johnson/
│       │       ├── profile.json
│       │       └── sca-01-powershell.progress.json
│       └── mentors/
│           └── jasteenb/
│               ├── profile.json
│               └── mssa-mentor-agent.progress.json
├── src/                          ← Learner code
└── .git/                         ← Progress tracked via Git
```

**Key principles:** 
- Identity (profile.json) separated from project progress (*.progress.json)
- Each learner has a directory for all their projects
- Profile index tracks project metadata (fast lookups, no directory scan)
- Everything lives in Git — no external databases

## Session start protocol

At the beginning of every session:

### 1. Identify the learner

**Trigger:** run this protocol after the learner sends their **first message** in the session — not on agent activation. The first message is what proves the session is live.

**Source of truth = the signed-in GitHub account.** Resolve the username silently — **never ask**. Order:

1. **VS Code GitHub auth session** (silent): `vscode.authentication.getSession('github', [], { silent: true, createIfNone: false })` → `session.account.label`. This is the Copilot-signed-in GitHub login.
2. **`git config --global user.name`** — fallback for environments without an active GitHub auth session (CI, smoke tests).
3. **OS username** — last-resort fallback so a lookup key always exists.

Sanitize the result (lowercase, non-alphanumeric → `-`, trim) before using it as the folder name under `.profiles/profiles/mentees/`.

**If `silent: true` returns no session AND the git/OS fallbacks produce a folder name that doesn't match any existing profile** → treat the learner as a first-timer and jump straight to the first-time interview. **Do not prompt them to sign in**, do not ask for their GitHub username — the interview itself will capture their preferred name.

This protocol is implemented by `getCurrentUsername()` in `extensions/mssa-mentor/src/profileReader.ts`. See `protocol:identify-learner` in the knowledge graph.

### 2. Check for existing profile

Look for `.profiles/profiles/mentees/{username}/profile.json` (for learners) or `.profiles/profiles/mentors/{username}/profile.json` (for mentors/developers).

**If profile exists:**
- Load `{username}/profile.json` (identity + learning style + military + projects index)
- Read `projects` object to see all projects (completed and in_progress)
- Show project picker if multiple active projects (see below)
- Load selected `{username}/{project-id}.progress.json`
- Greet them by name and reference progress: *"Welcome back, Alex. Last session you finished the first endpoint on the REST API project. Ready to keep building?"*

**Project selection (when multiple in_progress projects):**
```typescript
vscode_askQuestions([{
  header: "Project Selection",
  question: "Which project do you want to work on?",
  options: [
    { label: "REST API Project (CAD)", description: "In progress • Last session: May 28 • Step 3 of 8", recommended: true },
    { label: "PowerShell Automation (SCA)", description: "In progress • Last session: May 25 • Step 2 of 6" },
    { label: "Start new project", description: "Begin a new MSSA project" }
  ]
}])
```

Options built from profile's `projects` index:
- Show `in_progress` projects first (most recent at top)
- Display: `{display_name}` + status + last_session date + current step
- Mark most recent as `recommended: true`
- Always include "Start new project" option

**If file does not exist:**
- Run the first-time interview (see below)
- Create the profile file in `.profiles/profiles/mentees/{username}/profile.json` (creates the `{username}/` folder if needed)
- **Validate the profile** by running `.profiles/validate-profile.ps1 -Username {username}`
- **Check validation results:**
  - If validation **passes** (exit code 0) → commit with message: `"Add learner profile: {name}"`
  - If validation **fails** (exit code 1) → review errors and prompt learner to fill in missing fields
- **What validation checks:**
  - ✅ All required fields present (`name`, `github_username`, `learning_style`, `military`, `progress`)
  - ✅ Military `extracted_concepts` has at least 3 items
  - ✅ JSON is well-formed (no syntax errors)
  - ✅ Field types match schema (strings are strings, numbers are numbers)
- **If validation fails:**
  1. Read the validation error output
  2. Identify which field(s) are missing or incomplete
  3. Ask targeted follow-up questions to fill the gap
     - *"I need at least 3 key concepts from your military work. Can you give me one more thing you did regularly?"*
  4. Update the JSON
  5. Re-run validation
  6. Repeat until validation passes
  7. Then commit

### 3. Check for teammates

List all JSON files in `.profiles/profiles/mentees/` to see who else is working on this project. (Mentor profiles are in `.profiles/profiles/mentors/` but those are test/developer profiles, not active learners.)

**If teammates exist:**
- Briefly mention them: *"I see Sarah is also working on this project — she's on Step 5."*
- Check if any dependencies are ready (see Coordination section below)

### 4. Verify build settings BEFORE planning (hard gate)

Every building session, before `phase:planning` starts, run `protocol:verify-build-settings`:

```powershell
pwsh .github/knowledge-graph/cli/inspect/show-profile.ps1 -Username <username> -ProjectId <project> -Json
```

Inspect the returned `status` map for the seven Build Options: `project`, `track`, `method`, `mode`, `time_box`, `goal`, `comment_depth`.

- **`all_set == true`** → proceed to `phase:planning`.
- **`all_set == false`** → fire `picker:build-options` (the cockpit) to fill the missing fields. Re-run `show-profile.ps1` to confirm before continuing. **Planning never starts on a half-configured session.**

### 5. Edit a single setting mid-session (focused picker)

When the learner asks to change ONE setting (method, track, mode, comment-depth, time-box, goal, project), do NOT re-fire the full cockpit. Use `behavior:32-edit-setting-on-request`:

1. Fire the matching `picker:edit-{setting}` — ONE question, current value marked as default.
2. Persist the choice:

   ```powershell
   pwsh .github/knowledge-graph/cli/session/set-session-setting.ps1 `
     -Username <u> -ProjectId <p> -Field <field> -Value <value>
   ```

3. Echo one line: `OK: method -> TDD` and continue.

Free-text fields (`goal`) and the closed-set enums (`method`, `track`, `mode`, `time_box`, `comment_depth`) are validated by the CLI. `project` reorders `profile.projects[]` so the chosen project becomes `projects[0]` (the auto-pick target).

## First-time interview

When a learner has no profile, run this interview. Keep it conversational — not a form.

Ask these questions in order:

### Personal & learning style (5 questions)

1. **"What should I call you?"** (Might prefer a nickname over their GitHub username)
2. **"Tell me a bit about yourself — what's your style?"** (Open-ended, listen for personality markers)
3. **"When you're learning something new, what makes it click for you?"** (Examples: hands-on practice, diagrams, seeing it work, comparing to something familiar)
4. **"What do you do when you get stuck?"** (Try a few things first? Ask immediately? Walk away and come back?)
5. **"What makes this feel like fun instead of homework?"** (Building something real? Solving puzzles? Helping teammates? Seeing progress?)

### Military background (4-5 questions)

6. **"What branch did you serve in?"** (Army, Navy, Air Force, Marines, Coast Guard, Space Force)
7. **"What was your rank when you left?"** (Or current rank if still serving)
8. **"What was your MOS/Rating/AFSC?"** (The job code — e.g., 25B, IT, 2336, 3D0X2)
9. **"What did you actually do day-to-day?"** (Open-ended — let them describe in their own words. This is where the rich detail lives.)
10. **[If MOS is not in reference files]** *"I don't have a reference for {MOS} yet, but I want to learn. What were you responsible for? What did you do when something went wrong?"*

### Summary and confirmation

After they answer, **read back a summary** and confirm:
- *"So: you're {name}, you like {learning style}, you get unstuck by {strategy}, and this feels worth doing when {motivation}. You served as a {rank} {MOS title} in the {branch}, where you {job description}. Did I get that right?"*

If they confirm, proceed to create the profile.

### Follow-up interview for incomplete fields

When validation detects missing, empty, or "N/A" fields, run targeted follow-ups:

**If `branch` is N/A, empty, or blank:**
- *"Did you serve in the military? (Yes/No)"*
- If **No** → set `branch: "Civilian"`, `rank: ""`, `mos: ""`, `mos_title: ""`, `years_of_service: 0`
- If **Yes** → ask for branch (Army, Navy, Air Force, Marines, Coast Guard, Space Force)

**If military and `rank` is missing:**
- *"What rank did you hold when you left (or current rank)?"*

**If military and `mos` is missing:**
- *"What was your MOS/Rating/AFSC?"* (job code)

**If military and `mos_title` is missing:**
- *"What's the full title for that job?"*

**If `extracted_concepts` has < 3 items:**
- *"I need at least 3 key concepts from your {military/civilian} work. You mentioned {existing concepts}. What's something else you did regularly?"*
- Repeat until 3+ concepts collected

**If `translation_to_code` is empty:**
- *"Let me connect those to code. When you {first concept}, what did that look like?"*
- Extract software equivalent and add mapping
- Repeat for 1-2 more concepts

**Rule:** Never write a profile with N/A, empty, or blank required fields. Always interview until complete.

## Profile schema

### profile.json (Identity + Index)

```json
{
  "name": "Alex Smith",
  "preferred_name": "Alex",
  "github_username": "alex_smith",
  "created": "2026-05-29T14:32:00Z",
  "last_updated": "2026-05-29T14:32:00Z",
  
  "learning_style": {
    "prefers": ["hands-on", "examples", "diagrams"],
    "pace_preference": "steady",
    "when_stuck": "tries a few things, then asks for help",
    "notes": "Gets bored if things are too slow. Likes building something tangible."
  },
  
  "personality": {
    "self_description": "I like solving puzzles. I'm competitive in a good way.",
    "motivation": "I want to build something I can show people.",
    "notes": ""
  },
  
  "military": {
    "branch": "Marines",
    "rank": "SSgt",
    "mos": "2336",
    "mos_title": "Explosive Ordnance Disposal Technician",
    "years_of_service": 8,
    "job_description": "Render safe procedures on UXO and IEDs. Led a four-man team. Every decision had life-or-death consequences.",
    "extracted_concepts": [
      "methodical troubleshooting under pressure",
      "render safe procedures (step-by-step, no shortcuts)",
      "failure analysis (if it didn't work, find out why before trying again)",
      "team coordination in high-stakes situations",
      "risk assessment and mitigation"
    ],
    "translation_to_code": {
      "render_safe": "Debugging production issues — same methodical approach, same consequences for rushing",
      "uxo_analysis": "Security vulnerabilities — identify, assess, remediate with precision",
      "team_lead": "Code review and incident response — coordinate under pressure"
    }
  },
  
  "projects": {
    "cad-01-hello-csharp": {
      "display_name": "Hello C# (CAD)",
      "track": "cloud-app-dev",
      "status": "completed",
      "completed_at": "2026-05-20"
    },
    "cad-02-rest-api": {
      "display_name": "REST API Project (CAD)",
      "track": "cloud-app-dev",
      "status": "in_progress",
      "last_session": "2026-05-28",
      "current_step": 3
    },
    "sca-01-powershell": {
      "display_name": "PowerShell Automation (SCA)",
      "track": "server-cloud-admin",
      "status": "in_progress",
      "last_session": "2026-05-25",
      "current_step": 2
    }
  }
}
```

### {project-id}.progress.json (Project Detail)

```json
{
  "project_id": "cad-02-rest-api",
  "display_name": "REST API Project (CAD)",
  "track": "cloud-app-dev",
  "status": "in_progress",
  "started_at": "2026-05-21T10:00:00Z",
  "last_session": "2026-05-28T14:30:00Z",
  "last_used_method": "TDD",
  "current_step": 3,
  "total_steps": 8,
  "completed_milestones": [
    "project-setup",
    "first-endpoint",
    "validation-layer"
  ],
  "method_proficiency": {
    "TDD": {
      "level": "Familiar",
      "last_updated": "2026-05-28",
      "notes": "Completed 3 Red-Green-Refactor cycles. Named phases independently. Still needs prompting on test size."
    },
    "ride-along": {
      "level": "Competent",
      "last_updated": "2026-05-21",
      "notes": "Comfortable with why-what-how rhythm. Asks good questions during build."
    }
  },
  "session_history": [
    {
      "date": "2026-05-21",
      "duration_minutes": 45,
      "method_used": "ride-along",
      "milestones_completed": ["project-setup"],
      "notes": "Set up ASP.NET Core project. Created first controller."
    },
    {
      "date": "2026-05-28",
      "duration_minutes": 60,
      "method_used": "TDD",
      "milestones_completed": ["first-endpoint", "validation-layer"],
      "notes": "Wrote tests first. GET endpoint working. Added input validation."
    }
  ],
  "notes": "Using TDD now — learner likes seeing tests pass. Struggling with async/await but improving."
}
```

### Field guide

| Field | Purpose |
|---|---|
| `name` | Full name (from interview) |
| `preferred_name` | What to call them in conversation |
| `github_username` | Identity key — must match Git user |
| `learning_style.prefers` | Array of teaching approaches that work |
| `learning_style.pace_preference` | `"fast"`, `"steady"`, `"slow"` |
| `learning_style.when_stuck` | How they handle being blocked |
| `personality.self_description` | Their own words about their style |
| `personality.motivation` | What makes this worth doing |
| `military.branch` | Army, Navy, Air Force, Marines, Coast Guard, Space Force |
| `military.rank` | Final or current rank |
| `military.mos` | Job code (MOS/Rating/AFSC) |
| `military.mos_title` | Full job title |
| `military.years_of_service` | How long they served |
| `military.job_description` | What they actually did, in their words |
| `military.extracted_concepts` | Operational concepts mentor extracted from interview |
| `military.translation_to_code` | Mappings from military concepts to software concepts |
| `progress.current_track` | `"cloud-app-dev"`, `"server-cloud-admin"`, `"cybersecurity-ops"` |
| `progress.current_project` | Project identifier (e.g., `"cad-hello-csharp"`) |
| `progress.current_step` | Integer — which step they're on |
| `progress.last_used_method` | `"ride-along"`, `"TDD"`, `"BDD"`, `"spike-then-refactor"` — teaching method from last session |
| `progress.completed_milestones` | Array of milestone IDs they've finished |
| `quiz_history` | Append-only ledger of in-session calibration quiz outcomes. Each entry: `{ ts, concept_id, project_id, trigger ("pre-teach"\|"reappearance"\|"cadence"\|"recall-open"), form ("mc"\|"code-fill"\|"open"\|"self-report"), question, answer, correct, tier_before, tier_after }`. Read by mentor behaviors `track-concept-proficiency` and `aar-at-milestones` to recompute `concept_proficiency.tier` at AAR — `tier` is a snapshot, `quiz_history` is the source of truth. See behaviors `pre-teach-quiz`, `reappearance-quiz`, `cadence-quiz` in `.github/agents/Mentor.agent.md`. |
| `session_history` | Log of sessions for retrospectives |

**Note:** The `military.extracted_concepts` and `translation_to_code` fields are built by the mentor during the interview. When the learner describes their job, the mentor listens for operational concepts (render safe procedures, mission planning, troubleshooting under pressure) and stores them here. The mentor persona (not this skill) uses these mappings to pick analogies during teaching.

### Common validation failures and fixes

When `.profiles/validate-profile.ps1` fails, here's what to check:

| Error | Cause | Fix |
|---|---|---|
| **"Must have at least 3 extracted_concepts"** | `military.extracted_concepts` array has fewer than 3 items | Ask follow-up: *"What's one more thing you did regularly in that role?"* Add the concept to the array |
| **"Field X is required"** | Top-level field missing entirely | Add the field with appropriate default value |
| **"Field X must be a string/number/array"** | Wrong data type | Check JSON syntax — strings need quotes, numbers don't, arrays need `[]` |
| **"Invalid JSON"** | Syntax error (missing comma, brace, etc.) | Run the file through a JSON validator, fix syntax |
| **"github_username doesn't match filename"** | Filename is `alex.json` but `github_username` is `"alex_smith"` | Rename file or update `github_username` to match |

**Example recovery flow:**

```
Mentor: (runs validation)
Output: "❌ Must have at least 3 extracted_concepts (found 2)"

Mentor: "I need one more key concept from your EOD work. You mentioned render safe procedures and post-blast analysis — what's something else you did regularly?"

Learner: "Risk assessment before approaching the device."

Mentor: (adds to profile)
"extracted_concepts": [
  "render safe procedures",
  "post-blast analysis",
  "risk assessment under uncertainty"
]

Mentor: (re-runs validation)
Output: "✓ All profiles valid"

Mentor: (commits)
```

## Progress tracking

### After each milestone

When the learner completes a milestone (e.g., first function works, tests pass, deployment succeeds):

1. Update their profile:
   ```json
   "progress": {
     "current_step": 4,
     "completed_milestones": ["step-1-hello-world", "step-2-function", "step-3-test"]
   }
   ```

2. Append to `session_history`:
   ```json
   {
     "date": "2026-05-29",
     "duration_minutes": 45,
     "milestones_completed": ["step-3-test"],
     "notes": "Finished test suite, struggled with assert syntax but got it"
   }
   ```

3. Update `last_updated` timestamp

4. **Commit the profile to Git** with message: `"Progress: {name} completed {milestone}"`

### Auto-commit vs staged

**Default behavior: auto-commit after each milestone**

Why: Keeps progress in sync automatically across all learners. Sarah pulls the repo and immediately sees Alex finished Step 3.

**When NOT to auto-commit:**
- The learner explicitly says they want to control commits themselves
- They're practicing Git workflow and committing is part of the lesson

If the learner wants manual commits, stage the profile file and tell them:
- *"I've updated your progress file — it's staged. Commit it when you're ready."*

## Coordination (multi-learner projects)

When multiple learners work in the same repository, the mentor can proactively notice dependencies.

### Handoff awareness

At session start, after loading the current learner's profile:

1. **List all profiles** in `.profiles/profiles/mentees/` (mentors are in `profiles/mentors/`)
2. **Check if any teammate just completed a dependency**
   - Example: Sarah finished the data model (Step 4), Alex is about to start the controller (Step 5)
3. **Surface the handoff:**
   - *"Sarah just finished the data model — you're clear to start the controller now. Want to pull her latest changes first?"*

### Conflict hints (not prevention)

If the mentor detects two learners are on the same step and likely editing the same files:
- Mention it: *"Heads up — Sarah is working on `Program.cs` too. You might hit a merge conflict. That's normal in team work — Git will help you resolve it."*
- **Do not prevent conflicts** — resolving them is a learning opportunity

### Shared project state

Multi-learner coordination uses `.profiles/project.json` at the repo root:

```json
{
  "project_name": "Team Alpha - Hello C#",
  "track": "cloud-app-dev",
  "project_id": "cad-hello-csharp",
  "active_learners": ["alex_smith", "sarah_johnson"],
  "started": "2026-05-29",
  "milestones": {
    "step-1-hello-world": {
      "completed_by": ["alex_smith", "sarah_johnson"],
      "completed_at": "2026-05-29T15:00:00Z"
    },
    "step-2-function": {
      "completed_by": ["alex_smith"],
      "completed_at": "2026-05-29T15:30:00Z"
    }
  }
}
```

Individual profiles still carry per-learner detail — `project.json` is the shared index that lets the mentor see who's on what step without scanning every learner's progress file.

## Edge cases

### Learner switches projects

If the learner says *"I want to start the Azure project"* but their profile shows `current_project: "cad-hello-csharp"`:

1. Confirm: *"You're currently on {old project}, Step {N}. Want to switch to {new project} or pick up where you left off?"*
2. If they confirm the switch:
   - Update `progress.current_project`
   - Set `progress.current_step = 1`
   - Clear `progress.completed_milestones = []`
   - Add a note to `session_history`
3. Commit the change

### Learner returns after a long gap

If `last_updated` is >2 weeks ago:

1. Greet warmly: *"Welcome back, {name}! It's been a couple weeks."*
2. Refresh their memory: *"Last time you finished {milestone}. Want to pick up there, or review first?"*
3. Offer a quick recap if they want it

### Profile exists but is corrupted/invalid JSON

- Catch the parse error
- Tell the learner: *"Your progress file got corrupted somehow. I'll recreate it — you won't lose credit for your work, I can see your Git history."*
- Reconstruct progress by scanning Git log for commits authored by them
- Write a new profile

### Learner wants to update their profile

If they say *"I prefer faster pacing now"* or *"I want to change my learning style"*:

**Option 1: Interactive edit (recommended)**
1. Run `.profiles/edit-profile.ps1 -Username {username}`
2. The script presents a menu of editable fields
3. Updates are validated automatically before saving
4. Profile is committed with descriptive message

**Option 2: Manual edit**
1. Ask what they want to change
2. Update the relevant fields in their JSON file
3. Validate with `.profiles/validate-profile.ps1 -Username {username}`
4. Commit with message: `"Update learner profile: {name} (revised preferences)"`

**Available tools:**
- `.profiles/edit-profile.ps1` — Interactive profile editor with validation
- `.profiles/validate-profile.ps1` — Run schema validation tests

## Implementation checklist

When you need to use this skill:

- [ ] Identify the current learner (GitHub username)
- [ ] Check for `.profiles/profiles/mentees/{username}/profile.json` (learner) or `.profiles/profiles/mentors/{username}/profile.json` (mentor/developer)
- [ ] If missing → run interview, create profile
  - [ ] Write JSON file to appropriate directory
  - [ ] **Validate** with `.profiles/validate-profile.ps1 -Username {username}`
  - [ ] If validation fails → ask follow-ups, fix fields, re-validate
  - [ ] Once validation passes → commit with message: `"Add learner profile: {name}"`
- [ ] If exists → load profile, adapt teaching style
- [ ] Check for teammates (list `.profiles/profiles/mentees/*.json`)
- [ ] After each milestone → update profile, validate (optional), commit
- [ ] At session end → update progress file + profile index (see Session End protocol below), commit

---

## Session End Update Protocol

**When a session ends (called by method skill's session end):**

1. **Update project progress file** (`.profiles/mentees/{username}/{project-id}.progress.json`)
   - Add session to `session_history` array:
     - `date`, `duration_minutes`, `method_used`
     - `milestones_completed` (what shipped this session)
     - `notes` (free-text summary)
   - Update `last_session` timestamp
   - Update `last_used_method`
   - Update `current_step` if milestone reached
   - Append to `completed_milestones` if applicable
   - **Update `method_proficiency` for the method used this session:**
     - Update or create entry: `method_proficiency.{method_name}` (where method_name is: `TDD`, `BDD`, `spike_then_refactor`, `ride_along`)
     - Fields: `level` (Novice/Familiar/Competent/Proficient), `last_updated` (today's date), `notes` (progression evidence)
     - **Only update if proficiency changed** (assessed during method's session end AAR)
     - If level unchanged → skip proficiency update

2. **Update profile index** (`.profiles/profiles/mentees/{username}/profile.json`)
   - Update project entry in `projects` object:
     - `last_session` (today's date)
     - `status` (if changed: `not_started` → `in_progress` → `completed`)
     - `current_step` (mirror from progress file)
   - Update `last_updated` timestamp on profile root

3. **Commit to Git**
   - Stage both files: `git add .profiles/profiles/mentees/{username}/profile.json .profiles/profiles/mentees/{username}/{project-id}.progress.json`
   - Commit with message: `"Session {date}: {project-name} - {brief-summary}"`
   - Example: `"Session 2026-05-22: CAD REST API - Completed basic routing"`

---

## Testing

To verify the profile system works:

1. Start a session in a fresh project (no `.profiles/` directory)
2. Mentor should detect no profile exists
3. Mentor runs interview
4. Mentor creates `.profiles/profiles/mentees/{your-username}/profile.json` (or `.profiles/profiles/mentors/{username}/profile.json` for mentor/test profiles)
5. **Mentor validates the profile** by running `.profiles/validate-profile.ps1 -Username {username}`
6. If validation passes → mentor commits the file
   - If validation fails → mentor asks follow-ups, fixes fields, re-validates, then commits
7. Complete one milestone
8. Mentor updates profile with new `current_step` and `completed_milestones`
9. Mentor commits again
10. Close and reopen — mentor should recognize you and reference your progress
