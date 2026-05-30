---
name: cad-todo-cli
description: |
  CAD track project #2. Learner extends a console app into a working in-memory TODO manager
  with add/list/complete/remove commands, then refactors the data and behavior out of
  `Program.cs` into a dedicated `Todo` class and a `TodoStore` class. Introduces
  collections (`List<T>`), control flow (`switch`, `while`), file I/O (`File.ReadAllText`,
  `File.WriteAllText`), classes with properties, and the separation-of-concerns discipline
  that makes project #3's API conversion painless. Auto-load when the learner is in
  `cloud-app-dev/cad-todo-cli` or asks to learn collections, file I/O, classes, properties,
  or "how do I organize my C# code into more than one file."
---

# Project: `cad-todo-cli`

> **Track:** Cloud App Development · **Project:** 2 of 9 · **Time:** ~90 minutes
>
> A console TODO app: add tasks, list them, mark them complete, delete them, save to disk so they survive between runs. Same problem shape as project #3 (cad-todo-api), so the modeling work pays off twice — first here in the console, then transplanted behind HTTP.

## Project goal

When this project is done, the learner can:

- Use `List<T>` to hold a collection of objects and walk through it with `foreach`.
- Use a `switch` expression to route a command string to the right behavior.
- Read and write a text file with `File.ReadAllText` / `File.WriteAllText`.
- Define a `class` with **properties** (the `{ get; set; }` shorthand) and a constructor.
- Split code across two `.cs` files in the same project and explain why each one exists.
- Name the **separation-of-concerns** principle and point at the line in `Program.cs` where they enforced it.

## Scope guardrail

This is the **last project before HTTP**. We are not introducing async (project #3), not introducing dependency injection (project #3), not introducing databases (project #4), not introducing JSON serialization frameworks (we'll hand-roll the file format here, then meet `System.Text.Json` in project #3). We *are* introducing classes-with-properties for real — `Todo` is the first real class the learner authors from scratch.

If the learner asks "shouldn't we use a database?" — the honest answer: yes, real programs do. **But** a database adds installation, schema, migrations, and a query language. Doing all that in project #2 would bury the modeling lesson. Files first; databases in #4.

## Prerequisites

| Prereq | Why |
|---|---|
| [`cad-hello-console`](../cad-hello-console/SKILL.md) complete | Knows the build/run loop, knows what a method and a variable are. |
| Comfortable opening files in VS Code | We're going to look at two `.cs` files side by side. |
| ~30 minutes uninterrupted | Phase 4 (refactor into classes) is a "stay in the chair" phase — interruptions break the mental thread. |

## Phases

### Phase 1 — Scaffold and build the command loop (~15 min)

**Goal:** New console project. Replace the body of `Program.cs` with a `while (true)` loop that prints a prompt, reads a command, and prints what command it saw. No real behavior yet — just the **input loop**.

**Commands (PowerShell):**
```powershell
cd $HOME\Projects
mkdir cad-todo-cli
cd cad-todo-cli
dotnet new console
code .
```

**Replace `Program.cs` with:**
```csharp
Console.WriteLine("TODO CLI \u2014 type 'help' for commands, 'quit' to exit.");

while (true)
{
    Console.Write("> ");
    string? input = Console.ReadLine();
    if (input is null) break;            // Ctrl+Z / Ctrl+D \u2014 end of input
    string command = input.Trim().ToLowerInvariant();

    if (command == "quit") break;

    Console.WriteLine($"You typed: {command}");
}

Console.WriteLine("Goodbye.");
```

**Run it:**
```powershell
dotnet run
# > add Buy milk
# You typed: add buy milk
# > quit
# Goodbye.
```

**Concepts to name out loud:**
- *This is **a loop*** — `while (true)` runs the body forever until something inside hits `break`. Loops are how interactive programs work — wait for input, react, wait again. Every shell, every game, every server runs a loop like this.
- *This is **a nullable reference type*** — `string?` (with the question mark) means "this might be null." `Console.ReadLine()` returns null when stdin closes (Ctrl+Z on Windows). The `?` forces the learner to deal with it; we deal with it by checking `is null` and breaking out. Name the `?`; project #3 will lean on it.
- *This is **string normalization*** — `Trim()` removes leading/trailing whitespace, `ToLowerInvariant()` makes the comparison case-insensitive. Without these, `"ADD "` and `"add"` would route to different code paths. Name "normalize before comparing" — it's a discipline learners will use forever.
- *This is **the difference between `==` and `=`*** — `==` compares, `=` assigns. Mixing them up is the #2 C# bug after off-by-one errors. Watch for it; the compiler catches some cases but not all.

**Common gotchas:**
- Forgot the `break` on `quit` — infinite loop. Ctrl+C kills it. Name what they just did: "you hit the kill switch every shell on every OS has." Useful muscle memory.
- `input is null` underlined as a warning in older C# versions — the syntax is C# 8+. .NET 8 ships C# 12, so this is fine. If they see a real error, check the `.csproj` for an unexpected `<LangVersion>` line.

**After-action prompt:** *"Your program runs forever until you type quit. That's the shape of every server you'll ever write \u2014 wait, react, wait, react. What's the part that decides what to do based on input? In Phase 2 we're going to make it actually decide."*

### Phase 2 — Route commands with `switch` (~15 min)

**Goal:** Replace the "you typed X" placeholder with a real **command router**. Add stub methods for `add`, `list`, `complete`, `remove`, and `help`. Each prints a placeholder message for now — Phase 3 fills them in.

**Replace `Program.cs` with:**
```csharp
Console.WriteLine("TODO CLI \u2014 type 'help' for commands, 'quit' to exit.");

while (true)
{
    Console.Write("> ");
    string? input = Console.ReadLine();
    if (input is null) break;

    string[] parts = input.Trim().Split(' ', 2);      // ["add", "Buy milk"]
    string command = parts[0].ToLowerInvariant();
    string argument = parts.Length > 1 ? parts[1] : "";

    if (command == "quit") break;

    switch (command)
    {
        case "help":     ShowHelp();              break;
        case "add":      AddTodo(argument);       break;
        case "list":     ListTodos();             break;
        case "complete": CompleteTodo(argument);  break;
        case "remove":   RemoveTodo(argument);    break;
        default:         Console.WriteLine($"Unknown command: {command}. Type 'help' for the list."); break;
    }
}

Console.WriteLine("Goodbye.");

static void ShowHelp()
{
    Console.WriteLine("Commands:");
    Console.WriteLine("  add <text>      Add a new TODO");
    Console.WriteLine("  list            Show all TODOs");
    Console.WriteLine("  complete <n>    Mark TODO #n as complete");
    Console.WriteLine("  remove <n>      Delete TODO #n");
    Console.WriteLine("  help            Show this message");
    Console.WriteLine("  quit            Exit");
}

static void AddTodo(string text)      => Console.WriteLine($"[stub] Add: {text}");
static void ListTodos()               => Console.WriteLine("[stub] List");
static void CompleteTodo(string arg)  => Console.WriteLine($"[stub] Complete: {arg}");
static void RemoveTodo(string arg)    => Console.WriteLine($"[stub] Remove: {arg}");
```

**Run it:**
```powershell
dotnet run
# > help
# Commands:
#   add <text>      Add a new TODO
#   ...
# > add Buy milk
# [stub] Add: Buy milk
# > quit
```

**Concepts to name out loud:**
- *This is **a switch statement*** — a clean way to route one of many possible values to different code. Better than a chain of `if/else if` for one reason: **intent**. A reader sees `switch (command)` and instantly knows "we're picking one branch based on `command`."
- *This is **a stub*** — a method with a placeholder body. We write stubs to define **the shape of the program** before we write the real logic. Project structure first, then fill it in. Name this; it's how senior engineers actually work.
- *This is **an expression-bodied method*** — `=>` lets you write a one-line method without curly braces. `static void AddTodo(string text) => Console.WriteLine(...);` is equivalent to a full method body with `{ }`. Cleaner for one-liners; never use it for anything longer than one line.
- *This is **`Split(' ', 2)`*** — splits on the first space only, into at most 2 pieces. `"add Buy milk"` → `["add", "Buy milk"]`. Without the `2`, you'd get `["add", "Buy", "milk"]` and the text "milk" would be lost. Name the gotcha; subtle bugs hide here.

**Common gotchas:**
- Missing `break` on a case — C# requires `break` (or `return`) on every case; if missing, the compiler errors. (Unlike C/JavaScript, which fall through silently.) Name this as a good thing.
- Default case in the wrong position — by convention `default` goes last, but the compiler doesn't care. Stick to convention; it's how every reader expects to find it.

**After-action prompt:** *"You wrote five stubs that don't do anything yet. Why is that better than implementing them in order? What does this approach buy you?"*

### Phase 3 — Implement the commands against an in-memory `List<string>` (~20 min)

**Goal:** Replace the stubs with real behavior, backed by a `List<string>`. By the end of this phase, the learner has a working TODO app — minus persistence.

**Replace the bottom half of `Program.cs` (everything from `ShowHelp` down) with:**
```csharp
// The in-memory store \u2014 lives only while the program runs (Phase 5 adds persistence)
List<string> todos = new();

static void ShowHelp()
{
    Console.WriteLine("Commands:");
    Console.WriteLine("  add <text>      Add a new TODO");
    Console.WriteLine("  list            Show all TODOs");
    Console.WriteLine("  complete <n>    Mark TODO #n as complete");
    Console.WriteLine("  remove <n>      Delete TODO #n");
    Console.WriteLine("  help            Show this message");
    Console.WriteLine("  quit            Exit");
}
```

Wait \u2014 we have a **scoping problem**. The four stub methods can't see `todos` because they're `static` and `todos` is in the top-level scope. Solution: remove `static`, move the methods *above* the loop, and put `todos` at the very top. Replace the **entire** `Program.cs` with:

```csharp
List<string> todos = new();

Console.WriteLine("TODO CLI \u2014 type 'help' for commands, 'quit' to exit.");

while (true)
{
    Console.Write("> ");
    string? input = Console.ReadLine();
    if (input is null) break;

    string[] parts = input.Trim().Split(' ', 2);
    string command = parts[0].ToLowerInvariant();
    string argument = parts.Length > 1 ? parts[1] : "";

    if (command == "quit") break;

    switch (command)
    {
        case "help":     ShowHelp();              break;
        case "add":      AddTodo(argument);       break;
        case "list":     ListTodos();             break;
        case "complete": CompleteTodo(argument);  break;
        case "remove":   RemoveTodo(argument);    break;
        default:         Console.WriteLine($"Unknown command: {command}. Type 'help' for the list."); break;
    }
}

Console.WriteLine("Goodbye.");

// \u2014\u2014\u2014\u2014 Local functions (can see `todos`) \u2014\u2014\u2014\u2014

void ShowHelp()
{
    Console.WriteLine("Commands:");
    Console.WriteLine("  add <text>      Add a new TODO");
    Console.WriteLine("  list            Show all TODOs");
    Console.WriteLine("  complete <n>    Mark TODO #n as complete");
    Console.WriteLine("  remove <n>      Delete TODO #n");
    Console.WriteLine("  help            Show this message");
    Console.WriteLine("  quit            Exit");
}

void AddTodo(string text)
{
    if (string.IsNullOrWhiteSpace(text))
    {
        Console.WriteLine("Usage: add <text>");
        return;
    }
    todos.Add(text);
    Console.WriteLine($"Added: {text} (#{todos.Count})");
}

void ListTodos()
{
    if (todos.Count == 0)
    {
        Console.WriteLine("(no TODOs)");
        return;
    }
    for (int i = 0; i < todos.Count; i++)
    {
        Console.WriteLine($"  {i + 1}. {todos[i]}");
    }
}

void CompleteTodo(string arg)
{
    if (!TryParseIndex(arg, out int index)) return;
    string done = todos[index];
    todos.RemoveAt(index);
    Console.WriteLine($"Completed: {done}");
}

void RemoveTodo(string arg)
{
    if (!TryParseIndex(arg, out int index)) return;
    string removed = todos[index];
    todos.RemoveAt(index);
    Console.WriteLine($"Removed: {removed}");
}

bool TryParseIndex(string arg, out int zeroBasedIndex)
{
    zeroBasedIndex = -1;
    if (!int.TryParse(arg, out int oneBased) || oneBased < 1 || oneBased > todos.Count)
    {
        Console.WriteLine($"Invalid index '{arg}'. Use 'list' to see valid numbers.");
        return false;
    }
    zeroBasedIndex = oneBased - 1;
    return true;
}
```

**Run it:**
```powershell
dotnet run
# > add Buy milk
# Added: Buy milk (#1)
# > add Walk dog
# Added: Walk dog (#2)
# > list
#   1. Buy milk
#   2. Walk dog
# > complete 1
# Completed: Buy milk
# > list
#   1. Walk dog
# > quit
```

**Concepts to name out loud:**
- *This is **`List<T>`*** — a resizable array of `T`. `List<string>` holds strings, `List<int>` holds ints. The `<T>` is **generics**: write the list code once, reuse it for any element type. Name generics now; they're everywhere in C#.
- *This is **a local function*** — defined inside `Program.cs`'s top-level scope, NOT static. Because it's not static, it can read and write the `todos` variable above it. Local functions are the natural fit for project-#1-style code where you want methods but don't yet need classes. **Project #2 Phase 4 will replace these with a real class** — name that this is a stepping-stone.
- *This is **`int.TryParse`*** — the safe way to parse an integer. Returns `true` if it worked, `false` if not, and writes the parsed value to the `out` parameter. Pattern: `if (!int.TryParse(arg, out int n)) return;` — fail fast on bad input.
- *This is **off-by-one*** — humans count from 1 (`1. Buy milk`), arrays count from 0 (`todos[0]`). `TryParseIndex` does the conversion in **one place** so the rest of the code uses 0-based indexes consistently. Naming "off-by-one" as a category of bug is half the cure.
- *This is **input validation at the boundary*** — every command method checks its input *first*, prints a usage message *then* returns. The validation lives at the boundary between user input and program logic. Name this; it's a discipline that scales to projects #3 (model validation) and #5 (authorization).

**Common gotchas:**
- Forgetting to remove `static` from the methods when introducing `todos` — compile error: "the name 'todos' does not exist in the current context." Name the rule: `static` methods can only see *static* state. We removed `static`; problem solved.
- `complete 0` succeeds — `int.TryParse("0", ...)` returns true. That's why the explicit `oneBased < 1` check is in `TryParseIndex`. Test bad input; that's how learners build the habit of defensive coding.

**After-action prompt:** *"Look at `AddTodo`, `CompleteTodo`, `RemoveTodo`. They all have a similar shape: validate input, do the thing, print confirmation. What's the cost of duplicating that shape vs. the cost of factoring it out?"*

### Phase 4 — Refactor into a `Todo` class and a `TodoStore` class (~25 min)

**Goal:** Replace the bare `List<string>` with a proper domain model. A `Todo` is no longer just a string — it has an **id**, a **text**, a **completed** flag, and a **created-at** timestamp. The list-management logic moves out of `Program.cs` into a dedicated `TodoStore` class. The Program file becomes thin — it just routes commands and prints output. This is the **architecture** that project #3 carries forward when it puts an API in front of the same model.

**New file: `Todo.cs`**
```csharp
namespace TodoCli;

public class Todo
{
    public int Id { get; set; }
    public string Text { get; set; } = "";
    public bool IsComplete { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public override string ToString()
    {
        string mark = IsComplete ? "[x]" : "[ ]";
        return $"{mark} {Id}. {Text}";
    }
}
```

**New file: `TodoStore.cs`**
```csharp
namespace TodoCli;

public class TodoStore
{
    private readonly List<Todo> _items = new();
    private int _nextId = 1;

    public IReadOnlyList<Todo> All() => _items;

    public Todo Add(string text)
    {
        var todo = new Todo { Id = _nextId++, Text = text };
        _items.Add(todo);
        return todo;
    }

    public Todo? Complete(int id)
    {
        var todo = _items.FirstOrDefault(t => t.Id == id);
        if (todo is null) return null;
        todo.IsComplete = true;
        return todo;
    }

    public Todo? Remove(int id)
    {
        var todo = _items.FirstOrDefault(t => t.Id == id);
        if (todo is null) return null;
        _items.Remove(todo);
        return todo;
    }
}
```

**Replace `Program.cs` with the thin version:**
```csharp
using TodoCli;

var store = new TodoStore();

Console.WriteLine("TODO CLI \u2014 type 'help' for commands, 'quit' to exit.");

while (true)
{
    Console.Write("> ");
    string? input = Console.ReadLine();
    if (input is null) break;

    string[] parts = input.Trim().Split(' ', 2);
    string command = parts[0].ToLowerInvariant();
    string argument = parts.Length > 1 ? parts[1] : "";

    if (command == "quit") break;

    switch (command)
    {
        case "help":     ShowHelp();              break;
        case "add":      Add(argument);           break;
        case "list":     List();                  break;
        case "complete": Complete(argument);      break;
        case "remove":   Remove(argument);        break;
        default:         Console.WriteLine($"Unknown command: {command}. Type 'help' for the list."); break;
    }
}

Console.WriteLine("Goodbye.");

void ShowHelp()
{
    Console.WriteLine("Commands: add <text> | list | complete <id> | remove <id> | help | quit");
}

void Add(string text)
{
    if (string.IsNullOrWhiteSpace(text)) { Console.WriteLine("Usage: add <text>"); return; }
    var todo = store.Add(text);
    Console.WriteLine($"Added: {todo}");
}

void List()
{
    var items = store.All();
    if (items.Count == 0) { Console.WriteLine("(no TODOs)"); return; }
    foreach (var t in items) Console.WriteLine($"  {t}");
}

void Complete(string arg)
{
    if (!int.TryParse(arg, out int id)) { Console.WriteLine("Usage: complete <id>"); return; }
    var done = store.Complete(id);
    Console.WriteLine(done is null ? $"No TODO with id {id}" : $"Completed: {done}");
}

void Remove(string arg)
{
    if (!int.TryParse(arg, out int id)) { Console.WriteLine("Usage: remove <id>"); return; }
    var removed = store.Remove(id);
    Console.WriteLine(removed is null ? $"No TODO with id {id}" : $"Removed: {removed}");
}
```

**Run it:**
```powershell
dotnet run
# > add Buy milk
# Added: [ ] 1. Buy milk
# > add Walk dog
# Added: [ ] 2. Walk dog
# > complete 1
# Completed: [x] 1. Buy milk
# > list
#   [x] 1. Buy milk
#   [ ] 2. Walk dog
```

**Concepts to name out loud:**
- *This is **a class*** — `public class Todo { ... }`. A blueprint for objects that have **state** (the properties) and **behavior** (the methods, like `ToString`). Compare this to Phase 3 where each TODO was a bare string — now each TODO is a *thing* with structure.
- *This is **a property*** — `public string Text { get; set; }` is shorthand for "a public string named `Text` that can be read and written from outside the class." The `get; set;` is **auto-implemented** — the compiler generates a hidden field behind the scenes. In project #3 we'll see properties with validation logic.
- *This is **a default value*** — `= ""` and `= DateTime.UtcNow` initialize properties when an object is created. Without them, `Text` would be `null` and the compiler would warn about it (nullable reference types). Name this; null-safety is a real C# discipline.
- *This is **`override`*** — `public override string ToString()` says "I'm replacing the default `ToString` that every C# object inherits." `Console.WriteLine(todo)` calls `ToString` automatically. Convenient + meaningful — the rendering logic lives with the data.
- *This is **encapsulation*** — `_items` is `private`, with `readonly`. Outside code (Program.cs) cannot touch `_items` directly; it has to go through `Add`, `Complete`, `Remove`, `All`. The store gets to enforce invariants (like "always assign a new id"). Name **encapsulation** as a word; learners hear it constantly in interviews.
- *This is **separation of concerns*** — `Todo` knows what a TODO *is*. `TodoStore` knows how to *manage a collection of TODOs*. `Program.cs` knows how to *talk to a user*. Three concerns, three files. In project #3, the API replaces Program.cs entirely \u2014 and `Todo` + `TodoStore` come along untouched. **This is the win.**
- *This is **LINQ*** (the `.FirstOrDefault` call) — "Language Integrated Query." A pile of methods on `IEnumerable<T>` that read like English: `_items.FirstOrDefault(t => t.Id == id)` = "give me the first item whose id equals `id`, or null if there is none." We'll meet LINQ for real in project #4 with EF Core.
- *This is **a lambda*** — `t => t.Id == id`. An inline anonymous method. `t` is a parameter, `t.Id == id` is the body. Lambdas are how you pass *behavior* to other methods. Name this; project #3 and #4 use them constantly.

**Common gotchas:**
- Two `.cs` files in the same project but `Program.cs` says "the name `TodoStore` does not exist" — missing `using TodoCli;` at the top of `Program.cs`. The namespace in `Todo.cs` and `TodoStore.cs` puts those classes in a *bucket*; the `using` opens that bucket for Program.cs.
- Property without `set` (just `{ get; }`) — read-only. Then you can't write to it from outside. Useful for immutable values, but here we need `set` because the store flips `IsComplete` from false to true.
- `_items` declared `readonly` and trying to reassign it (`_items = new()`) — compile error. `readonly` means "the *reference* can't change after the constructor runs." You can still call `_items.Add(...)` because that mutates the list, doesn't reassign the field. Name this distinction; it confuses learners for years.

**After-action prompt:** *"You went from one `.cs` file to three. Walk me through each file: what's its job in one sentence, and what's in scope for it to know vs. not know? Pretend a new teammate is looking at this code for the first time \u2014 where does their cursor go first?"*

### Phase 5 — Save and load TODOs from a file (~15 min)

**Goal:** Add **persistence**. When the program starts, load TODOs from `todos.txt`. When the program changes the list (add/complete/remove), save them back. Now closing the program doesn't lose your TODOs.

**Replace `TodoStore.cs` with:**
```csharp
using System.Text.Json;

namespace TodoCli;

public class TodoStore
{
    private readonly List<Todo> _items = new();
    private int _nextId = 1;
    private readonly string _path;

    public TodoStore(string path)
    {
        _path = path;
        Load();
    }

    public IReadOnlyList<Todo> All() => _items;

    public Todo Add(string text)
    {
        var todo = new Todo { Id = _nextId++, Text = text };
        _items.Add(todo);
        Save();
        return todo;
    }

    public Todo? Complete(int id)
    {
        var todo = _items.FirstOrDefault(t => t.Id == id);
        if (todo is null) return null;
        todo.IsComplete = true;
        Save();
        return todo;
    }

    public Todo? Remove(int id)
    {
        var todo = _items.FirstOrDefault(t => t.Id == id);
        if (todo is null) return null;
        _items.Remove(todo);
        Save();
        return todo;
    }

    private void Load()
    {
        if (!File.Exists(_path)) return;
        string json = File.ReadAllText(_path);
        if (string.IsNullOrWhiteSpace(json)) return;
        var loaded = JsonSerializer.Deserialize<List<Todo>>(json);
        if (loaded is null) return;
        _items.AddRange(loaded);
        _nextId = _items.Count == 0 ? 1 : _items.Max(t => t.Id) + 1;
    }

    private void Save()
    {
        string json = JsonSerializer.Serialize(_items, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(_path, json);
    }
}
```

**Update `Program.cs` to pass the file path:**
```csharp
var store = new TodoStore("todos.json");
```

**Run it:**
```powershell
dotnet run
# > add Buy milk
# Added: [ ] 1. Buy milk
# > quit

# Now check the file
Get-Content todos.json
# [
#   {
#     "Id": 1,
#     "Text": "Buy milk",
#     "IsComplete": false,
#     "CreatedAt": "2026-05-29T..."
#   }
# ]

# Run again \u2014 your TODO is still there
dotnet run
# > list
#   [ ] 1. Buy milk
```

**Concepts to name out loud:**
- *This is **persistence*** — keeping state across program runs. The Phase 4 store lost everything at `quit`; now it survives. Persistence is the **single biggest difference** between a toy program and a real one. The "where do I store it" question (file, database, cloud blob, queue) is what projects #4, #6, and #8 are about.
- *This is **`System.Text.Json`*** — the .NET-built-in JSON library. `Serialize` turns a `List<Todo>` into a JSON string; `Deserialize<List<Todo>>` turns a JSON string back into a `List<Todo>`. The angle brackets tell the deserializer what shape to expect. Name JSON; it's the data format the entire industry runs on.
- *This is **a constructor*** — `public TodoStore(string path)`. Runs once when you write `new TodoStore("todos.json")`. The job of a constructor is to set up the object so it's ready for use \u2014 here, "ready" means "loaded with existing data from disk."
- *This is **`File.Exists` before `ReadAllText`*** — first run has no file. Without the check, we'd crash with `FileNotFoundException`. Name the pattern: **check before you read**.
- *This is **the cost of "save after every change"*** — every `Add`, `Complete`, `Remove` writes the entire list to disk. Fine for 50 TODOs, terrible for 50,000. Real apps batch writes, use databases, or use append-only logs. Project #4 introduces a real database for exactly this reason.

**Common gotchas:**
- `todos.json` ends up in the wrong folder — `dotnet run` runs from the project directory, but the working directory might differ when launched from VS Code's debugger. Use a fully-qualified path for production code; the relative path is fine here for demo.
- Editing `todos.json` by hand and breaking the JSON — `Deserialize` throws. Wrap in try/catch in production. Here, the error is the lesson: "don't hand-edit JSON unless you know the format."
- Schema drift \u2014 if you add a new property to `Todo` (e.g. `Priority`), old `todos.json` files don't have it and `Deserialize` fills the new field with the default value. Name this; "what happens when the data shape changes" is a question every backend engineer answers a hundred times.

**After-action prompt:** *"You added file I/O to `TodoStore` and Program.cs didn't change at all. Why is that important? What would have happened if you'd put the file I/O in Program.cs instead?"*

## When to break the method

- Learner has prior coding experience (Python, JS) — collapse Phases 1–2 into a 10-minute fast-pass. Keep Phase 4 intact \u2014 the C#-specific class/property syntax is the part they don't already know.
- Learner is struggling with the Phase 4 refactor (cognitive load tipping point) — split into two sessions. Phase 4a: just extract `Todo` (still bare list in Program.cs). Phase 4b: extract `TodoStore`. Reps before depth.
- Learner asks "can I use a `Dictionary<int, Todo>` instead of `List<Todo>`?" — yes! Have them do it. Then ask them what they gave up (ordered iteration) and what they gained (O(1) lookup by id). That's a *real* engineering trade-off conversation \u2014 worth the detour.
- Learner finishes Phase 5 with time to spare — extend with: add a `due-date` property to `Todo` and a `list --overdue` command. Same data model, new query. Good prep for project #3's filter-on-query patterns.

## Definition of done

The learner can demonstrate, observably:

1. Project compiles and runs from scratch (`dotnet run`).
2. `add`, `list`, `complete`, `remove`, `help`, `quit` all work as designed.
3. TODOs persist across runs (close the program, reopen, `list` shows previous TODOs).
4. The repo has three `.cs` files (`Program.cs`, `Todo.cs`, `TodoStore.cs`) and the learner can describe what each one does in one sentence.
5. The learner can name **separation of concerns** and point at the line of code in `Program.cs` where the boundary is enforced (the `var store = new TodoStore(...);` line plus the absence of any `File.` or `List<Todo>` calls in Program.cs).

## Next steps

When done, the learner is ready for **[`cad-todo-api`](../cad-todo-api/SKILL.md)** (project #3) — same `Todo` model, same store concept, but the **user interface** changes from "a person typing commands" to "an HTTP client sending requests." The `Todo` class and the spirit of `TodoStore` carry over almost verbatim; `Program.cs` is replaced by ASP.NET Core's request pipeline.
