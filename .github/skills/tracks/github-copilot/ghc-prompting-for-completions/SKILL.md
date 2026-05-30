---
name: ghc-prompting-for-completions
description: |
  GitHub Copilot track project #2. Learner builds 5 small functions by steering Copilot's
  inline completions with three prompt levers: comments-as-intent, signatures-as-shape,
  and naming-as-direction. Practices Ctrl+Enter for alternates, the open-tabs context
  trick, and recognizing when Copilot is guessing vs informed. Auto-load when the learner
  is in `github-copilot/ghc-prompting-for-completions` or asks how to steer Copilot,
  prompt inline completions, get better suggestions, use comments as prompts, or use the
  context window.
---

# Project: `ghc-prompting-for-completions`

> **Track:** GitHub Copilot · **Project:** 2 of 9 · **Time:** ~75 minutes
>
> The single biggest skill jump in Copilot use isn't a feature — it's learning that **what you type before the suggestion controls what the suggestion is**. The function name, the signature, the comment above it, and the contents of your other open tabs all feed Copilot's prediction. By the end of this project the learner has built 5 small functions where they steered each one on purpose, and can articulate the three levers they used.

## Project goal

When this project is done, the learner can:

- Steer inline completions using **three levers**: comment above the function (intent), function signature (shape), function name (direction).
- Use the **open-tabs trick** — Copilot reads from currently-open VS Code tabs, so opening a relevant file changes what it suggests.
- Recognize the difference between **Copilot informed** (good context, suggestion makes sense) and **Copilot guessing** (no context, suggestion is generic).
- Use **Ctrl+Enter** to open the completions panel when an inline suggestion looks wrong.
- Articulate why "write better names" beats "write a longer prompt" for inline completions.

## Scope guardrail

This is **5 small functions, three levers, one comparison exercise**. We are not writing tests (project #4), not using chat (project #3), not customizing Copilot (project #6). The point: the muscle memory of "prompt the completion on purpose" instead of "type some code and hope."

If the learner asks "but isn't Copilot Chat better for this?" — answer honestly: *for some tasks, yes — chat is project #3. Inline completions are still the highest-volume Copilot interaction. Most engineers use this surface dozens of times an hour. Getting it right pays the most*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`ghc-copilot-foundations`](../ghc-copilot-foundations/SKILL.md) — the four keystrokes are muscle memory | Can accept, reject, cycle, partial-accept without thinking |
| Python 3.10+ (or pick another language and translate as you go) | `python --version` |

## Phases

### Phase 1 — Lever 1: the comment above the function (~15 min)

**Goal:** Write the comment FIRST, then type the function signature, and watch Copilot's suggestion change.

**Open a new file `prompts.py`.**

**Drill A — no comment:**
```python
def parse(text):
```
Pause for ghost text. Note what Copilot suggests. (Likely something generic — splitting on whitespace, or `json.loads`.)

**Drill B — with a comment that narrows intent:**
```python
# Parse a comma-separated string into a list of integers, ignoring blanks.
def parse(text):
```
Pause for ghost text. The suggestion should now narrow toward `[int(x) for x in text.split(",") if x.strip()]` or similar.

**Drill C — a comment that specifies edge cases:**
```python
# Parse a comma-separated string into a list of integers.
# Raise ValueError with a clear message if any token isn't an integer.
# Strip whitespace around tokens. Ignore empty tokens.
def parse(text):
```
The suggestion should now include `try/except` and a custom error message.

**Concepts to name out loud:**
- *This is **the comment as the prompt*** — Copilot reads everything above your cursor as context. The function name + signature are the headline; the docstring or comment is the body of the prompt. Better body = better suggestion.
- *This is **why "specs in plain English" pay off*** — every edge case you write in the comment is one less thing you have to ask for, fix, or remember. Treat the comment as the contract.
- *This is **how this differs from chat*** — you didn't open chat, didn't type a long prompt. You wrote a comment you'd want in the code anyway, and Copilot used it.

**After-action prompt:** *"Drills A, B, C produced three different functions. The only thing that changed was the comment. What does that tell you about where to invest your typing time?"*

### Phase 2 — Lever 2: the signature (~15 min)

**Goal:** Use parameter names + type hints + return type as the second steering lever.

**Drill A — vague signature:**
```python
def filter(items, x):
```
Suggestion is whatever Copilot thinks `filter` and `x` mean. Usually wrong.

**Drill B — typed, named signature:**
```python
from typing import Iterable
def filter_older_than(users: Iterable[dict], min_age: int) -> list[dict]:
```
Pause for ghost text. The suggestion should now write the right list comprehension because the types tell Copilot what's coming in and what's going out.

**Drill C — even narrower with a `pass` body and a follow-up call:**
```python
def filter_older_than(users: Iterable[dict], min_age: int) -> list[dict]:
    """Return users whose 'age' field is strictly greater than min_age."""
    return [u for u in users if u.get("age", 0) > min_age]

# Quick check
filter_older_than([{"name": "Alice", "age": 30}, {"name": "Bob", "age": 20}], 25)
```
The call after the function tells Copilot how it's meant to be used → next function you write Copilot already knows the shape of `users`.

**Concepts to name out loud:**
- *This is **type hints as Copilot's primary source of truth*** — even more than the comment. Copilot relies heavily on types. Untyped code = worse suggestions. Typed code = sharper suggestions.
- *This is **why a sample call sticks*** — Copilot reads the example above the cursor and learns the data shape. Drop one example into your code and the next 10 functions get better.
- *This is **encoding specificity*** — the more specific your signature, the more Copilot's training has to lock onto. `filter(items, x)` matches millions of patterns. `filter_older_than(users: Iterable[dict], min_age: int) -> list[dict]` matches one.

**After-action prompt:** *"Drill B got a usable answer where Drill A didn't. What's the cheapest change you'd make to your own coding habits to get more of that?"*

### Phase 3 — Lever 3: the function name (~10 min)

**Goal:** See how the function name alone shifts Copilot's behavior.

**Drill — same signature, different names:**

```python
def fetch_user(id: int) -> dict:
```
Suggestion likely involves HTTP / requests / a DB call.

```python
def build_user(id: int) -> dict:
```
Suggestion likely constructs a dict in-memory.

```python
def validate_user(id: int) -> dict:
```
Suggestion likely raises errors or returns a `{"valid": True/False}` result.

```python
def cached_user(id: int) -> dict:
```
Suggestion likely involves a cache lookup-then-fetch pattern.

**Concepts to name out loud:**
- *This is **the name as the verb of intent*** — `fetch`, `build`, `validate`, `cached` each map to a different code pattern in Copilot's training. Pick the verb you mean.
- *This is **why team naming conventions pay off twice*** — they help humans AND they help Copilot. A repo where every reader function starts with `get_` and every writer with `save_` gives Copilot a clearer signal.

**After-action prompt:** *"You wrote four versions with the same signature and different names. If your team named everything `do_user`, what would Copilot's suggestion quality look like?"*

### Phase 4 — The open-tabs trick (~15 min)

**Goal:** Watch what happens to suggestions when you change which tabs are open.

**Setup — create two files:**

`models.py`:
```python
from dataclasses import dataclass

@dataclass
class Product:
    sku: str
    name: str
    price_cents: int
    in_stock: bool

@dataclass
class Order:
    id: int
    products: list[Product]
    customer_email: str
```

`orders.py`:
```python
def total_price(order):
```

**Drill A — only `orders.py` open:** pause for ghost text. The suggestion is generic — maybe `return sum(p.price for p in order.products)` or `return order.total`.

**Drill B — open `models.py` in another tab so Copilot sees it:** delete the function and retype. Now the suggestion should know about `price_cents` (not `price`) and produce `return sum(p.price_cents for p in order.products)`.

**Drill C — close `models.py`:** delete and retype again. The suggestion may revert to generic.

**Concepts to name out loud:**
- *This is **the context window in plain English*** — Copilot doesn't read your whole repo. It reads (a) the file you're typing in, (b) other files you have open in tabs, (c) a small amount of "neighboring" code via similarity search. That's it.
- *This is **why "I'm about to write code that uses module X" → open X first*** — a 5-second habit. Open the relevant file before you write the function that uses it. Free quality boost.
- *This is **why tab hygiene matters*** — too many irrelevant tabs open = noisy context = worse suggestions. Close tabs you're not using.

**Common gotchas:**
- Opened `models.py` but suggestion still generic → tab order matters; recently-opened tabs weight more. Click into `models.py`, then back to `orders.py`.
- Suggestions get worse over time → too many tabs open. Close some.

**After-action prompt:** *"Drill A and Drill B used the same code with different tabs open. What's the rule you just discovered about how Copilot reads context?"*

### Phase 5 — The five-function gauntlet (~20 min)

**Goal:** Build 5 small functions, prompting each one on purpose with the three levers.

**File `gauntlet.py`** — write each of these with a comment above, a typed signature, and a thoughtful name. Use Ctrl+Enter when the first suggestion looks off.

1. **`parse_iso_date(value: str) -> datetime`** — accept ISO-8601 strings, raise `ValueError` for bad input.
2. **`chunked(items: list, size: int) -> list[list]`** — split a list into chunks of N items; last chunk may be smaller.
3. **`mask_email(email: str) -> str`** — turn `alice@example.com` into `a***e@example.com`.
4. **`retry(fn, attempts: int = 3, delay_seconds: float = 1.0)`** — call `fn`, retry on exception up to N times.
5. **`group_by(items: list[dict], key: str) -> dict`** — group a list of dicts by the value of one key.

**Rules:**
- Write the comment FIRST.
- Use type hints in the signature.
- Use a precise verb in the name.
- If the first inline suggestion isn't what you want, press Ctrl+Enter to see alternates.
- Run each function with a sample input in a REPL or `if __name__ == "__main__":` block — verify it works before moving on.

**Concepts to name out loud:**
- *This is **the prompt-and-verify loop*** — every function is two moves: prompt deliberately, verify it works. Both halves are required. Skipping verify = accepting wrong code.
- *This is **what "Copilot informed" feels like*** — the suggestion lines up with the spec you wrote, the types match, and it runs. Once you've felt this, the contrast with "Copilot guessing" is unmistakable.

**After-action prompt:** *"Five functions, five prompts. Which one took the most iterations to get right, and what did you change between attempts? Which one was one-shot? What was different about the one-shot?"*

## When to break the method

- Learner already comfortable with Python type hints → great, this lands fast. Spend more time on phases 4-5.
- Learner uses a language without strong types (raw JavaScript, Bash) → still works; the comment + name levers carry more weight. Type hints lever is weaker.
- Time short → phases 1-2-4 are the must-do. Phase 5 (the gauntlet) is reinforcement.

## Definition of done

Observable, the learner can:

- [ ] Show 5 finished functions in `gauntlet.py` that work when called.
- [ ] Demonstrate Drill A vs Drill B (open-tabs trick) on a fresh pair of files.
- [ ] Explain in one sentence each: comment-as-prompt, signature-as-shape, name-as-direction, the context window, tab hygiene.
- [ ] Use Ctrl+Enter to open the completions panel and pick a non-first suggestion.

## Next project

→ [`ghc-chat-driven-debugging`](../ghc-chat-driven-debugging/SKILL.md) — flip from "write code" to "fix code." Use Copilot Chat with `/fix` and `/explain` on a deliberately-buggy program, learning the diagnosis → hypothesis → fix → verify loop.
