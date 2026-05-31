# MSSA Mentor Knowledge Graph

Multi-layer structured map of the Mentor system. Each layer is its own JSON graph; they merge into one combined graph.

## Layout

```
.github/knowledge-graph/
├── README.md                    ← you are here
├── INTEGRATION_SUMMARY.md
│
├── output/                      ← Generated artifacts (gitignored)
│   ├── merged-graph.json       ← Combined graph from all layers
│   └── call-flow-nodes.json    ← Pre-computed call flows
│
├── cli/                         ← Daily user commands
│   ├── audit-quality.ps1       ← Find technical debt
│   ├── check-skill-exists.ps1  ← Avoid duplicates
│   ├── show-skill-impact.ps1   ← Impact analysis
│   ├── recommend-next-skills.ps1 ← Learning path
│   └── show-progress.ps1       ← Learner progress dashboard
│
├── build/                       ← Graph maintenance
│   ├── merge.ps1               ← Combine all layers
│   ├── rebuild-if-stale.ps1    ← Auto-rebuild when needed
│   ├── health.ps1              ← Health checks
│   ├── gap-analysis.ps1        ← Gap classification
│   ├── fix-remaining-gaps.ps1  ← Gap repair
│   ├── generate-call-flow-nodes.ps1 ← Pre-compute call flows
│   └── scaffold-node-type.ps1  ← Scaffold new node types
│
├── tests/                       ← Validation & debugging
│   ├── test-graph.ps1          ← Full integrity check
│   ├── validate-audit.ps1      ← Audit function validation
│   ├── check-edges.ps1         ← Edge inspection
│   └── check-types.ps1         ← Node type distribution
│
├── demos/                       ← Interactive demos
│   ├── demo-query.ps1          ← 5 usage demos
│   └── demo-full.ps1           ← Comprehensive demo
│
├── lib/                         ← Core runtime module
│   └── query.psm1              ← 12 exported functions
│
├── queries/                     ← Query scripts (callable from skill)
│   ├── Get-CallFlow.ps1        ← Show execution flow
│   ├── Get-Dependencies.ps1    ← Outgoing edges
│   ├── Get-Dependents.ps1      ← Incoming edges
│   ├── Get-SkillPath.ps1       ← Shortest path between nodes
│   ├── Get-SkillRecommendations.ps1 ← Learning path
│   ├── Get-Subgraph.ps1        ← Export filtered subgraphs
│   └── _Format-GraphOutput.ps1 ← Shared formatting helpers
│
└── data/                        ← Source graphs
    └── MentorAgent/            ← This repo's graphs
        ├── system/             ← Architecture & call flow
        │   ├── mentor-graph.json
        │   └── README.md
        └── code/               ← Source map
            ├── code-graph.json
            └── README.md
```

## Why two graphs?

| Graph | Answers | Best for |
|---|---|---|
| `data/MentorAgent/system/` | "What does this agent DO? What are the rules? How does a session flow?" | Onboarding, finding rule duplicates, picking what to extract to JSON |
| `data/MentorAgent/code/` | "Where is this rule actually written? What script implements this validator? Which test covers this skill?" | Code review, refactoring, dead-code detection, dependency tracking |

A **system** node `script:validate-profile` says "this script validates profiles." A **code** node `code-file:.profiles/validate-profile.ps1` says "here is the actual file with these functions and parameters." `merge.ps1` joins them so you can ask either question against one graph.

## The merge model

| Graph | ID prefix convention |
|---|---|
| system | `agent:`, `skill:`, `protocol:`, `phase:`, `rule:`, `script:`, `file:`, etc. (already in place) |
| code | `code-file:`, `code-func:`, `code-param:`, `code-schema:`, `code-field:`, `code-test:`, `code-call:` |

Prefixes never collide. `merge.ps1`:
1. Reads every `*-graph.json` in subfolders
2. Validates no duplicate node IDs across graphs (collision = abort)
3. Merges nodes, edges, clusters into `output/merged-graph.json`
4. Adds an optional `bridges` section in each graph's metadata declaring `system_id → code_id` mappings (e.g. system's `script:validate-profile-ps1` ↔ code's `code-file:.profiles/validate-profile.ps1`). Merge resolves these into typed `implemented_by` edges.

## Quick commands

```powershell
# Learner progress dashboard
pwsh .github/knowledge-graph/cli/show-progress.ps1 -Username "alex_smith"
pwsh .github/knowledge-graph/cli/show-progress.ps1 -Username "alex_smith" -Track "cloud-app-dev"

# Quality audit (find technical debt)
pwsh .github/knowledge-graph/cli/audit-quality.ps1

# Check for duplicate skills before creating new ones
pwsh .github/knowledge-graph/cli/check-skill-exists.ps1 -Name "TDD"

# Impact analysis (what depends on this skill?)
pwsh .github/knowledge-graph/cli/show-skill-impact.ps1 -SkillId "skill:learner-profile"

# Skill recommendations (what should I learn next?)
pwsh .github/knowledge-graph/cli/recommend-next-skills.ps1 -CompletedSkills "skill:cad-hello-console"

# Self-healing rebuild (auto-detects staleness)
pwsh .github/knowledge-graph/build/rebuild-if-stale.ps1

# Force rebuild regardless of freshness
pwsh .github/knowledge-graph/build/rebuild-if-stale.ps1 -Force

# Test the graph (12 functional tests)
pwsh .github/knowledge-graph/tests/test-graph.ps1

# Health check (topology validation)
pwsh .github/knowledge-graph/build/health.ps1 -Layer merged

# Gap analysis (triage health findings)
pwsh .github/knowledge-graph/build/gap-analysis.ps1 -Layer merged
```

## Self-healing system

The graph auto-rebuilds when source files are modified. Run `rebuild-if-stale.ps1` before any operation that depends on the graph being current:

```powershell
# In your workflow script:
pwsh .github/knowledge-graph/build/core/rebuild-if-stale.ps1 -Quiet
# ... then use output/merged-graph.json
```

**Staleness triggers:**
- Any `.md` or `.json` file under `.github/skills/`, `.github/agents/`, `.profiles/` modified after the graph's `last_updated` timestamp
- Build scripts (`extract.ps1`, `merge.ps1`) modified after the graph
- Graph doesn't exist or has no `last_updated` metadata

**Exit codes:**
- `0` — Graph fresh (no rebuild) OR rebuild succeeded
- `1` — Rebuild failed (errors logged to stderr)

**Pre-commit hook example:**
```powershell
# .git/hooks/pre-commit (Windows)
#!/usr/bin/env pwsh
pwsh -NoProfile -File .github/knowledge-graph/rebuild-if-stale.ps1 -Quiet
if ($LASTEXITCODE -ne 0) {
    Write-Host "Graph rebuild failed — commit blocked." -ForegroundColor Red
    exit 1
}
```

## Test suite

`test-graph.ps1` runs 12 functional tests:
1. Find mentor agent node
2. Find all track nodes
3. Find skills under a track
4. Verify bridges exist
5. Path finding (mentor → skill)
6. Schema instances bridged
7. All tracks reachable from mentor
8. Skill dependency discovery
9. Cluster coverage >90%
10. File node path validation
11. Edge connectivity (no dangling)
12. Query performance <100ms

All 12 passing = graph is production-ready.

## Diagnostic tools

| Tool | Purpose | When to use |
|---|---|---|
| `health.ps1` | Topology validation (13 checks) | After every rebuild; CI gate |
| `gap-analysis.ps1` | Triage health findings into REAL GAP / EXPECTED / NEEDS REVIEW | When health.ps1 shows warnings/failures |
| `test-graph.ps1` | Functional validation (12 tests) | Before deploying graph-dependent features |
| `rebuild-if-stale.ps1` | Self-healing rebuild | Before any graph query; in pre-commit hooks |

**DONE definition:** `health.ps1` reports `FAIL 0`, `gap-analysis.ps1` reports `REAL GAP 0`, `test-graph.ps1` reports `12/12 passed`.

## Using the Graph at Runtime

The graph is **queryable at runtime** — the Mentor agent can dynamically load only relevant skills instead of loading everything.

### Query Module (`query.psm1`)

```powershell
Import-Module .github/knowledge-graph/query.psm1

# Get prioritized skill list for current session
$files = Get-AgentLoadList -Intent "build a REST API" -Method "TDD" -Track "cloud-app-dev"
# Returns: learner-profile, TDD, intent-matched skills, track README

# Find all skills for a track
$skills = Get-TrackSkills -Track "cloud-app-dev"

# Keyword-based search
$results = Get-RelevantSkills -Intent "profile validation" -MaxResults 5

# Path finding
$path = Get-SkillPath -From "agent:mentor" -To "skill:learner-profile"

# Get dependencies
$deps = Get-SkillDependencies -SkillId "skill:learner-profile"
```

### Main Entry Point: `Get-AgentLoadList`

Returns an ordered list of skill files to load for the current session:

```powershell
Get-AgentLoadList -Intent "user's stated goal" -Method "ride-along" -Track "cloud-app-dev"
```

**Returns (in load order):**
1. `learner-profile` (always first — session foundation)
2. Selected method skill (ride-along, TDD, BDD, spike-then-refactor)
3. 2-3 intent-matched skills (keyword search against descriptions)
4. Track README if track specified

**Benefits:**
- Load 4-6 files instead of 20+ (faster sessions, better context window usage)
- Scale to 100+ skills without performance degradation
- Self-healing via `rebuild-if-stale.ps1` (graph auto-updates when files change)

### Demo

```powershell
pwsh .github/knowledge-graph/demos/demo-query.ps1
```

Shows:
- Dynamic skill loading for 4 different intents
- Track skill discovery (3 tracks)
- Keyword search (4 queries)
- Path finding (2 examples)
- Performance check (sub-100ms after initial load)

**Or run the comprehensive demo** (all 3 capabilities):

```powershell
pwsh .github/knowledge-graph/demos/demo-full.ps1
```

Shows dynamic loading + quality audit + skill discovery in one session.

---

## Quality Audit (Find Technical Debt)

The `audit-quality.ps1` script surfaces quality issues automatically:

```powershell
# Run full audit
pwsh .github/knowledge-graph/cli/audit-quality.ps1

# Filter to specific category
pwsh .github/knowledge-graph/cli/audit-quality.ps1 -Category untested

# Output as JSON
pwsh .github/knowledge-graph/cli/audit-quality.ps1 -Json
```

### What It Checks

| Check | Surfaces |
|---|---|
| **Orphans** | Skills nothing references (dead code candidates) |
| **Dead-ends** | Skills that don't reference anything (isolated) |
| **Broken refs** | File paths that don't exist |
| **No description** | Empty descriptions (hurts keyword search) |
| **Unclustered** | Nodes not assigned to any cluster |
| **Untested** | Skills with no test coverage |

### Example Output

```
========================================
 Knowledge Graph Quality Audit
========================================

[0] Orphan Skills (Nothing References Them)
  ✓ No issues

[0] Dead-End Skills (Reference Nothing)
  ✓ No issues

[0] Broken File References
  ✓ No issues

[0] Missing Descriptions
  ✓ No issues

[0] Unclustered Nodes
  ✓ No issues

[54] Untested Skills

  • ride-along skill (default method)
    ID: skill:ride-along
    Type: skill
    File: .github/skills/methods/ride-along/SKILL.md
    Issue: No test coverage

  ... and 53 more

========================================
 Summary
========================================

Found 54 quality issues across 6 categories.

Recommendations:
  • Untested: Add test nodes with 'tests' edges
```

### Current State (May 30, 2026)

- **54 skills untested** (98% of skills have no test coverage)
- Only `learner-profile` skill has tests (test:profile-load, test:proficiency-tracking)
- All other checks pass (0 orphans, 0 dead-ends, 0 broken refs, 0 missing descriptions, 0 unclustered)

**Why this matters:** Surfaces technical debt that's invisible without graph analysis. Before the quality audit, you had to manually track which skills needed tests. Now it's automatic.

---

## Skill Discovery (Avoid Duplicates)

The `check-skill-exists.ps1` script prevents duplicate work by finding existing skills before you build a new one:

```powershell
# Check if similar skill exists
pwsh .github/knowledge-graph/cli/check-skill-exists.ps1 -Name "git-basics"

# Include description for better matching
pwsh .github/knowledge-graph/cli/check-skill-exists.ps1 -Name "api-auth" -Description "Teach REST API authentication"

# Set higher threshold (50 = very similar only)
pwsh .github/knowledge-graph/cli/check-skill-exists.ps1 -Name "docker-intro" -Threshold 50

# Export as JSON
pwsh .github/knowledge-graph/cli/check-skill-exists.ps1 -Name "profile" -Json
```

### Similarity Scoring

| Score | Meaning | Action |
|---|---|---|
| **70+** | EXACT MATCH | Don't build - use existing skill |
| **50-69** | VERY SIMILAR | Review before building - might extend existing |
| **30-49** | SIMILAR | Check for overlap - likely safe to build |
| **<30** | WEAK MATCH | Different enough - safe to build |

### Example Output

```
========================================
 Skill Discovery Check
========================================

Searching for: 'TDD'
Description: 'Test-driven development'

Found 1 similar skill(s):

[75] TDD skill
  ID: skill:tdd
  Type: skill
  File: .github/skills/methods/TDD/SKILL.md
  Cluster: teaching-methods
  Description: Test-Driven Development teaching method. Red-Green-Refactor.
  → EXACT MATCH - Don't build, use this

========================================
 Recommendation
========================================

⚠️  STOP: Exact match found!

The skill 'TDD skill' already exists.
File: .github/skills/methods/TDD/SKILL.md

→ Use the existing skill instead of building a new one.
```

**Why this matters:** Before creating "learn-git-basics", check if "git-fundamentals" or "version-control-intro" already exists. Prevents duplicate skills with slightly different names.

---

## Impact Analysis (What Breaks If I Change This?)

The `show-skill-impact.ps1` script shows what depends on a skill before you change or remove it:

```powershell
# See what depends on learner-profile skill
pwsh .github/knowledge-graph/cli/show-skill-impact.ps1 -SkillId "skill:learner-profile"

# Include indirect dependencies (transitive impact)
pwsh .github/knowledge-graph/cli/show-skill-impact.ps1 -SkillId "skill:ride-along" -IncludeIndirect

# Export as JSON
pwsh .github/knowledge-graph/cli/show-skill-impact.ps1 -SkillId "skill:tdd" -Json
```

### Example Output

```
========================================
 Impact Analysis: skill:learner-profile
========================================

DIRECT IMPACT (2 dependents):

  [1] agent:
    • Mentor
      Relationship: Mentor --composes--> skill:learner-profile
      File: .github/agents/Mentor.agent.md

  [1] rule:
    • 1. Identify the learner first
      Relationship: 1. Identify the learner first --delegates_to--> skill:learner-profile

========================================
 Summary
========================================

Total direct dependents: 2
  Agents: 1

⚠️  WARNING: Changing this skill affects 2 direct dependent(s).
   Agents depend on this - breaking changes require agent updates.
```

**Why this matters:** Before refactoring `learner-profile`, you know 1 agent and 1 behavior depend on it. Breaking changes mean updating both.

---

## Skill Recommendations (What Should I Learn Next?)

The `recommend-next-skills.ps1` script suggests what to learn based on completed skills:

```powershell
# After completing hello-console, what's next?
pwsh .github/knowledge-graph/cli/recommend-next-skills.ps1 -CompletedSkills "skill:cad-hello-console"

# Multiple completed skills
pwsh .github/knowledge-graph/cli/recommend-next-skills.ps1 -CompletedSkills "skill:ride-along","skill:learner-profile"

# Filter to specific track
pwsh .github/knowledge-graph/cli/recommend-next-skills.ps1 -CompletedSkills "skill:cad-hello-console" -Track "cloud-app-dev"

# Get more results
pwsh .github/knowledge-graph/cli/recommend-next-skills.ps1 -CompletedSkills "skill:tdd" -MaxResults 10
```

### Recommendation Algorithm

| Strategy | Score | Example |
|---|---|---|
| **Direct recommendation** | +50 | skill A has "recommends" edge to skill B |
| **Builds on completed skill** | +30 | Advanced skill requires what you just learned |
| **Same cluster** | +20 | Related skills in same topic area |
| **Track progression** | +15 | Next skill in same MSSA track |

### Priority Levels

- **HIGH** (50+): Direct recommendation or builds on your work
- **MEDIUM** (30-49): Related or next in track
- **LOW** (<30): Loosely related

### Example Output

```
========================================
 Skill Recommendations
========================================

Based on completed skills:
  • skill:cad-hello-console

TOP 5 RECOMMENDATIONS:

[1] cad-todo-api-ef [MEDIUM]
    Score: 35
    File: .github/skills/tracks/cloud-app-dev/cad-todo-api-ef/SKILL.md
    Why: In same cluster: track-curriculum; Next in track progression

========================================
 Next Steps
========================================

→ Start with: cad-todo-api-ef
```

**Why this matters:** "You learned X, now try Y" becomes data-driven. After completing a console app, the graph recommends API development as the natural next step.

---

# Build the combined graph
pwsh .github/knowledge-graph/merge.ps1
```

## Current state

| Layer | Status |
|---|---|
| `system/mentor-graph.json` | Built — 269 nodes, 385 edges, 9 clusters, 8 duplicates + 5 conflicts + 8 extraction candidates flagged |
| `code/code-graph.json` | Skeleton only — Phase B will populate from the live repo |
| `merge.ps1` | Built — handles 1+ graphs, collision detection, bridge resolution |

## Adding a new layer

Drop a new subfolder with one `*-graph.json` file and (optionally) an `audit.ps1`. `merge.ps1` picks it up automatically. Example future layers:

- `tests/` — coverage map: which tests cover which rules
- `runtime/` — telemetry overlay: how often each path is actually taken
- `learners/` — anonymized progress patterns across mentees
