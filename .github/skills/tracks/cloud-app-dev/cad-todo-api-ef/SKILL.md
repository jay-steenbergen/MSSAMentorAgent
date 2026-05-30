---
name: cad-todo-api-ef
description: Build progression that swaps the in-memory store in cad-todo-api for a real database using Entity Framework Core and SQLite. Use when the learner wants to learn ORMs, DbContext, migrations, real async/await, or LINQ queries against a database hands-on. Pairs with the ride-along method.
---

# Skill: cad-todo-api-ef

The learner takes the working API from `cad-todo-api` and replaces the in-memory `TodoStore` with a real database via Entity Framework Core + SQLite. By the end they can `curl POST /todos`, restart the app, `curl GET /todos`, and **the data is still there.** That moment is the whole point of this project.

This is project #4 in the [CAD track](../README.md). It is a **build recipe**, not a lecture. The mentor uses it to know what to build and which concepts to surface; *how* to teach those concepts lives in [`methods/ride-along`](../../../methods/ride-along/SKILL.md).

## Project goal

Replace `TodoStore` with `TodoDbContext`. Add one migration. The four endpoints from `cad-todo-api` keep working — only now the data persists across restarts in a SQLite file (`todos.db`) sitting next to the binary.

## Prerequisites

| Need | Why |
|---|---|
| `cad-todo-api` complete OR equivalent | Learner has a working 4-endpoint API and understands DI, controllers, routing |
| .NET 8 SDK installed | `dotnet --version` returns 8.x |
| `dotnet-ef` tool installed globally | Run `dotnet tool install --global dotnet-ef` once; verify with `dotnet ef --version`. Run this *before* Phase 1 starts — don't discover it's missing mid-phase. |
| Comfort with `List<T>` and basic LINQ (`.Where`, `.FirstOrDefault`) | EF queries look like LINQ. If learner has never seen LINQ on a list, pause and do a 5-minute warm-up on an in-memory `List<int>` before touching EF. |

If the learner has not done `cad-todo-api` — stop. This project is a *modification* of that one. There is nothing to modify if it doesn't exist.

## Phases

Each phase ends with a working build the learner can run. After every phase, run a brief **after-action review** per the ride-along method.

### Phase 1 — Add EF Core packages and the DbContext (~20 min)

**Goal:** Learner installs the two EF Core NuGet packages, creates `Data/TodoDbContext.cs`, and registers it in DI. App still runs (using the old `TodoStore`) — nothing visible changed yet.

**Files touched:**
- `<project>.csproj` (NuGet packages added) — `Microsoft.EntityFrameworkCore.Sqlite`, `Microsoft.EntityFrameworkCore.Design`
- `Data/TodoDbContext.cs` (new) — derives from `DbContext`, exposes `DbSet<Todo> Todos`
- `Program.cs` (one line) — `builder.Services.AddDbContext<TodoDbContext>(opt => opt.UseSqlite("Data Source=todos.db"))`

**Concepts to name out loud:**
- *This is an ORM* — Object-Relational Mapper. It maps C# classes (`Todo`) to database rows so you write LINQ instead of SQL. EF Core is Microsoft's ORM.
- *This is a `DbContext`* — the bridge between your code and the database. One instance ≈ one open conversation with the database. The framework opens and closes it for you per request.
- *This is `AddDbContext` vs `AddSingleton`* — in `cad-todo-api` we registered `TodoStore` as a singleton (one for the app's life). `DbContext` is **scoped** by default — one per HTTP request, then disposed. Database connections are expensive; you don't want one shared forever. Name this difference out loud — it's the second time the learner has seen DI lifetime decisions, and the contrast cements the concept.
- *This is the connection string* — `"Data Source=todos.db"` tells SQLite to use a local file. No server, no install, no credentials. SQLite is a database in a single file.

**Common gotchas:**
- Wrong package name — there is `Microsoft.EntityFrameworkCore.Sqlite` (what we want) and `System.Data.SQLite` (don't want). Have the learner read the package author and version before installing.
- Forgot `Microsoft.EntityFrameworkCore.Design` — without it the `dotnet ef` commands in Phase 3 fail with a confusing message. Install both packages now.
- Namespace mismatch — `TodoDbContext` lives in a new `Data/` folder. Make sure the `using` for that namespace lands in `Program.cs` and the controller.

**After-action prompt:** *"What's the difference between how we registered `TodoStore` last project and how we registered `TodoDbContext` this project? Why does that difference exist?"*

### Phase 2 — Swap the controller from TodoStore to TodoDbContext (~25 min)

**Goal:** `TodosController` now takes `TodoDbContext` in its constructor instead of `TodoStore`. Every endpoint method becomes truly `async` and uses `await` on EF's async LINQ methods. The app still won't run end-to-end until Phase 3 (no database file exists yet) — but the code compiles and we can talk through every line.

**Files touched:** `Controllers/TodosController.cs` (rewrite the body of each method). **Leave `Services/TodoStore.cs` in place** — don't delete it. Keeping both files side by side gives the learner a before/after to compare in the after-action.

**What the methods look like now** (mentor sketches these, learner types):
- `GET /todos` → `return Ok(await _db.Todos.ToListAsync());`
- `GET /todos/{id}` → `var t = await _db.Todos.FindAsync(id); return t is null ? NotFound() : Ok(t);`
- `POST /todos` → `_db.Todos.Add(todo); await _db.SaveChangesAsync(); return CreatedAtAction(...);`
- `DELETE /todos/{id}` → `var t = await _db.Todos.FindAsync(id); if (t is null) return NotFound(); _db.Todos.Remove(t); await _db.SaveChangesAsync(); return NoContent();`

**Concepts to name out loud:**
- *This is real `async/await`* — last project the signature was `async` but there was nothing to `await`. Now `ToListAsync()` and `SaveChangesAsync()` are genuine I/O — the thread is freed up while the database does its work. The Phase 3 signature from `cad-todo-api` was setup for exactly this moment. Pay it off explicitly.
- *This is LINQ-to-EF* — `_db.Todos.ToListAsync()` looks like a `List<T>` method, but EF translates it to SQL behind the scenes. The learner can write `.Where(...)`, `.OrderBy(...)`, `.FirstOrDefault(...)` and EF figures out the SQL.
- *This is `SaveChangesAsync`* — EF tracks every change you make (add, modify, remove) and **batches them** until you call `SaveChangesAsync`. Until then, nothing has hit the database. This is a recurring source of bugs in EF code; name it now.
- *This is the difference between `Find` and `FirstOrDefault`* — `FindAsync(id)` looks in EF's local cache first; `FirstOrDefaultAsync(t => t.Id == id)` always hits the database. Both work for our case. Show both, name the difference.
- *This is a POCO / EF entity by convention* — our `Todo` class has no `[Key]`, no `[Table]`, no base class. EF discovers it because it's the type parameter of `DbSet<Todo>` and uses convention: *"the property called `Id` is the primary key."* Same class is doing double duty — it's our API model AND our database entity. Annotations exist (`[Key]`, `[Required]`, `[MaxLength(200)]`) for when convention isn't enough — we'll see them in `cad-todo-api-auth`.

**Common gotchas:**
- Forgetting `await` on EF calls — returns a `Task<List<Todo>>` instead of a `List<Todo>` and JSON serialization produces garbage. The compiler usually warns; have the learner read warnings.
- Forgetting `using Microsoft.EntityFrameworkCore;` — the `Async` LINQ methods (`ToListAsync`, `FindAsync`) live in that namespace. Without the `using`, they don't appear in IntelliSense and learner panics.
- Forgetting `SaveChangesAsync` — `POST /todos` returns 201 but nothing actually saved. Easy to miss in code review. If learner hits this in Phase 4, let them discover it before pointing.
- `FindAsync` returns `Todo?` (nullable) under .NET 8's default nullable context. The `is null` check in the sketches satisfies the compiler. If learner sees a CS8600 / CS8602 warning, that's why — name nullable reference types out loud as a C# language feature, not an EF feature.

**After-action prompt:** *"In the POST endpoint, what would happen if you forgot `await _db.SaveChangesAsync()`? Why does EF work that way? Open both `TodoStore.cs` and `TodosController.cs` — which file got shorter? Which one is doing more work now, even though it's not visible?"*

### Phase 3 — Create the first migration and the database (~25 min)

**Goal:** Run `dotnet ef migrations add InitialCreate`, look at the generated migration file, run `dotnet ef database update`, watch `todos.db` appear on disk. The app now starts, all four endpoints work, data is being written to a real database.

**Files touched:** `Migrations/` folder appears (generated — learner reads it but doesn't edit), `todos.db` file appears at the project root.

**Commands the learner runs:**
```
dotnet ef migrations add InitialCreate
dotnet ef database update
dotnet run
```

**Concepts to name out loud:**
- *This is a migration* — a versioned script that describes a schema change ("add a Todos table with these columns"). Generated by EF from your `DbContext` + entity classes. Checked into source control. Run forward (apply) or backward (rollback).
- *This is the difference between `migrations add` and `database update`* — `add` *writes* the migration file. `update` *runs* migrations against the database. Two separate steps so you can review the SQL before it touches your data.
- *This is the migration file* — open `Migrations/<timestamp>_InitialCreate.cs`. Read it together. Point at `Up` (apply) and `Down` (rollback). Name them out loud. This file is the contract between your code's model and the database's shape.
- *This is the `.db` file* — SQLite is a single file. You can open it in [DB Browser for SQLite](https://sqlitebrowser.org/) or the VS Code SQLite extension and *see* the row appear after `POST /todos`. Strongly recommend doing this once — concrete > abstract.
- *Databases don't belong in source control* — add `todos.db` (and `todos.db-shm`, `todos.db-wal` if they appear) to `.gitignore` right now, before the file grows. The schema lives in `Migrations/`. The data is a per-developer artifact. Commit code, commit migrations, never commit the `.db` file.

**Common gotchas:**
- `dotnet-ef` tool not installed — error message *"Could not execute because the specified command or file was not found."* Fix: `dotnet tool install --global dotnet-ef`.
- `dotnet ef` says *"Unable to create a 'DbContext' of type ..."* — most common cause is running from the wrong folder (must be in the project folder with the `.csproj`). If that's not it, check that `AddDbContext` actually runs in `Program.cs` — a misplaced `return` or early `if` can skip it.
- Migration command run from wrong folder — must be in the project folder (where the `.csproj` is). Otherwise EF can't find the `DbContext`.
- Stale `todos.db` from a previous run — if the schema doesn't match, `update` may fail. For a tutorial it's safe to delete `todos.db` and re-run `database update`. Name this trade-off — in production, deleting the database is never the answer.

**After-action prompt:** *"What's in the migration file? Walk me through `Up()` line by line. If you wanted to undo this migration tomorrow, what command would you run?"*

### Phase 4 — Evolve the schema with a second migration (~15 min)

**Goal:** Add a `Description` field to `Todo`, generate a second migration, apply it, see the column appear in the existing database without losing existing data. This is the moment migrations earn their existence.

**Files touched:** `Models/Todo.cs` (add `public string? Description { get; set; }`), `Migrations/` (new migration file appears).

**Commands the learner runs:**
```
dotnet ef migrations add AddDescription
dotnet ef database update
```

**Concepts to name out loud:**
- *This is schema evolution* — production databases can't be wiped every time the model changes. Migrations let you ship code that updates the database in place. This is why migrations exist.
- *This is `string?`* — the `?` makes `Description` nullable so existing rows (which have no description) stay valid. Without the `?`, EF would generate a `NOT NULL` column and the migration would fail on the existing rows.
- *This is reading SQL* — open the new migration file. The generated `Up()` is one `ALTER TABLE` statement. Reading generated SQL is a real skill — name it.

**Common gotchas:**
- Forgot the `?` on `Description` — migration fails because existing rows can't satisfy `NOT NULL`. Let learner hit this, read the error, then fix. If they're stuck after one prompt, climb the [ride-along escalation ladder](../../../methods/ride-along/SKILL.md).
- Editing the migration file by hand — generally a bad idea unless you know what you're doing. Name the rule: *"Treat generated migrations as read-only unless you have a specific reason."*

**After-action prompt:** *"You just added a column to a live database without losing data. Walk me through how — what files changed, what commands ran, in what order?"*

### Phase 5 — Smoke-test persistence across restarts (~10 min)

**Goal:** Learner drives the API through a sequence that proves the data actually persists. This is the *"it's a real database now"* moment.

**What to do** (in Swagger UI or `curl`):

1. `POST /todos` with body `{"title": "Buy bread", "description": "for the week", "isDone": false}` → expect **201 Created**.
2. `GET /todos` → expect the new TODO with `description` populated.
3. **Stop the app** (Ctrl+C in the terminal).
4. `dotnet run` again.
5. `GET /todos` → **expect the same TODO still there.**
6. (Optional, if SQLite browser installed) Open `todos.db` and find the row in the `Todos` table. Look at the `Description` column.

**Concepts to reinforce:**
- *Persistence is the difference* — in `cad-todo-api`, restart = empty list. Here, restart = data still there. That's what a database buys you.
- *The schema is now versioned* — the `Migrations/` folder is the history. Anyone who clones the repo can run `dotnet ef database update` and get the exact same schema.

**After-action prompt:** *"Where on disk does the data actually live? If you wanted a teammate to get the same schema on their machine, what would they run? What would happen if they didn't?"*

## When to break the method

The ride-along method assumes the learner can drive the keyboard. If during any phase you discover:

- **Learner has never written LINQ** — pause. Spend 5-10 minutes on `.Where`, `.Select`, `.FirstOrDefault` against an in-memory `List<int>`. EF's async LINQ is unintelligible without the synchronous version first.
- **Learner is shaky on `async/await`** — pause. Walk through one synchronous version of a controller method and one async version side by side. Name the difference: *"this one frees the thread while waiting; that one doesn't."*
- **Learner can't read SQL** — that's fine and expected. Don't pause for a SQL crash course. Just point at `CREATE TABLE` in the migration and translate it in English: *"this makes a table called Todos with these columns."*

These are not method failures. The ride-along method *expects* the mentor to drop into a 3-10 minute concept tangent when a foundation is missing — the rule is to name it out loud and return to the build.

## Definition of done

- API runs locally (`dotnet run`) with the SQLite database
- All four endpoints work end-to-end against the database (verified in Phase 5)
- Data survives `dotnet run` → Ctrl+C → `dotnet run` (verified in Phase 5)
- Two migrations exist in the `Migrations/` folder, both applied
- Learner can describe — without looking — what an ORM is, what a `DbContext` is, what a migration is, and *why* migrations exist (i.e. why we don't just rewrite the schema each time)

## Next project

If learner wants to put the API behind a login → [`cad-todo-api-auth`](../cad-todo-api-auth/SKILL.md) (adds JWT auth).
If learner wants to push it to the cloud as-is → [`cad-deploy-app-service`](../cad-deploy-app-service/SKILL.md).
