---
name: cad-function-queue-trigger
description: Build progression that adds an Azure Function with a Storage Queue trigger to the TODO API ecosystem. When the API records a new attachment, it drops a message on a queue; the Function picks it up, reads the blob, computes a hash + size, and writes a metadata record back. Teaches serverless triggers, bindings, isolated worker model, idempotency, and poison queues. Use when the learner wants to learn Azure Functions, event-driven processing, queue triggers, blob input bindings, scale-to-zero, or serverless cost models. Pairs with the ride-along method.
---

# Skill: cad-function-queue-trigger

The learner extends the deployed TODO API from `cad-deploy-app-service` with an **event-driven background worker**: an Azure Function that reacts whenever a new attachment is uploaded. The API writes a small JSON message to a Storage **Queue** after each successful upload. The Function listens on that queue, downloads the blob, computes its SHA-256 hash and length, and writes a `metadata/<blobname>.json` sibling blob alongside the original.

By the end the learner has a working **serverless** component — a piece of code with no web server, no plan it pays for at idle, that wakes up only when work arrives. They've also wrestled with the unique gotchas of message-driven systems: messages get redelivered, handlers must be idempotent, and bad messages need a place to die.

This is project #8 in the [CAD track](../README.md). It is a **build recipe**, not a lecture. The mentor uses it to know what to build and which concepts to surface; *how* to teach those concepts lives in [`methods/ride-along`](../../../methods/ride-along/SKILL.md).

## Project goal

Two new working pieces, deployed alongside the existing API:

1. **Producer change (in the API):** after a successful blob upload, the controller writes a message to a Storage Queue named `attachment-uploaded` with the blob name and the owning user.
2. **New Azure Function project:** an isolated-worker .NET 8 Function with a `QueueTrigger` named `OnAttachmentUploaded` that downloads the blob, computes SHA-256 + size, and writes a `metadata/<blobname>.json` blob using a Blob output binding.

A real end-to-end run looks like:

1. `POST /todos/{id}/attachment` returns `200 OK`.
2. Within a few seconds, `metadata/<blobname>.json` appears in the storage account with the hash and byte length.
3. The Function's invocation log shows the message-id, blob name, and elapsed time.

The learner ends knowing how to wire a producer and a consumer through Azure Storage, why "fire and forget" is harder than it sounds, and why every queue eventually needs a poison-message strategy.

> **Scope guardrail.** We use **Azure Storage Queue** (not Service Bus). Storage Queue is simpler, cheaper, and built into the storage account we already have from `cad-blob-uploader`. Service Bus is the right answer for transactional workflows, sessions, dead-letter management, and topics/subscriptions — and it's worth naming as the upgrade path. But adding a new Azure resource (and a new SDK, and namespaces vs queues vs subscriptions) blows the project scope. Stay on Storage Queue here; mention Service Bus once, name what it adds, move on.

## Prerequisites

| Need | Why |
|---|---|
| `cad-deploy-app-service` complete OR equivalent | The producer side modifies the deployed controller from #6/#7. The Function uses the same storage account. |
| Azure Functions Core Tools v4 (`func --version` returns 4.x) | Local Function host. `winget install Microsoft.Azure.FunctionsCoreTools` on Windows. |
| Azurite running locally (`azurite --location <folder>` or VS Code extension) | Local Function emulation hits Azurite for queue + blob. Same Azurite the API already uses from `cad-blob-uploader`. |
| Storage Explorer (optional but huge) | Lets the learner *see* messages arrive in the queue and metadata blobs appear. Worth installing if they don't have it. |

If `func --version` doesn't return 4.x, **stop and install before Phase 1**. The CLI is the entire development experience for Functions; debugging without it is painful.

## Phases

Each phase ends with a working build the learner can run. After every phase, run a brief **after-action review** per the ride-along method.

### Phase 1 — Scaffold the Function project, run it locally with a manually-queued message (~25 min)

**Goal:** Create a sibling project to the API (`TodoApi.Worker`) using the Functions Core Tools, define an `OnAttachmentUploaded` queue-triggered function, run it locally against Azurite, and manually drop a test message into the queue to see the function fire.

**Commands the learner runs (PowerShell):**
```powershell
# Sit next to your existing TodoApi project, then scaffold the Function project
cd path\to\your-solution-folder
func init TodoApi.Worker --worker-runtime dotnet-isolated --target-framework net8.0
cd TodoApi.Worker

# Add the queue trigger function (the template will be regenerated below)
func new --name OnAttachmentUploaded --template "Queue trigger"

# Make sure the Azurite-aware packages are installed
dotnet add package Microsoft.Azure.Functions.Worker.Extensions.Storage.Queues
dotnet add package Microsoft.Azure.Functions.Worker.Extensions.Storage.Blobs
```

**Files touched:**
- `TodoApi.Worker/TodoApi.Worker.csproj` — new project, .NET 8 isolated worker
- `TodoApi.Worker/Program.cs` — generated by `func init`; leave it as-is for now (it sets up the host)
- `TodoApi.Worker/host.json` — Functions host config
- `TodoApi.Worker/local.settings.json` — **local-only secrets/config**, never committed
- `TodoApi.Worker/OnAttachmentUploaded.cs` — replace the template with the snippet below

**Replace the contents of `OnAttachmentUploaded.cs`:**
```csharp
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace TodoApi.Worker;

public class OnAttachmentUploaded
{
    private readonly ILogger<OnAttachmentUploaded> _log;

    public OnAttachmentUploaded(ILogger<OnAttachmentUploaded> log)
    {
        _log = log;
    }

    [Function(nameof(OnAttachmentUploaded))]
    public void Run(
        [QueueTrigger("attachment-uploaded", Connection = "StorageConnection")] string message)
    {
        _log.LogInformation("Got queue message: {Message}", message);
    }
}
```

**Set `local.settings.json` to point at Azurite:**
```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "StorageConnection": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated"
  }
}
```

**Run it locally and manually drop a test message:**
```powershell
# Terminal 1: make sure Azurite is running (skip if your VS Code extension auto-starts it)
azurite --silent --location $env:TEMP\azurite

# Terminal 2: run the function host
func start
# Watch for: "Functions: OnAttachmentUploaded: queueTrigger"

# Terminal 3: drop a message into the queue using Azure CLI against Azurite
az storage queue create --name attachment-uploaded --connection-string "UseDevelopmentStorage=true"
az storage message put --queue-name attachment-uploaded --content "hello world" --connection-string "UseDevelopmentStorage=true"
# In Terminal 2 you should see: "Got queue message: hello world"
```

**Concepts to name out loud:**
- *This is serverless* — there is no `Program.cs` you wrote to listen on a port, no `app.Run()`, no web server. The **Functions runtime** ran your method when a message arrived. In Azure, that runtime is invisible infrastructure billed per execution. Name it; this is the entire premise.
- *This is the isolated worker model* — your function code runs in its own .NET 8 process, separate from the Functions host process. The two talk over gRPC. The alternative (in-process model) runs your code inside the host's process, but locks you to whatever .NET version the host supports. Isolated worker = your .NET version, your dependencies, your DI container. **Pick isolated, always, for new projects.** Name the choice and why.
- *This is a trigger vs a binding* — the `[QueueTrigger(...)]` attribute is a **trigger**: it tells the runtime *when* to invoke this method (a new message in this queue). The runtime hands you the message as a method parameter. Later we'll add an `[BlobOutput(...)]` parameter — that's a **binding**: it tells the runtime *what to do with the return value or `out` parameter*. Triggers fire; bindings move data. Name the distinction.
- *This is `local.settings.json`* — local-only config + secrets, **never committed** (the `func init` template gitignores it for you, check). The connection strings here become App Settings when deployed to Azure. Same `Configuration.GetValue<string>(...)` semantics, same `__` rule as ASP.NET Core.
- *This is "UseDevelopmentStorage=true"* — the magic connection string that points at Azurite (ports 10000–10002). Same trick from `cad-blob-uploader` Phase 1. Name the consistency: every Azure SDK supports this string, locally and identically.

**Common gotchas:**
- Picking `dotnet` instead of `dotnet-isolated` for `--worker-runtime` — that's the deprecated in-process model. Re-run `func init` if so.
- Azurite not running — `func start` shows the function but it never fires. Check Terminal 1 for the Azurite process; restart if dead.
- Queue name mismatch — the attribute string (`"attachment-uploaded"`) and the queue you create with `az storage queue create` must match exactly. Hyphens vs underscores vs camelCase has burned many a developer.
- `func: command not found` — Core Tools not on PATH after install. Restart the terminal; if still missing, run `winget install Microsoft.Azure.FunctionsCoreTools` again or check `$env:PATH`.
- `Program.cs` from the template not importing `Microsoft.Extensions.Hosting` — usually fine, but if the host won't start, paste the canonical isolated-worker `Program.cs` from the [official template](https://learn.microsoft.com/en-us/azure/azure-functions/dotnet-isolated-process-guide).

**After-action prompt:** *"You dropped a string onto a queue and a method ran. Where did the runtime live, who started it, and who told it to invoke your method?"*

### Phase 2 — Wire the API producer (~15 min)

**Goal:** Modify the `PostAttachment` action in `TodoApi`'s `TodosController` to write a JSON message to the `attachment-uploaded` queue after a successful upload. Locally, both API and Function point at Azurite, so the end-to-end loop runs on the laptop.

**Files touched:**
- `TodoApi/TodoApi.csproj` — `dotnet add package Azure.Storage.Queues`
- `TodoApi/Program.cs` — register `QueueServiceClient` next to the `BlobServiceClient`
- `TodoApi/Controllers/TodosController.cs` — add `QueueServiceClient` to the constructor, write a message at the end of `PostAttachment`

**`Program.cs` registration (next to the `BlobServiceClient` from `cad-deploy-app-service` Phase 3):**
```csharp
using Azure.Identity;
using Azure.Storage.Queues;

builder.Services.AddSingleton(sp =>
{
    var url = builder.Configuration["Storage:QueueServiceUrl"];
    if (!string.IsNullOrEmpty(url))
    {
        // Cloud: managed identity (App Service has the role from Phase 7)
        return new QueueServiceClient(new Uri(url),
            new DefaultAzureCredential(),
            new QueueClientOptions { MessageEncoding = QueueMessageEncoding.Base64 });
    }
    // Local: same connection string used for blobs
    var conn = builder.Configuration["Storage:ConnectionString"];
    return new QueueServiceClient(conn,
        new QueueClientOptions { MessageEncoding = QueueMessageEncoding.Base64 });
});
```

**Update `appsettings.json`:**
```json
{
  "Storage": {
    "ConnectionString": "UseDevelopmentStorage=true",
    "ContainerName": "todo-attachments",
    "QueueServiceUrl": "",
    "QueueName": "attachment-uploaded"
  }
}
```

**Producer change in `TodosController.cs`** — the controller already has `_db` and `_blobService` fields and the existing `PostAttachment` action from `cad-blob-uploader` Phase 3. We're (a) adding two new fields + a new constructor parameter, and (b) appending one block at the **bottom** of `PostAttachment` (after the existing `_db.SaveChangesAsync()`, before the existing `return Ok(...)`):
```csharp
using Azure.Storage.Blobs;
using Azure.Storage.Queues;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
using System.Text.Json;

[Authorize]
[ApiController]
[Route("todos")]
public class TodosController : ControllerBase
{
    private readonly TodoDbContext _db;
    private readonly BlobServiceClient _blobService;
    private readonly QueueServiceClient _queueService;   // NEW
    private readonly string _queueName;                  // NEW

    public TodosController(
        TodoDbContext db,
        BlobServiceClient blobService,
        QueueServiceClient queueService,                 // NEW
        IConfiguration config)                           // NEW
    {
        _db = db;
        _blobService = blobService;
        _queueService = queueService;
        _queueName = config["Storage:QueueName"] ?? "attachment-uploaded";
    }

    // ... other actions (Get, Post, etc.) stay as they are ...

    [HttpPost("{id}/attachment")]
    [RequestSizeLimit(50_000_000)]
    public async Task<IActionResult> PostAttachment(int id, IFormFile file)
    {
        // ... existing body from cad-blob-uploader Phase 3 stays unchanged:
        // resolve userId, owner-scoped lookup, generate blob name,
        // upload stream, set todo.AttachmentBlobName + ContentType,
        // await _db.SaveChangesAsync();

        // NEW — append this block AFTER SaveChangesAsync, BEFORE the existing return:
        var queue = _queueService.GetQueueClient(_queueName);
        await queue.CreateIfNotExistsAsync();
        var payload = JsonSerializer.Serialize(new
        {
            todoId = todo.Id,
            blobName = todo.AttachmentBlobName,
            ownerId = userId,
            uploadedAt = DateTimeOffset.UtcNow
        });
        await queue.SendMessageAsync(payload);

        return Ok(new { todo.Id, todo.AttachmentBlobName });
    }
}
```

**Verify locally:**
1. Start Azurite, the API (`dotnet run`), and the Function (`func start`) in three terminals.
2. From a fourth terminal, run the full upload smoke test from `cad-deploy-app-service` Phase 4 against `http://localhost:5000`.
3. Watch the Function terminal — within a second of the upload completing, you should see the queue message logged.

**Concepts to name out loud:**
- *This is loose coupling* — the API doesn't know the Function exists. The Function doesn't know the API exists. They share **a queue name** in storage. Either side can be redeployed, scaled, or rewritten in a different language without the other noticing. Name it; this is the structural payoff of message-driven design.
- *This is "fire and forget" with a twist* — the API writes a message and returns 200 to the client immediately. The work the Function does happens *after* the response. The user gets a fast API; the heavy work runs asynchronously. Name the latency-vs-correctness tradeoff: the upload feels instant; the metadata appears a moment later. If your domain can't tolerate that gap, you'd do the work inline. (Storage Queue gives you "at-least-once" delivery; the message *will* be processed, but maybe twice — Phase 4.)
- *This is `MessageEncoding.Base64`* — Storage Queue messages historically were XML-encoded, then libraries shifted to base64 to safely transport binary. The new Azure SDK default is `None`, but the Functions runtime *expects* base64. Mismatched encodings = silent failures (message arrives but the trigger never fires). Use base64 on both ends. Name it; this gotcha is brutal because nothing logs an error.
- *This is the same managed-identity pattern* — the cloud-path branch in `Program.cs` uses `DefaultAzureCredential` against a `QueueServiceUrl`. Identical shape to the `BlobServiceClient` registration from `cad-deploy-app-service`. Naming patterns out loud is how learners start to *expect* them; this is the third time it's appeared.

**Common gotchas:**
- Forgetting `await queue.CreateIfNotExistsAsync()` — first message fails with "The specified queue does not exist." Either create the queue at startup or call it on every send (cheap, idempotent).
- Encoding mismatch (default `None` in `QueueServiceClient`, base64 expected by the Functions trigger) — message arrives in Azurite but trigger never fires. Set `MessageEncoding = QueueMessageEncoding.Base64` on both the producer and (in the Function trigger attribute, if needed) the consumer.
- Awaiting `SendMessageAsync` *before* `SaveChangesAsync` — if the DB save fails after the queue message is sent, the Function will run for a TODO that doesn't exist. Order matters: persist the source of truth first, *then* announce it. (Bonus naming: this is the **dual-write problem**. Real systems use outbox patterns; we don't go there here, just name it.)
- API and Function pointing at different Azurite instances — only one process can bind to ports 10000–10002 at a time. If `func start` fails with "Address already in use," kill the other Azurite or share one instance.

**After-action prompt:** *"You added a `SendMessageAsync` call after `SaveChangesAsync`. What's the order, why, and what would happen if you swapped them?"*

### Phase 3 — Implement the real handler with a Blob input binding + Blob output binding (~25 min)

**Goal:** Replace the "log the message" placeholder with the actual work: parse the JSON message, download the blob, compute SHA-256 and byte length, and write a `metadata/<blobname>.json` sibling blob using an **output binding** instead of an explicit SDK call.

**Files touched:**
- `TodoApi.Worker/OnAttachmentUploaded.cs` — full rewrite below
- `TodoApi.Worker/TodoApi.Worker.csproj` — already has the blob extension package from Phase 1; confirm

**Full replacement for `OnAttachmentUploaded.cs`:**
```csharp
using System.Security.Cryptography;
using System.Text.Json;
using Azure.Storage.Blobs;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace TodoApi.Worker;

public record AttachmentMessage(int TodoId, string BlobName, string OwnerId, DateTimeOffset UploadedAt);

public record AttachmentMetadata(string BlobName, string OwnerId, long Bytes, string Sha256, DateTimeOffset ProcessedAt);

public class OnAttachmentUploaded
{
    private readonly ILogger<OnAttachmentUploaded> _log;

    public OnAttachmentUploaded(ILogger<OnAttachmentUploaded> log)
    {
        _log = log;
    }

    [Function(nameof(OnAttachmentUploaded))]
    [BlobOutput("metadata/{BlobName}.json", Connection = "StorageConnection")]
    public async Task<string> Run(
        [QueueTrigger("attachment-uploaded", Connection = "StorageConnection")] AttachmentMessage message,
        [BlobInput("todo-attachments/{BlobName}", Connection = "StorageConnection")] Stream blobStream)
    {
        var sw = System.Diagnostics.Stopwatch.StartNew();

        // Stream straight into the hasher — no full-file buffer in memory.
        using var sha = SHA256.Create();
        var hashBytes = await sha.ComputeHashAsync(blobStream);
        var hash = Convert.ToHexString(hashBytes).ToLowerInvariant();
        var size = blobStream.Length;

        var metadata = new AttachmentMetadata(
            BlobName: message.BlobName,
            OwnerId: message.OwnerId,
            Bytes: size,
            Sha256: hash,
            ProcessedAt: DateTimeOffset.UtcNow);

        _log.LogInformation(
            "Processed {Blob} for owner {Owner}: {Bytes} bytes, sha256={Hash}, took {Ms}ms",
            message.BlobName, message.OwnerId, size, hash, sw.ElapsedMilliseconds);

        return JsonSerializer.Serialize(metadata, new JsonSerializerOptions { WriteIndented = true });
    }
}
```

**Verify end-to-end locally:**
1. Restart `func start` (the host needs a fresh build for binding changes).
2. Upload a file via the API.
3. Open Storage Explorer (or use `az storage blob list --container-name metadata --connection-string "UseDevelopmentStorage=true"`).
4. You should see `<blobname>.json` with the hash, size, owner, and processed-at timestamp.

**Concepts to name out loud:**
- *This is binding-as-method-signature* — the `[QueueTrigger]` and `[BlobInput]` attributes turn parameter names into runtime wiring. The runtime parses the queue message JSON into your `AttachmentMessage` record (no `JsonSerializer.Deserialize` call), pulls the matching blob into a `Stream`, and you write code as if both arrived by magic. **The return value is the output binding** — whatever you return gets written to `metadata/<blobName>.json`. This is what people mean when they call Functions "code at the speed of attributes." Name it.
- *This is the binding expression `{BlobName}`* — curly braces inside binding paths reference properties of the trigger payload. The Functions runtime parses the queue message into your `AttachmentMessage` record, then exposes each property (`BlobName`, `OwnerId`, `TodoId`) as a binding variable. So `metadata/{BlobName}.json` substitutes the property at invocation time. Same trick works for `{OwnerId}` if you wanted a per-owner folder. Name the indirection; it feels magical until you see the pattern. (Older docs sometimes show `{message.BlobName}` — don't use that form in the isolated worker; it inconsistently resolves and silently writes to the wrong path.)
- *This is "you don't open a `BlobServiceClient`"* — the input binding gave you a `Stream`. No SDK instantiation, no `GetBlobContainerClient`, no `OpenReadAsync`. The runtime did it. **In production**, teams sometimes drop the binding and use the SDK directly because bindings hide where authentication and retries happen. For a small handler, bindings win. For complex flows, explicit SDK wins. Name the tradeoff.
- *This is streaming hash computation* — `SHA256.ComputeHashAsync(stream)` reads the blob in chunks and never holds the whole file in memory. Critical for the 50 MB upload limit from `cad-blob-uploader` Phase 3 — a memory-buffering hash would explode under load. Name it; this is one of those "I never thought about it" moments that separates intermediate from senior.

**Common gotchas:**
- Forgetting `Connection = "StorageConnection"` on the bindings — the runtime defaults to `AzureWebJobsStorage`. Works locally because both point at Azurite, but in cloud the function runtime might use a different storage account than your data. Be explicit.
- Returning `null` or an empty string from the function — the output binding writes that empty value to the blob, silently producing an empty file. If you want to *conditionally skip* the output, you need a different binding shape (`out` parameter set to null + `[Optional]`). For now, always return a payload.
- Stream position not at zero — if you `await blobStream.ReadAsync(...)` before hashing, the hasher gets fewer bytes. We don't read anything before `sha.ComputeHashAsync(blobStream)` here, but warn the learner: if you ever pre-read the stream, call `blobStream.Position = 0` before hashing.
- Adding the `using Microsoft.Azure.Functions.Worker.Extensions.Storage.Blobs` somewhere it isn't needed — the binding attributes live in `Microsoft.Azure.Functions.Worker`; the *package* registers them. You install the package; you don't `using` it.

**After-action prompt:** *"Your function method takes a `Stream` parameter for the blob. Who opened that stream, and when does it get closed?"*

### Phase 4 — Idempotency + poison messages (~20 min)

**Goal:** Make the handler safe to run twice on the same message (idempotent) and configure what happens when a message fails repeatedly (poison queue). Both are real production concerns that bite the *first* time the queue retries a message — usually in production, at 2 AM, with no rehearsal.

**Concept work first** (~5 min of mentor explanation):
- Storage Queue guarantees **at-least-once delivery**. If your handler crashes mid-execution, the message becomes visible again after the lock expires (default 30 seconds) and another (or the same) worker picks it up.
- A handler is **idempotent** if running it N times produces the same observable state as running it once. Our handler today is *almost* idempotent: hashing the same blob produces the same hash, but `BlobOutput` overwrites the metadata blob each time. That's fine — same input → same output → same blob written. Lucky.
- A **poison message** is one that fails every retry. Storage Queue moves it to `<queue-name>-poison` after `MaxDequeueCount` attempts (default 5). Nothing watches that queue unless you make something watch it.

**Idempotency stance for this handler** — we are **not adding an explicit skip check**. Our handler is *naturally* idempotent: hashing the same blob always produces the same hash, and `BlobOutput` overwrites the metadata blob with the same bytes. Running it twice = running it once, observable-state-wise.

> **The production answer**, when the work isn't naturally idempotent (e.g. "charge a credit card"), is to include an **idempotency key** in the message (often a GUID generated by the producer) and have the handler check "have I already processed this key?" against a store (Cosmos, Redis, a `processed_messages` table) before doing the work. The check + the work need to be transactional with the result write, which is why this gets hard fast. **For this project, name the pattern; don't build it.**

**Configure max retries + poison queue** — edit `host.json`:
```json
{
  "version": "2.0",
  "extensions": {
    "queues": {
      "maxDequeueCount": 5,
      "visibilityTimeout": "00:00:30",
      "batchSize": 16,
      "newBatchThreshold": 8
    }
  },
  "logging": {
    "applicationInsights": {
      "samplingSettings": { "isEnabled": true, "excludedTypes": "Request" }
    }
  }
}
```

**Add a poison-queue handler** — drop a second function into `OnAttachmentUploaded.cs`:
```csharp
public class OnAttachmentPoisoned
{
    private readonly ILogger<OnAttachmentPoisoned> _log;

    public OnAttachmentPoisoned(ILogger<OnAttachmentPoisoned> log)
    {
        _log = log;
    }

    [Function(nameof(OnAttachmentPoisoned))]
    public void Run(
        [QueueTrigger("attachment-uploaded-poison", Connection = "StorageConnection")] string message)
    {
        // Production: write to a deadletter table, page an on-call, file an issue.
        // For learning: log loudly so the learner sees the queue exists and was used.
        _log.LogError("POISON MESSAGE: {Message}. Investigate manually.", message);
    }
}
```

**Force a poison-message scenario locally:**
1. In `OnAttachmentUploaded.Run`, temporarily add `throw new InvalidOperationException("forced failure");` as the first line.
2. Restart `func start`.
3. Upload one attachment via the API.
4. Watch the Function host — same message tries 5 times, then `OnAttachmentPoisoned` fires with the original message.
5. Remove the `throw`. Restart.

**Concepts to name out loud:**
- *This is at-least-once delivery* — Storage Queue guarantees no message is *lost*. It does **not** guarantee no message is *duplicated*. Any handler that mutates state must assume it might run twice on the same input. Name it; this is the single biggest design fact in message-driven systems.
- *This is idempotency* — a property of your code, not of the queue. The queue gives you the same message twice; your handler decides whether that's a bug or a no-op. Hashing + overwrite = naturally idempotent. Charging a credit card = needs an idempotency key. Name the spectrum.
- *This is `visibilityTimeout`* — when a worker picks up a message, the queue hides it for 30 seconds. If the worker finishes within 30 seconds, it deletes the message. If it crashes or takes longer, the message reappears and another worker (or the same one, retried) picks it up. Tune this to be longer than your worst-case processing time, but not so long that crashes go undetected forever. Name the tradeoff.
- *This is the poison queue* — Storage Queue auto-creates `<queue>-poison` and moves any message that fails `maxDequeueCount` times. **By default nobody is listening.** A queue with no poison handler is a silent failure machine. The `OnAttachmentPoisoned` function above is the minimum production-ready answer. Name it.
- *This is "always have a deadletter strategy"* — the question isn't "will we have poison messages?" It's "do we know about them?" Logging them is the floor; alerting on them is the bar. Name it as a checklist item for every queue-driven feature.

**Common gotchas:**
- `maxDequeueCount` set too low (e.g. 1) — transient errors (network blips, throttling) cause the message to immediately become poison. Default 5 is usually right.
- Forgetting that the poison queue is **a different queue** — connecting to `attachment-uploaded` and grepping for failures won't find anything. The poison queue is `attachment-uploaded-poison` (suffix).
- `visibilityTimeout` shorter than the handler's runtime — handler is still working when the lock expires; a second worker picks up the same message; both finish; you have a duplicate. Symptoms: spurious "duplicate write" errors that vanish in dev where the handler is fast.
- Re-deploying the function while the queue has un-processed messages — the new code will pick them up on next visibility expiry. If the new code has a breaking bug, those messages all become poison. Name the operational pattern: **drain the queue or pause the trigger before risky deploys**.

**After-action prompt:** *"You forced a failure. The message ran 5 times, then moved to the poison queue. Walk me through what would have happened in production if you hadn't added `OnAttachmentPoisoned`."*

### Phase 5 — Deploy the Function to Azure with shared managed identity, full end-to-end smoke (~20 min)

**Goal:** Create a Function App on the **Consumption plan** (pay-per-execution, scale-to-zero), grant it the same Storage Blob + Queue roles the App Service already has, deploy from the project folder, and run the smoke test against the deployed API. Watch the metadata blob appear in cloud storage within seconds of upload.

**Commands the learner runs (PowerShell, in the same terminal that still has `$rg`, `$storageName`, `$appName`, `$storageUrl` from project #7):**
```powershell
$funcName = "$appName-worker"   # globally unique; reuse the unique tail from $appName

# Function App needs its own storage *for runtime metadata* (separate from data storage)
$funcRuntimeStorage = ($storageName + "fn")
az storage account create -n $funcRuntimeStorage -g $rg -l $loc --sku Standard_LRS

# Create the Function App on the Consumption plan (Y1 = consumption SKU)
az functionapp create -n $funcName -g $rg `
  --storage-account $funcRuntimeStorage `
  --consumption-plan-location $loc `
  --runtime dotnet-isolated --runtime-version 8 `
  --functions-version 4 `
  --os-type Linux

# Turn on the managed identity
az functionapp identity assign -n $funcName -g $rg
$funcPrincipalId = az functionapp identity show -n $funcName -g $rg --query principalId -o tsv

# Grant it Blob Data Contributor + Queue Data Contributor on the shared data storage
$storageId = az storage account show -n $storageName -g $rg --query id -o tsv
az role assignment create --assignee $funcPrincipalId --role "Storage Blob Data Contributor" --scope $storageId
az role assignment create --assignee $funcPrincipalId --role "Storage Queue Data Contributor" --scope $storageId

# Wire the Function App's settings — point StorageConnection at the data storage account via identity
# Note the __serviceUri / __queueServiceUri / __blobServiceUri convention — this is how the
# Functions extensions consume managed-identity connections.
az functionapp config appsettings set -n $funcName -g $rg --settings `
  "StorageConnection__queueServiceUri=https://$storageName.queue.core.windows.net" `
  "StorageConnection__blobServiceUri=https://$storageName.blob.core.windows.net"

# Deploy from the worker project folder
cd path\to\TodoApi.Worker
func azure functionapp publish $funcName

# Also wire the API to write to the queue using managed identity in the cloud
az webapp config appsettings set -n $appName -g $rg --settings `
  "Storage__QueueServiceUrl=https://$storageName.queue.core.windows.net" `
  Storage__QueueName="attachment-uploaded"

# Redeploy the API so it picks up the QueueServiceClient registration
cd path\to\TodoApi
az webapp up -n $appName -g $rg

# End-to-end smoke: upload a file, then look for the metadata blob
$url = "https://$appName.azurewebsites.net"
# (re-run the login + upload flow from cad-deploy-app-service Phase 4 against $url)

# After ~5 seconds, list the metadata container
az storage blob list --account-name $storageName --container-name metadata --auth-mode login -o table
```

**Concepts to name out loud:**
- *This is the Consumption plan* — Azure runs your function on shared infrastructure. You pay per execution (sub-cent per invocation + GB-seconds) and **scale to zero** when idle (no executions = no charge). Cold start (200ms–2s for .NET) is the cost. For background processors, almost always the right tier. Premium plan eliminates cold start but charges per-vCPU even when idle. Name the tradeoff.
- *This is two storage accounts* — the Function App needs **its own storage account** for runtime metadata (function key state, timer locks, instance tracking). That's separate from the **data storage account** where your blobs and queues live. This trips everyone; name it explicitly. Sharing storage between Function runtime and data is technically allowed but invites contention.
- *This is the managed-identity connection naming convention* — for Function triggers/bindings that use managed identity, you set `<ConnectionName>__queueServiceUri` (and `__blobServiceUri`, `__tableServiceUri`) instead of `<ConnectionName>` with a full connection string. The double-underscore suffix tells the extension: *"use identity to talk to this endpoint."* Name it; it's not obvious from the docs, and every learner spends 20 minutes debugging it the first time.
- *This is the full picture* — by the end of this phase, the system is: API → writes blob → writes queue message → Function trigger fires → Function reads blob → Function writes metadata blob. **Five Azure resources** (App Service + Storage data account + Storage Queue + Function App + Function runtime storage). All connected by managed identity. No secrets anywhere in source. Name the assembly explicitly; this is the kind of system the learner now knows how to wire from scratch.

**Common gotchas:**
- Function name not globally unique — `*.azurewebsites.net` is one namespace shared by both Web Apps and Function Apps. If `$funcName` collides with `$appName`, add another suffix.
- Using `Storage__ConnectionString` instead of `__blobServiceUri` for managed-identity bindings — Function won't recognize the identity setup and will fail at startup with a confusing connection-string-required error. Use the `__blobServiceUri` / `__queueServiceUri` form.
- Function App identity missing the **Queue** role even though Blob role is granted — Function starts but the trigger never fires (it can't read the queue to know there's a message). Both roles required.
- Cold start on the first message — after a deploy or 5+ minutes of idle, the first message takes 1–2 seconds to process. Subsequent messages in the same window are warm. If the smoke test seems "stuck," wait 10 seconds.
- `func azure functionapp publish` from the wrong folder — same gotcha as `az webapp up` in #7. Always `cd` into the worker project folder first.

**After-action prompt:** *"You uploaded one file. List every byte that moved between resources from `POST` to metadata blob appearing — and which Azure identity authorized each hop."*

## When to break the method

The ride-along method assumes the learner can drive the keyboard. If during any phase you discover:

- **Learner has never seen `await` / `async`** — Phase 1's function method is `async Task<string>`. Pause for a 5-minute aside on async/await fundamentals before going further; you'll lose them on Phase 3 otherwise.
- **Learner doesn't understand serialization** — the queue message is JSON in/out. If they're shaky on `JsonSerializer.Serialize` and DTOs/records, slow down on Phase 2 and walk through one round-trip by hand.
- **Functions Core Tools won't install / run** — break the session; spend 15 min fixing it. There is no productive "let's read about Functions" path that bypasses the local runtime. The CLI is the IDE for this work.
- **Azurite issues** (ports in use, won't start, locked DB) — pause and resolve. Trying to develop Functions against cloud storage from a laptop is slow and expensive. Azurite has to work.
- **Learner panics at "queues"** — the word triggers memories of message-bus complexity. 3-minute aside with the postal-mail analogy: producer drops a postcard in a mailbox, consumer empties the mailbox on their schedule. Don't go deeper; the abstraction is enough.

These are not method failures. The ride-along method *expects* the mentor to drop into a 3–5 minute concept tangent when a foundation is missing.

## Definition of done

- Local: API upload → message visible in Azurite queue → Function picks it up → metadata blob appears in Azurite
- Cloud: API upload (against the deployed `$appName`.azurewebsites.net) → Function fires within 10 seconds → metadata blob visible in the cloud storage account
- Forced-failure run: a `throw` in the handler causes 5 retries, then poison-queue handler fires (verified via log output)
- `host.json` declares `maxDequeueCount`, `visibilityTimeout`, and batching settings explicitly
- The Function uses managed identity in the cloud (no connection string with key in the function's App Settings)
- Learner can name, without looking: at-least-once delivery, idempotency, visibility timeout, poison queue, the difference between trigger and binding, the difference between isolated and in-process model, the difference between Function-runtime storage and data storage

## Next project

If learner wants to put this whole thing under a build pipeline → [`cad-cicd-pipeline`](../cad-cicd-pipeline/SKILL.md).
