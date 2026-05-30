---
name: cad-hello-console
description: |
  CAD track project #1. Learner writes their first C# program: a console app that asks for a
  name and prints a personalized greeting. Establishes the dev loop (edit → save → `dotnet run` →
  see output) and the absolute minimum vocabulary they need for project #2 and beyond:
  variables, methods, classes, namespaces, top-level statements. Auto-load when the learner
  is in `cloud-app-dev/cad-hello-console` or asks to learn C#, .NET, write their first program,
  install .NET, or set up a development environment for the first time.
---

# Project: `cad-hello-console`

> **Track:** Cloud App Development · **Project:** 1 of 9 · **Time:** ~45 minutes (longer if installing .NET for the first time)
>
> A console app that asks for a name and greets the user. The smallest possible thing that proves "I can write, build, and run C# on this machine." Every subsequent CAD project builds on the dev loop established here.

## Project goal

When this project is done, the learner can:

- Open a PowerShell prompt, navigate to a folder, and run `dotnet new`, `dotnet build`, `dotnet run` without referring to notes.
- Read a `Program.cs` file and explain what each line does (the `using`, the namespace inference, top-level statements, `Console.WriteLine`).
- Edit, save, and re-run a C# file and see the change reflected — the **inner loop** of all software development.
- Name three things out loud: *variable*, *method*, *class*. Use each in a sentence about their own code.

## Scope guardrail

This is **C# 101 with a PowerShell prompt and VS Code**. We are not setting up Visual Studio (the IDE), not configuring NuGet feeds, not introducing async, not introducing classes-with-fields-and-constructors (that's project #2), and not introducing tests (that's project #9). One file, top-level statements, one input, one output.

If the learner asks "when do we get to Azure?" — answer honestly: *project #7*. They have six projects to go. The discipline of "smallest first" is the lesson, not a limitation.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Windows 10/11 (MSSA default) | `winver` |
| PowerShell 5.1+ (ships with Windows) or 7+ | `$PSVersionTable.PSVersion` |
| Admin rights to install .NET SDK (one-time) | `whoami /priv` shows `SeBackupPrivilege` enabled or similar |
| ~2 GB free disk for the SDK | `Get-PSDrive C` |

That's it. No Azure subscription, no GitHub account, no IDE other than VS Code.

## Phases

### Phase 1 — Install .NET 8 SDK and verify (~10 min)

**Goal:** Get the .NET 8 SDK installed and confirm `dotnet --version` returns `8.x.x`. This is the only install step in the whole project.

**Commands the learner runs (PowerShell):**
```powershell
# Check if .NET is already installed
dotnet --version
# If you see 8.0.xxx or higher, skip to Phase 2.
# If you see "command not found" or a version < 8, continue.

# Install via winget (easiest)
winget install Microsoft.DotNet.SDK.8

# After install finishes, OPEN A NEW PowerShell window
# (PATH changes don't apply to existing terminals)
dotnet --version
# Should now print 8.0.xxx
```

**Concepts to name out loud:**
- *This is the **.NET SDK*** — "SDK" = Software Development Kit. It bundles the C# compiler, the runtime that *executes* compiled code, and the `dotnet` command-line tool that ties everything together. One install, everything you need to build and run C# code.
- *This is **the runtime vs the SDK*** — you only need the **runtime** to *run* a .NET app someone else built. You need the **SDK** to *build* one yourself. We need the SDK because we're going to build. (Servers in production typically install only the runtime — smaller footprint.)
- *This is **the PATH variable*** — `winget install` adds `dotnet` to a system list of "places PowerShell looks for commands." Existing terminals cached the old PATH; they don't see the new entry until you open a fresh terminal. Name this gotcha now; learners will hit it again with every new tool they install.

**Common gotchas:**
- `dotnet --version` still says "command not found" after install — almost always means "you didn't open a fresh terminal." Close the window. Open a new PowerShell. Try again.
- Winget itself isn't installed (older Windows 10) — fall back to the [official installer](https://dotnet.microsoft.com/download/dotnet/8.0) → Windows x64 SDK.
- Corporate proxy blocks the install — name it as a real-world problem; have the learner check with their IT contact. Don't try to work around it in the session.

**After-action prompt:** *"You typed `dotnet --version` and got a number back. Walk me through what just happened — where did `dotnet` come from, where does it live on disk, and how did PowerShell find it?"*

### Phase 2 — Create, build, and run the default template (~10 min)

**Goal:** Generate a new console project, look at the files .NET created, build it, run it. See "Hello, World!" print. The learner does NOT modify anything yet — this phase is "what did the template give us, and what does each part do?"

**Commands the learner runs (PowerShell):**
```powershell
# Create a folder for this project
cd $HOME
mkdir Projects -Force
cd Projects
mkdir cad-hello-console
cd cad-hello-console

# Generate a console app project in the current folder
dotnet new console

# Look at what was created
Get-ChildItem
# You should see:
#   Program.cs
#   cad-hello-console.csproj
#   obj/   (build intermediates — ignore for now)

# Open in VS Code (or your editor of choice)
code .

# Back in PowerShell: build the project
dotnet build

# Run it
dotnet run
# Expected output: Hello, World!
```

**Open `Program.cs` in VS Code and read it together** — it's three lines:
```csharp
// See https://aka.ms/new-console-template for more information
Console.WriteLine("Hello, World!");
```

That's the entire program. (Yes, really.)

**Concepts to name out loud:**
- *This is **a project*** — the `.csproj` file is the manifest. It tells `dotnet` what kind of thing you're building (a console app, an API, a library), what version of .NET to target, and what packages to depend on. Open it; it's tiny right now. Every CAD project from here on adds lines to its `.csproj`.
- *This is **top-level statements*** — older C# required you to wrap your code in `class Program { static void Main(string[] args) { ... } }`. .NET 6+ lets you write the inside-of-Main code directly. The compiler generates the wrapper for you. Name the magic; in project #3 we'll see a hint of the older form again.
- *This is **`Console.WriteLine`*** — `Console` is a built-in **class**, `WriteLine` is a **method** on that class. The dot says "give me the WriteLine thing that belongs to Console." This is the dot operator. They will see it ten thousand times in their career — name it the first time.
- *This is **the build → run loop*** — `dotnet build` compiles your source code into an executable. `dotnet run` does build-then-execute as a convenience. In practice you'll mostly use `dotnet run` during development. CI systems run `dotnet build` separately so they can run tests in the middle.

**Common gotchas:**
- `dotnet new console` fails with "the SDK is not installed" — back to Phase 1.
- `Program.cs` in VS Code shows the OLDER full-Main version — you ran an older template. .NET 8's default is top-level statements. Run `dotnet new console --use-program-main` to opt INTO the older form if you ever need to, but the default is correct here.
- `dotnet run` prints garbage Unicode (mojibang on Windows) — `chcp 65001` to switch the console to UTF-8 for the session.

**After-action prompt:** *"You ran one command and a program printed text. Three different programs ran to make that happen \u2014 the C# compiler, the .NET runtime, and your code. What was each one's job?"*

### Phase 3 — Modify the program: ask for a name, greet the user (~15 min)

**Goal:** Replace the hardcoded "Hello, World!" with a real interaction — read the user's name from the console, store it in a variable, print a personalized greeting. Introduces **variables**, **`Console.ReadLine`**, and string interpolation.

**Files touched:** `Program.cs`.

**Replace the contents of `Program.cs` with:**
```csharp
Console.Write("What's your name? ");
string name = Console.ReadLine();
Console.WriteLine($"Hello, {name}! Welcome to C#.");
```

**Run it:**
```powershell
dotnet run
# Output:
#   What's your name? Jay
#   Hello, Jay! Welcome to C#.
```

**Concepts to name out loud:**
- *This is **a variable*** — `string name` declares a slot in memory typed to hold a string (text). `= Console.ReadLine()` fills that slot with whatever the user typed. **Name** the *type-declaration-and-assignment* pattern; it's the most common line of code in any program.
- *This is **string interpolation*** — the `$` before the string and the `{name}` inside it tell the compiler "substitute the value of `name` here." Without the `$`, you'd literally print `Hello, {name}!`. The dollar sign is the magic. Pre-C# 6 you'd write `"Hello, " + name + "!"` — name the upgrade.
- *This is **`Console.Write` vs `Console.WriteLine`*** — `Write` prints without a newline at the end; `WriteLine` adds one. We use `Write` for the prompt so the cursor stays on the same line.
- *This is **types*** — `string` is a **type**. C# is strongly-typed: every variable has a known type at compile time. `int name = Console.ReadLine();` would fail to compile because `ReadLine` returns a string, not an int. Name this; project #2 will lean on it.

**Try one mistake on purpose** — change `string name = ...` to `int name = ...`. Save. Run:
```powershell
dotnet run
# Expected: a compile error mentioning "Cannot implicitly convert type 'string' to 'int'"
```

Name the lesson: **the compiler catches type mistakes before the program runs.** This is one of the biggest reasons C# is used for large systems — wrong types fail at build time, not at 2 AM in production. Revert the change.

**Common gotchas:**
- `Console.ReadLine()` returns `string?` (nullable string) in newer C# — VS Code might underline `name` in yellow with a "may be null" warning. For now, ignore it; we'll address null-handling in project #3 when we introduce the API.
- Forgetting the `$` before the interpolated string — prints `Hello, {name}!` literally. Symptoms learners describe: "the placeholder didn't get replaced." Name it; this is the #1 string-interpolation bug.
- Typing the curly braces in Word's smart-quote mode (somehow) — `\u201c` instead of `"`. Use a real code editor (VS Code), not Word, for source files.

**After-action prompt:** *"You added one new keyword \u2014 `string` \u2014 and two new methods \u2014 `Console.ReadLine` and `Console.Write`. Which of those is a type, which are methods, and how can you tell at a glance?"*

### Phase 4 — Refactor: extract a `Greet` method (~10 min)

**Goal:** Take the greeting logic and move it into its own **method**. Introduces method declaration, parameters, return types, and the concept of "code that you call by name."

**Files touched:** `Program.cs`.

**Replace `Program.cs` with:**
```csharp
Console.Write("What's your name? ");
string name = Console.ReadLine();
string greeting = BuildGreeting(name);
Console.WriteLine(greeting);

// Method definition (can live below the top-level statements)
static string BuildGreeting(string personName)
{
    return $"Hello, {personName}! Welcome to C#.";
}
```

**Run it:**
```powershell
dotnet run
# Output unchanged from Phase 3 \u2014 same input, same output.
```

**Concepts to name out loud:**
- *This is **a method*** — `BuildGreeting` is a block of code with a name. You **call** a method by writing its name followed by parentheses with arguments. `BuildGreeting(name)` says "run the BuildGreeting code with `name` as input, give me the result back."
- *This is **a parameter*** — `string personName` inside the parentheses declares a slot that gets filled in *each time the method is called*. The variable `name` (outside the method) and the parameter `personName` (inside the method) are different slots that happen to hold the same value during the call.
- *This is **a return type*** — `string` before `BuildGreeting` says "this method, when it finishes, hands back a string." `void` would mean "hands back nothing." The `return` keyword does the handing-back.
- *This is **`static`*** — for top-level-statements files, helper methods need to be `static`. We'll un-name `static` for real in project #2 when we introduce classes. For now: "the template requires it, here it is."
- *This is **why refactor*** — Phase 3's code worked. Phase 4 does the same thing. So why? Because *named, reusable pieces* are how programs scale beyond 20 lines. The discipline of "if this logic exists, give it a name" is the difference between hobby code and professional code. Name it.

**Common gotchas:**
- Forgetting `return` inside the method — compile error: "not all code paths return a value." Name it: the compiler statically verifies that every path through the method ends with a `return`.
- Calling the method with the wrong type — `BuildGreeting(42)` — compile error. Strong typing again. Revert and move on.
- Forgetting `static` — compile error about "local function definitions are not allowed in top-level statements" or similar. Add `static`. Don't fight it; we explain why in #2.

**After-action prompt:** *"You changed two lines of code and it ran exactly the same. So what did you gain? Pretend you have to add a *second* kind of greeting (formal vs casual) \u2014 walk me through how Phase 3's code vs Phase 4's code would handle that."*

## When to break the method

- Learner has prior coding experience (Python, JavaScript, anything) — collapse Phases 1–3 into a 15-minute walkthrough and spend the real time on Phase 4 + naming the C#-specific differences (strong typing, `static`, `Console.WriteLine` vs `print`).
- Learner is on macOS or Linux — `winget` doesn't apply; use the .NET installer or `brew install dotnet-sdk` / `apt install dotnet-sdk-8.0`. Everything else in the project works identically.
- Learner asks "can I use Visual Studio instead of VS Code?" — yes, but warn them: Visual Studio (the full IDE) is heavier, takes longer to start, and **the CAD track uses VS Code as the baseline** for consistency with all the other Microsoft training material they'll see. They can switch later if they want.
- Learner finishes Phase 4 with 20 minutes to spare — extend with: add a second method `BuildFarewell(string name)` and call it after the greeting. Same pattern, more reps.

## Definition of done

The learner can demonstrate, observably:

1. Open a fresh PowerShell prompt → `dotnet --version` returns 8.x — no notes, no Google.
2. From scratch: `dotnet new console` in a new folder, `dotnet run`, see "Hello, World!" — no notes.
3. Modify `Program.cs` to ask for a name and greet the user — no notes.
4. Explain, in their own words, what a *variable*, a *method*, and a *class* are (even though we only built methods, not classes — they should know `Console` is a class and what that means).

## Next steps

When done, the learner is ready for **[`cad-todo-cli`](../cad-todo-cli/SKILL.md)** (project #2) — extend the dev loop from "one input, one output" to "a real interactive program with persistent state, multiple features, and code organized into more than one file."
