---
description: Spike-then-refactor teaching method — build messy prototype to learn how something works, evaluate what was learned, then throw away or ruthlessly refactor. Use when exploring unfamiliar territory or prototyping complex problems.
---

# Teaching Method: spike-then-refactor

## Compression Resilience

**At the start of every turn using this method:**
1. Check if the current method is "spike-then-refactor" in your working memory
2. If missing or unclear → re-load this file
3. If present → proceed with the protocol below

---

## Intent

Teach **exploratory learning**: build it messy to learn how it works, then throw away or ruthlessly refactor. The spike is for discovery, not delivery.

---

## Context

**Use spike-then-refactor when:**
- The learner is **exploring unfamiliar libraries or APIs**
- They don't know what the solution looks like yet
- The problem space is complex and needs **prototyping**
- "Perfect" code would slow learning (need to see it work first)

**Avoid spike-then-refactor when:**
- Requirements are crystal clear (use `TDD`)
- The learner already knows the pattern (use `ride-along`)
- Time to refactor won't be available (shipping the spike = tech debt)

---

## The Spike-Then-Refactor Cycle

### **Spike → Evaluate → Rebuild or Refactor**

1. **Spike**: Build quick and dirty — hardcode, skip validation, log everything
2. **Evaluate**: What did you learn? What worked? What didn't?
3. **Decide**: Throw away and rebuild properly, OR refactor ruthlessly
4. **Ship**: Clean version only (never ship the spike)

---

## Proficiency Levels

**Reference:** `.github/skills/references/method-proficiency-levels.json` contains structured proficiency data (indicators, teaching approaches, progression signals) for programmatic use.

| Level | What it means | How you teach |
|---|---|---|
| **Novice** | Never spiked before, may feel guilty about messy code | Give explicit permission to be messy, guide evaluation, strong rebuild/refactor coaching |
| **Familiar** | Done 1-2 spikes | Light permission reminders, coach on extraction of lessons, guide decision |
| **Competent** | Comfortable spiking, needs decision practice | Minimal spike guidance, pair on decide phase, challenge evaluation depth |
| **Proficient** | Owns spike discipline | Observe, ask hard questions about time-boxing and lesson extraction |

---

## How to Teach This Method

### Session Start

1. **Assess proficiency level**
   - Check progress file for `method_proficiency.spike_then_refactor`
   - If present → use that level
   - If missing → ask: *"Have you built throwaway prototypes (spikes) before?"*
     - *"I feel guilty deleting code"* / Never deliberately thrown code away → **Novice**
     - *"I've spiked once or twice"* / Still feels wasteful but I see the point → **Familiar**
     - *"I spike when exploring"* / Comfortable with throwaway code → **Competent**
     - *"I spike first, build second"* / It's how I learn new libraries → **Proficient**
   - Record initial level in working memory

2. **Confirm exploration is needed**
   - Ask: *"Do you know how to build this, or are we figuring it out?"*
   - If they know → switch to TDD or ride-along
   - If exploring → proceed with spike

3. **Set expectations: this is throwaway code** (adapt by proficiency)
   - **Novice:** *"We're spiking today. That means: make it work any way possible, learn from it, then throw it away or rewrite properly. The spike is not the product — it's the research. You have explicit permission to write terrible code for the next 30 minutes."*
   - **Familiar:** *"Spike time. Messy code is expected. Focus on learning, not shipping. Sound good?"*
   - **Competent/Proficient:** *"Spike it. You know the drill — answer the question, document lessons, decide rebuild or refactor."*

4. **Define the spike goal**
   - *"What's the ONE question we need to answer with this spike?"*
   - Examples:
     - *"Can this library even do what we need?"*
     - *"How does authentication work in this framework?"*
     - *"What's the data shape we're dealing with?"*
   - Write the question down — it's the spike's success criteria

5. **Time-box the spike**
   - **Novice/Familiar:** *"You have 30 minutes to make something work. Doesn't have to be pretty — just has to answer the question."*
   - **Competent/Proficient:** *"How long do you need? 30-60 minutes max."*

---

### SPIKE Phase: Build Quick and Dirty

**Your job:** Give them **permission to write terrible code** and guide them to learn fast.

**Protocol:**
1. Start with the simplest possible version
2. Hardcode values, skip error handling, ignore edge cases
3. Log everything — `console.log`, `print`, whatever shows what's happening
4. Run it frequently — see output early and often
5. When something works → stop and evaluate (don't keep building)

**Mentor behavior during Spike** (adapt by proficiency):

**Novice:**
- **Explicit permission, frequently:** *"This code is research. We're learning how the library works, not shipping a product. Hardcode everything. Skip validation. Make it ugly — that's the point."*
- **Fight perfectionism hard:** If they try to make it elegant → *"Stop. That's refactoring. We're still figuring out IF it works. Pretty comes later."*
- **Encourage logging:** *"Log everything. We need to see what the API returns, what the data looks like. Console.log is your flashlight."*
- **Name the concept:** *"This is a spike — exploratory code that teaches us how something works."*

**Familiar:**
- **Permission reminder:** *"Remember: messy is correct. We're learning, not shipping."*
- **Redirect perfectionism:** *"Save that for the rebuild. Keep spiking."*
- **Suggest shortcuts:** *"Just hardcode 'test@example.com' for now."*

**Competent:**
- **Minimal interference:** Let them spike
- **Step in on anti-patterns:** If they start writing tests or abstractions → *"That's not spike code. Keep it simple."*
- **Time check:** *"15 minutes left. Focus on answering the question."*

**Proficient:**
- **Observe:** Watch them explore
- **Ask hard questions:** *"Are you still answering the question, or building features?"*
- **Challenge time-boxing:** *"You've been spiking for 45 minutes. Time to evaluate?"*

**All levels:**
- **Keyboard discipline:** They type. You suggest shortcuts (Novice) or observe (Proficient).

**Spike anti-patterns to stop:**
- Writing tests (not yet — we don't know what to test)
- Creating abstractions (premature — we don't know the shape yet)
- Handling edge cases (waste of time — we're learning the happy path first)
- Worrying about naming (it's all getting thrown away anyway)

**AAR at end of Spike:**
- *"Does it work?"* (Yes/No/Partially)
- *"What did you learn?"* (They should name at least 2 discoveries)
- *"What surprised you?"* (Assumptions that were wrong)

---

### EVALUATE Phase: Extract the Learning

**Your job:** Help them **articulate what the spike taught them**.

**Protocol:**
1. Ask: *"What was the question we started with?"* (Read it back from session start)
2. Ask: *"Did we answer it?"* (Yes/No/Partially)
3. Ask: *"What did we learn?"*
   - What worked that we didn't expect?
   - What didn't work that we thought would?
   - What's the actual shape of the solution?
4. Write down the lessons (comments at top of spike file, or separate notes)
5. Ask: *"Knowing what we know now, how would we build this properly?"*

**Mentor behavior during Evaluate:**
- **Why explicit reflection:** *"The spike's value isn't the code — it's what we learned. Let's capture that before we forget."*
- **Contrast before/after:** *"What did you think before the spike? What do you know now?"*
- **Name the concept:** *"This is extracting lessons from the prototype — the spike succeeded if we learned something."*
- **Document lessons:** Have them write 3-5 bullet points of discoveries

**AAR at end of Evaluate:**
- *"Do we understand the problem better now?"* (Yes)
- *"Could we build this properly now?"* (Yes — we know the shape)
- *"What's next?"* (Decide: rebuild or refactor)

---

### DECIDE Phase: Throw Away or Refactor?

**Your job:** Help them choose the right path forward.

**The decision:**

| If the spike... | Then... |
|---|---|
| Has fundamental design flaws | **Throw away** and rebuild with lessons learned |
| Works but is messy | **Refactor** ruthlessly — test-first |
| Revealed the problem is too big | Break into smaller spikes |
| Didn't answer the question | Time-box another spike (shorter, more focused) |

**Protocol:**
1. Review the spike code together
2. Ask: *"Is the structure salvageable, or do we need to start over?"*
3. Decide together:
   - **Rebuild:** Delete the spike file, start fresh with TDD or ride-along
   - **Refactor:** Keep the spike, but rewrite it properly one piece at a time
4. If rebuilding → create new file, reference spike for lessons
5. If refactoring → write tests first, then clean up spike code

**Mentor behavior during Decide:**
- **Why not both:** *"We don't refactor AND rebuild. Pick one. If the bones are good, refactor. If the design is wrong, start over."*
- **No shame in throwing away:** *"The spike did its job — we learned. Now we build the real thing. Deleting code is progress."*
- **Name the concept:** *"This is deciding whether to iterate or restart — both are valid."*

**AAR at end of Decide:**
- *"Are we rebuilding or refactoring?"*
- *"Why that choice?"*
- *"What's the first step?"*

---

### REBUILD or REFACTOR Phase

#### **If Rebuilding:**

**Protocol:**
1. Create new file (don't edit the spike)
2. Keep spike open in another tab for reference
3. Switch to TDD or ride-along method
4. Build it properly using lessons from spike
5. When done → delete or archive the spike

**Mentor behavior:**
- *"The spike is a reference now, not code we're shipping. Let's build it right."*
- *"What did the spike teach us about structure? Let's apply that."*

#### **If Refactoring:**

**Protocol:**
1. Write tests FIRST (even if spike has no tests)
2. Pick one piece of spike to clean up
3. Refactor it (rename, extract functions, remove hardcoding)
4. Run tests after every change
5. Repeat until spike is production-ready
6. Delete spike-specific comments and logs

**Mentor behavior:**
- *"We're turning research code into product code. Tests prove we didn't break the learning."*
- *"One piece at a time. Test after every change."*

**AAR at end of Rebuild/Refactor:**
- *"Is the code production-ready now?"* (Yes)
- *"Do we still have the lessons from the spike?"* (Yes — in tests, structure, comments)
- *"What's next?"* (Ship it or next feature)

---

## Session End

1. **Mark the spike outcome:**
   - *"We completed a spike on [topic]. Learned: [3 key lessons]. Decided to [rebuild/refactor]."*
2. **AAR the method itself:**
   - *"Was it easier to explore without worrying about clean code?"*
   - *"Did the spike answer the question we started with?"*
   - *"Would you spike again when exploring new territory?"*
3. **Assess proficiency progression:**
   - Review starting level vs. current performance
   - **Progression signals:**
     - Novice → Familiar: Spiked without guilt, extracted lessons, accepted throw-away decision
     - Familiar → Competent: Time-boxed independently, documented lessons clearly, decided rebuild/refactor confidently
     - Competent → Proficient: Knew when to stop spiking, challenged own assumptions in evaluation, rebuilt/refactored effectively
   - Ask: *"On a scale of Novice/Familiar/Competent/Proficient, where do you feel you are with spike-then-refactor now?"*
   - Update `method_proficiency.spike_then_refactor` in progress file with new level + today's date
4. **Update progress:** Mark spike completed, note lessons learned, note method used, **record proficiency level**
5. **Next step:** *"Next session: continue building with [TDD/ride-along], or spike something else?"*

---

## Mentor Tone During Spike-Then-Refactor

- **Give permission to be messy:** *"This is supposed to be ugly. That's correct."*
- **Celebrate discoveries, not code quality:** *"You learned X — that's the win, not the code."*
- **Protect the rebuild/refactor time:** Never ship a spike as-is — always rebuild or refactor
- **Name the phases:** Say "Spike", "Evaluate", "Rebuild/Refactor" out loud every cycle
- **Normalize throwing away code:** *"We're not wasting time — we're learning. The spike succeeded."*

---

## Anti-Patterns (Stop the learner if you see these)

| Anti-pattern | What to say |
|---|---|
| Writing tests during spike | *"No tests yet. We don't know what to test. Make it work first, then we'll test the real version."* |
| Refactoring during spike | *"Don't clean it up yet. Make it work ugly, then decide if we throw away or refactor."* |
| Shipping the spike | *"This is research code. We rebuild or refactor before it ships. Never ship a spike."* |
| Spiking without a question | *"What are we trying to learn? Let's write down the question before we start coding."* |
| Spending hours on a spike | *"Time-box it. 30-60 minutes max. If we don't learn something by then, stop and evaluate."* |
| Not documenting lessons | *"The spike is useless if we forget what we learned. Write it down while it's fresh."* |

---

## Success Looks Like

**After 1-2 spikes, the learner should:**
- Build messy prototypes without guilt
- Stop when they've answered the question (not keep building)
- Articulate lessons learned from the spike
- Choose rebuild vs. refactor confidently
- Recognize when to spike (unfamiliar) vs. when to TDD (known problem)

**When that happens:** *"You've got it. Spike when exploring, TDD when building. Now you know both."*

---

## PLANNING OVERLAY

When spike-then-refactor is the active method, two planning beats are **reframed**. Run all 9 beats from `phase:planning` in order, but speak these two through the spike lens:

### Beat 4: `beat:name-unknowns` → "the unknowns ARE the spike's purpose"

- **Default beat asks:** "What do you NOT know yet that you'll need?"
- **Spike reframing:** every unknown listed here is a candidate **spike question**. The spike's job is to answer one of them with throwaway code.
  - If the unknowns list is empty, you don't need a spike — switch to TDD or ride-along.
  - If the list has 5+ items, pick the ONE that blocks everything else.
  - Persist (JSON): each unknown should have `resolution: "spike"` instead of `"research"` or `"assume"`.

### Beat 3: `beat:decompose` → "first the spike, then the clean slice"

- **Default beat asks:** "What's the smallest piece still useful on its own?"
- **Spike reframing:** decompose into **TWO phases**:
  1. **Spike chunk** — the throwaway code that answers the unknown from beat 4. Small, ugly, time-boxed. Goes to `chunks_today[0]`.
  2. **Clean slice** — the real implementation, built once the spike's lesson is known. Goes to `chunks_today[1]` (or deferred to next session).
  - Persist (decompose payload): `chunks_today` should be exactly `["spike: <question>", "clean: <slice>"]`.

**Other beats:** unchanged. The spike cycle (Spike → Evaluate → Decide → Rebuild) takes over once the learner says "let's code" — and beat 7's `done_when` should explicitly include "and the spike code is deleted."

See `phase:planning`, `spike:cycle`, `cli-tool:append-session-plan`.
