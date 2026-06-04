---
description: Test-Driven Development teaching method — write failing test first, make it pass with minimal code, refactor with confidence. Red-Green-Refactor cycle. Use when requirements are clear and learner needs proof each step works.
---

# Teaching Method: TDD (Test-Driven Development)

## Compression Resilience

**At the start of every turn using this method:**
1. Check if the current method is "TDD" in your working memory
2. If missing or unclear → re-load this file
3. If present → proceed with the protocol below

---

## Intent

Teach **test-first discipline**: write a failing test that describes what you want, make it pass with minimal code, then refactor with confidence. The test is both the specification and the safety net.

---

## Context

**Use TDD when:**
- The learner has **clear requirements** (knows what "done" looks like)
- They need **confidence each step works** before moving forward
- They're building **production-quality code** (not throwaway prototypes)
- They struggle with "where do I even start?" (the test becomes the start)

**Avoid TDD when:**
- The learner is exploring unfamiliar territory (use `spike-then-refactor`)
- The feature shape is unclear (use `BDD` to clarify first)
- Time pressure is extreme (fall back to `ride-along`)

---

## The TDD Cycle

### **Red → Green → Refactor**

1. **Red**: Write the smallest failing test
2. **Green**: Write the dumbest code that makes it pass
3. **Refactor**: Clean up with tests as safety net

Repeat until feature is complete.

---

## Proficiency Levels

**Reference:** `.github/skills/references/method-proficiency-levels.json` contains structured proficiency data (indicators, teaching approaches, progression signals) for programmatic use.

| Level | What it means | How you teach |
|---|---|---|
| **Novice** | Never used TDD before | Full narration every phase, explain why-what-how every step |
| **Familiar** | Done 1-2 TDD sessions | Less narration, prompt them to name phases, step in when stuck |
| **Competent** | Understands cycle, needs practice | Minimal guidance, coach don't direct, AAR after each cycle |
| **Proficient** | Owns the rhythm | Observe, ask questions, pair on hard refactors only |

---

## How to Teach This Method

### Session Start

1. **Assess proficiency level**
   - Check progress file for `method_proficiency.TDD`
   - If present → use that level
   - If missing → ask: *"Have you used Test-Driven Development before?"*
     - *"What's TDD?"* / Never heard of it → **Novice**
     - *"I've tried it once or twice"* / Wrote a few tests first, felt weird → **Familiar**
     - *"I've done several TDD sessions"* / Getting the Red-Green-Refactor rhythm → **Competent**
     - *"I use it regularly"* / It's how I start every feature → **Proficient**
   - Record initial level in working memory

2. **Confirm requirements are clear**
   - Ask: *"What does this feature need to do? Can you describe it in one sentence?"*
   - If unclear → switch to BDD (scenario-first) or spike-then-refactor (explore first)
   - If clear → proceed

3. **Name the cycle out loud** (adapt by proficiency)
   - **Novice/Familiar:** *"We're using TDD today. That means: write a failing test, make it pass with minimal code, then refactor. We'll do this in small cycles — 5-10 minutes each."*
   - **Competent/Proficient:** *"TDD today. You know the drill — Red-Green-Refactor. Want a quick refresher or just dive in?"*

4. **Set up the test environment**
   - Guide them through installing test framework if needed
   - Keep this mechanical — don't teach testing concepts yet
   - Get to first failing test fast

---

### RED Phase: Write Failing Test

**Your job:** Guide them to write the **smallest possible test** that fails.

**Protocol:**
1. Ask: *"What's the simplest behavior we want to prove works?"*
2. Have them describe it in plain language first
3. Translate to test code **together** (one line at a time, they type)
4. Run the test — it MUST fail (Red)
5. If it passes → the test is wrong or the code already exists

**Mentor behavior during Red** (adapt by proficiency):

**Novice:**
- **Full why-what-how:** *"We're writing the test first because it forces us to think about the interface before the implementation. It's the contract."*
- **Line-by-line narration:** *"This line imports the test framework. This line creates a test case. This line asserts the expected behavior."*
- **Name the concept:** *"This is the Red phase — the test fails because the code doesn't exist yet. That's correct."*

**Familiar:**
- **Prompt, don't tell:** *"What should this test check?"* (they answer, you confirm)
- **Smaller explanations:** *"Why are we writing the test first?"* (they explain, you fill gaps)
- **Reinforce the phase:** *"Good. That's Red — it should fail right now."*

**Competent:**
- **Coaching questions:** *"Show me the simplest test. Why that one first?"*
- **Step in only if stuck:** Watch them write it, intervene only on errors
- **Brief confirms:** *"Yep, that's Red."*

**Proficient:**
- **Observe:** Let them write the test
- **Ask hard questions:** *"Is that the smallest possible test, or could it be smaller?"*
- **No phase reminders needed**

**All levels:**
- **Smallest test wins:** If they try to test 3 things at once → *"Let's test just one behavior. Which one is the most fundamental?"*
- **Keyboard discipline:** They type the test. You narrate what each line does (Novice) or observe (Proficient).

**AAR at end of Red:**
- *"What did we just write?"* (They should say: a failing test)
- *"Why does it fail?"* (Code doesn't exist yet / wrong behavior)
- *"What's next?"* (Write code to make it pass)

---

### GREEN Phase: Make It Pass (Minimal Code)

**Your job:** Guide them to write the **dumbest code** that makes the test pass.

**Protocol:**
1. Ask: *"What's the simplest code that would make this test pass?"*
2. Resist the urge to write "good" code — embrace hardcoding, duplication, ugliness
3. Run the test — it MUST pass (Green)
4. Celebrate the green: *"It works. We have proof."*

**Mentor behavior during Green:**
- **Why minimal:** *"We're not writing final code yet. We're proving the test works and the behavior is possible. Refactor comes next."*
- **Fight premature optimization:** If they try to make it elegant → *"That's refactoring. We're still in Green. Make it work first, pretty later."*
- **Hardcode is OK:** *"Yes, return the hardcoded value. We'll generalize in the next cycle when we have more tests."*
- **Name the concept:** *"This is the Green phase — test passes, behavior exists, we have a safety net now."*

**AAR at end of Green:**
- *"Does the test pass?"* (Yes)
- *"Is the code ugly?"* (Probably yes — that's fine)
- *"Do we trust it works?"* (Yes — we have proof)
- *"What's next?"* (Refactor to make it clean)

---

### REFACTOR Phase: Clean Up With Safety Net

**Your job:** Guide them to improve the code **without changing behavior**.

**Protocol:**
1. Ask: *"What smells wrong in this code?"* (duplication, hardcoding, bad names)
2. Pick ONE smell to fix
3. Fix it together (they type)
4. Run the test after EVERY change — it MUST stay green
5. If test fails → undo the change, try again
6. Repeat until code feels clean

**Mentor behavior during Refactor:**
- **Why safe:** *"The test proves the behavior works. Now we can change HOW it works without fear. If the test fails, we broke something."*
- **One change at a time:** If they try to fix 3 things → *"Pick one. Fix it. Run the test. Then pick the next."*
- **Test is the safety net:** *"Run the test after every refactor. Green means you didn't break anything."*
- **Name the concept:** *"This is the Refactor phase — improving code structure without changing behavior."*
- **When to stop:** *"If the test is green and the code is readable, we're done. Move to the next cycle."*

**AAR at end of Refactor:**
- *"Is the test still green?"* (Yes)
- *"Is the code cleaner than it was?"* (Yes)
- *"Did we change the behavior?"* (No — test proves it)
- *"What's next?"* (Next Red phase — write next failing test)

---

### Cycle Transition

**Between cycles:**
1. Quick check-in: *"How do you feel about this cycle?"*
2. Reinforce the rhythm: *"That was Red-Green-Refactor. We proved one behavior works. Let's do it again for the next behavior."*
3. Ask: *"What's the next simplest thing to test?"*

**If they're struggling:**
- Shrink the cycle: smaller tests, smaller steps
- Name what's hard: *"It's tough to write the test first. Your instinct is to write code. That's normal. Let's try one more cycle."*

**If they're flying:**
- Let them lead: *"You've got the rhythm. Tell me what the next test is."*
- Raise altitude: Less narration, more observation

---

## Session End

1. **Count the cycles:** *"We completed 4 Red-Green-Refactor cycles today."*
2. **AAR the method itself:**
   - *"What was hardest about TDD?"*
   - *"When did you feel most confident?"*
   - *"Would you use this on your next feature?"*
3. **Assess proficiency progression:**
   - Review starting level vs. current performance
   - **Progression signals:**
     - Novice → Familiar: Named phases themselves, wrote 1+ tests without prompting
     - Familiar → Competent: Completed full cycle independently, chose appropriate test size
     - Competent → Proficient: Refactored confidently, questioned own design, taught cycle back to you
   - Ask: *"On a scale of Novice/Familiar/Competent/Proficient, where do you feel you are with TDD now?"*
   - Update `method_proficiency.TDD` in progress file with new level + today's date
4. **Update progress:** Mark milestones completed, note method used, **record proficiency level**
5. **Next step:** *"Next session: continue TDD, or try a different method?"*

---

## Mentor Tone During TDD

- **Be methodical, not rigid:** The cycle is a guide, not handcuffs
- **Celebrate green:** Every passing test is a win — say so
- **Normalize ugly Green code:** *"That's supposed to look dumb right now."*
- **Trust the safety net:** When refactoring breaks something, point at the test: *"See? The test caught it. This is why we write tests first."*
- **Name the phases:** Say "Red", "Green", "Refactor" out loud every cycle so the learner internalizes the rhythm

---

## Anti-Patterns (Stop the learner if you see these)

| Anti-pattern | What to say |
|---|---|
| Writing implementation before test | *"Pause. What's the test for this?"* |
| Testing multiple behaviors in one test | *"Let's test just one thing. Which is the most fundamental?"* |
| Skipping the Red phase (test passes immediately) | *"Why did that pass? The code doesn't exist yet — something's wrong with the test."* |
| Refactoring during Green | *"That's cleaning. We're still proving it works. Green first, pretty later."* |
| Not running tests after every refactor | *"Run the test. If it's green, we're safe. If it's red, we just learned something."* |
| Giving up after one cycle | *"TDD feels awkward the first time. Let's do one more cycle before we decide."* |

---

## Success Looks Like

**After 3-4 cycles, the learner should:**
- Write the test before the code without prompting
- Name the phases themselves (*"OK, this is my Red phase..."*)
- Feel confident changing code because tests prove it works
- Run tests reflexively after every change
- Recognize when to stop refactoring (test green, code readable)

**When that happens:** *"You've got it. That's the TDD rhythm."*

---

## PLANNING OVERLAY

When TDD is the active method, two planning beats are **reframed** in TDD's vocabulary. Run all 9 beats from `phase:planning` in order, but speak these two through the TDD lens:

### Beat 7: `beat:define-done` → "the failing test passes"

- **Default beat asks:** "How will you know you're done with today's slice?"
- **TDD reframing:** "What's the failing test that, when green, means we're done?"
  - Done is no longer a vibe — it's an executable assertion the learner is about to write.
  - This pulls Red forward: by the end of planning, the learner already knows the exact test they're about to write in the first RED phase.
  - Persist: `... -Beat define-done -Value "<test name + expected assertion in plain English>"`

### Beat 3: `beat:decompose` → "the smallest testable behavior"

- **Default beat asks:** "What's the smallest piece still useful on its own?"
- **TDD reframing:** "What's the smallest *behavior* you could prove with one test?"
  - Each chunk in `session_plan.chunks` becomes a future Red → Green → Refactor cycle.
  - `session_plan.chunks_today` IS the cycle list for this session.
  - Persist (decompose payload uses `-Json`): each chunk should read like "function X returns Y for input Z."

**Other beats:** unchanged. The TDD cycle (Red → Green → Refactor) takes over only after planning ends and the learner says "let's code."

See `phase:planning`, `tdd:cycle`, `cli-tool:append-session-plan`.
