---
name: cad-todo-api
description: Build progression for an ASP.NET Core Web API that exposes the TODO list from cad-todo-cli over HTTP. Use when the learner wants to learn web APIs, REST, controllers, dependency injection, or model binding hands-on. Pairs with the ride-along method.
---

# Skill: cad-todo-api

The learner builds a working ASP.NET Core Web API that serves CRUD endpoints for a TODO list. By the end they can `curl` the API, see JSON come back, and explain *why* each piece exists.

This is project #3 in the [CAD track](../README.md). It is a **build recipe**, not a lecture. The mentor uses it to know what to build and which concepts to surface; *how* to teach those concepts lives in [`methods/ride-along`](../../../methods/ride-along/SKILL.md).

## Project goal

A 4-endpoint REST API (`GET /todos`, `GET /todos/{id}`, `POST /todos`, `DELETE /todos/{id}`) backed by an in-memory list. The learner ends the session with a running API they can hit with `curl` or the browser, and a working mental model of what a controller, a route, and DI actually are.

## Prerequisites

| Need | Why |
|---|---|
| `cad-hello-console` done OR equivalent | Learner knows what `dotnet run` does, can edit a `.cs` file without freezing |
| `cad-todo-cli` done OR equivalent | Learner has already modeled a TODO and a list of TODOs. We reuse the `Todo` class concept, just move it behind HTTP. |
| .NET 8 SDK installed | `dotnet --version` returns 8.x |
| `curl` or browser | To hit the API |

If the learner has not done #2 — offer to do a 5-minute warm-up where they sketch a `Todo` class on paper before starting phase 1. Do not skip the modeling step.

## Phases

Each phase ends with a working build the learner can run. After every phase, run a brief **after-action review** per the ride-along method.

### Phase 1 — Scaffold and run a starter API (~20 min)

**Goal:** Learner runs `dotnet new webapi --use-controllers`, gets the default app running, hits the `WeatherForecast` endpoint in a browser, opens the Swagger UI at `/swagger`, and can point at the file where the route is defined.

**Files touched:** `Program.cs`, `Controllers/WeatherForecastController.cs` (read-only — we don't modify it yet).

**Concepts to name out loud:**
- *This is HTTP* — the browser sends a **request** (URL + verb, like `GET`), the server sends a **response** (status code + body). Everything in this project is just request → response. Name this even if it feels obvious — many learners have never had it said out loud.
- *This is a template* — scaffolding is not magic, it's a script that drops files. `--use-controllers` tells .NET to give us a controllers-based project instead of the minimal-API style (which is the .NET 8 default and doesn't produce a `Controllers/` folder).
- *This is the entry point* — `Program.cs` is where the app starts, just like `Main` in a console app.
- *This is a controller* — a class that owns a set of related HTTP endpoints.
- *This is Swagger / OpenAPI* — the auto-generated `/swagger` page is a live, clickable description of every endpoint the API exposes. It's how the learner will exercise the API for the rest of the session without writing `curl` commands.

**Common gotchas:**
- Port conflicts — if 5000/5001 is taken, the app crashes silently. Have the learner read the launch URL from the terminal output, not assume.
- HTTPS dev cert — first run may prompt to trust the dev cert. Run `dotnet dev-certs https --trust` if needed.
- Forgot `--use-controllers` — if the project has no `Controllers/` folder, it's the minimal-API template. Easiest fix: delete the folder and re-scaffold with the flag.

**After-action prompt:** *"What did `dotnet new webapi --use-controllers` actually do? Name three files it created and what each one is for. What's the difference between the `GET` you just hit in the browser and a `POST`?"*

### Phase 2 — Add the Todo model and an in-memory store (~25 min)

**Goal:** Learner creates `Models/Todo.cs` and `Services/TodoStore.cs`, registers the store in the DI container.

**Files touched:** `Models/Todo.cs` (new), `Services/TodoStore.cs` (new), `Program.cs` (one line — `builder.Services.AddSingleton<TodoStore>()`).

**Concepts to name out loud:**
- *This is a model* — a plain class that represents data, no behavior
- *This is a singleton* — one shared instance for the whole app's lifetime
- *This is dependency injection* — we register the store once, the framework gives it to anyone who asks

**Common gotchas:**
- Learner may want to make `TodoStore` `static`. Don't let them — DI is the whole point. Ask: *"If you had two TODO lists, how would `static` handle that?"*
- Namespace mismatches — the project's root namespace must match the folder structure or `using` statements break.

**After-action prompt:** *"Why did we register `TodoStore` as a singleton instead of `new`-ing it inside the controller?"*

### Phase 3 — Build the TodosController with GET endpoints (~30 min)

**Goal:** `GET /todos` returns the list as JSON. `GET /todos/{id}` returns one or 404. Both endpoints are written as `async Task<IActionResult>` even though our in-memory store is instant.

**Files touched:** `Controllers/TodosController.cs` (new), `Controllers/WeatherForecastController.cs` (delete — we don't need it).

**Concepts to name out loud:**
- *This is REST* — we're treating `/todos` as a **resource**. `GET /todos` lists them, `GET /todos/{id}` reads one. In Phase 4 we'll add `POST /todos` to create and `DELETE /todos/{id}` to remove. Same noun, different verbs — that's the REST pattern in one sentence.
- *This is routing* — the `[Route]` attribute is how the framework maps a URL to a method.
- *This is model binding* — `{id}` in the URL becomes the `int id` parameter, automatically.
- *This is constructor injection* — the controller asks for `TodoStore` in its constructor, DI provides it. (Second time we've seen DI — that's recognition, not new learning. Call it out so the learner notices the pattern.)
- *This is `async Task<IActionResult>`* — real web APIs return `Task` so the server can handle other requests while one is waiting on I/O. Our in-memory store is instant so there's nothing to `await` yet, but we write the signature the way production code does so we don't have to rewrite it in `cad-todo-api-ef`. Name this trade-off out loud — don't sneak it past them.

**Common gotchas:**
- Forgetting `[ApiController]` — without it, model binding behaves differently and 400 responses lose their auto-formatting.
- Returning the raw list vs `Ok(list)` — both work, but `Ok()` is explicit about the status code. Show both, name the difference.
- Casing in JSON — .NET serializes `Title` as `title` by default. If learner is surprised, that's a teachable moment about JSON conventions.

**After-action prompt:** *"What would happen if you removed the `[ApiController]` attribute? Don't guess — try it."*

### Phase 4 — Add POST and DELETE (~25 min)

**Goal:** `POST /todos` accepts a JSON body and adds to the store. `DELETE /todos/{id}` removes one and returns 204.

**Files touched:** `Controllers/TodosController.cs` (extend).

**Concepts to name out loud:**
- *This is `[FromBody]`* — model binding from the request body, vs from the URL
- *This is `CreatedAtAction`* — the conventional response for POST that returns 201 + a `Location` header
- *This is the difference between 200, 201, 204* — status codes are not decoration, each one means something specific

**Common gotchas:**
- Forgetting to assign `Id` on POST — learner posts a TODO, store accepts it with `Id = 0`, next POST overwrites it. Let them hit it first, then ask *"what happened?"* If they're still stuck after one prompt, climb the [ride-along escalation ladder](../../../methods/ride-along/SKILL.md) (hint → narrower question → demo a fragment → write the line for them, only as a last resort).
- DELETE with no body — DELETE responses should usually be 204 No Content, not 200 with an empty body.

**After-action prompt:** *"You just hit four endpoints. Trace what happens from `curl POST /todos` to the JSON response — every layer."*

### Phase 5 — Smoke-test all four endpoints (~10 min)

**Goal:** Learner drives every endpoint once, in order, and watches the data round-trip. This is the moment the project goes from "I built it" to "I see it work end to end."

**What to do** (in Swagger UI from Phase 1, or `curl` — pick whichever shows status codes most clearly):

1. `GET /todos` → expect `[]` (empty list on a fresh run).
2. `POST /todos` with body `{"title": "Buy bread", "isDone": false}` → expect **201 Created** and a `Location` header pointing at `/todos/1`.
3. `GET /todos/1` → expect the TODO just created.
4. `GET /todos/999` → expect **404 Not Found**.
5. `DELETE /todos/1` → expect **204 No Content**.
6. `GET /todos` → expect `[]` again.

**Concepts to reinforce:**
- *Status codes are signals* — 200, 201, 204, 404 each told you something specific. Walk through what each one meant in this run, in plain English.
- *State is in-memory* — restart `dotnet run` and notice everything is gone. That's the problem `cad-todo-api-ef` solves next.

**After-action prompt:** *"Which status codes did you see during the smoke test? For each one, say what it meant. Where did the `1` in `/todos/1` come from?"*

## When to break the method

The ride-along method assumes the learner can drive the keyboard. If during any phase you discover:

- **Learner has never seen attributes (`[Route]`, `[ApiController]`)** — pause the build. Spend 5 minutes on what an attribute is and why C# uses them. Then resume.
- **Learner has never seen generics (`List<Todo>`)** — same. Don't barrel past it.
- **Learner is copy-pasting without reading** — stop. Ask them to explain the last block they pasted, in their own words, before continuing.

These are not method failures. The ride-along method *expects* the mentor to drop into a 3-5 minute concept tangent when a foundation is missing — the rule is to name it out loud and return to the build.

## Definition of done

- API runs locally (`dotnet run`)
- Learner completed the Phase 5 smoke test and observed each status code (200, 201, 204, 404) at least once
- Learner can answer the after-action prompts for every phase without re-reading the code
- Learner can describe — without looking — what HTTP request/response is, what REST means, what DI is, what a controller is, and what model binding does

## Next project

If learner wants persistence beyond a single run → [`cad-todo-api-ef`](../cad-todo-api-ef/SKILL.md) (adds EF Core + SQLite).
If learner wants to put it in the cloud → [`cad-deploy-app-service`](../cad-deploy-app-service/SKILL.md).
