---
name: ghc-custom-instructions
description: |
  GitHub Copilot track project #6. Learner writes `.github/copilot-instructions.md` for
  a small C# Web API and an additional `.instructions.md` file with `applyTo` scoping,
  then verifies Copilot follows the rules by generating new code and watching it match
  the conventions. Auto-load when the learner is in
  `github-copilot/ghc-custom-instructions` or asks how to write copilot-instructions.md,
  use applyTo, scope instructions to file patterns, or make Copilot follow team
  conventions.
---

# Project: `ghc-custom-instructions`

> **Track:** GitHub Copilot · **Project:** 6 of 9 · **Time:** ~75 minutes
>
> The single highest-leverage thing a team can do with Copilot — and the one most teams skip — is write a `.github/copilot-instructions.md`. Every Chat request, every Edit-mode prompt, every code review in this repo gets your team's conventions injected automatically. This project builds one, scopes a second file with `applyTo`, and verifies the rules actually fire.

## Project goal

When this project is done, the learner can:

- Write a `.github/copilot-instructions.md` at repo root that applies to every Copilot interaction.
- Write a scoped `.instructions.md` file with `applyTo:` frontmatter to target specific file patterns.
- Articulate **what kinds of rules work** (specific, behavioral, verifiable) vs **what kinds don't** (vague, aspirational).
- Verify a rule is being followed by running a Copilot prompt and reading the diff.
- Order rules by priority — the rules that fire most often go first.

## Scope guardrail

This is **one root instructions file + one scoped instructions file + verification on a small C# API**. We are not building skills (project #7) or agents (project #8). The point: master the simplest customization primitive first.

If the learner asks "why use instructions over agents?" — answer honestly: *instructions apply to everything in scope automatically and silently. Agents are explicit invocations. Instructions are the bedrock; agents are the specialized tools you reach for*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`ghc-copilot-foundations`](../ghc-copilot-foundations/SKILL.md) — Chat + Edit modes work | Can run `/explain` and Edit-mode |
| .NET 8 SDK installed | `dotnet --version` |
| A throwaway repo to build the API in | `git init` |

## Phases

### Phase 1 — Scaffold the API (~10 min)

**Goal:** A minimal C# Web API exists with one controller and one endpoint.

**Steps:**
```powershell
mkdir TodoApi
cd TodoApi
dotnet new webapi -minimal:false -n TodoApi
git init
git add .
git commit -m "scaffold"
```

Inside the project you'll have a default `WeatherForecastController.cs` and `Program.cs`. Delete the weather forecast files; we want a clean slate.

Create `Controllers/TodosController.cs`:
```csharp
using Microsoft.AspNetCore.Mvc;

namespace TodoApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class TodosController : ControllerBase
{
    [HttpGet]
    public IActionResult GetAll()
    {
        return Ok(new[] { new { Id = 1, Title = "Buy milk" } });
    }
}
```

Run:
```powershell
dotnet run
```

In another terminal:
```powershell
curl http://localhost:5000/api/todos
```

You should see the JSON response. Stop the server.

**After-action prompt:** *"You have a 1-endpoint API. Before adding any conventions, what would your team's coding standards say if you were starting a real project here?"*

### Phase 2 — Write the root instructions file (~25 min)

**Goal:** A `.github/copilot-instructions.md` exists with 5-7 concrete rules.

**Create `.github/copilot-instructions.md`:**

```markdown
# TodoApi — Copilot Instructions

This is a .NET 8 minimal Web API for todo management. When generating code,
follow these conventions strictly. Cite the rule number when you skip one.

## Style and structure

1. **Use record types for DTOs.** All request/response models are `record`, not `class`.
2. **Use `Result<T>` pattern for service returns.** Services return `Result<T>` from
   the `TodoApi.Common` namespace (never throw for expected failures like NotFound or
   ValidationError). Throw only for programmer errors (null where required, etc.).
3. **Use `ILogger<T>` for logging.** Never use `Console.WriteLine`. Always inject
   `ILogger<TheClassName>` and use structured logging: `_logger.LogInformation("Todo {Id} created", todo.Id);`
4. **Use `async`/`await` for all I/O.** Method names end in `Async`. Cancellation
   tokens are always the last parameter.

## API conventions

5. **All controllers end with `Controller`** and inherit from `ControllerBase`.
6. **Use `[ProducesResponseType]` attributes** on every action. List every status
   code the action can return.
7. **Return `IActionResult`** (not `ActionResult<T>`) for consistency across the
   codebase.

## Testing

8. **Use xUnit + FluentAssertions.** Test files mirror source: `TodosController.cs`
   has `TodosControllerTests.cs` in `TodoApi.Tests`.
9. **One Assert per test method when practical.** Multiple assertions per test only
   when they test one logical thing (e.g. status + body together).

## What NOT to do

- Do not use Entity Framework. We use Dapper.
- Do not use `var` for primitive types — only for reference types where the type
  is obvious from the right-hand side.
- Do not add `using System;` etc. — `<ImplicitUsings>enable</ImplicitUsings>` is on.
```

**Concepts to name out loud:**
- *This is **the file Copilot reads on EVERY chat in this repo*** — no `applyTo` needed at repo root. It applies to all files.
- *This is **rules expressed as behavior, not preference*** — "use record types for DTOs" is verifiable. "write clean code" is not. Verifiable rules are the only ones that work.
- *This is **the priority ordering you control*** — rule #1 fires most often, rule #9 least. Put high-frequency rules first; Copilot weights them more.
- *This is **the "what NOT to do" section*** — Copilot's training is biased toward popular patterns (EF Core, var everywhere). Anti-conventions need explicit callouts or they slip through.

**Common gotchas:**
- Writing rules like "be thorough" or "write good code" → ignored, because Copilot can't tell when it's being thorough enough. Always express rules as concrete patterns.
- Too long (over ~50 rules) → Copilot starts ignoring later rules. Keep tight.
- Conflicting rules → undefined behavior. Read the file like a checklist.

**After-action prompt:** *"You wrote 9 rules. Which one is most likely to be ignored by Copilot, and how would you make it harder to ignore?"*

### Phase 3 — Verify the rules fire (~15 min)

**Goal:** Generate a new controller and verify the rules are followed.

**Steps:**
1. Commit the instructions file: `git add .github/copilot-instructions.md && git commit -m "add instructions"`
2. In VS Code, restart the Copilot Chat session (sometimes needed for instructions to load).
3. Open Chat in **Edit mode**.
4. Prompt: `Add a TagsController with full CRUD endpoints for Tag (Id int, Name string). Use the service pattern with an ITagService interface and TagService implementation. Wire it up in Program.cs.`
5. Read the proposed diff. Check:
   - Are DTOs `record` types? (rule 1)
   - Does the service return `Result<T>`? (rule 2 — you'll need to scaffold `Result<T>` first OR Copilot may invent its shape)
   - Are logger calls structured? (rule 3)
   - Are methods `async` with `Async` suffix + cancellation token? (rule 4)
   - Does the class name end in `Controller`? (rule 5)
   - Are `[ProducesResponseType]` attributes present? (rule 6)

**Score the output: how many rules followed / not followed?**

If a rule was skipped, add to chat: `You skipped rule #N (the rule). Please regenerate following all rules from .github/copilot-instructions.md.`

Copilot should re-issue the diff respecting that rule.

**Concepts to name out loud:**
- *This is **the verification step you can't skip*** — instructions are advisory until you check. Trust by default fails silently.
- *This is **how rules teach themselves*** — when you call out a skipped rule, Copilot apologizes and fixes. The fix sticks for the rest of the conversation.
- *This is **why rules need to be SCAFFOLDED*** — rule 2 (Result<T>) referenced a namespace. If `TodoApi.Common.Result<T>` doesn't exist as a real type, Copilot has to invent it. Real code in the repo > rules describing imaginary code.

**After-action prompt:** *"How many of 9 rules did Copilot follow on first try? For the missed ones — were they vague, conflicting, or about code that doesn't exist yet?"*

### Phase 4 — Scoped instructions with `applyTo` (~15 min)

**Goal:** A second `.instructions.md` file with `applyTo` targets only test files.

**Create `.github/instructions/tests.instructions.md`:**

```markdown
---
applyTo: "**/*Tests.cs"
---

# Test file conventions

These rules apply ONLY to files matching `**/*Tests.cs`.

1. **One test class per source class.** Mirror the source file structure.
2. **Use the `Should_<behavior>_When_<condition>` naming pattern.** Example:
   `Should_ReturnNotFound_When_TodoIdDoesNotExist`.
3. **Use the AAA pattern** — `// Arrange`, `// Act`, `// Assert` comments. Even
   for one-line tests, mark Act and Assert.
4. **FluentAssertions over xUnit's Assert.** Use `result.Should().Be(expected)`
   not `Assert.Equal(expected, result)`.
5. **Mock with NSubstitute, not Moq.** Standard for the codebase.
6. **Arrange via test fixtures** — common setup in a constructor, NOT
   `[ClassData]` or static factories.
```

Now in Edit mode:
1. Create the test project: `dotnet new xunit -n TodoApi.Tests` (run from the parent directory).
2. Reference the main project: `dotnet add TodoApi.Tests reference TodoApi`.
3. In Chat: `Write tests for TagsController.GetAll, GetById, Create, Update, Delete. Cover both success cases and the not-found case for GetById/Update/Delete.`

Watch the generated test file. It should:
- Use `Should_X_When_Y` naming (from `tests.instructions.md`, not the root file)
- Use AAA pattern
- Use FluentAssertions
- Use NSubstitute
- Mirror source file structure

**Try a non-test file:** ask Copilot to add a new controller. The test rules should NOT fire — only the root rules apply.

**Concepts to name out loud:**
- *This is **`applyTo` as the glob matcher*** — `"**/*Tests.cs"` matches any file ending in `Tests.cs` at any depth. Other globs: `"src/auth/**/*"`, `"**/*.tsx"`, `"docs/**/*.md"`.
- *This is **layered instructions*** — root file applies always. Scoped files add (or override) for matching files. Both apply when you're in a matching file.
- *This is **why scope matters*** — test files have different conventions than production. A single root file would either bloat (rules for both) or miss (rules for one).

**Common gotchas:**
- `applyTo` matches by file path of the active editor, not of the file being generated → if you're chatting about a test file but have a source file open, the rules don't fire. Open the test file.
- Multiple `.instructions.md` files that conflict → undefined. Don't write contradictory scoped instructions.
- Backslashes in `applyTo` globs → use forward slashes always, even on Windows.

**After-action prompt:** *"You split rules across two files. What's the rule for when to scope vs put it at the root?"*

### Phase 5 — Refine via real use (~10 min)

**Goal:** Use the instructions over 2-3 real interactions, find one rule that's wrong or missing, fix the file.

**Run 3 more prompts**:
1. `Add validation to TagsController.Create — name must be 1-50 chars, not whitespace-only.`
2. `Add a search endpoint to TodosController that filters by title substring.`
3. `Add a health-check endpoint that returns `200 OK` with `{ "status": "healthy" }`.`

**For each, ask:**
- Did Copilot do something the instructions DIDN'T cover? Add a rule for next time.
- Did Copilot follow a rule but it didn't help? Reword the rule.
- Did the test rules conflict with a real test? Adjust the rule.

**Examples of refinements you might add:**
- "When adding validation, use Data Annotations (`[Required]`, `[StringLength]`) for simple cases; use FluentValidation for complex multi-field rules."
- "Health-check endpoints live under `/health`, not `/api/health`. They are not versioned."
- "Search endpoints use query string parameters (`?q=milk`), not POST body."

**Concepts to name out loud:**
- *This is **the instructions file as a living document*** — every "Copilot did something weird" is feedback. Add a rule. Over a few weeks the file converges on your team's actual conventions.
- *This is **the conversation-to-convention pipeline*** — discovered preferences become written rules. Written rules apply automatically. Team learns a new convention by reading the file.
- *This is **why instructions beat onboarding docs*** — instructions actually fire when work happens. Onboarding docs get read once and forgotten.

**After-action prompt:** *"You added 1-2 rules from real use. If your team did this consistently for 3 months, what would the file look like? What does that tell you about the value of writing instructions early?"*

## When to break the method

- Learner is on a different language (Python, TypeScript) → instructions work the same. Adjust the rules for the language conventions but the mechanism is identical.
- Learner already has Copilot in a real repo → use that repo. Adding 5 rules to a real codebase is the highest-impact version of this exercise.
- Time short → phases 2-3-4 are the must-do. Phase 5 (refine via use) can be a follow-up over a week.

## Definition of done

Observable, the learner can:

- [ ] Show `.github/copilot-instructions.md` with 5+ concrete rules at the repo root.
- [ ] Show `.github/instructions/tests.instructions.md` with `applyTo:` frontmatter.
- [ ] Show Copilot following at least 3 specific rules in a generated diff.
- [ ] Identify one rule that didn't fire and explain why (vague / non-existent referenced code / not in scope).
- [ ] Explain in one sentence each: root vs scoped instructions, `applyTo` glob matching, what makes a rule verifiable vs vague.

## Next project

→ [`ghc-prompt-files`](../ghc-prompt-files/SKILL.md) — instructions apply to every chat; prompt files are reusable templates you invoke on demand. Build a `.prompt.md` for a repeated task (e.g. "scaffold a new REST endpoint with controller, tests, and docs") and run it from chat.
