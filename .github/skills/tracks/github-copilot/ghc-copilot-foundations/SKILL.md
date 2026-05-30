---
name: ghc-copilot-foundations
description: |
  GitHub Copilot track project #1. Learner installs the Copilot extensions, signs in,
  and writes a tiny calculator function with inline completions — learning Tab to accept,
  Esc to reject, Alt+] / Alt+[ to cycle, Ctrl+→ to accept word-by-word, and how to read
  ghost text. Auto-load when the learner is in `github-copilot/ghc-copilot-foundations`
  or asks to install Copilot, set up Copilot, learn the Copilot loop, or understand
  inline completions vs chat vs edit mode.
---

# Project: `ghc-copilot-foundations`

> **Track:** GitHub Copilot · **Project:** 1 of 9 · **Time:** ~60 minutes
>
> The first time you press Tab on a Copilot suggestion that just *works*, you'll think it's magic. The second time, when it accepts a confidently wrong answer, you'll think it's broken. Both reactions skip the part where you learn to drive. This project teaches the loop — accept, reject, cycle, partial-accept — on a small calculator you build alongside.

## Project goal

When this project is done, the learner can:

- Install **GitHub Copilot** and **Copilot Chat** in VS Code and sign in.
- Read the difference between **inline completions** (ghost text in the editor) and **Copilot Chat** (side panel conversation) and **edit mode** (multi-file changes).
- Use the four keystrokes every Copilot user must own: **Tab** (accept), **Esc** (reject), **Alt+]** / **Alt+[** (cycle alternates), **Ctrl+→** (accept word-by-word).
- Open the **Copilot completions panel** (Ctrl+Enter) to see multiple suggestions at once.
- Articulate when to use inline vs chat vs edit — in one sentence each, at interview level.

## Scope guardrail

This is **one tiny project, four keystrokes, three modes**. We are not customizing Copilot (project #6), not writing prompts (project #7), not building agents (project #8). The point: the basic loop has to be muscle memory before anything else makes sense.

If the learner asks "how do I make Copilot follow my team's style?" — answer honestly: *that's project #6. First master the keystrokes; you'll appreciate why customization matters once you've felt Copilot guess wrong*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| GitHub account with a Copilot license (Free, Individual, or Business) | [github.com/settings/copilot](https://github.com/settings/copilot) shows "Copilot enabled" |
| VS Code 1.85+ installed | `code --version` |
| Python 3.10+ (used for the calculator example) | `python --version` |

## Phases

### Phase 1 — Install, sign in, sanity check (~10 min)

**Goal:** Both Copilot extensions installed and signed in.

**Steps:**
1. **VS Code → Extensions → search "GitHub Copilot" → Install.** This installs both:
   - `GitHub.copilot` (inline completions engine)
   - `GitHub.copilot-chat` (the side-panel chat + slash commands + agents)
2. Bottom-right status bar → click the **Copilot icon** → **Sign in to GitHub**.
3. Browser opens → authorize the extension → return to VS Code.
4. **Sanity check:** create a file `calc.py` and type:
   ```python
   def add(a, b):
   ```
   Pause for ~1 second. You should see **ghost text** appear suggesting `return a + b`. Press **Tab** to accept. If you see ghost text, you're done with setup.

**Concepts to name out loud:**
- *This is **ghost text*** — Copilot's suggestion overlaid on your editor in faded grey. Until you press Tab, nothing is committed.
- *This is **two extensions, one product*** — `copilot` does the inline completions, `copilot-chat` does the conversational side panel. You want both. They share auth but are independently updatable.
- *This is **per-language enablement*** — Copilot can be disabled for specific languages (e.g. you don't want completions while writing Markdown emails). Status bar icon → settings.

**Common gotchas:**
- No ghost text appears → check the status bar icon. If it shows a slash, Copilot is disabled for this file type. Click → enable.
- "Free trial limit reached" → you're on the Free tier and hit the monthly cap (a few thousand completions). Upgrade to Individual ($10/mo) or wait until the next billing cycle.
- Sign-in loop → browser is signed into a different GitHub account than the one with Copilot. Sign out, retry with the right account.

**After-action prompt:** *"You installed two extensions. Why two? What does each do, and what would break if you only had one?"*

### Phase 2 — The four keystrokes (~15 min)

**Goal:** The learner has used Tab, Esc, Alt+] / Alt+[, and Ctrl+→ deliberately at least twice each.

**Set up the playground** — append to `calc.py`:
```python
def subtract(a, b):
```

**Drill 1 — Tab to accept:** Pause. Ghost text appears. Press **Tab**. Code is committed.

**Drill 2 — Esc to reject:** Type a new line:
```python
def multiply(a, b):
```
Ghost text appears. Press **Esc**. Ghost text disappears. Nothing committed.

**Drill 3 — Alt+] to cycle to the next alternate:** Type:
```python
def divide(a, b):
```
Ghost text appears (likely `return a / b`). Press **Alt+]** — a different suggestion appears (likely with a zero-check). Press **Alt+]** again — another alternate. Press **Alt+[** to go back. Press **Tab** when you like one.

**Drill 4 — Ctrl+→ to accept word-by-word:** Type:
```python
def power(base,
```
Ghost text suggests something like `exponent): return base ** exponent`. Instead of accepting the whole thing, press **Ctrl+→** — only the next word is accepted. Press again — the next word. This is how you take what's useful and leave the rest.

**Concepts to name out loud:**
- *This is **the four-keystroke loop*** — every working Copilot user does these without thinking. Practice them on purpose now, you'll save thousands of bad accepts later.
- *This is **why cycling matters*** — Copilot's first suggestion isn't always its best. The cycle key (`Alt+]`) shows you alternates that often differ meaningfully (e.g. with/without error handling, recursive vs iterative).
- *This is **word-by-word accept as the "I'll edit it anyway" superpower*** — when the suggestion is 80% right, take the 80% with Ctrl+→ and stop before the wrong part. Beats accepting then deleting.

**Common gotchas:**
- Alt+] doesn't work → some keyboards have the `]` key in a different position; check **Keyboard Shortcuts → search "Copilot: Next Suggestion"** to remap.
- Tab accepts the wrong thing → you accepted ghost text when you meant to indent. Esc cancels ghost text; you can re-trigger it with **Alt+\\** if you want it back.

**After-action prompt:** *"You used all four keystrokes. Which one was the most surprising — and when will you reach for it in real coding?"*

### Phase 3 — The completions panel (~10 min)

**Goal:** The learner has used Ctrl+Enter to open the completions panel and seen multiple full suggestions side-by-side.

**Steps:**
1. New function in `calc.py`:
   ```python
   def factorial(n):
   ```
2. Pause for ghost text.
3. Press **Ctrl+Enter** — a new panel opens showing 5-10 full alternate completions.
4. Each completion is a different approach (iterative loop, recursive, with input validation, etc.).
5. Click "Accept Solution" on the one you like → it's inserted at the cursor.

**Concepts to name out loud:**
- *This is **the panel as the brainstorm view*** — when you don't know which approach is right, see multiple at once. Especially valuable for non-trivial functions where Copilot's first guess at intent might be wrong.
- *This is **a different cost*** — the panel calls the model more times to generate alternatives. Don't open it for every line. Reserve for genuine decision points.

**After-action prompt:** *"You saw 5 alternate factorials. If two of them differ only by style (loop vs recursion), how do you decide which one to take?"*

### Phase 4 — Inline vs Chat vs Edit (~15 min)

**Goal:** The learner has opened each surface and used each at least once.

**Inline (already comfortable):** ghost text in the editor.

**Chat — open the side panel** (Ctrl+Alt+I on Windows, or click the Copilot icon in the activity bar):
- Type: `Explain what the factorial function does and what edge cases it doesn't handle.`
- Copilot replies in the side panel. You can ask follow-ups.
- Try a **slash command**: type `/explain` then highlight the factorial function in the editor → Copilot explains it.

**Edit mode — multi-file changes** (in the Chat panel, click the **mode dropdown** at the bottom → switch from Ask to Edit):
- Select `calc.py` in the working set.
- Prompt: `Add type hints to every function in this file.`
- Copilot proposes a diff across the file. Review the changes inline, accept or reject each.

**Concepts to name out loud:**
- *This is **inline as "complete what I'm typing"*** — fastest, no leaving the editor. Best for adding the next line, the next argument, the next test case.
- *This is **chat as "explain or design"*** — you stop typing code and talk. Best for "why is this broken," "what does this do," "design me an algorithm."
- *This is **edit as "change this code"*** — Copilot proposes a diff, you review. Best for refactors, multi-file changes, applying a pattern across a codebase.
- *This is **slash commands as shortcuts to common asks*** — `/fix`, `/explain`, `/tests`, `/doc`. Faster than typing the full prompt.

**Common gotchas:**
- Chat panel doesn't open → keyboard shortcut conflict. View → Open View → search "GitHub Copilot Chat".
- `/explain` works on nothing → you didn't have anything selected or open. Highlight code first.
- Edit mode applies changes you didn't expect → always review before accepting. The diff preview is non-destructive.

**After-action prompt:** *"You used all three modes. Tell me in one sentence each: when inline beats chat, when chat beats edit, when edit beats inline."*

### Phase 5 — Build the calculator with intent (~10 min)

**Goal:** Use all four keystrokes and at least two of the three modes to finish the calculator.

**Open the calculator file. You should have:** `add`, `subtract`, `multiply`, `divide`, `power`, `factorial`.

**Tasks:**
1. **Inline + Ctrl+→:** Add a `square_root(n)` function. Accept the suggestion word-by-word, stop before any try/except (you'll add it deliberately).
2. **Chat `/fix`:** Highlight `divide` → in chat: `/fix this function to handle division by zero`. Accept the fix.
3. **Edit mode:** In Edit mode, prompt: `Add a docstring to every function explaining what it does and what it returns. Keep them one line.`
4. **Verify:** open a Python REPL, `import calc`, call each function. Confirm they work.

**Concepts to name out loud:**
- *This is **picking the right surface for each move*** — adding the next function is inline. Fixing one thing is `/fix`. Touching every function is Edit mode. Same product, three jobs.
- *This is **always running the code before declaring done*** — Copilot's confidence is unrelated to its correctness. Run it.

**After-action prompt:** *"Your calculator works. What did Copilot get right first try, and what did it get wrong? What does the wrong-list tell you about where to be skeptical?"*

## When to break the method

- Learner is on Mac → keyboard shortcuts differ (`Cmd` not `Ctrl` for some). Show them the **Keyboard Shortcuts** view; search "Copilot" to see every binding for their OS.
- Learner already uses Copilot daily → skip phases 1-2, jump to phase 4 (the modes comparison is where most daily users have gaps).
- Time short → phases 1-2-4 are the must-do. Phase 3 (completions panel) and phase 5 (build the calculator) are reinforcement.

## Definition of done

Observable, the learner can:

- [ ] Show ghost text appearing in `calc.py` and accept it with Tab.
- [ ] Cycle through at least 2 alternate suggestions with Alt+] / Alt+[.
- [ ] Accept a partial suggestion with Ctrl+→.
- [ ] Open the Copilot Chat panel and run `/explain` on a highlighted function.
- [ ] Run Edit mode on `calc.py` and accept a diff that touches multiple functions.
- [ ] Explain in one sentence each: ghost text, inline vs chat vs edit, slash command, completions panel.

## Next project

→ [`ghc-prompting-for-completions`](../ghc-prompting-for-completions/SKILL.md) — now that the loop is muscle memory, learn to steer completions on purpose: comments-as-prompts, signatures-as-prompts, naming-as-prompts. Five small functions, each prompted deliberately.
