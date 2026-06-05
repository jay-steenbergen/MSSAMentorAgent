# Test: First-Message Greeting — Bare User Input Path

**Type:** Integration — entry-point regression
**Tests:** `agent:mentor` + `behavior:open-with-mos-joke` + `behavior:01-identify-learner`
**Created:** 2026-06-04
**Why this test exists:** On 2026-06-04 Jay typed `hey` to `@Mentor` and got `Hey. What are we working on?` — a generic greeting with no name, no military riff, no profile load. The agent's session contract said to identify the learner and greet by name, but the agent skipped step 1 entirely. This test pins both paths: name + branch/MOS joke on first message, every time.

---

## Setup

**Given:**
- Profile exists at `.profiles/profiles/mentors/jasteenb/profile.json` with `military.branch = "Marines"`, `military.mos = "2336"`, `preferred_name = "Jay"`
- User signed in as `jasteenb` in VS Code
- Fresh chat window — no prior turns, no seed prompt from the extension
- Mentor agent is loaded (`@Mentor` in chat)

---

## Test Scenarios

Run all three. Each is a separate fresh chat. A pass requires all three.

### Scenario A — bare hello (user-typed entry)

**User types:**

```
@Mentor hey
```

**Pass criteria:**
- [ ] Greets by preferred name (`Jay`)
- [ ] Includes a fresh one-liner riffing on `Marines` + MOS `2336` (Ordnance / EOD-adjacent)
- [ ] Joke is original — not copied from any prior test run or session log
- [ ] Asks how much time + offers continue / new-project picker (per `behavior:open-with-intent`)
- [ ] Does NOT respond with a generic "What are we working on?"

### Scenario B — extension seed (welcome command)

**User invokes:** `MSSA Mentor: Welcome` from Command Palette (fires the extension seed prompt).

**Pass criteria:**
- [ ] Greets by preferred name
- [ ] Includes a *different* military riff than Scenario A (proves non-recycled)
- [ ] Asks how much time + offers picker

### Scenario C — repeat of A in a second fresh chat

**User types in a brand-new chat:**

```
@Mentor hey
```

**Pass criteria:**
- [ ] Greets by preferred name
- [ ] Military riff is **different** from Scenarios A and B (proves mint-per-greeting, not a cached line)

---

## Failure Modes This Test Catches

| Failure | Symptom |
|---|---|
| Agent skips identify-learner on bare input | No name in greeting |
| Joke behavior missing from contract | No military riff |
| Joke cached / scripted | Same riff appears in A and C |
| Extension seed path edited but graph path missed | Scenario B passes, A fails (the 2026-06-04 bug) |
| Profile not loaded | Greeting uses `username` not `preferred_name` |

---

## Actual Result

**Date run:** _not yet run_
**Result:** _pending_

**Notes:** _Run after `behavior:open-with-mos-joke` lands. First run will baseline what the agent actually produces._
