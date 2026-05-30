---
name: ghc-test-generation
description: |
  GitHub Copilot track project #4. Learner has Copilot generate tests for a small function,
  discovers the tests pass on a buggy version (false confidence), then writes the
  bug-revealing test themselves. Teaches the "AI tests as starting line, not finish line"
  discipline. Auto-load when the learner is in `github-copilot/ghc-test-generation` or asks
  how to use Copilot to write tests, generate unit tests, use `/tests`, or evaluate
  AI-generated tests.
---

# Project: `ghc-test-generation`

> **Track:** GitHub Copilot · **Project:** 4 of 9 · **Time:** ~75 minutes
>
> Copilot will happily write you 12 tests for any function. They will all pass. That tells you exactly nothing about whether the function is correct, because Copilot inferred its tests from the function's behavior, not from the function's intent. This project drills the discipline: use `/tests` for the boring 80%, hand-write the test that reveals the bug.

## Project goal

When this project is done, the learner can:

- Use `/tests` (or chat) to generate a unit test file for a function.
- Run the generated tests and confirm they pass.
- Identify whether the tests cover **intent** (what the function should do) or just **behavior** (what the function currently does).
- Write a test that intentionally fails on a buggy implementation — the "bug-revealing test."
- Articulate why "AI-generated tests are a starting point, not a substitute for thinking through edge cases."

## Scope guardrail

This is **one function, two implementations, three rounds of tests**. We are not building a full test suite (that's a software engineering course), not learning pytest deeply (read the docs), not setting up CI (project #6 territory). The point: muscle memory in "trust but verify" for AI-written tests.

If the learner asks "but my company doesn't have time to hand-write tests if Copilot can do it" — answer honestly: *the bug Copilot's tests didn't catch will cost more than the 5 minutes of thinking. Cheap tests that don't catch bugs are negative ROI*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`ghc-chat-driven-debugging`](../ghc-chat-driven-debugging/SKILL.md) — comfortable with `/explain`, `/fix` | Can drive Chat panel |
| Python 3.10+ with pytest installed | `pip install pytest` then `pytest --version` |

## Phases

### Phase 1 — The function (~10 min)

**Goal:** A function exists, with one obvious-looking implementation that has a subtle bug.

**Create `discount.py`:**
```python
"""Apply a percentage discount to a price, with a maximum cap."""


def apply_discount(price_cents: int, discount_percent: int, max_discount_cents: int) -> int:
    """
    Apply a percentage discount to price_cents, but never reduce the price
    by more than max_discount_cents. Return the final price in cents.

    Examples:
        apply_discount(10000, 10, 500)  -> 9500  (10% off = 1000, capped at 500)
        apply_discount(10000, 5, 1000)  -> 9500  (5% off = 500, under the cap)
        apply_discount(10000, 0, 500)   -> 10000 (no discount)
    """
    discount = price_cents * discount_percent // 100
    if discount > max_discount_cents:
        discount = max_discount_cents
    return price_cents - discount
```

**Sanity-run a few examples in a REPL:**
```python
from discount import apply_discount
apply_discount(10000, 10, 500)   # 9500  ✅
apply_discount(10000, 5, 1000)   # 9500  ✅
apply_discount(10000, 0, 500)    # 10000 ✅
```

Looks fine. There ARE bugs hiding. Don't tell the learner what they are yet.

**Concepts to name out loud:**
- *This is **a function that looks correct because the happy path works*** — the happy path is what most tests check. The bugs hide in edge cases (negative inputs, zero inputs, percentages above 100, integer overflow). The hard part of testing is thinking of cases the author didn't.

**After-action prompt:** *"The function looks fine. List three edge cases you'd test before you'd ship this. Don't peek at the bugs yet."*

### Phase 2 — Let Copilot write tests with `/tests` (~15 min)

**Goal:** Generated test file exists and the tests pass.

**Steps:**
1. Highlight the `apply_discount` function in `discount.py`.
2. In Chat: `/tests`
3. Copilot proposes a test file. It might choose pytest or unittest. Accept and save as `test_discount.py`.
4. Run:
   ```powershell
   pytest test_discount.py -v
   ```
5. All tests pass. Green across the board.

**What you'll typically see in the generated file:**
```python
def test_apply_discount_percentage():
    assert apply_discount(10000, 10, 500) == 9500

def test_apply_discount_under_cap():
    assert apply_discount(10000, 5, 1000) == 9500

def test_apply_discount_zero_percent():
    assert apply_discount(10000, 0, 500) == 10000

def test_apply_discount_max_cap():
    assert apply_discount(20000, 50, 1000) == 19000
```

**Concepts to name out loud:**
- *This is **AI-generated tests for the happy path*** — Copilot mirrored the examples in your docstring. Same shape, slightly different numbers. These tests prove the function does what the docstring shows. They don't prove the function is correct.
- *This is **the "all green" trap*** — green tests mean tests pass. They do NOT mean code works. The most expensive production bugs ship with green test suites.

**After-action prompt:** *"All tests passed. Are you confident the function works? Why or why not?"*

### Phase 3 — Ask Copilot to add edge-case tests (~15 min)

**Goal:** Get a second round of tests that targets edge cases — and notice the gaps.

**Steps:**
1. In chat: `Add more tests covering edge cases: negative discount percent, discount percent greater than 100, price of zero, negative price, very large numbers, max_discount_cents of zero.`
2. Copilot proposes more tests. Accept and add to `test_discount.py`.
3. Run pytest again. Watch what happens.

**You'll likely see:**
- A test for `apply_discount(10000, -10, 500)` that asserts the result is `10000` or `11000` (Copilot guessed) — it actually returns `11000` because negative discount * positive price = negative discount, then subtracting a negative = adding. The function silently INCREASES the price.
- A test for `apply_discount(10000, 150, 500)` (discount > 100%) that asserts `9500` because the cap kicks in — actually correct only because of the cap.
- A test for `apply_discount(0, 10, 500)` that asserts `0` — passes, fine.

The interesting case: **the negative discount test.** Whichever value Copilot guessed for the assertion, it likely matches what the function does, NOT what the function should do.

**Concepts to name out loud:**
- *This is **Copilot inferring the spec from the code*** — when Copilot writes the assertion for `apply_discount(10000, -10, 500)`, it runs the code in its head and writes the result. If the code is wrong, the assertion is wrong, and the test "passes" while the bug remains.
- *This is **why generated tests can't catch the bugs in the code they're generated from*** — fundamental limitation. The tests encode the current behavior, not the intended behavior. A real test author would think: "should negative percentages even be allowed?" Copilot doesn't.

**After-action prompt:** *"Look at what Copilot wrote for the negative-discount test. Is the assertion testing what SHOULD happen, or what DOES happen? What's the difference?"*

### Phase 4 — Write the bug-revealing test by hand (~20 min)

**Goal:** The learner writes a test that fails on the current implementation.

**The bug:** `apply_discount(10000, -10, 500)` returns `11000` — the function increased the price by accepting a negative discount. This is wrong by intent (you'd never want a "discount" that makes things more expensive) but the function never validates input.

**Write the test:**
```python
import pytest

def test_apply_discount_rejects_negative_percent():
    """A negative discount percent is nonsensical. Should raise ValueError."""
    with pytest.raises(ValueError, match="discount_percent must be between 0 and 100"):
        apply_discount(10000, -10, 500)

def test_apply_discount_rejects_percent_over_100():
    """A discount over 100% would mean paying the customer. Should raise ValueError."""
    with pytest.raises(ValueError, match="discount_percent must be between 0 and 100"):
        apply_discount(10000, 150, 500)

def test_apply_discount_rejects_negative_price():
    """Negative prices are not valid input. Should raise ValueError."""
    with pytest.raises(ValueError, match="price_cents must be non-negative"):
        apply_discount(-100, 10, 500)
```

**Run pytest. Watch them fail (red).**

**Now fix the function:**
```python
def apply_discount(price_cents: int, discount_percent: int, max_discount_cents: int) -> int:
    if price_cents < 0:
        raise ValueError(f"price_cents must be non-negative, got {price_cents}")
    if not 0 <= discount_percent <= 100:
        raise ValueError(f"discount_percent must be between 0 and 100, got {discount_percent}")
    if max_discount_cents < 0:
        raise ValueError(f"max_discount_cents must be non-negative, got {max_discount_cents}")
    discount = price_cents * discount_percent // 100
    if discount > max_discount_cents:
        discount = max_discount_cents
    return price_cents - discount
```

**Re-run pytest. All green now (including the original happy-path tests).**

**Concepts to name out loud:**
- *This is **the red-green-refactor loop done backwards*** — usually you write a failing test FIRST, then write the code. Here you discovered the missing test AFTER the code existed. Both directions are valid; both rely on the same skill: thinking about what should be true, not what is true.
- *This is **the test as the spec in executable form*** — `test_apply_discount_rejects_negative_percent` is a one-sentence contract: "negative discounts are invalid." Until you wrote it, that contract didn't exist anywhere in the codebase.
- *This is **why hand-written tests catch bugs Copilot tests can't*** — you brought intent. You decided "negative discounts should be illegal." Copilot couldn't have decided that from reading the code.

**After-action prompt:** *"Your hand-written tests caught what Copilot missed. What did you do that Copilot couldn't?"*

### Phase 5 — A workflow you can use forever (~15 min)

**Goal:** Codify the test-with-Copilot workflow as a 4-step routine.

**The workflow:**

1. **Write the function with docstring + examples.** Examples are mini-tests embedded in the doc.
2. **`/tests` for the happy path.** Copilot writes the mirror tests. They pass. This is fine — it covers the boring 80%.
3. **Ask for edge-case tests.** Steered prompt: "tests for [list of edge cases I thought of]." Even if Copilot's assertions are wrong, the test STRUCTURES are useful — you just fix the assertions.
4. **Hand-write the bug-revealing tests.** This is the only step Copilot can't do. Ask: "what should be illegal? what should fail loud? what would surprise the caller?"

**Apply the workflow to a new function — write it now in `discount.py`:**

```python
def best_discount(price_cents: int, discounts: list[int]) -> int:
    """
    Given a price and a list of percentage discounts to choose from,
    return the lowest possible final price (apply only the BEST single discount,
    not all of them together).
    """
```

Run the 4 steps. Compare what you got from `/tests` vs what you hand-wrote.

**Concepts to name out loud:**
- *This is **the routine that scales*** — every function you write for the rest of your career can run this 4-step loop. Copilot saves you typing on the boring 80%, your brain catches the bugs.
- *This is **why the docstring is the highest-leverage thing you can write*** — it drives the function suggestion AND the test suggestions. Good docstrings = good code AND good tests.

**After-action prompt:** *"You ran the workflow on `best_discount`. What did Copilot's tests get right, and what did your hand-written tests catch?"*

## When to break the method

- Learner already TDDs daily → they'll grasp this fast. Spend more time on phase 5 (workflow codification).
- Learner is new to pytest → spend 5 extra minutes on phase 2 explaining the pytest output format. They'll need it.
- Time short → phases 1-2-4 are the must-do. Phase 5 is reinforcement.

## Definition of done

Observable, the learner can:

- [ ] Show a passing test file generated by `/tests`.
- [ ] Show a hand-written test that fails on the original buggy function.
- [ ] Show the fixed function that makes the hand-written tests pass without breaking the originals.
- [ ] Explain in one sentence each: AI tests prove behavior not intent, the all-green trap, the 4-step workflow.

## Next project

→ [`ghc-code-review-with-copilot`](../ghc-code-review-with-copilot/SKILL.md) — flip from "write tests" to "review code." Run Copilot review on a deliberately-flawed PR diff and score every finding as true-positive / false-positive / missed. Learn where AI review beats humans and where it loses badly.
