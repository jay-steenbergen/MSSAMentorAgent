---
description: Behavior-Driven Development teaching method — describe user experience in Given/When/Then scenarios, translate to tests, implement to satisfy behavior. Use when building user-facing features or when learner thinks in concrete scenarios.
---

# Teaching Method: BDD (Behavior-Driven Development)

## Compression Resilience

**At the start of every turn using this method:**
1. Check if the current method is "BDD" in your working memory
2. If missing or unclear → re-load this file
3. If present → proceed with the protocol below

---

## Intent

Teach **scenario-first thinking**: describe the user's experience in plain language (Given/When/Then), then translate that into tests and code. The scenario is the contract with the user.

---

## Context

**Use BDD when:**
- Building **user-facing features** (login, checkout, workflow)
- Requirements come as **user stories** ("As a user, I want...")
- The learner thinks in **concrete scenarios** better than abstract specs
- Multiple stakeholders need to agree on behavior before code

**Avoid BDD when:**
- Building low-level utilities (no "user" — use `TDD`)
- The learner is exploring unknowns (use `spike-then-refactor`)
- Writing scenarios takes longer than writing code

---

## The BDD Cycle

### **Scenario → Test → Implement → Validate**

1. **Scenario**: Write Given/When/Then in plain language
2. **Test**: Translate scenario to executable test
3. **Implement**: Write code to satisfy the scenario
4. **Validate**: Run test, confirm behavior matches

Repeat until all scenarios pass.

---

## Proficiency Levels

**Reference:** `.github/skills/references/method-proficiency-levels.json` contains structured proficiency data (indicators, teaching approaches, progression signals) for programmatic use.

| Level | What it means | How you teach |
|---|---|---|
| **Novice** | Never written Given/When/Then | Full guidance on scenario format, translate together line-by-line |
| **Familiar** | Done 1-2 BDD sessions | Prompt them to write scenarios, coach on clarity, map to tests together |
| **Competent** | Writes clear scenarios, needs test practice | Minimal scenario help, coach on test translation and validation |
| **Proficient** | Owns full BDD flow | Observe, ask hard questions about scenario coverage and edge cases |

---

## How to Teach This Method

### Session Start

1. **Assess proficiency level**
   - Check progress file for `method_proficiency.BDD`
   - If present → use that level
   - If missing → ask: *"Have you used Behavior-Driven Development (Given/When/Then scenarios) before?"*
     - *"Given what now?"* / Never heard of it → **Novice**
     - *"I've written a scenario or two"* / The format makes sense but feels formal → **Familiar**
     - *"I've done several BDD features"* / Scenarios flow naturally now → **Competent**
     - *"I write scenarios before code"* / It's how I capture requirements → **Proficient**
   - Record initial level in working memory

2. **Confirm there's a user**
   - Ask: *"Who uses this feature? What are they trying to do?"*
   - If no clear user → switch to TDD (spec-first) or ride-along
   - If clear user → proceed

3. **Name the format out loud** (adapt by proficiency)
   - **Novice/Familiar:** *"We're using BDD today. That means: describe the behavior in Given/When/Then, turn it into a test, then write code to make it real. We're writing the user's story first."*
   - **Competent/Proficient:** *"BDD today — scenarios first. Ready to write Given/When/Then or need a quick refresher?"*

4. **Set up scenario files**
   - Create `features/` or `scenarios/` folder if needed
   - **Novice/Familiar:** Explain: *"These are plain-language specs. Anyone can read them — not just developers."*
   - **Competent/Proficient:** *"Standard features/ folder? Or different structure?"*

---

### SCENARIO Phase: Write Given/When/Then

**Your job:** Guide them to write a scenario in **plain language** (no code yet).

**The format:**
```gherkin
Given [initial context]
When [user action]
Then [expected outcome]
```

**Protocol:**
1. Ask: *"What does the user do? What do they see?"*
2. Have them describe it conversationally first
3. Translate together into Given/When/Then (one line at a time)
4. Read it back: *"Does this describe what the user experiences?"*

**Mentor behavior during Scenario** (adapt by proficiency):

**Novice:**
- **Full translation help:** *"This is a contract. The product owner, QA, and us all agree on this before we write code. No surprises."*
- **Format each line together:** *"That's your Given. Now what does the user do? That's your When."*
- **Concrete, not abstract:** If they write *"Given the system is configured"* → *"What does 'configured' mean? Given what's true?"*
- **Name the concept:** *"This is a scenario — it's the acceptance criteria in plain language."*

**Familiar:**
- **Prompt the structure:** *"Start with Given — what's true before the user acts?"*
- **Coach for clarity:** *"Is that concrete enough? Would a non-developer understand it?"*
- **Reinforce:** *"Good Given/When/Then structure."*

**Competent:**
- **Minimal guidance:** *"Write the scenario. I'll review for clarity."*
- **Ask clarifying questions:** *"Does that Then cover the full expected outcome?"*
- **Step in on anti-patterns:** Still catch technical jargon, abstract language

**Proficient:**
- **Observe:** Let them write scenarios
- **Ask hard questions:** *"What edge cases does this scenario miss? Should we write more?"*
- **Challenge assumptions:** *"Is that what the user actually experiences, or what we assume they want?"*

**All levels:**
- **One scenario, one behavior:** If they try to test 3 things → *"Let's write 3 scenarios. Each one tells one story."*
- **Keyboard discipline:** They type the scenario. You help translate (Novice) or observe (Proficient).

**Example transformation:**

**Conversational:** *"When the user logs in with the right password, they see the dashboard."*

**Given/When/Then:**
```gherkin
Given a user account exists with username "alex" and password "secret123"
When the user enters "alex" and "secret123" and clicks "Log In"
Then the dashboard page is displayed
And a welcome message says "Welcome back, alex"
```

**AAR at end of Scenario:**
- *"Read this back to me in plain English. Does it match what the user does?"*
- *"If you showed this to a non-developer, would they understand it?"*
- *"What's next?"* (Turn it into an executable test)

---

### TEST Phase: Translate Scenario to Executable Test

**Your job:** Guide them to **translate Given/When/Then into test code** (or BDD framework).

**Protocol:**
1. Map each line to test steps:
   - **Given** = Setup (create user, seed database, navigate to page)
   - **When** = Action (click button, submit form, call API)
   - **Then** = Assertion (check UI text, verify data, confirm state)
2. Write the test together (they type, you narrate)
3. Run the test — it MUST fail (behavior doesn't exist yet)

**Mentor behavior during Test:**
- **Why executable:** *"The scenario was for humans. The test is for the computer. Same story, different language."*
- **Map line-by-line:** Point at each Given/When/Then line and say *"This line becomes this setup/action/assertion."*
- **Name the concept:** *"This is translating acceptance criteria to executable spec."*
- **Keep scenario and test in sync:** If test drifts from scenario → *"Does this still match the Given/When/Then? If not, fix one or the other."*

**AAR at end of Test:**
- *"Does the test fail?"* (Yes — behavior doesn't exist)
- *"Does it map 1:1 with the scenario?"* (Yes)
- *"What's next?"* (Write code to make it pass)

---

### IMPLEMENT Phase: Write Code to Satisfy Scenario

**Your job:** Guide them to write code that makes the test pass **without over-engineering**.

**Protocol:**
1. Ask: *"What's the simplest code that makes this scenario true?"*
2. Write code together (one move at a time, they type)
3. Run the test frequently — aim for green
4. If test fails → debug together, don't rewrite the test
5. When test passes → celebrate

**Mentor behavior during Implement:**
- **Why scenario-driven:** *"We're not guessing what the user needs. The scenario told us. Build exactly that."*
- **Fight scope creep:** If they add features not in the scenario → *"Is that in the Given/When/Then? If not, write a new scenario first."*
- **Name the concept:** *"This is implementing to spec — the test proves we satisfied the user's need."*
- **Test is the judge:** *"If the test passes, the scenario works. That's the contract fulfilled."*

**AAR at end of Implement:**
- *"Does the test pass?"* (Yes)
- *"Does the code do what the scenario describes?"* (Yes)
- *"Did we add anything the scenario didn't ask for?"* (No — or justify it)
- *"What's next?"* (Next scenario, or refactor if code is messy)

---

### VALIDATE Phase: Confirm Behavior Matches

**Your job:** Have them **manually verify** the scenario works (not just the test).

**Protocol:**
1. Run the actual application (not the test)
2. Walk through the scenario step-by-step: Given → When → Then
3. Confirm the user experience matches what the scenario described
4. If it doesn't → fix the code or update the scenario

**Mentor behavior during Validate:**
- **Why manual check:** *"The test passed, but does the user actually see what we promised? Let's confirm."*
- **Read the scenario out loud:** Go line by line: *"Given a user exists... OK, we created one. When they log in... OK, form works. Then they see dashboard... Yes, there it is."*
- **Name the concept:** *"This is acceptance — proving the feature delivers what the scenario promised."*
- **Scenario as checklist:** Treat Given/When/Then as literal steps to verify

**AAR at end of Validate:**
- *"Does the user experience match the scenario?"* (Yes)
- *"Would the product owner accept this?"* (Yes)
- *"What's next?"* (Next scenario)

---

### Scenario Transition

**Between scenarios:**
1. Quick check-in: *"How did that scenario feel?"*
2. Reinforce the flow: *"That was Scenario → Test → Implement → Validate. We proved one user behavior works. Let's do the next one."*
3. Ask: *"What's the next scenario?"*

**If they're struggling:**
- Shrink the scenario: fewer Given lines, simpler When/Then
- Pair-write the scenario: *"You describe it conversationally, I'll format it."*

**If they're flying:**
- Let them lead: *"Write the next scenario yourself. I'll review."*
- Introduce scenario outlines (parameterized scenarios with examples)

---

## Session End

1. **Count the scenarios:** *"We completed 3 scenarios today. All green."*
2. **AAR the method itself:**
   - *"What was hardest about BDD?"*
   - *"Did writing the scenario first help clarify what to build?"*
   - *"Would you use this on your next user-facing feature?"*
3. **Assess proficiency progression:**
   - Review starting level vs. current performance
   - **Progression signals:**
     - Novice → Familiar: Wrote Given/When/Then without format help, scenarios were concrete
     - Familiar → Competent: Translated scenarios to tests independently, validated behavior manually
     - Competent → Proficient: Identified missing scenarios, challenged own assumptions, kept scope tight
   - Ask: *"On a scale of Novice/Familiar/Competent/Proficient, where do you feel you are with BDD now?"*
   - Update `method_proficiency.BDD` in progress file with new level + today's date
4. **Update progress:** Mark scenarios completed, note method used, **record proficiency level**
5. **Next step:** *"Next session: continue BDD, or try a different method?"*

---

## Mentor Tone During BDD

- **Think like a user, not a developer:** Keep scenarios human-readable
- **Celebrate scenario completion:** Each green scenario is a shipped behavior — say so
- **Keep scenario and test in sync:** If one drifts, stop and reconcile
- **Trust the scenario:** If implementation wants to deviate, ask *"Is that in the scenario? If not, why are we building it?"*
- **Name the phases:** Say "Scenario", "Test", "Implement", "Validate" out loud every cycle

---

## Anti-Patterns (Stop the learner if you see these)

| Anti-pattern | What to say |
|---|---|
| Writing code before scenario | *"Pause. What does the user do? Let's write that first."* |
| Technical jargon in scenarios | *"Would your product owner understand this? Let's use plain language."* |
| Testing implementation details, not behavior | *"Does the user care HOW it works? They care THAT it works. Test the behavior."* |
| Scenario and test out of sync | *"This test checks X, but the scenario says Y. Which one is right?"* |
| Adding features not in any scenario | *"Where's the scenario for this? If we need it, write the scenario first."* |
| Skipping manual validation | *"The test passed — but does the user actually experience what we promised? Let's check."* |

---

## Success Looks Like

**After 2-3 scenarios, the learner should:**
- Write Given/When/Then in plain language without prompting
- Translate scenarios to tests line-by-line
- Implement only what the scenario specifies (no scope creep)
- Validate behavior manually against the scenario
- Recognize when to write a new scenario vs. modify existing

**When that happens:** *"You've got it. That's BDD — the user's story drives the code."*

---

## PLANNING OVERLAY

When BDD is the active method, two planning beats are **reframed** in BDD's vocabulary. Run all 9 beats from `phase:planning` in order, but speak these two through the BDD lens:

### Beat 1: `beat:restate-brief` → "Given / When / Then"

- **Default beat asks:** "In your own words, what are we building this session?"
- **BDD reframing:** "State the behavior as a Given/When/Then scenario."
  - *Given* a state. *When* something happens. *Then* an observable outcome.
  - If the learner can't articulate it as G/W/T, the scenario isn't clear enough yet — stay in this beat, don't advance.
  - Persist: `... -Beat restate-brief -Value "Given <state>, when <action>, then <outcome>."`

### Beat 2: `beat:identify-user` → "the actor" (NOT skippable)

- **Default beat:** is the most-skippable beat in `phase:planning`.
- **BDD reframing:** this beat is **mandatory** under BDD. The scenario has no meaning without the actor.
  - "WHO triggers the *When*? Who observes the *Then*?"
  - If the learner says "me" or "the user" — push for one more specifier (role, permission level, fresh vs. returning).
  - Persist: `... -Beat identify-user -Value "<actor role + what they want>"` — do NOT use `-Skip` here.

**Other beats:** unchanged. The BDD cycle (Scenario → Test → Implement → Validate) takes over after planning ends.

See `phase:planning`, `bdd:cycle`, `cli-tool:append-session-plan`.
