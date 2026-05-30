---
name: cad-deploy-app-service
description: Build progression that deploys the secured TODO API (with blob attachments) from cad-blob-uploader to Azure App Service. Use when the learner wants to learn Azure App Service, deployment slots, app settings, Key Vault references, managed identity, and configuration-as-code hands-on. Pairs with the ride-along method.
---

# Skill: cad-deploy-app-service

The learner takes the local TODO API — JWT auth, EF + SQLite, Azure Blob attachments — and ships it to **Azure App Service**, the platform-as-a-service home for ASP.NET Core apps. By the end, the API runs on a real `*.azurewebsites.net` URL with HTTPS, the JWT signing key lives in **Azure Key Vault** (not source control), the storage connection uses **managed identity** (no secrets), and the learner can roll forward a new version without downtime via a **deployment slot**.

This is project #7 in the [CAD track](../README.md). It is a **build recipe**, not a lecture. The mentor uses it to know what to build and which concepts to surface; *how* to teach those concepts lives in [`methods/ride-along`](../../../methods/ride-along/SKILL.md).

## Project goal

A live `https://<your-name>-todo-api.azurewebsites.net` URL where:

- The `/auth/login` endpoint issues JWTs signed with a key stored in Key Vault.
- The `/todos/{id}/attachment` endpoints talk to a real Azure Storage account using the App Service's managed identity (no connection string in config).
- A **staging slot** runs alongside production; learner can deploy, smoke-test, and swap.
- The SQLite file lives on App Service's local disk (good enough for this project; a real product would move to Azure SQL — name that, don't build it).

The learner ends with a URL they can send to a friend, a portal they can navigate, and a working understanding that "deploying to the cloud" is mostly a configuration exercise once the app itself is correct.

> **Scope guardrail.** This project assumes the learner has an Azure subscription (the MSSA program provides free credits via Azure for Students or Visual Studio subscription). All resources are created in a single resource group the learner can delete in one click when they're done. We use the **F1 (free) or B1 (basic, ~$13/month) tier** of App Service — both are enough for this work. We do **not** set up a custom domain, a CDN, or a WAF. Those are the right answers for a real product and they're out of scope here.

## Prerequisites

| Need | Why |
|---|---|
| `cad-blob-uploader` complete OR equivalent | This project deploys that one. There must be a working API with JWT auth + blob attachments. |
| Azure subscription (free credits OK) | Need to actually create cloud resources. Verify the learner can log into [portal.azure.com](https://portal.azure.com) **before** Phase 1 starts. |
| Azure CLI installed (`az --version` returns 2.60+) | We script the resource creation. `winget install Microsoft.AzureCLI` on Windows. |
| `az login` works | Run it once before the session. If it opens a browser and shows the subscription, you're good. |
| Git repo for the project | App Service deploys from a git push (or a zip). The learner doesn't need GitHub yet — local git is enough for now. |

If `az login` doesn't show a subscription, **stop and resolve before Phase 1**. Trying to debug auth mid-deploy is a session-killer.

## Phases

Each phase ends with a working build the learner can run or a real Azure resource. After every phase, run a brief **after-action review** per the ride-along method.

### Phase 1 — Create the Azure resources (~25 min)

**Goal:** Learner uses the Azure CLI to create a resource group, App Service plan, App Service (Web App), Storage account, and Key Vault. App is empty (nothing deployed) but reachable at `https://<name>.azurewebsites.net` showing the default landing page.

**Commands the learner runs** (PowerShell — one at a time, naming things as we go):
```powershell
# Variables (set these once in the terminal; $suffix gives every resource a unique tail)
$suffix = Get-Random -Maximum 9999
$rg = "rg-todo-api-dev"
$loc = "eastus2"
$appName = "<your-initials>-todo-api-$suffix"           # must be globally unique
$storageName = "<yourinitials>todoapi$suffix"           # lowercase, alphanumeric only
$vaultName = "kv-<your-initials>-todo-$suffix"

# Create resource group (a folder for everything)
az group create -n $rg -l $loc

# Create App Service plan (the VM your app runs on — F1 is free)
az appservice plan create -n plan-todo-api -g $rg --sku F1 --is-linux

# Create the Web App
az webapp create -n $appName -g $rg -p plan-todo-api --runtime "DOTNETCORE:8.0"

# Create storage account (for blob attachments)
az storage account create -n $storageName -g $rg -l $loc --sku Standard_LRS

# Create Key Vault (for the JWT signing key)
az keyvault create -n $vaultName -g $rg -l $loc --enable-rbac-authorization true
```

> **PowerShell vs bash.** Every command block in this skill is written for PowerShell because the MSSA toolchain runs on Windows. If the learner is on macOS or in Git Bash, the `az` commands are identical — only the variable syntax differs (`$rg=...` with no `$` on assignment in bash, `$RANDOM` instead of `Get-Random`, `$(...)` for command substitution instead of `$(...)` capture). Don't switch shells mid-session; the variable names won't carry across terminals.

**Files touched:** none locally. Everything lives in Azure now.

**Concepts to name out loud:**
- *This is a resource group* — Azure's folder. Everything in it shares lifecycle, billing, access control. Delete the group → delete every resource inside. The single most useful undo button in cloud development. Name it.
- *This is an App Service plan vs an App Service* — the **plan** is the VM (CPU, RAM, region). The **App Service** (Web App) is the application running on that VM. One plan can host many apps. Pricing lives on the plan, not the app. F1 (free) supports up to 10 apps; B1 supports unlimited within its CPU/RAM. Confused learners almost always confuse these two — name the difference now.
- *This is `az` as the canonical interface* — every Azure resource has the same triple: portal (point-and-click), CLI (`az`), REST API. The CLI is what production teams use because it's scriptable, reviewable, and the same commands work in CI/CD. Name it. We'll use `az` for everything; we'll *also* visit the portal so the learner sees what was created.
- *This is the `*.azurewebsites.net` URL* — App Service gives every app a free default domain with HTTPS already configured. Production teams add a custom domain (e.g. `api.example.com`) later. For this project the default is fine.
- *This is `--sku F1`* — the SKU is the size/tier. F1 = free, B1 = basic ($13/mo), P1V3 = production. They differ in CPU, RAM, scale-out, custom domains, etc. F1 has hard limits (60 min/day CPU, no always-on, no custom domain) that bite later. For learning, F1 is great. Name the tradeoff so the learner knows when to upgrade.
- *This is `--enable-rbac-authorization`* — Key Vault has two access models: the legacy **access policy** model and the modern **RBAC** model. Use RBAC. Phase 3 will grant the App Service's managed identity a *role* on the vault, not an access policy entry. RBAC is consistent with the rest of Azure; access policies are not.

**Common gotchas:**
- App Service name not globally unique — `azurewebsites.net` names share the global DNS namespace. Pick something unique. Include `$RANDOM` or your initials + date.
- Storage account name rules — must be lowercase, 3–24 chars, letters and digits only. No dashes. (Yes, this is inconsistent with every other Azure resource. Live with it.)
- Region picking — pick the same region for every resource in the group. Cross-region traffic costs money and adds latency. `eastus2` is a safe default for North America.
- F1 tier and the SQLite file — F1's local disk is wiped on restart. SQLite data won't survive a deploy. We accept this for now; production would use Azure SQL or Postgres. Name the limitation.

**After-action prompt:** *"You created 5 resources. What's in the resource group, and which one would you delete first if you wanted to keep the storage data?"*

### Phase 2 — Push the JWT signing key to Key Vault, wire App Settings (~25 min)

**Goal:** Move secrets out of `appsettings.json`. The JWT signing key lives in **Key Vault**; the App Service reads it via a **Key Vault reference** in its **App Settings**. The storage connection moves to App Settings (still a connection string for now — managed identity comes in Phase 3).

**Commands the learner runs:**
```powershell
# Generate a strong JWT signing key (random 48 bytes → base64)
$bytes = New-Object byte[] 48
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$jwtKey = [Convert]::ToBase64String($bytes)

# Store it in Key Vault
az keyvault secret set --vault-name $vaultName --name JwtSigningKey --value $jwtKey

# Get the App Service's managed identity (turn it on)
az webapp identity assign -n $appName -g $rg

# Grant the App Service "Key Vault Secrets User" role on the vault
$appPrincipalId = az webapp identity show -n $appName -g $rg --query principalId -o tsv
$vaultId = az keyvault show -n $vaultName --query id -o tsv
az role assignment create --assignee $appPrincipalId `
  --role "Key Vault Secrets User" --scope $vaultId

# Wire App Settings (key is a Key Vault reference; storage is a connection string for now)
$storageConn = az storage account show-connection-string -n $storageName -g $rg --query connectionString -o tsv
az webapp config appsettings set -n $appName -g $rg --settings `
  Jwt__Issuer="todo-api" `
  Jwt__Audience="todo-api-clients" `
  "Jwt__Key=@Microsoft.KeyVault(VaultName=$vaultName;SecretName=JwtSigningKey)" `
  "Storage__ConnectionString=$storageConn" `
  Storage__ContainerName="todo-attachments"
```

**Files touched:**
- `appsettings.json` — keep the local dev values; App Service settings override them at runtime.
- `appsettings.Development.json` — confirm dev values stay here and don't leak to production.

**Concepts to name out loud:**
- *Your existing controller code does not change* — the `AuthController` from `cad-todo-api-auth` already reads `_config["Jwt:Key"]`. After Phase 2, that same line returns the Key Vault secret instead of the value from `appsettings.json`. **No code edit.** This is *the* moment to name what's powerful here: secrets moved out of source control, and the application doesn't know or care. Name it before naming the mechanism.
- *This is configuration overrides* — ASP.NET Core's `IConfiguration` reads from multiple sources in a defined order: `appsettings.json` → `appsettings.{Environment}.json` → environment variables → command-line args. App Service injects **App Settings as environment variables**, so they override the JSON files. Same code; different config per environment. Name it; this is the entire premise of "config follows the deploy, code doesn't."
- *This is the `__` (double underscore) convention* — App Settings can't contain `:` (Azure portal limitation). ASP.NET Core converts `__` to `:` at read-time. So `Jwt__Key` in App Settings = `Jwt:Key` in `IConfiguration`. Name it; it's the #1 "why isn't my setting being read?" gotcha.
- *This is managed identity* — instead of giving your app a username and password, Azure gives it an **identity** automatically. The app can prove it's itself to other Azure services (Key Vault, Storage, SQL) without any secrets in config. `az webapp identity assign` turns it on; `az role assignment create` says what it's allowed to do. This is the cloud-native answer to "where do I put the password?" — *you don't*.
- *This is a Key Vault reference* — the magic string `@Microsoft.KeyVault(VaultName=...;SecretName=...)` in App Settings tells App Service: *"at runtime, fetch this secret from the vault using my managed identity and inject it as the value."* Your code reads `_config["Jwt:Key"]` and gets the actual secret. The secret never appears in your code, your config files, or the portal. Name the indirection clearly.
- *This is "Key Vault Secrets User"* — the minimum RBAC role to read secrets. Don't grant "Key Vault Administrator" — that lets the app *write and delete* secrets too. Principle of least privilege: smallest role that does the job. Name it; it's a habit worth building now.

**Common gotchas:**
- Forgetting `--enable-rbac-authorization` when creating the vault — `az role assignment create` will fail with a confusing error because the vault is in access-policy mode. Recreate the vault if so.
- Pasting the Key Vault reference with the wrong syntax — must be exactly `@Microsoft.KeyVault(VaultName=...;SecretName=...)` with semicolon, no spaces. If it fails, App Service treats the literal string as the value and the JWT signing fails silently.
- App Settings using `:` instead of `__` — looks fine in portal, doesn't work at runtime. ASP.NET Core won't find the key.
- Granting the role before the managed identity exists — `az webapp identity assign` first, *then* `az role assignment create`. Order matters because the second command references the identity from the first.
- Role assignment taking 1–2 minutes to propagate — first request after granting may still return 403. Wait, retry.

**After-action prompt:** *"Where does the JWT signing key actually live now? Walk through the chain from `_config[\"Jwt:Key\"]` in the controller back to where the bytes are stored."*

### Phase 3 — Switch storage to managed identity (~25 min)

**Goal:** Replace the storage connection string with managed-identity auth. Code change: `BlobServiceClient` is constructed with a service URL and `DefaultAzureCredential` instead of a connection string. Azure change: grant the App Service the "Storage Blob Data Contributor" role on the storage account.

**Commands the learner runs:**
```powershell
# Grant the App Service's managed identity blob contributor on the storage account
$storageId = az storage account show -n $storageName -g $rg --query id -o tsv
az role assignment create --assignee $appPrincipalId `
  --role "Storage Blob Data Contributor" --scope $storageId

# Replace the connection-string app setting with a service URL
$storageUrl = "https://$storageName.blob.core.windows.net"
az webapp config appsettings delete -n $appName -g $rg --setting-names Storage__ConnectionString
az webapp config appsettings set -n $appName -g $rg --settings "Storage__ServiceUrl=$storageUrl"
```

**Code change** in `Program.cs`:
```csharp
using Azure.Identity;
using Azure.Storage.Blobs;

builder.Services.AddSingleton(sp =>
{
    var url = builder.Configuration["Storage:ServiceUrl"];
    if (!string.IsNullOrEmpty(url))
    {
        // Production / cloud path: managed identity
        return new BlobServiceClient(new Uri(url), new DefaultAzureCredential());
    }
    // Local dev path: connection string to Azurite or a real account
    var conn = builder.Configuration["Storage:ConnectionString"];
    return new BlobServiceClient(conn);
});
```

**Files touched:**
- `<project>.csproj` — `dotnet add package Azure.Identity`
- `Program.cs` — registration above

**Concepts to name out loud:**
- *This is `DefaultAzureCredential`* — a chain of credential providers the Azure SDK tries in order: managed identity (on Azure), VS / VS Code login (on dev machine), Azure CLI login, environment variables. **Same code runs in both places**; the credential resolves differently based on environment. The whole point: you stop writing "if (production) ... else ..." in your auth code. Name it loudly.
- *This is "Storage Blob Data Contributor"* — the role that grants read + write + list on blob data. There's also "Storage Blob Data Reader" (read-only) and "Storage Account Contributor" (manages the storage account itself, *not* the data — confusingly named). Pick the data role, not the account role. This trips everyone.
- *This is the SAS-URL coda* — back in `cad-blob-uploader` Phase 4, we wrote `blob.CanGenerateSasUri` as a guard. Now we hit the reason: managed-identity-based clients **cannot** generate a SAS the simple way. They need a **user delegation key** (`BlobServiceClient.GetUserDelegationKey(...)`). The simple SAS code from Phase 4 will throw at runtime when deployed. Two paths: (a) keep SAS, refactor to user delegation key; (b) drop SAS, stream the file through the API with `return File(...)` and accept the bandwidth cost. **For this project, pick (b)** — it's one method change, no new auth concept. Name (a) so the learner knows the production answer exists.
- *This is one bridge between dev and prod* — the `Program.cs` ternary (`ServiceUrl` → managed identity vs `ConnectionString` → Azurite) is the textbook pattern. Both paths run the same code downstream. Name the pattern; it shows up for every Azure SDK client.

**Code change** for the SAS coda — **delete the entire existing `GetAttachment` method** in `TodosController.cs` (the SAS version from `cad-blob-uploader` Phase 4) and paste this replacement into the same controller. The `using` directives at the top of the file should already include the four we need from `cad-blob-uploader` (`Azure.Storage.Blobs`, `Microsoft.AspNetCore.Authorization`, `Microsoft.AspNetCore.Mvc`, `Microsoft.EntityFrameworkCore`, `System.Security.Claims`) — confirm before pasting:
```csharp
using Azure.Storage.Blobs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
// ... existing class with [Authorize][ApiController][Route("todos")] and the
// _db / _blobService fields and constructor from cad-blob-uploader stay as-is.

[HttpGet("{id}/attachment")]
public async Task<IActionResult> GetAttachment(int id)
{
    var userId = User.FindFirstValue("sub");
    var todo = await _db.Todos.FirstOrDefaultAsync(t => t.Id == id && t.OwnerId == userId);
    if (todo is null || todo.AttachmentBlobName is null) return NotFound();

    var blob = _blobService.GetBlobContainerClient("todo-attachments")
                           .GetBlobClient(todo.AttachmentBlobName);
    var stream = await blob.OpenReadAsync();
    return File(stream, todo.AttachmentContentType ?? "application/octet-stream");
}
```

> Note the `using Azure.Storage.Sas;` from `cad-blob-uploader` Phase 4 can stay or go — it's now unused. Removing it keeps the controller clean; either way it compiles.

**Common gotchas:**
- Forgetting to grant the role on the storage account before deploying — first attachment request returns 403. Wait for the role assignment to propagate (1–2 min) and retry.
- Picking the wrong role ("Storage Account Contributor" instead of "Storage Blob Data Contributor") — App Service can manage the storage account *resource* but can't touch blob data. Subtle and common.
- Leaving the SAS code from `cad-blob-uploader` Phase 4 — `CanGenerateSasUri` returns false under managed identity, the endpoint returns the "SAS generation not supported" `Problem` response. Replace the body with the streamed `File(...)` version above.
- `DefaultAzureCredential` working locally because of `az login` — masks managed-identity bugs. The first time you'd notice the role assignment is missing is in production. Walk the learner through `Storage__ServiceUrl` being set locally too (point it at Azurite or skip), so the dev path tests the same code path as production.

**After-action prompt:** *"`DefaultAzureCredential` ran the same line of code on your laptop and on App Service and got a working credential both times. Where did each one come from?"*

### Phase 4 — Deploy with `az webapp up`, smoke-test on the public URL (~20 min)

**Goal:** Push the code, watch the build run on Azure, hit the live URL with `curl`, prove the full flow (login → create TODO → upload attachment → download) works in the cloud.

**Commands the learner runs:**
```powershell
# IMPORTANT: cd into the folder that contains your .csproj before running az webapp up.
# az inspects the current directory to figure out what to publish.
cd path\to\TodoApi   # the folder with TodoApi.csproj

# First deploy — az figures out the runtime and pushes the zip
az webapp up -n $appName -g $rg --runtime "DOTNETCORE:8.0" --os-type Linux

# Watch the live log stream while it starts (Ctrl+C to detach; the app keeps running)
az webapp log tail -n $appName -g $rg
```

**Smoke test** (from a second PowerShell terminal — re-set `$appName` here too since variables don't cross terminals):
```powershell
$appName = "<paste the same name from Phase 1>"
$url = "https://$appName.azurewebsites.net"

# 1. Login
$loginResponse = Invoke-RestMethod -Method Post -Uri "$url/auth/login" `
  -ContentType "application/json" `
  -Body '{"username":"alice","password":"alicepw"}'
$token = $loginResponse.token
$token  # should be a JWT

# 2. Create a TODO
Invoke-RestMethod -Method Post -Uri "$url/todos" `
  -Headers @{ Authorization = "Bearer $token" } `
  -ContentType "application/json" `
  -Body '{"title":"Hello from the cloud"}'

# 3. Upload an attachment (PowerShell multipart form)
$form = @{ file = Get-Item .\receipt.jpg }
Invoke-RestMethod -Method Post -Uri "$url/todos/1/attachment" `
  -Headers @{ Authorization = "Bearer $token" } -Form $form

# 4. Download
Invoke-WebRequest -Uri "$url/todos/1/attachment" `
  -Headers @{ Authorization = "Bearer $token" } -OutFile downloaded.jpg

# 5. Confirm bytes match
Get-FileHash .\receipt.jpg, .\downloaded.jpg
```

**Concepts to name out loud:**
- *This is `az webapp up`* — the simplest possible deploy. It zips the project, uploads it, runs `dotnet publish` server-side, and restarts the app. Real teams replace this with GitHub Actions or Azure Pipelines (project #9). For the first deploy ever, `az webapp up` is hard to beat.
- *This is `log tail`* — App Service streams stdout, stderr, and the platform log over a persistent connection. Every startup error, every exception, every `Console.WriteLine` shows up here. Name it; it's *the* debug surface for App Service apps and learners often miss it for months.
- *This is the cold start* — first request after a deploy (or after idle on F1) takes 10–30 seconds because the runtime spins up. Subsequent requests are fast. If the smoke test fails on the first try, retry once before debugging.
- *This is "it works in the cloud now"* — the same code that ran on localhost now runs on a public URL with HTTPS. Nothing in the code changed except the config-reading lines you wrote in Phase 2 and 3. Name the milestone explicitly; this is the entire point of platform-as-a-service.

**Common gotchas:**
- 502 Bad Gateway on first request — almost always cold start. Wait 30 seconds, retry. If still failing, hit `log tail` and look for startup exceptions.
- Missing `appsettings.Development.json` values causing startup failure in cloud — the production environment doesn't read `Development.json`. Make sure every config key the app reads has a value in App Settings.
- F1 tier hitting CPU/quota limits — 60 minutes of compute per day, app shuts down past that. Move to B1 ($13/mo) if the learner wants to keep the app live for a few days of testing.
- Running `az webapp up` from the wrong folder — it auto-detects the project from the current directory. If you run it from the repo root and the `.csproj` is one folder down, you'll get a confusing "could not detect language" or "no app found" error. Always `cd` into the project folder first.

**After-action prompt:** *"You hit `$URL/auth/login` and got a JWT back. List every Azure resource that was involved in serving that one request."*

### Phase 5 — Add a staging slot, deploy + swap without downtime (~25 min)

**Goal:** Create a **deployment slot** named `staging`. Deploy a small change (bump a version string in a response header). Test it on the staging slot's URL. **Swap** with production — instant cutover, zero downtime. Roll back with a second swap if anything's wrong.

**Code change first** — add a tiny piece of middleware to `Program.cs` that stamps an `X-Version` header on every response. This is the signal we'll watch flip when we swap slots:
```csharp
// Add this between `var app = builder.Build();` and `app.UseAuthentication();`
app.Use(async (context, next) =>
{
    context.Response.Headers["X-Version"] = "2";
    await next();
});
```

**Commands the learner runs (PowerShell):**
```powershell
# F1 doesn't support slots — bump to B1 first
az appservice plan update -n plan-todo-api -g $rg --sku B1

# Create the staging slot
az webapp deployment slot create -n $appName -g $rg --slot staging

# Copy app settings into the slot (slot settings are independent by default)
az webapp config appsettings set -n $appName -g $rg --slot staging --settings `
  Jwt__Issuer="todo-api" `
  Jwt__Audience="todo-api-clients" `
  "Jwt__Key=@Microsoft.KeyVault(VaultName=$vaultName;SecretName=JwtSigningKey)" `
  "Storage__ServiceUrl=$storageUrl" `
  Storage__ContainerName="todo-attachments"

# Grant the slot's managed identity the same roles
$slotPrincipalId = az webapp identity assign -n $appName -g $rg --slot staging --query principalId -o tsv
az role assignment create --assignee $slotPrincipalId --role "Key Vault Secrets User" --scope $vaultId
az role assignment create --assignee $slotPrincipalId --role "Storage Blob Data Contributor" --scope $storageId

# Deploy the X-Version: 2 change to the staging slot (run from the project folder)
az webapp up -n $appName -g $rg --slot staging

# Hit the staging URL — note the -staging suffix
(Invoke-WebRequest -Method Head -Uri "https://$appName-staging.azurewebsites.net").Headers["X-Version"]
# Expect: 2

# Hit production — still on the old code
(Invoke-WebRequest -Method Head -Uri "https://$appName.azurewebsites.net").Headers["X-Version"]
# Expect: nothing (no header) or 1 if you ran this before

# Swap staging into production
az webapp deployment slot swap -n $appName -g $rg --slot staging --target-slot production

# Hit production again — same code as staging now
(Invoke-WebRequest -Method Head -Uri "https://$appName.azurewebsites.net").Headers["X-Version"]
# Expect: 2

# Bad version? Swap back instantly (run this same command again)
# az webapp deployment slot swap -n $appName -g $rg --slot staging --target-slot production
```

**Concepts to name out loud:**
- *This is a deployment slot* — a second copy of the app, with its own URL and its own config, running on the same plan. Deploy to staging, test, then **swap** — Azure flips the routing in front of both slots atomically. Production traffic goes to what was staging; old production becomes the new staging (great for instant rollback).
- *This is zero-downtime deploy* — the swap doesn't restart production. Azure warms up the staging slot (runs startup, hits a health endpoint), then flips. The change is invisible to in-flight requests. Name it; this is *the* operational reason to use App Service over a plain VM.
- *This is "slot settings vs app settings"* — by default, app settings travel with the swap (production setting moves to staging on swap). Mark a setting as a **slot setting** to pin it to the slot (e.g. a connection string that should stay pointing at staging's database even after a swap). For this project nothing is pinned, but name the concept.
- *This is the rollback path* — a swap is its own undo. If production starts erroring after the swap, run the swap command again. Old code is back in 30 seconds. No redeploy, no rebuild. Name it as the operational safety net it is.

**Common gotchas:**
- F1 doesn't support slots — Phase 5 starts by upgrading the plan to B1. If the learner skips this, slot creation fails immediately.
- App settings not copied into the new slot — fresh slots come with empty settings. Production secrets don't auto-travel; you have to set them explicitly (or use slot configuration in Bicep/Terraform).
- The slot has a separate managed identity — the production slot's role assignments don't apply to staging. Grant the slot identity its own roles, or the deployed code will get 403s from Key Vault and Storage. (This is the #1 staging-only failure.)
- Swapping with broken staging — the swap will succeed, then production is broken. The fix is *another swap*. Stay calm; that's the whole point.

**After-action prompt:** *"You just deployed a change without taking the API offline. Walk through what Azure actually did between `az webapp deployment slot swap` and the next request hitting the new code."*

## When to break the method

The ride-along method assumes the learner can drive the keyboard. If during any phase you discover:

- **Learner has never used Azure portal or `az` CLI** — pause on Phase 1. 5 minutes navigating the portal: subscription → resource group → resource. Resume.
- **Learner is shaky on environment variables / 12-factor config** — Phase 2 lives or dies on this. If they don't have a model for "config follows the deploy," do a 3-minute aside with a worked example (same code, two configs, two behaviors).
- **Learner doesn't have an Azure subscription** — break the session entirely. Get them signed up for Azure for Students (free, no credit card needed for students; Visual Studio subscribers get $150/month). Trying to mock this on localhost defeats the whole project.
- **Quota or policy blocks a resource** — corporate tenants sometimes have policies that prevent free-tier creation, public IPs, or specific regions. If the learner hits a "request disallowed by policy" error, switch to a different subscription (personal Azure account) or a different region.

These are not method failures. The ride-along method *expects* the mentor to drop into a 3–5 minute concept tangent when a foundation is missing — and for cloud work, sometimes the missing foundation is "have an Azure account."

## Definition of done

- `https://<name>.azurewebsites.net` returns a JWT when called with valid credentials
- A TODO created on the live URL persists across a deploy
- An attachment uploaded on the live URL is visible in the Storage account in the Azure portal
- Downloading the attachment returns the exact bytes that were uploaded
- `appsettings.json` and source control contain **zero secrets** (no JWT key, no storage connection string)
- A `staging` slot exists with the same settings as production
- A swap was performed at least once and verified by an HTTP response header change
- Learner can describe — without looking — what managed identity does, what a Key Vault reference does, why secrets don't live in code, and what a swap accomplishes

## Next project

If learner wants to react to blob uploads with a serverless function → [`cad-function-queue-trigger`](../cad-function-queue-trigger/SKILL.md).
If learner wants to automate this whole deploy → [`cad-cicd-pipeline`](../cad-cicd-pipeline/SKILL.md).
