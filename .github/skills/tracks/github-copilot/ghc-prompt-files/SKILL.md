---
name: ghc-prompt-files
description: |
  GitHub Copilot track project #7. Learner builds 3 reusable `.prompt.md` files with
  YAML frontmatter and `${input:...}` parameters, invokes them from Chat, and builds
  a decision tree for when to use prompt files vs slash commands vs raw chat.
  Auto-load when the learner is in `github-copilot/ghc-prompt-files` or asks how to
  write a prompt file, use a .prompt.md, pass parameters to prompts, or create reusable
  prompts.
---

# Project: `ghc-prompt-files`

> **Track:** GitHub Copilot · **Project:** 7 of 9 · **Time:** ~75 minutes
>
> Custom instructions are silent and always-on. Slash commands are short and built-in. **Prompt files** are the middle layer — reusable templates with parameters that an engineer invokes on demand for repeated multi-step tasks. By the end of this project the learner has built three prompt files for real recurring work, invoked them from Chat, and knows which surface (instruction / prompt file / agent) is right for which kind of task.

## Project goal

When this project is done, the learner can:

- Create a `.github/prompts/<name>.prompt.md` file with YAML frontmatter (`mode`, `description`, `model`).
- Use `${input:variableName}` placeholders that prompt the user when the file is invoked.
- Invoke a prompt file from Chat using `/<name>` or the prompt picker.
- Distinguish when to use a **prompt file** vs a **slash command** vs **raw chat** vs an **instruction file** vs an **agent**.
- Iterate a prompt file based on what came back — adding constraints, examples, format requirements.

## Scope guardrail

This is **3 prompt files for a small Python project + 1 decision tree**. We are not building agents (project #8). The point: muscle memory in "I'll do this task more than 3 times — let's templatize it."

If the learner asks "isn't this just a slash command?" — answer honestly: *slash commands are fixed and built-in. Prompt files are yours, version-controlled with the repo, and accept parameters. The shape is the same; ownership is different*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`ghc-custom-instructions`](../ghc-custom-instructions/SKILL.md) — comfortable with YAML frontmatter | Can read/write a `.instructions.md` file |
| Python 3.10+ and pytest | `pytest --version` |
| A small repo to work in (can be a fresh one or one from an earlier project) | `git init` |

## Phases

### Phase 1 — Identify a repeating task (~10 min)

**Goal:** Pick a task you've done at least twice and would do again. This is the prompt file's reason to exist.

**Brainstorm — what do you find yourself typing into Copilot more than once?** Examples:

- "Generate a CRUD module for a new resource"
- "Add OpenAPI/Swagger doc comments to this endpoint"
- "Write a SQL migration to add a new column with index and default"
- "Convert this synchronous function to async"
- "Generate a docstring with examples for this function"
- "Write a Dockerfile for this Python service"

**Pick three.** They become your three prompt files.

For this project, use these (adjust if you have better candidates):

1. **`scaffold-pytest-fixture`** — generate a pytest fixture for a given class with mocked dependencies.
2. **`write-docstring`** — generate a Google-style docstring for the selected function with type info and examples.
3. **`new-cli-command`** — scaffold a new sub-command in a `click`-based CLI with file, args, tests.

**Concepts to name out loud:**
- *This is **the "I'll do this again" filter*** — anything you'll do once is a one-off chat. Anything you'll do many times is worth a template. The break-even is around 3 uses.
- *This is **the cost-of-templating*** — a prompt file takes ~10 minutes to build and refine. After 3 uses you've saved time. After 30 uses you've saved hours.

**After-action prompt:** *"You picked 3 tasks. Which one are you most likely to use in the next month? That's the one to perfect first."*

### Phase 2 — Build prompt file #1 (~15 min)

**Goal:** A working `.prompt.md` file that takes parameters.

**Create `.github/prompts/scaffold-pytest-fixture.prompt.md`:**

```markdown
---
mode: agent
description: Generate a pytest fixture for the given class with mocked dependencies and one usage example.
model: gpt-4
---

Generate a pytest fixture for the class `${input:className}` from module `${input:modulePath}`.

Requirements:

1. The fixture function name is `${input:className:snake_case}_fixture` (snake_case of the class name).
2. Use `pytest.fixture` decorator with no scope arg (default function scope).
3. For each constructor parameter of the class, decide whether to:
   - Mock it with `unittest.mock.Mock(spec=ActualType)` if it's an object dependency
   - Provide a sensible default literal if it's a primitive (int=0, str="", list=[], dict={})
4. Return the constructed instance, ready to use.
5. After the fixture, generate ONE example test that uses the fixture and asserts the instance is not None.
6. Place all imports at the top of the file in the order: stdlib, third-party, local.

Format:
- Single Python code block.
- No surrounding prose.
- If you don't know the constructor signature, ask me to paste it instead of guessing.
```

**Save. Commit.**

**Invoke it:**
1. Open Copilot Chat.
2. Type `/scaffold-pytest-fixture` (the picker should suggest it from the file name).
3. Copilot prompts for `className` and `modulePath`.
4. Provide `UserService` and `services.users`.
5. Receive the fixture.

**Concepts to name out loud:**
- *This is **`${input:name}` as the parameter prompt*** — when the file is invoked, VS Code asks for each `input:` value. You can also do `${input:name:default}` to provide a default.
- *This is **`mode: agent`*** — the prompt file runs in agent mode, which means Copilot can use tools (read files, write files, run commands). Other modes: `ask` (chat-only, no tools), `edit` (file edits only).
- *This is **the "ask me if you don't know" pattern at the end*** — Copilot's default is to guess. Telling it "ask me" prevents low-quality guesses.

**Common gotchas:**
- File name `my-prompt.prompt.md` → invoked as `/my-prompt`. The `.prompt.md` is stripped.
- File doesn't show in picker → restart the Chat session. VS Code caches the prompt list.
- `${input:className:snake_case}` filter not built-in → that syntax was illustrative. Copilot will respect the natural-language request "use snake_case" without a formal filter.

**After-action prompt:** *"You invoked the prompt file. Did Copilot follow all 6 requirements? Which one did it skip, if any?"*

### Phase 3 — Build prompt file #2 with constraints + examples (~15 min)

**Goal:** A more constrained prompt file with an embedded example showing the desired format.

**Create `.github/prompts/write-docstring.prompt.md`:**

```markdown
---
mode: edit
description: Generate a Google-style docstring for the selected function. Edit mode — modifies the file directly.
---

Generate a Google-style docstring for the function selected in the editor.

Requirements:

1. **Summary line** — one sentence, imperative mood ("Return X" not "Returns X"). End with a period.
2. **Description paragraph** — 1-3 sentences explaining intent if the summary needs amplification. Skip if not.
3. **Args section** — list every parameter with its type and a description. Skip self.
4. **Returns section** — describe what's returned and its type. Skip if `-> None`.
5. **Raises section** — list each exception type that the function can raise (analyze the code body), with the condition. Skip if it raises nothing.
6. **Example section** — exactly ONE realistic example using `>>>` REPL syntax. Pick inputs that exercise the typical case (not the trivial case).

Do NOT add type info that's already in the signature (PEP 484 type hints) unless adding clarification.

Example of the desired format:

```python
def chunk_list(items: list, size: int) -> list[list]:
    """Split a list into chunks of `size` items.

    Args:
        items: The list to chunk.
        size: Maximum items per chunk. Must be positive.

    Returns:
        A list of chunks. Last chunk may have fewer than `size` items.

    Raises:
        ValueError: If size is not positive.

    Example:
        >>> chunk_list([1, 2, 3, 4, 5], 2)
        [[1, 2], [3, 4], [5]]
    """
```

Edit the file in place — modify the function to include the docstring. Do not change the function body.
```

**Save. Commit.**

**Invoke it:**
1. Open a Python file with an undocumented function.
2. Select the function (highlight).
3. In Chat: `/write-docstring`
4. Edit mode runs — proposes a diff that adds the docstring.
5. Accept.

**Concepts to name out loud:**
- *This is **`mode: edit`*** — the prompt file modifies the file directly, doesn't just return text in chat. Useful when you want the result IN the code, not in the conversation.
- *This is **an embedded example as the highest-leverage instruction*** — showing one example of the desired output is worth 10 rules describing it. Copilot pattern-matches against examples reliably.
- *This is **scope-aware prompting*** — "the function selected in the editor" reads from VS Code's current selection. The prompt file knows about the editor state.

**After-action prompt:** *"You showed Copilot ONE example. Compare the result quality vs prompt file #1 (which had no example). What did the example buy you?"*

### Phase 4 — Build prompt file #3 (multi-file output) (~15 min)

**Goal:** A prompt file that creates multiple files at once — controller, model, test.

**Create `.github/prompts/new-cli-command.prompt.md`:**

```markdown
---
mode: agent
description: Scaffold a new sub-command in the click-based CLI with command file, registration, and tests.
---

Scaffold a new sub-command named `${input:commandName}` in the click-based CLI for this repo.

Requirements:

1. **Read `cli/__init__.py`** to find the existing command group and any conventions (decorators, helpers, error handling).
2. **Create `cli/commands/${input:commandName}.py`** with:
   - A click command function decorated with `@click.command(name="${input:commandName}")`
   - Click options/arguments for what the command needs (ask the user what inputs the command takes)
   - The command function body should do `${input:description}` (the work the command performs)
   - Structured logging via `logger = logging.getLogger(__name__)`
3. **Register the command** in `cli/__init__.py` by importing it and adding to the group.
4. **Create `tests/cli/test_${input:commandName}.py`** with pytest tests using click's `CliRunner`:
   - Test the happy path with all required inputs.
   - Test that missing required inputs produce the expected error message.
   - Test the help text (`--help` should mention the description).
5. **Update `README.md`** — add a row to the commands table (if a table exists) with command name and description.

Before generating, READ the relevant files to match existing patterns. Don't invent conventions if they already exist in the repo.
```

**Save. Commit.**

**Invoke it:**
1. Create a tiny click CLI first (or use one you have):
   ```python
   # cli/__init__.py
   import click

   @click.group()
   def cli():
       pass

   if __name__ == "__main__":
       cli()
   ```
2. In Chat: `/new-cli-command`
3. Provide `commandName=greet`, `description=print a greeting for the given name`.
4. Watch Copilot create 3-4 files.
5. Run `python -m cli greet --name Alice` to verify.

**Concepts to name out loud:**
- *This is **agent mode doing multi-file orchestration*** — the prompt file describes the goal; Copilot decides what to read first, what to write, in what order. You provide structure (the requirements list); Copilot provides execution.
- *This is **"read X first" as the highest-impact instruction*** — without it, Copilot invents a CLI structure that doesn't match yours. With it, Copilot matches existing patterns.
- *This is **the limit of prompt files*** — when a task needs persistent persona ("you are an API design reviewer"), agents are better. When a task is a one-shot template, prompt files are right.

**Common gotchas:**
- Prompt file invents conventions because the agent didn't read existing files → add explicit "READ X first" at the top of the requirements.
- Multi-file output fails partially → agent mode is best-effort; you may need to ask "complete the test file too" as a follow-up.
- The command doesn't appear when run → registration in `cli/__init__.py` missed. Check imports.

**After-action prompt:** *"Three files were created from one invocation. What did Copilot have to figure out that the prompt file didn't tell it explicitly?"*

### Phase 5 — Build the decision tree (~10 min)

**Goal:** Codify when to use which surface — write it as a decision tree in a NOTES file.

**Create `cli-vs-prompt-vs-agent.md` (notes, not committed to a real repo):**

```markdown
# When to use which Copilot surface

## Decision tree

Q: Does the rule apply to ALL files in the repo, silently, without invocation?
   → `.github/copilot-instructions.md` (always-on, repo-wide)

Q: Does the rule apply only to specific files, silently, without invocation?
   → `.github/instructions/*.instructions.md` with `applyTo:` (scoped, always-on)

Q: Do I invoke this template on demand for a one-off transformation?
   → Slash command (`/explain`, `/fix`, `/tests`) for common built-in ones
   → `.github/prompts/*.prompt.md` for repo-specific ones

Q: Do I want a persistent persona that does many related tasks across a conversation?
   → Custom agent (`.github/agents/*.agent.md`) — project #8

Q: Do I just want to ask a question once?
   → Raw chat. No need to over-engineer.

## Side-by-side

|                          | Instruction | Prompt file | Agent | Slash cmd |
|--------------------------|:-:|:-:|:-:|:-:|
| Always-on (silent)        | ✅ | ❌ | ❌ | ❌ |
| Invoke on demand          | ❌ | ✅ | ✅ | ✅ |
| Takes parameters          | ❌ | ✅ | ⚠️ | ❌ |
| Multi-turn persona        | ❌ | ❌ | ✅ | ❌ |
| Repo-scoped               | ✅ | ✅ | ✅ | ❌ |
| User-defined              | ✅ | ✅ | ✅ | ❌ |
| Versioned with repo       | ✅ | ✅ | ✅ | ❌ |
```

**Concepts to name out loud:**
- *This is **the surface map*** — every Copilot user eventually trips over "which one do I use?" Having the answer in your head saves the next 6 months of confusion.
- *This is **why prompt files are the middle*** — heavier than slash commands (you own them, they take parameters), lighter than agents (no persistent persona, no tool scoping).

**After-action prompt:** *"You have a decision tree. Walk a real task through it — pick a task from your day job and decide which surface you'd use. Defend the choice."*

## When to break the method

- Learner already uses Copilot heavily → ask them to convert their 3 most common ad-hoc chats into prompt files. The exercise lands harder when the template solves a real annoyance.
- Learner is brand-new to Copilot → skip phase 4 (multi-file agent mode); it's overwhelming. Stick to phases 1-3-5.
- Time short → phases 2-3-5 are the must-do. Phase 4 is depth.

## Definition of done

Observable, the learner can:

- [ ] Show 3 working `.prompt.md` files in `.github/prompts/`.
- [ ] Invoke each one from Chat and produce the expected output.
- [ ] Show one prompt file that took parameters and one that read editor selection.
- [ ] Walk through the decision tree for "I want to add type hints to every function in this file" and pick the right surface.
- [ ] Explain in one sentence each: prompt file vs slash command, agent mode vs edit mode vs ask mode, `${input:name}` parameter prompts.

## Next project

→ [`ghc-custom-agents`](../ghc-custom-agents/SKILL.md) — build a custom Copilot agent with a focused persona (e.g. "API design reviewer"). Learn why the `tools:` field is restrictive not declarative, and why most agents should omit it entirely.
