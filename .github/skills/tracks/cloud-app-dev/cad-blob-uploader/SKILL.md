---
name: cad-blob-uploader
description: Build progression that adds Azure Blob Storage attachment uploads to the TODO API from cad-todo-api-auth. Use when the learner wants to learn cloud storage SDKs, async I/O against a network service, multipart file uploads, content types, SAS tokens, and configuration secrets hands-on. Pairs with the ride-along method.
---

# Skill: cad-blob-uploader

The learner extends the JWT-secured TODO API so each TODO can have a file attachment (a photo, a receipt, a PDF). Files don't live in the database — they live in **Azure Blob Storage**, a cloud object store. The TODO row stores only a reference. By the end, the learner has uploaded real files to a real cloud service, can download them back via a time-limited URL, and can explain why "files in the database" is almost always the wrong answer.

This is project #6 in the [CAD track](../README.md). It is a **build recipe**, not a lecture. The mentor uses it to know what to build and which concepts to surface; *how* to teach those concepts lives in [`methods/ride-along`](../../../methods/ride-along/SKILL.md).

## Project goal

Two new endpoints on the secured API:

- `POST /todos/{id}/attachment` (authenticated, owner-only) → multipart upload, streams the file to Blob Storage, saves the blob name on the TODO row
- `GET /todos/{id}/attachment` (authenticated, owner-only) → returns a short-lived SAS URL the client can use to download the file directly from Azure

The learner ends with a TODO that has a real photo attached, an Azure Storage container they can see in the portal, and a working understanding that the API never *holds* the file — it just brokers access to it.

> **Scope guardrail.** This project uses the real Azure Blob Storage SDK against either **Azurite** (the free local emulator, recommended) or a real Azure Storage account on the learner's subscription. We do *not* set up identity-based access (managed identity, RBAC) — we use a connection string in `appsettings.json`. That's deliberate: identity-based auth is the right answer in production and it shows up in `cad-deploy-app-service`. For now, the goal is to feel how the SDK works.

## Prerequisites

| Need | Why |
|---|---|
| `cad-todo-api-auth` complete OR equivalent | This project extends that one. There must be a working JWT-secured EF-backed API. |
| .NET 8 SDK installed | `dotnet --version` returns 8.x |
| **Azurite running locally** OR an Azure Storage account | The SDK has to talk to *something*. Azurite is free, runs in Docker or as a VS Code extension, and behaves like the real service. Verify Azurite is running on port 10000 (blob) *before* Phase 1 starts. |
| Comfort with `appsettings.json` | We'll add a storage connection string. Same file pattern as the JWT settings. |
| A small test file ready to upload | A photo from the phone, a PDF, anything < 5 MB. Have it on disk before Phase 4. |

If Azurite isn't running, Phase 1 will fail with a confusing socket error. Run `azurite --silent` (or start the VS Code Azurite extension) and confirm port 10000 is listening before starting.

## Phases

Each phase ends with a working build the learner can run. After every phase, run a brief **after-action review** per the ride-along method.

### Phase 1 — Add the Storage SDK and a BlobServiceClient (~25 min)

**Goal:** Learner installs `Azure.Storage.Blobs`, adds the storage connection string to `appsettings.json`, registers a `BlobServiceClient` in DI, and verifies on startup that the SDK can reach the storage service. App still runs and behaves exactly as before.

**Commands the learner runs:**
```
dotnet add package Azure.Storage.Blobs
```

**Files touched:**
- `<project>.csproj` (NuGet package added)
- `appsettings.json` — new `Storage` section with `ConnectionString` and `ContainerName` (use `todo-attachments`)
- `Program.cs` — register `BlobServiceClient` as a **singleton** in DI: `builder.Services.AddSingleton(x => new BlobServiceClient(builder.Configuration["Storage:ConnectionString"]));`
- (Optional) brief startup code that calls `GetBlobContainerClient("todo-attachments").CreateIfNotExistsAsync()` so the container exists before the first upload

**Concepts to name out loud:**
- *This is an SDK vs an HTTP API* — Azure Blob Storage has a REST API. We could call it with `HttpClient` and hand-roll the auth signature. We don't. We use the SDK because it handles auth, retries, streaming, and serialization. SDKs are a thin layer over an HTTP API — name it, because the learner will hit non-SDK services later (raw REST, gRPC) and it helps to know what the SDK was doing for them.
- *This is `BlobServiceClient` as a singleton* — fourth time naming DI. The SDK client is thread-safe and expensive to create (it holds connection pools). Singleton, not scoped, not transient. Compare to `TodoDbContext` (scoped — *not* thread-safe, cheap to create per request). The lifetime depends on the client, not on a rule. Name the *why*.
- *This is a connection string* — a single string that bundles endpoint + credentials. Convenient for dev. In production we replace it with a **managed identity** (the app proves it's Azure-hosted, no secret needed). Two pieces of foreshadowing in one bullet — name both, build the connection string version now.
- *This is Azurite* — a local emulator. Same SDK, same API surface, runs on your laptop. Connection string `UseDevelopmentStorage=true` points the SDK at it. Production code never knows the difference. This is the same pattern as SQLite for EF in Phase 3 of `cad-todo-api-ef` — a local stand-in that matches the real thing's contract. Name the pattern; it shows up *everywhere* in cloud development.
- *This is a container* — Blob Storage's namespace unit, roughly equivalent to a folder or an S3 bucket. Containers hold blobs. We need exactly one, named `todo-attachments`, created at startup if it doesn't exist. Idempotent setup: `CreateIfNotExistsAsync()`.

**Common gotchas:**
- Azurite not running — SDK throws a socket / connection-refused error during the first storage call. Diagnose by hitting `http://127.0.0.1:10000/devstoreaccount1` in a browser; if nothing answers, Azurite isn't running.
- Wrong connection string format — `UseDevelopmentStorage=true` works for Azurite defaults. Real Azure connection strings look completely different (start with `DefaultEndpointsProtocol=https;AccountName=...`). Don't paste the wrong one.
- `BlobServiceClient` registered with the wrong lifetime — scoped or transient creates a new HTTP pool per request and tanks performance. Singleton is the rule for HTTP-based SDK clients.
- Forgetting to call `CreateIfNotExistsAsync` and assuming the container exists — the first upload will throw `ContainerNotFound`. Either pre-create it manually in Azurite or do it at startup.

**After-action prompt:** *"Why does `BlobServiceClient` get registered as a singleton when `TodoDbContext` is scoped? In one sentence each."*

### Phase 2 — Add the attachment column and migration (~15 min)

**Goal:** Add `AttachmentBlobName` (nullable string) and `AttachmentContentType` (nullable string) to the `Todo` model. Generate and apply a migration. The TODO row will hold the *reference* to the file, not the file itself.

**Files touched:**
- `Models/Todo.cs` — add `public string? AttachmentBlobName { get; set; }` and `public string? AttachmentContentType { get; set; }`
- `Migrations/` — new migration appears after `dotnet ef migrations add AddAttachment`

**Commands the learner runs:**
```
dotnet ef migrations add AddAttachment
dotnet ef database update
```

**Concepts to name out loud:**
- *This is a reference, not a copy* — the database stores the blob *name* (e.g. `todo-42-receipt.jpg`) and the content type. The file itself lives in Blob Storage. Two systems, one source of truth per concern: SQL for structured data, blob storage for bytes. Putting files in the database (`varbinary(max)`) is technically possible and almost always wrong — name *why*: row size explodes, backups balloon, queries get slow, and the database is the most expensive storage you own.
- *This is the third migration* — recognition, not new learning. Same `add` + `update` command pair from `cad-todo-api-ef` Phase 3 and `cad-todo-api-auth` Phase 4. Name it so the learner *notices* the pattern is repeating.
- *This is nullable by design* — most TODOs won't have attachments. Nullable in the model, nullable in the schema. `string?` (with the `?`) and EF Core will make the column nullable automatically because of the nullable reference type context. Name the bridge between C# nullability and SQL nullability.

**Common gotchas:**
- Forgetting the `?` on `string` — column will be `NOT NULL` and existing rows without attachments will block the migration. If the learner hits this, the fix is the `?`, then regenerate the migration.
- Running `migrations add` from the wrong folder — same gotcha as `cad-todo-api-ef`. Run from the project root, not the solution root.

**After-action prompt:** *"Why store only the blob name in the database and not the file bytes? Give two reasons."*

### Phase 3 — Add the upload endpoint (~30 min)

**Goal:** `POST /todos/{id}/attachment` accepts a multipart file, streams it to Blob Storage, updates the TODO row with the blob name and content type. Authenticated and owner-scoped (same `OwnerId` check as Phase 4 of `cad-todo-api-auth`).

**Files touched:**
- `Controllers/TodosController.cs` — new action method `UploadAttachment(int id, IFormFile file)` with `[HttpPost("{id}/attachment")]`

**The endpoint shape** (`TodosController` now has both `TodoDbContext` and `BlobServiceClient` injected via the constructor):
```csharp
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

[Authorize]
[ApiController]
[Route("todos")]
public class TodosController : ControllerBase
{
    private readonly TodoDbContext _db;
    private readonly BlobServiceClient _blobService;

    public TodosController(TodoDbContext db, BlobServiceClient blobService)
    {
        _db = db;
        _blobService = blobService;
    }

    // … existing actions …

    [HttpPost("{id}/attachment")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(50_000_000)] // 50 MB cap for this endpoint
    public async Task<IActionResult> UploadAttachment(int id, IFormFile file)
    {
        if (file is null || file.Length == 0) return BadRequest("No file.");

        var userId = User.FindFirstValue("sub");
        var todo = await _db.Todos.FirstOrDefaultAsync(t => t.Id == id && t.OwnerId == userId);
        if (todo is null) return NotFound();

        var blobName = $"todo-{id}-{Guid.NewGuid():N}-{file.FileName}";
        var container = _blobService.GetBlobContainerClient("todo-attachments");
        var blob = container.GetBlobClient(blobName);

        await using var stream = file.OpenReadStream();
        await blob.UploadAsync(stream, new BlobHttpHeaders { ContentType = file.ContentType });

        todo.AttachmentBlobName = blobName;
        todo.AttachmentContentType = file.ContentType;
        await _db.SaveChangesAsync();

        return Ok(new { blobName, contentType = file.ContentType });
    }
}
```

**Concepts to name out loud:**
- *This is multipart/form-data* — a different request body format from JSON. Browsers send file uploads this way. ASP.NET Core's `IFormFile` parses it for you. Name the format because the learner will see `Content-Type: multipart/form-data; boundary=...` in `curl -v` and wonder what's happening.
- *This is streaming* — `file.OpenReadStream()` returns a `Stream`, and `blob.UploadAsync(stream, ...)` reads from it. The file's bytes pass *through* the API process to Azure without being fully loaded into memory. For a 100 MB upload, this is the difference between working and OOM-crashing the app. Name it — streams are everywhere in .NET I/O and most learners never realize they're using them.
- *This is content type as data* — the file's MIME type (`image/jpeg`, `application/pdf`) is metadata that *travels with* the blob. We store it on both the blob (as `BlobHttpHeaders.ContentType`) and the TODO row. The blob version is what Azure sends to the browser on download; the row version is what we use for filtering and display.
- *This is real async I/O* — recognition from `cad-todo-api-ef` Phase 2. Every database call was async then. Every storage call is async now. The reason is the same — the thread is freed during the network wait. Fourth time naming async (Program.cs → controllers → EF → SDK). Pure recognition; no new concept.
- *This is the third use of owner-scoped lookup* — `FirstOrDefaultAsync(t => t.Id == id && t.OwnerId == userId)`. Same pattern as `GET /todos/{id}` from Phase 4 of `cad-todo-api-auth`. If they only check `t.Id == id`, that's the IDOR bug again — name it. Authorization at the row level isn't a one-time concern; it's every endpoint that touches user data.

**Common gotchas:**
- Forgetting `[Consumes("multipart/form-data")]` — Swagger UI won't render a file upload widget and `curl` requests with `-F file=@...` get a confusing 415 Unsupported Media Type.
- Forgetting the owner-scoped check — endpoint will let any authenticated user attach a file to any TODO. IDOR, again.
- Reading the file fully into memory with `file.CopyToAsync(ms)` and then uploading the MemoryStream — works for small files, dies on large ones. Stream straight from `OpenReadStream()` to `UploadAsync()`.
- Re-uploading to the same blob name and not realizing the old blob is overwritten — Azure's default behavior is overwrite. We use a `Guid` in the blob name to avoid collisions, but worth naming what the SDK does if you don't.
- Default form body size limit (~28 MB) — ASP.NET Core caps multipart bodies at `FormOptions.MultipartBodyLengthLimit` by default. A phone photo is fine; a 4K video isn't. The `[RequestSizeLimit(50_000_000)]` attribute on the action raises it for this endpoint only. For app-wide changes, configure `FormOptions` in `Program.cs`.

**After-action prompt:** *"Two things happened on the network during your upload. What were they, in order? What would have broken if either one failed halfway through?"*

### Phase 4 — Add the download endpoint with a SAS URL (~25 min)

**Goal:** `GET /todos/{id}/attachment` returns a short-lived **SAS URL** the client can use to download the file directly from Azure Storage. The API never serves the file bytes itself.

**Files touched:**
- `Controllers/TodosController.cs` — new action method `GetAttachment(int id)` with `[HttpGet("{id}/attachment")]`

**The endpoint shape** (add to the same `TodosController` from Phase 3):
```csharp
using Azure.Storage.Sas;

[HttpGet("{id}/attachment")]
public async Task<IActionResult> GetAttachment(int id)
{
    var userId = User.FindFirstValue("sub");
    var todo = await _db.Todos.FirstOrDefaultAsync(t => t.Id == id && t.OwnerId == userId);
    if (todo is null || todo.AttachmentBlobName is null) return NotFound();

    var container = _blobService.GetBlobContainerClient("todo-attachments");
    var blob = container.GetBlobClient(todo.AttachmentBlobName);

    if (!blob.CanGenerateSasUri) return Problem("SAS generation not supported by this client.");

    var sasUri = blob.GenerateSasUri(BlobSasPermissions.Read, DateTimeOffset.UtcNow.AddMinutes(15));
    return Ok(new { url = sasUri.ToString(), expiresInMinutes = 15 });
}
```

**Concepts to name out loud:**
- *This is a SAS URL* — Shared Access Signature. A regular blob URL with extra query-string parameters that prove (cryptographically) that the bearer is allowed to do exactly one thing (read this blob) for a limited time. The client downloads straight from Azure; our API isn't in the data path. Name *why*: the API process doesn't have to spend bandwidth or CPU streaming the file back. For a real product, this is the difference between a $50/month and $5000/month server bill.
- *This is short-lived credentials* — 15 minutes is plenty for a user to click a link. After that, the URL is dead. Compare to the JWT from Phase 2 of `cad-todo-api-auth` — same pattern (expiry as a security control), different mechanism (signed parameters vs signed token). Both say: *if it leaks, the damage window is small*.
- *This is `CanGenerateSasUri`* — the SDK's check that the client was constructed with credentials capable of generating a SAS (account key or user delegation key). Connection-string-based clients can. Managed-identity-based clients need extra setup (user delegation SAS). Name the check now so the learner doesn't get a confusing exception when they move to managed identity in `cad-deploy-app-service`.
- *This is the API as broker, not server* — the learner has now built two endpoints where the API's job is to *authorize* and *hand back a URL*. The actual data flow goes around the API. This is a foundational cloud pattern; name it loudly. Almost every "scalable" architecture uses some version of this.

**Common gotchas:**
- Forgetting the owner check on download — exact same IDOR risk as upload. Name it again.
- Returning the SAS URL without expiry info in the response — clients need to know when it'll stop working. Always include `expiresInMinutes` (or an absolute timestamp).
- Trying to use a managed-identity client to generate a SAS without first getting a user delegation key — works fine with connection strings, throws on managed identity. We'll hit it in `cad-deploy-app-service`; no need to fix here, just know it's coming.
- Confusing learners who expect the API to "send the file" — they may think `return File(stream, contentType)` is the right answer. It would work; it's also exactly the bandwidth-eating pattern SAS exists to avoid. Name both options out loud and explain the choice.

**After-action prompt:** *"Two ways the API could deliver the file to the client: stream it through the API, or return a SAS URL. Which did you pick and why? When would the other one make more sense?"*

### Phase 5 — Smoke-test upload and download end-to-end (~15 min)

**Goal:** Upload a real file as user A, download it back, confirm isolation against user B, and inspect the blob in Azurite.

**What to do:**

1. Log in as user A → get a JWT.
2. Create a TODO with `POST /todos`, body `{"title": "Phone receipt"}`. Note the id.
3. `POST /todos/{id}/attachment` with a file (use Swagger UI's file picker or `curl -F file=@receipt.jpg`). Expect **200** + blob name in the response.
4. `GET /todos/{id}/attachment` → expect a SAS URL.
5. Paste the SAS URL into a browser. Expect the file to download or display.
6. **Verify expiry**: re-run step 4 but pass `1` minute as the expiry (temporarily edit the controller to `AddMinutes(1)`), wait ~70 seconds, then retry the URL. Expect **403 Forbidden**. Restore `15` when done. (If you want to skip the edit, you can wait 16 minutes on the original URL — but the 1-minute test is the fast path.)
7. Log in as user B → get a JWT.
8. `GET /todos/{id}/attachment` (user A's TODO id) with user B's token. Expect **404 Not Found** (owner-scoped lookup means it doesn't even acknowledge the TODO exists).
9. Inspect Azurite: open the Azure Storage Explorer extension in VS Code, expand the local emulator, find the `todo-attachments` container, see the blob.
10. Confirm in the database: open `todos.db`, find the TODO row, confirm `AttachmentBlobName` and `AttachmentContentType` are populated.

**Concepts to reinforce:**
- *Three systems collaborated* — the API authorized, the database stored the reference, the blob store held the bytes. Each did one job. Name the separation.
- *Authorization happened twice in the upload* — first the JWT proved who the user was (`[Authorize]`), then the row-level check proved they owned the TODO. Same two layers from `cad-todo-api-auth`.
- *The SAS URL took the API out of the download path* — step 5 went straight from browser to Azure. The API only handed out the keys.

**After-action prompt:** *"Three different systems worked together to make this upload happen. Name them and what each one did."*

## When to break the method

The ride-along method assumes the learner can drive the keyboard. If during any phase you discover:

- **Learner has never used Docker or VS Code extensions to run a service** — pause on Azurite. 3 minutes on what a local emulator is and why it's the same SDK code. Resume.
- **Learner is shaky on async/await** — Phase 3 and 4 lean hard on it. If they can't explain what `await` does in their own words, drop into a 5-minute aside. Use the after-action prompt from `cad-todo-api-ef` Phase 2 as a check.
- **Learner is overwhelmed by "the cloud"** — slow down. The whole project is cloud-shaped. Name that Azurite is local, the SDK doesn't know the difference, and "the cloud" is just someone else's computer with HTTP on the front.
- **Azurite repeatedly fails to start** — break ride-along for setup. Get Azurite stable as its own checkpoint before touching code.

These are not method failures. The ride-along method *expects* the mentor to drop into a 3–5 minute concept tangent when a foundation is missing.

## Definition of done

- API runs locally (`dotnet run`) against Azurite (or a real storage account)
- All Phase 5 smoke-test steps produce the expected results
- The blob is visible in Azurite's container
- The TODO row in `todos.db` has the blob name and content type
- The SAS URL works in a fresh browser tab and expires when it says it will
- Learner can describe — without looking — what a SAS URL is, why the API doesn't serve the file bytes itself, why `BlobServiceClient` is a singleton, and why files don't go in the database

## Next project

If learner wants to put this in the cloud → [`cad-deploy-app-service`](../cad-deploy-app-service/SKILL.md) (where the connection string moves to App Configuration and managed identity replaces it).
If learner wants to react to blob uploads with a serverless function → [`cad-function-queue-trigger`](../cad-function-queue-trigger/SKILL.md).
