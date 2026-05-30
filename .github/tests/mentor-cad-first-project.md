pu# Test: Mentor — CAD first-project intake

**Validates:** All three pass criteria from [`.github/copilot-instructions.md`](../copilot-instructions.md) — scope-and-time intake, learner-at-keyboard, concept naming.

**Parameterized.** Replace `{TARGET_PROJECT}` with any CAD project slug (see [`.github/skills/tracks/cloud-app-dev/README.md`](../skills/tracks/cloud-app-dev/README.md)). Default target: `cad-hello-console`.

**Estimated runtime:** 3 turns, ~2 minutes.

---

## Setup

- **Agent:** `@Mentor`
- **Editor context:** Any file (the test deliberately uses a mismatched open file to verify intent-honoring). Recommended: open `.github/skills/tracks/cloud-app-dev/cad-blob-uploader/SKILL.md` so the test exercises the "honor stated intent over editor context" rule.
- **Fresh chat:** Yes.

---

## Turn 1 — Cold open

**Send:**
> Hi, I just started the MSSA Cloud App Dev track. I'm a veteran transitioning out — no coding background. I'd like to start with the first project. Can you help me get going?

**Expect (pass criteria):**
- ✅ Mentor asks **what you want to learn / be able to do** by end of session
- ✅ Mentor asks **how much time** you have
- ✅ Zero code is written or pasted
- ✅ Mentor does not pitch the file currently open in the editor as "a good start" — if it mentions the open file, it must redirect to `cad-hello-console` (project #1) per the learner's stated intent

**Common failure modes:**
- ❌ Mentor recommends the open editor file as the starting project (intent-vs-context bias — fixed 2026-05-29, see `mentor-editor-context-bias.md`)
- ❌ Mentor dumps an install command without asking scope/time first
- ❌ Mentor invents a project not in the CAD README

---

## Turn 2 — Concrete request

**Send (substitute `{TARGET_PROJECT}` if testing a non-default project):**
> I want to start with the very first project in the CAD track — {TARGET_PROJECT}. I have about 45 minutes. Goal: I want to understand how C# basics work before I touch anything cloud-related. Let's begin.

**Expect (pass criteria):**
- ✅ Mentor confirms the plan in 1-3 sentences (time + project + scope)
- ✅ Mentor outlines **phases** (not all the code) at a high level
- ✅ Mentor gives the learner **one move** — a single command or step — and then **stops**, asking the learner to report back
- ✅ The move is small (one keystroke / one command), not a multi-file paste
- ✅ Mentor explains the **why** before the **what** and **how**

**Common failure modes:**
- ❌ Mentor dumps the entire SKILL.md verbatim
- ❌ Mentor stacks 3+ moves in one turn without waiting
- ❌ Mentor writes the code for the learner instead of telling them what to type

---

## Turn 3 — Simulated success

**Send:**
> Done. It printed [whatever the expected output is — for `cad-hello-console` Phase 1, paste a `.NET 8.x.x` version string]. What's next?

**Expect (pass criteria):**
- ✅ Mentor runs a brief **after-action review** — usually 1-2 sentences acknowledging what just happened and what concept was demonstrated
- ✅ Mentor **names at least one concept out loud** (e.g. *"that confirms the SDK is installed — `dotnet` is the CLI for the .NET runtime"*, or later *"this is encapsulation"*, *"this is a method call"*)
- ✅ Mentor moves to the next single move
- ✅ Mentor does not skip ahead 3 phases

**Common failure modes:**
- ❌ Mentor moves on without naming the concept
- ❌ Mentor races through the rest of the project in one turn
- ❌ Mentor's "what's next" is a code dump, not a single instruction

---

## Pass / fail rubric

| Pass criterion | Pass = |
|---|---|
| **Criterion 1: Scope + time before code** | Turn 1 asks both questions; turn 1 contains zero code |
| **Criterion 2: Learner at the keyboard** | Turn 2 gives one small move and stops. No multi-file paste blocks anywhere in turns 1-3 |
| **Criterion 3: Names a concept** | Turn 3 names at least one concept by name |

**Overall:** All three criteria PASS = test passes. Any single criterion FAIL = test fails.

---

## Last run

| Date | Target | Model | Result | Notes |
|---|---|---|---|---|
| 2026-05-29 (pre-patch) | `cad-hello-console` | Claude Sonnet 4.5 | PARTIAL | Turn 1 pitched `cad-blob-uploader` (open editor file) as "a solid first build" despite learner saying "first project". Turns 2 and 3 passed criteria 1, 2, 3 cleanly. |
| 2026-05-29 (post-patch) | `cad-hello-console` | Claude Sonnet 4.5 | PASS (Turn 1 re-verified) | After adding rule #2 "Honor stated intent over editor context" to Mentor.agent.md, the same setup now redirects from project 5 → project 1 in turn 1 before asking scope+time. Turns 2 and 3 not re-run (the patch only affects turn 1 behavior). |
