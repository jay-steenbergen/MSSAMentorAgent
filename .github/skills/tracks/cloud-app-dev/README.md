# CAD — Cloud Application Development tracker

Build progression for the **CAD** MSSA track. Each row is one project skill — one buildable thing the learner ships in 1-3 mentor sessions. The mentor picks a project based on what the learner wants to learn next; the ride-along method drives *how* the build happens.

**Target certification:** AZ-204 (Developing Solutions for Microsoft Azure).
**Stack:** C#, .NET, ASP.NET Core, EF Core, Azure App Service, Azure Storage, Azure Functions, GitHub Actions.

## Projects

| # | Skill | Builds | Core concepts | Status |
|---|---|---|---|---|
| 1 | [`cad-hello-console`](./cad-hello-console/SKILL.md) | C# console app, one class | Variables, methods, classes, `dotnet run` | **ready** |
| 2 | [`cad-todo-cli`](./cad-todo-cli/SKILL.md) | In-memory TODO CLI | Collections, loops, file I/O, separation of concerns | **ready** |
| 3 | [`cad-todo-api`](./cad-todo-api/SKILL.md) | ASP.NET Core Web API for the TODO list | Routing, controllers, DI, model binding, REST, HTTP, async | **ready** |
| 4 | [`cad-todo-api-ef`](./cad-todo-api-ef/SKILL.md) | Add EF Core + SQLite to the API | ORM, DbContext, migrations, real async/await, LINQ | **ready** |
| 5 | [`cad-todo-api-auth`](./cad-todo-api-auth/SKILL.md) | Add JWT auth to the API | Identity, claims, authorization filters | **ready** |
| 6 | [`cad-blob-uploader`](./cad-blob-uploader/SKILL.md) | Add Azure Blob attachments to the secured API | Azure SDK, streaming I/O, SAS URLs, content type | **ready** |
| 7 | [`cad-deploy-app-service`](./cad-deploy-app-service/SKILL.md) | Deploy the TODO API to Azure App Service | App Service, app settings, deployment slots | **ready** |
| 8 | [`cad-function-queue-trigger`](./cad-function-queue-trigger/SKILL.md) | Add an Azure Function that reacts to attachment uploads via Storage Queue | Functions, queue trigger, blob bindings, idempotency, poison queues | **ready** |
| 9 | [`cad-cicd-pipeline`](./cad-cicd-pipeline/SKILL.md) | GitHub Actions pipeline: build, test, deploy API + Worker via OIDC, gated by Environment, with end-to-end smoke | GitHub Actions, OIDC, federated credentials, Environments, smoke test, Dependabot | **ready** |

## How the mentor uses this

1. Learner says what they want to learn (e.g. *"I want to understand APIs"*).
2. Mentor scans the table — matches the goal to project #3 (`cad-todo-api`).
3. Mentor checks prerequisites — if learner hasn't done #2 (`cad-todo-cli`), mentor offers to start there or skip the prereq if learner already has the concepts.
4. Mentor loads the project SKILL.md and runs a [ride-along](../../methods/ride-along/SKILL.md) session against the project's phases.

## Status legend

| Status | Meaning |
|---|---|
| **ready** | SKILL.md drafted and reviewed against the ride-along method + completeness bar; safe to run in a real session |
| **drafted** | SKILL.md exists, ready to use in a session, but has not been through a Kimberly-led review yet |
| planned | Listed here, not yet authored |
| revising | Authored, but needs rework before next use |

## Out of scope for this tracker

- Curriculum lecture notes — Microsoft Learn and the MSSA program own those.
- Per-session lesson plans — those are emergent, driven by the ride-along method.
- Cert exam prep cramming — projects align to AZ-204, but this is not a study guide.
