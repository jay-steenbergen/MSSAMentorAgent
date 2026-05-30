---
name: ghc-chat-driven-debugging
description: |
  GitHub Copilot track project #3. Learner takes a deliberately-buggy Python program,
  uses Copilot Chat `/fix` and `/explain` to walk diagnosis → hypothesis → fix → verify,
  and learns when the AI's first explanation is wrong. Practices the discipline of
  reading the explanation BEFORE accepting the fix. Auto-load when the learner is in
  `github-copilot/ghc-chat-driven-debugging` or asks how to debug with Copilot, use
  `/fix`, use `/explain`, or fix a stack trace with AI.
---

# Project: `ghc-chat-driven-debugging`

> **Track:** GitHub Copilot · **Project:** 3 of 9 · **Time:** ~75 minutes
>
> Debugging is where Copilot Chat earns its keep — and where bad users get burned hardest. "Make it work" produces a fix that suppresses the symptom and hides the bug. Disciplined users walk the loop: paste the error, read the explanation, propose a hypothesis, test the fix, verify. This project drills that loop on a buggy program where the obvious fix is wrong.

## Project goal

When this project is done, the learner can:

- Use `/fix` to propose a fix from a selected piece of broken code.
- Use `/explain` to understand what code does before deciding it's wrong.
- Use `@workspace` to give Chat context about files Copilot can't see.
- Recognize when Copilot's first fix **suppresses the symptom** vs **resolves the root cause** — and steer it to the latter.
- Articulate the debugging loop in 4 words: **observe → hypothesize → test → verify**.

## Scope guardrail

This is **one buggy program, three bug categories, one disciplined debugging loop**. We are not learning a debugger (use the VS Code debugger separately), not writing tests (project #4), not using agents (project #8). The point: Copilot Chat is a debugging tool only if you debug *with* it, not delegate *to* it.

If the learner asks "why don't I just paste the whole error and ask Copilot to fix it?" — answer honestly: *because then you don't know if the fix is right or just plausible. Disciplined debugging is the moat between you and the Stack Overflow copy-paste engineer*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`ghc-copilot-foundations`](../ghc-copilot-foundations/SKILL.md) — Chat panel works | Can open Chat and run a slash command |
| Python 3.10+ | `python --version` |
| A terminal to run the program | `pwsh` or built-in VS Code terminal |

## Phases

### Phase 1 — The buggy program (~10 min)

**Goal:** The learner has the program in their editor and has run it to see the failure.

**Create `bank.py`:**

```python
"""A small bank account simulator with three intentional bugs."""

from dataclasses import dataclass, field

@dataclass
class Account:
    holder: str
    balance: float = 0.0
    transactions: list = field(default_factory=list)

    def deposit(self, amount):
        # Bug 1: no validation that amount is positive
        self.balance += amount
        self.transactions.append(("deposit", amount))

    def withdraw(self, amount):
        # Bug 2: allows balance to go negative
        self.balance -= amount
        self.transactions.append(("withdraw", amount))

    def transfer(self, other, amount):
        # Bug 3: not atomic — if other.deposit throws, money is lost
        self.withdraw(amount)
        other.deposit(amount)


def average_balance(accounts):
    # Subtle bug 4: division by zero if accounts is empty
    total = sum(a.balance for a in accounts)
    return total / len(accounts)


if __name__ == "__main__":
    a = Account("Alice", balance=100)
    b = Account("Bob", balance=50)

    a.deposit(-50)            # Should error but silently shrinks balance
    a.withdraw(1000)          # Should error but goes negative
    a.transfer(b, 30)         # Works for now — but fragile
    print(f"Alice: {a.balance}")
    print(f"Bob: {b.balance}")

    accounts = []
    print(f"Average: {average_balance(accounts)}")  # Crashes
```

**Run it:**
```powershell
python bank.py
```

You should see:
```
Alice: -980.0
Bob: 80.0
Traceback (most recent call last):
  File "bank.py", line ...
ZeroDivisionError: division by zero
```

**Concepts to name out loud:**
- *This is **the value of running the code*** — the bugs aren't all stack traces. Some are wrong values (`Alice: -980.0` should not exist). Eyes on the output is the first debug skill.
- *This is **four bugs, three categories*** — silent wrong behavior (deposit/withdraw), correctness-under-failure (transfer atomicity), and obvious crashes (zero division). Each needs a different debugging move.

**After-action prompt:** *"You ran the program and saw three problems. List them in order of how easy they were to spot. What does that tell you about what production bugs feel like?"*

### Phase 2 — Bug 4 (the crash) with `/explain` then `/fix` (~15 min)

**Goal:** Fix the easy one — but use `/explain` FIRST to practice the discipline.

**Steps:**
1. In the Copilot Chat panel, highlight the `average_balance` function in `bank.py`.
2. In chat: `/explain`
3. Read the explanation. Copilot will describe what the function does and (usually) flag the zero-division risk.
4. Now: `/fix handle the empty list case by returning 0`
5. Copilot proposes a diff. **Review it before accepting.** Check: does it handle the case? Does it break anything else?
6. Accept. Re-run `python bank.py`. The crash should be gone.

**Concepts to name out loud:**
- *This is **`/explain` as the warmup*** — before asking Copilot to change code, ask it to read code. It forces you to verify Copilot understood the function the way YOU understand it. If the explanation is wrong, the fix will be wrong.
- *This is **specifying the fix you want*** — `/fix` alone is vague. `/fix handle the empty list case by returning 0` is steered. Vague prompts produce vague fixes.
- *This is **review-before-accept on every diff*** — chat fixes are NOT inline completions. They land as a diff. You can reject. Always read first.

**After-action prompt:** *"You read `/explain` before `/fix`. What would you have missed if you'd just run `/fix` on its own?"*

### Phase 3 — Bug 1 (silent wrong behavior) — fix the SYMPTOM trap (~15 min)

**Goal:** Watch Copilot propose a symptom-suppressing fix, then steer it toward a real fix.

**Steps:**
1. Highlight the `deposit` method.
2. Chat: `Alice's balance went negative after depositing -50. What's wrong?`
3. Copilot will explain (probably correctly) that `deposit` accepts negative amounts.
4. Now ask: `/fix prevent negative deposits`

   Watch what Copilot proposes. It will likely write something like:
   ```python
   if amount < 0:
       return
   ```
   or
   ```python
   if amount < 0:
       amount = abs(amount)
   ```

   **Both are wrong.** The first silently drops the deposit (no signal to caller). The second silently converts to a deposit of the absolute value (changes intent).

5. Push back in chat: `That silently drops the bad input. The caller has no idea their deposit was ignored. Raise a ValueError instead with a message that explains the requirement.`

6. New fix:
   ```python
   if amount <= 0:
       raise ValueError(f"deposit amount must be positive, got {amount}")
   ```

7. Accept. Re-run `python bank.py`. Now it raises an error on the bad deposit (this is good — the caller can see and handle it).

**Concepts to name out loud:**
- *This is **the symptom-vs-cause distinction*** — Copilot's first instinct is often to make the error go away. That's symptom suppression. A real fix preserves the signal (raises an exception, returns an explicit error) so the bug is visible.
- *This is **why push-back works*** — Copilot is genuinely good at adjusting when you tell it what's wrong with the fix. "That silently drops the input — raise instead" is a one-line steering that changes the answer.
- *This is **why "fail loud" beats "fail silent" in production code*** — a silent failure is a bug that lives forever. A loud failure is a bug that gets fixed.

**After-action prompt:** *"Copilot's first fix would have silently passed your test. What did the silent fix cost the code's user? What did the loud fix give them?"*

### Phase 4 — Bug 3 (transfer atomicity) — when Copilot needs more context (~20 min)

**Goal:** Use `@workspace` and walk a multi-step debugging conversation.

**Set up the failure scenario** by editing the main block:
```python
if __name__ == "__main__":
    a = Account("Alice", balance=100)
    b = "not an account"   # Force the transfer to fail mid-operation

    a.transfer(b, 30)
    print(f"Alice: {a.balance}")
```

**Run:**
```powershell
python bank.py
```

You'll see Alice's balance is 70 — but the transfer failed (Bob didn't get the money because `b` isn't even an Account). Money is lost.

**Steps:**
1. Highlight the `transfer` method.
2. Chat: `/explain transfer and what happens when other.deposit fails`
3. Copilot will explain that withdraw runs first, then deposit, and if deposit throws, the withdraw is not rolled back.
4. Now ask: `/fix make transfer atomic — either both sides succeed or neither happens`
5. Copilot will propose something like:
   ```python
   def transfer(self, other, amount):
       try:
           self.withdraw(amount)
           other.deposit(amount)
       except Exception:
           self.deposit(amount)  # rollback
           raise
   ```
6. Read carefully. Ask: `What if the deposit succeeds but then the rollback line itself fails? Is there a cleaner way?`
7. Copilot may propose validating `other` and `amount` upfront before any mutation — the cleanest pattern.
8. Compare both. Pick the cleaner one. Accept.

**Concepts to name out loud:**
- *This is **the multi-turn debugging conversation*** — one prompt rarely lands the right answer for non-trivial bugs. Keep the conversation going. "What if X?" "Is there a cleaner way?" These follow-ups are where the value compounds.
- *This is **atomicity as a real concept*** — either-both-or-neither. The pattern shows up everywhere in real systems (DB transactions, multi-file writes, cross-service calls). Naming it now means you'll recognize it later.

**Common gotchas:**
- Copilot suggests `try/finally` and you accept blindly → re-read it. Finally runs regardless of exception; usually NOT what you want for rollback (you want to rollback only on failure, not on success).
- Copilot suggests pre-validation but doesn't reset state on partial failure → still a bug. Walk through "what if X fails after Y?" each time.

**After-action prompt:** *"You ended up with cleaner code than Copilot's first proposal. What was the question you asked that got you there?"*

### Phase 5 — Bug 2 (overdraft) — your turn to drive the loop alone (~15 min)

**Goal:** The learner walks the full debugging loop with no help, on `withdraw`.

**The loop:**
1. **Observe** — what's wrong? Run the code, see the output.
2. **Hypothesize** — what's the cause? State it in one sentence before asking Copilot.
3. **Test the hypothesis** — `/explain` the relevant code, see if your hypothesis matches what Copilot says.
4. **Fix** — `/fix` with specific steering. Read the diff. Push back if it's symptom-suppression.
5. **Verify** — run the code with the original failure case AND with a new edge case (e.g. withdraw exactly the balance — should succeed; withdraw balance + 0.01 — should fail).

**Requirements for done:**
- A withdrawal greater than balance raises a `ValueError` with a useful message.
- A withdrawal exactly equal to balance succeeds (leaves balance at 0).
- A withdrawal of 0 raises (it's a meaningless operation).
- A negative withdrawal raises (probably an attempted underflow attack).

**Concepts to name out loud:**
- *This is **the loop as the unit of debugging*** — observe, hypothesize, test, fix, verify. Skip any step and you're guessing.
- *This is **the verify step as the cheap insurance*** — you spent 10 minutes debugging. Spending 30 seconds checking edge cases catches the 80% case where the fix has a new bug.

**After-action prompt:** *"You walked the full loop on `withdraw`. Which step did you find most tempting to skip? What would have happened if you skipped it?"*

## When to break the method

- Learner is an experienced debugger → skip phases 1-2, go straight to phase 3 (the symptom trap). That's where most engineers regress with AI tools.
- Learner has never used a debugger → consider running the VS Code debugger (F5, breakpoint, step) alongside the Copilot loop. They complement each other.
- Time short → phases 1-3-5 are the must-do. Phase 4 (atomicity) is depth.

## Definition of done

Observable, the learner can:

- [ ] Show `bank.py` running with all 4 bugs fixed and clear error messages on edge cases.
- [ ] Use `/explain` on a function and read the explanation before asking for changes.
- [ ] Use `/fix` with a specific steering instruction (not bare `/fix`).
- [ ] Push back on a Copilot fix that suppresses a symptom and get a real fix.
- [ ] Walk the observe → hypothesize → test → fix → verify loop on a new bug without prompting.
- [ ] Explain in one sentence each: symptom vs cause, fail loud vs fail silent, atomicity.

## Next project

→ [`ghc-test-generation`](../ghc-test-generation/SKILL.md) — write a small function, have Copilot generate tests for it, discover the tests pass on a buggy version, then write the test that actually catches the bug. Learn why Copilot tests are a starting line, not a finish line.
