---
name: cad-cicd-pipeline
description: |
  CAD track project #9. Build a GitHub Actions CI/CD pipeline that builds, tests, and deploys
  both the TodoApi (App Service) from project #7 and the TodoApi.Worker (Function App) from
  project #8. Use OIDC federated credentials (no long-lived secrets), split build/test/deploy
  into separate jobs, gate production deploys behind a GitHub Environment with reviewers, and
  wire a smoke test that fails the pipeline if the deployed system is broken. Auto-load when
  the learner is in `cloud-app-dev/cad-cicd-pipeline` or asks about GitHub Actions, OIDC,
  workflow YAML, federated credentials, deployment environments, or CI/CD for Azure.
---

# Project: `cad-cicd-pipeline`

> **Track:** Cloud App Development · **Project:** 9 of 9 (capstone) · **Time:** ~120 minutes
>
> Wire up GitHub Actions so every push to `main` builds the API and the Worker, runs unit tests, and (on green) deploys both to Azure — App Service and Function App — using OIDC federated credentials. Gate production deploys behind manual approval. End the pipeline with a smoke test that calls the deployed `/health` endpoint and fails the run if it returns anything other than 200.

## Project goal

When this project is done, the learner can:

- Read a GitHub Actions workflow file top-to-bottom and explain what every key does (`on`, `jobs`, `needs`, `permissions`, `environment`, `if`).
- Explain *why* OIDC federated credentials beat client secrets (no secret to rotate, no secret to leak, token scoped to a single workflow run).
- Configure a GitHub Environment with a required reviewer so production deploys require a human click.
- Push a deliberate breakage (e.g. a failing unit test, a 500 in the smoke test) and watch the pipeline catch it *before* anything ships.
- Roll back by re-running a previous green workflow against production.

## Scope guardrail

This is a **GitHub Actions** project. We are not setting up Azure DevOps Pipelines, not building reusable composite actions, not writing custom JavaScript actions, and not configuring self-hosted runners. We use GitHub-hosted Linux runners and stock marketplace actions (`actions/checkout`, `actions/setup-dotnet`, `azure/login`, `azure/webapps-deploy`, `azure/functions-action`).

If the learner already knows GitHub Actions and wants to compare to Azure Pipelines, mention it once (same concepts, different YAML dialect, ADO has stricter approval gates) and move on. **Do not detour.**

## Prerequisites

| Prereq | Verify with |
|---|---|
| Project #7 deployed and reachable (`https://$appName.azurewebsites.net/health` returns 200) | `Invoke-WebRequest "https://$appName.azurewebsites.net/health"` |
| Project #8 deployed and reachable (Function App exists, queue trigger fires end-to-end) | Upload via API → metadata blob appears |
| Code is in a **GitHub** repo (not ADO) — Actions only runs on GitHub | `git remote -v` shows `github.com` |
| You are a GitHub repo **admin** (need to create Environments + Secrets) | Repo Settings → Collaborators shows your role |
| Azure CLI logged in to the same subscription where #7/#8 live | `az account show` |
| `gh` CLI installed and authenticated (`gh auth status`) | `gh --version` |

## Phases

The learner does the work; you (the mentor) explain *why*, point at the *what*, and only *type for them* if they're explicitly stuck and ask. Every phase ends with an after-action prompt.

### Phase 1 — Create the App Registration for OIDC + federated credentials (~25 min)

**Goal:** Stand up an Entra ID app registration that GitHub Actions can authenticate as via OpenID Connect — no client secret stored anywhere. Configure two federated credentials: one trusted for the `main` branch (deploys to prod), one trusted for pull requests (build/test only, no deploy).

**Files touched:** None yet. This phase is all Azure CLI + GitHub CLI.

**Commands the learner runs (PowerShell, in the same terminal where `$rg`, `$appName`, `$funcName` from #7/#8 are still set — or re-set them now):**
```powershell
# Re-set if you opened a fresh terminal
$rg        = "todoapi-rg"          # match project #7
$appName   = "todoapi-<your-tail>" # match project #7
$funcName  = "$appName-worker"     # match project #8
$subId     = az account show --query id -o tsv
$tenantId  = az account show --query tenantId -o tsv

# GitHub repo coordinates (owner/repo) — used by the federated credential subject
$ghOwner = "your-github-username"   # or org name
$ghRepo  = "your-repo-name"

# 1. Create the Entra app registration
$appName_oidc = "github-actions-todoapi"
$appId = az ad app create --display-name $appName_oidc --query appId -o tsv
$spObjectId = az ad sp create --id $appId --query id -o tsv

# 2. Grant the SP Contributor on the resource group (deploys touch App Service + Function App)
az role assignment create `
  --assignee $appId `
  --role Contributor `
  --scope "/subscriptions/$subId/resourceGroups/$rg"

# 3. Add a federated credential for the main branch (allows deploy)
$mainCred = @{
  name      = "github-main"
  issuer    = "https://token.actions.githubusercontent.com"
  subject   = "repo:${ghOwner}/${ghRepo}:ref:refs/heads/main"
  audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json -Compress
# Write BOM-free UTF-8 — az CLI rejects files with a BOM ("Failed to parse JSON")
[IO.File]::WriteAllText("$PWD\fed-main.json", $mainCred, [Text.UTF8Encoding]::new($false))
az ad app federated-credential create --id $appId --parameters fed-main.json

# 4. Add a federated credential for pull requests (build/test only)
$prCred = @{
  name      = "github-pr"
  issuer    = "https://token.actions.githubusercontent.com"
  subject   = "repo:${ghOwner}/${ghRepo}:pull_request"
  audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json -Compress
[IO.File]::WriteAllText("$PWD\fed-pr.json", $prCred, [Text.UTF8Encoding]::new($false))
az ad app federated-credential create --id $appId --parameters fed-pr.json

Remove-Item fed-main.json, fed-pr.json
```

**Verify the subjects match GitHub's exact format** — a single typo here is the #1 cause of `AADSTS70021` in Phase 3. Run this and read the output character-by-character against your real GitHub `owner/repo`:
```powershell
az ad app federated-credential list --id $appId --query "[].{name:name, subject:subject}" -o table
# Expected output (with YOUR values, no placeholders):
# Name          Subject
# ------------  -------------------------------------------------
# github-main   repo:jasteenb/MSSAMentorAgent:ref:refs/heads/main
# github-pr     repo:jasteenb/MSSAMentorAgent:pull_request
```

If you see `repo:your-github-username/your-repo-name:...` in there, `$ghOwner` / `$ghRepo` were never set — fix the variables and re-run steps 3 and 4.

**Push the three non-secret values into GitHub Actions variables** (these are *not* secrets — knowing the client ID doesn't grant any access):
```powershell
gh variable set AZURE_CLIENT_ID       --body $appId
gh variable set AZURE_TENANT_ID       --body $tenantId
gh variable set AZURE_SUBSCRIPTION_ID --body $subId
```

**Verify:**
```powershell
gh variable list
# Should show all three variables.

az ad app federated-credential list --id $appId --query "[].{name:name, subject:subject}" -o table
# Should show github-main and github-pr.
```

**Concepts to name out loud:**
- *This is **OpenID Connect (OIDC) for CI/CD*** — when an Actions workflow runs, GitHub mints a short-lived JWT that proves "this is repo X, branch Y, run Z." Azure trusts that JWT (because we registered the federated credential) and exchanges it for a real access token. The token lives for ~1 hour and dies with the workflow run. **There is no secret stored in GitHub.** Name this loudly — it's the single most important security upgrade in modern CI/CD.
- *This is **federated identity*** — instead of GitHub holding a credential, GitHub *proves who it is* and Azure decides whether to trust the proof. The `subject` field (`repo:owner/repo:ref:refs/heads/main`) is the *exact* claim Azure pattern-matches against. Get one character wrong and authentication fails with a generic "AADSTS70021" — name that gotcha now so they don't waste an hour later.
- *This is **least privilege at the subject level*** — by splitting `main` and `pull_request` into two federated credentials with separate names, you can revoke one without touching the other. PR builds should never deploy; main builds do. **Two credentials, two purposes**, even though they point at the same app registration.
- *This is **the role assignment is what grants permission*** — the app registration is just an identity. Until you `az role assignment create`, it can authenticate but can't do anything. Same pattern as the managed identities in #7 and #8. Name the consistency.

**Common gotchas:**
- `subject` doesn't match what GitHub sends — GitHub sends `repo:owner/repo:ref:refs/heads/main` for branch pushes, `repo:owner/repo:pull_request` for PRs, `repo:owner/repo:environment:production` for environment deploys. Copy the format exactly. Case matters.
- Forgetting the role assignment — `azure/login` succeeds, then every subsequent `az` call fails with `AuthorizationFailed`. The app authenticated as nobody-with-permissions.
- Storing the client ID as a *secret* — works, but secrets are masked in logs (the literal string `***` replaces them), which makes debugging painful. Client ID, tenant ID, and subscription ID are *not* sensitive. Use **variables**, not secrets.
- Org-owned repos with SSO enforcement — the GitHub CLI might need `gh auth refresh -s admin:org` before it can write variables. If `gh variable set` fails with a 403, run that first.

**After-action prompt:** *"You created two federated credentials with different subjects. What would happen if a PR build tried to deploy to production, and which line of the workflow is going to stop it?"*

### Phase 2 — Build + test job (runs on every push and PR) (~25 min)

**Goal:** Create `.github/workflows/ci.yml` with a single job that checks out the repo, sets up .NET 8, restores, builds (Release), and runs unit tests. This job runs on every push and every PR. **No Azure access yet** — this is pure GitHub-hosted compute.

**Files touched:**
- `.github/workflows/ci.yml` — new file
- `TodoApi.Tests/` — new test project (if one doesn't exist yet)

**Create a unit test project if you don't already have one** — most learners don't have tests yet because #3–#8 didn't require them:
```powershell
cd path\to\repo-root
dotnet new xunit -o TodoApi.Tests
dotnet sln add TodoApi.Tests
cd TodoApi.Tests
dotnet add reference ..\TodoApi\TodoApi.csproj
dotnet add package Microsoft.AspNetCore.Mvc.Testing
```

**Drop one real test in `TodoApi.Tests/HealthCheckTests.cs`** so the pipeline has something to run:
```csharp
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace TodoApi.Tests;

public class HealthCheckTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public HealthCheckTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task Health_endpoint_returns_200()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/health");
        Assert.Equal(System.Net.HttpStatusCode.OK, response.StatusCode);
    }
}
```

**Make `Program` visible to the test project** — .NET 8 top-level statements emit an `internal` `Program` class. `WebApplicationFactory<Program>` can't reach it across project boundaries. Add this one-liner at the **very bottom** of `TodoApi/Program.cs`:
```csharp
public partial class Program { }
```

Without this, the test build fails with `error CS0122: 'Program' is inaccessible due to its protection level`. Add it now — it's a no-op at runtime and a build-time requirement for integration tests.

**The workflow file** — `.github/workflows/ci.yml`:
```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up .NET 8
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'

      - name: Restore
        run: dotnet restore

      - name: Build (Release)
        run: dotnet build --configuration Release --no-restore

      - name: Test
        run: dotnet test --configuration Release --no-build --logger "trx;LogFileName=test-results.trx"

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: '**/TestResults/*.trx'
```

**Commit, push, and watch the run:**
```powershell
git add .github/workflows/ci.yml TodoApi.Tests/
git commit -m "ci: add build + test workflow"
git push

# Watch the run in the terminal (much faster than the browser for a single job)
gh run watch
```

**Concepts to name out loud:**
- *This is **a workflow*** — one YAML file in `.github/workflows/`. GitHub auto-discovers it. The filename (`ci.yml`) is just a label; the `name:` field is what shows in the UI.
- *This is **a job*** — a unit of work that runs on a single runner (here: `ubuntu-latest`, a fresh VM provisioned per run). Every job inside the same workflow runs **in parallel by default** unless you wire `needs:` between them (next phase).
- *This is **a step*** — one action or one shell command inside a job. Steps run sequentially, share the runner's filesystem and environment, and a failing step stops the job (unless you mark it `continue-on-error: true`).
- *This is **`uses:` vs `run:`*** — `uses:` invokes a pre-built action (someone else's reusable YAML/JS/Docker), `run:` runs a shell command directly. Prefer `uses:` for anything someone has already solved (checkout, setup-dotnet, login); `run:` for project-specific commands.
- *This is **caching is opt-in, not free*** — every step starts from a fresh VM. `dotnet restore` re-downloads every package every run. Name it now; we'll add caching in Phase 5 as an explicit "make it faster" exercise.
- *This is **`if: always()`** for artifacts** — by default, steps don't run after a failure. But test results are *most* valuable when tests fail. `if: always()` says "run this even if a previous step failed." Same pattern: log uploads, screenshot uploads, deploy-failure diagnostics.

**Common gotchas:**
- `WebApplicationFactory<Program>` can't find `Program` — symptoms: `error CS0122: 'Program' is inaccessible due to its protection level`. Fix: add `public partial class Program { }` at the bottom of `TodoApi/Program.cs`. Top-level statements emit an `internal` Program class by default.
- Workflow doesn't run after push — check that the YAML is on the **default branch** (usually `main`). GitHub Actions only triggers from workflow files on the default branch (for branch pushes from feature branches, the workflow must already exist on `main`).
- `dotnet test` finds no tests — usually means the test project isn't in the solution (`dotnet sln add` fixed that above) or the `<IsPackable>` property is set weirdly. `dotnet test --list-tests` locally to debug.
- Indentation errors in YAML — YAML is whitespace-significant. Use spaces, never tabs. If the parser complains about an obscure line, copy a known-good workflow and edit incrementally.

**After-action prompt:** *"You pushed a workflow file, and a job started on a VM you've never seen. Walk me through every step — who allocated the VM, what was on it when it started, and what happened to it after the job finished?"*

### Phase 3 — Deploy-API job, gated behind an Environment (~30 min)

**Goal:** Add a second job `deploy-api` that depends on `build-and-test`, runs only on pushes to `main` (not on PRs), uses the OIDC federated credential from Phase 1, publishes the API project, and deploys it to App Service. Wrap the job in a GitHub Environment called `production` so a human has to click "Approve" before it runs.

**Files touched:** `.github/workflows/ci.yml` (extend it).

**Create the `production` Environment first** (web UI is simpler than `gh` here):
1. Repo → Settings → Environments → New environment → `production`.
2. Add a **required reviewer** (yourself, or a teammate). Save.
3. Optionally add a deployment branch rule: `main` only.

**Extend `ci.yml`** — append a new job:
```yaml
  deploy-api:
    needs: build-and-test
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    environment: production
    permissions:
      id-token: write   # OIDC needs this to mint the JWT
      contents: read    # actions/checkout needs this
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up .NET 8
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'

      - name: Publish API
        run: dotnet publish TodoApi/TodoApi.csproj --configuration Release --output ./publish/api

      - name: Azure login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}

      - name: Deploy to App Service
        uses: azure/webapps-deploy@v3
        with:
          app-name: todoapi-<your-tail>   # match $appName from project #7
          package: ./publish/api
```

> Replace `todoapi-<your-tail>` with the literal name of your App Service from project #7. (Hardcoding is fine for now; we promote it to a workflow variable in Phase 5.)

**Commit, push, watch:**
```powershell
git add .github/workflows/ci.yml
git commit -m "ci: add gated deploy-api job"
git push

gh run watch
```

The `build-and-test` job runs immediately. `deploy-api` then enters the **Waiting for review** state — go to the run in the browser (or `gh run view --web`) and click **Review deployments → production → Approve and deploy**.

**Verify the deploy:**
```powershell
Invoke-WebRequest "https://$appName.azurewebsites.net/health" | Select-Object StatusCode
# Should be 200.
```

**Concepts to name out loud:**
- *This is **`needs:` builds a dependency graph*** — `deploy-api` won't start until `build-and-test` completes successfully. If `build-and-test` fails, `deploy-api` is skipped (not failed). Multiple jobs can `needs:` the same upstream, fanning out parallel work after a single gate.
- *This is **`if:` filters at the job level*** — `github.ref == 'refs/heads/main' && github.event_name == 'push'` means "main branch, push event only." PR builds get the build/test pass but never reach the deploy job. Name the safety: **PRs cannot deploy**, structurally.
- *This is **`environment:` is a manual gate + a credential scope*** — pointing a job at an environment does two things: (1) GitHub enforces any rules attached to the environment (required reviewers, deployment branches, wait timers), and (2) the OIDC token's subject claim becomes `repo:owner/repo:environment:production` instead of `repo:owner/repo:ref:refs/heads/main`. If you wanted *only* production deploys to be allowed, you'd federate against that environment subject instead of `main`.
- *This is **`permissions:` at the job level*** — GitHub Actions defaults to a generous token scope. **Always** explicitly request only what you need. `id-token: write` is the magic line that unlocks OIDC; without it, `azure/login` fails with "could not mint id token." `contents: read` is the minimum for `actions/checkout`.
- *This is **`dotnet publish`** vs **`dotnet build`*** — `build` compiles and stops; `publish` compiles, copies all runtime dependencies into one folder, and produces a self-contained deployable artifact. The deploy action zips the publish folder and uploads it. Name the distinction; learners conflate the two constantly.
- *This is **the human in the loop*** — a required reviewer means production deploys cannot happen autonomously. Some teams want continuous deployment (no manual gate); others (regulated industries, on-call-driven services) require human approval. The gate is one click in the Environment settings — name how easy it is to add or remove.

**Common gotchas:**
- `azure/login` fails with `AADSTS70021` — the federated credential subject doesn't match what GitHub sent. Compare exactly: `repo:OWNER/REPO:ref:refs/heads/main` (case-sensitive, watch for typos in the GitHub username or repo name). The error log shows the actual subject GitHub sent — copy it back into the federated credential.
- Missing `permissions: id-token: write` — `azure/login` fails with `Error: Unable to get ACTIONS_ID_TOKEN_REQUEST_URL`. The token endpoint is only available when the workflow has that permission.
- Forgot to update `app-name` — deploy succeeds against a *different* App Service (yours or someone else's, if the name is taken). Always verify the URL after deploy.
- The reviewer is the same person who pushed — by default, GitHub *does* allow self-approval. For real production you'd add `prevent-self-review: true` to the environment. Name it as a security upgrade.

**After-action prompt:** *"You pushed to main, the build passed, and then the workflow paused. Who told it to pause, who told it to resume, and what token did it use to authenticate to Azure when it did?"*

### Phase 4 — Deploy-Worker job + end-to-end smoke test (~20 min)

**Goal:** Add a third job `deploy-worker` that deploys the Function App from project #8 (same OIDC credential, same environment gate), then a fourth job `smoke-test` that runs after both deploys and calls the live `/health` endpoint. If the smoke fails, the workflow run is marked failed and a notification fires.

**Extend `ci.yml`** — append two more jobs:
```yaml
  deploy-worker:
    needs: build-and-test
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    environment: production
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up .NET 8
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'

      - name: Publish Worker
        run: dotnet publish TodoApi.Worker/TodoApi.Worker.csproj --configuration Release --output ./publish/worker

      - name: Azure login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}

      - name: Deploy to Function App
        uses: azure/functions-action@v1
        with:
          app-name: todoapi-<your-tail>-worker   # match $funcName from project #8
          package: ./publish/worker

  smoke-test:
    needs: [deploy-api, deploy-worker]
    runs-on: ubuntu-latest
    steps:
      - name: Hit /health
        run: |
          URL="https://todoapi-<your-tail>.azurewebsites.net/health"
          for i in 1 2 3 4 5; do
            STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
            if [ "$STATUS" = "200" ]; then
              echo "Smoke passed on attempt $i"
              exit 0
            fi
            echo "Attempt $i: got $STATUS, retrying in 10s..."
            sleep 10
          done
          echo "Smoke failed: /health did not return 200 after 5 attempts"
          exit 1
```

> Replace `todoapi-<your-tail>` with the literal App Service name from project #7. Phase 5 promotes this (and the function app name) to a workflow-level `env:` variable so you stop hardcoding it in three places.

> The `smoke-test` job runs on `ubuntu-latest` and uses `bash` (the default shell for Linux runners). This is the **one** place we use bash instead of PowerShell, because it's running on a GitHub-hosted Linux VM, not the learner's Windows box. Name the distinction: PowerShell is the local-dev shell; the workflow runs on whatever OS the runner is.

**Verify the wiring:**
```powershell
git add .github/workflows/ci.yml
git commit -m "ci: deploy worker + smoke test"
git push

gh run watch
```

Approve the deploy. Watch `deploy-api` and `deploy-worker` run **in parallel** (both depend on `build-and-test`, neither depends on the other). Then `smoke-test` runs after both succeed.

**Force a failure to prove the smoke catches it:**
1. In `TodoApi/Program.cs`, temporarily change the `/health` endpoint to return `Results.StatusCode(500)`.
2. Commit and push.
3. Watch: build passes, deploys succeed, **smoke-test fails on attempt 5**, workflow marked failed.
4. Revert. Push. Pipeline goes green.

**Concepts to name out loud:**
- *This is **parallel deploys, sequential verification*** — `deploy-api` and `deploy-worker` both `needs: build-and-test`, neither needs the other → they run at the same time. `smoke-test` lists both in `needs: [deploy-api, deploy-worker]` → it waits for both. Name the shape: **fan out, then fan back in**. Saves wall-clock time without sacrificing safety.
- *This is **a smoke test is not a load test*** — it answers one question: "did the deploy break the basic case?" Five retries with 10s between covers the App Service cold-start window. If `/health` returns 500 reliably, deploy is broken; if it's flaky, you have a different problem. Name the scope.
- *This is **bash on the runner*** — Linux runner means bash steps. If you switched to `runs-on: windows-latest`, you'd use PowerShell (or `shell: pwsh`). The workflow YAML is platform-agnostic; the *commands inside* are platform-specific.
- *This is **a failing smoke is a failing deploy*** — by chaining `smoke-test` after the deploys with `needs:`, a smoke failure marks the **whole workflow run** as failed. The deploys themselves succeeded (the new code is on the App Service), but the run is red. Next step (in real life): wire a rollback — re-deploy the previous green artifact. We don't build that here; **name it as the next homework**.

**Common gotchas:**
- `azure/functions-action` deploys but the function doesn't run — usually a missing app setting on the Function App. The deploy action only ships the code; app settings (like `StorageConnection__queueServiceUri`) are infra-as-code, not code-deploy. They were set in project #8 Phase 5 and persist across deploys.
- `--output ./publish/worker` and `package: ./publish/worker` paths don't match — typo bait. They have to be the same.
- 500 from `/health` on first run after deploy — App Service does a cold start; the first request can take 30–60 seconds. The 5-retry loop covers that. If you tightened it to 1 attempt, real deploys would flake intermittently.
- Smoke runs *before* the deploy is actually live — `azure/webapps-deploy` returns success when the upload completes, not when the new code is serving traffic. The retry loop in smoke covers the gap. Name it: **success of the deploy step ≠ success of the deployment**.

**After-action prompt:** *"You broke `/health`, pushed, and the workflow turned red after the deploys succeeded. From the moment the broken code was live until you reverted, what was the user experience for someone hitting the deployed API?"*

### Phase 5 — Polish: cache restore, promote hardcoded names to variables, add dependabot (~20 min)

**Goal:** Three small upgrades that turn a working pipeline into a *maintainable* one. (1) Cache the NuGet restore so subsequent runs are 30–60s faster. (2) Replace the hardcoded `todoapi-<your-tail>` and `-worker` suffix with workflow-level variables. (3) Add Dependabot so package updates open PRs automatically — which then flow through the same CI we just built.

**1. Cache the NuGet restore** — `actions/setup-dotnet@v4` has a built-in cache; turn it on:
```yaml
      - name: Set up .NET 8
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'
          cache: true
          cache-dependency-path: '**/packages.lock.json'
```

This requires lock files. **First**, enable lock file generation in every csproj — add this property to the `<PropertyGroup>` block in `TodoApi/TodoApi.csproj`, `TodoApi.Worker/TodoApi.Worker.csproj`, and `TodoApi.Tests/TodoApi.Tests.csproj`:
```xml
<RestorePackagesWithLockFile>true</RestorePackagesWithLockFile>
```

Without this, `dotnet restore --use-lock-file` generates the file once but **doesn't regenerate it when packages change** — next package add breaks CI with `error NU1004: The packages lock file is inconsistent`.

**Then** generate the lock files:
```powershell
dotnet restore --use-lock-file
git add **/packages.lock.json **/*.csproj
git commit -m "ci: enable NuGet lock files for cache"
```

**2. Promote hardcoded names** — at the top of `ci.yml`, under `name:`:
```yaml
env:
  APP_SERVICE_NAME: todoapi-<your-tail>
  FUNCTION_APP_NAME: todoapi-<your-tail>-worker
```

Then in every job step that referenced the hardcoded name:
```yaml
      - name: Deploy to App Service
        uses: azure/webapps-deploy@v3
        with:
          app-name: ${{ env.APP_SERVICE_NAME }}
          package: ./publish/api
```

```yaml
      - name: Hit /health
        run: |
          URL="https://${{ env.APP_SERVICE_NAME }}.azurewebsites.net/health"
          # ...rest of the loop unchanged
```

**3. Add Dependabot** — `.github/dependabot.yml`:
```yaml
version: 2
updates:
  - package-ecosystem: "nuget"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

Commit, push:
```powershell
git add .github/workflows/ci.yml .github/dependabot.yml
git commit -m "ci: cache restore, env vars, dependabot"
git push
```

**Verify:**
- Run the workflow once to seed the cache.
- Run it a second time (push a no-op commit). The `Set up .NET 8` step should report `Cache restored successfully` and `dotnet restore` should drop from ~30s to ~2s.
- Within a week, Dependabot will open its first PR. That PR will trigger your CI workflow, build/test will run, and you can review + merge. The PR cannot deploy (PR builds skip `deploy-api` and `deploy-worker` by the `if:` filter from Phase 3).

**Concepts to name out loud:**
- *This is **caching is content-addressable*** — the cache key is derived from the lock file hash. If no packages change, the cache hits; if you bump a package version, the lock file changes, the cache misses, restore runs fresh, and a new cache is saved. **Caches expire after 7 days of disuse**, and total cache size per repo is capped at 10 GB.
- *This is **`env:` at workflow level vs job level vs step level*** — workflow-level env is visible everywhere; job-level overrides workflow-level; step-level overrides both. Use workflow-level for "constants that the whole pipeline needs to agree on" (like resource names).
- *This is **Dependabot is GitHub-native CI for dependencies*** — it watches your manifest files (`*.csproj`, `package.json`, `.github/workflows/*.yml`), opens PRs when updates are available, and groups them by ecosystem. The opened PR triggers your CI, so dependency bumps go through the same tests as human changes. Free, opt-in, lives in `.github/dependabot.yml`.
- *This is **the "version pinning" tradeoff*** — lock files (and Dependabot) give you reproducible builds + opt-in updates. The cost is: someone has to actually merge the Dependabot PRs, or they pile up. Name the discipline: **review Dependabot PRs weekly**, treat them like code review, don't auto-merge security-sensitive packages.

**Common gotchas:**
- Lock file out of date — `dotnet restore` errors with `error NU1004: The packages lock file is inconsistent`. Re-run `dotnet restore --use-lock-file --force-evaluate` and commit the updated lock files.
- Env interpolation in `run:` steps — bash needs `${{ env.VAR }}` (GitHub Actions syntax), not `$VAR` (which would be a literal bash env lookup, and the value isn't set there). Easy to mix up.
- Dependabot PRs failing CI because of new linting rules — common when a major version bump is in the PR. Treat the failure as data; either pin to the previous major or fix forward.

**After-action prompt:** *"You enabled caching, promoted the app names to env vars, and turned on Dependabot. Which of those three changes will pay off the most in the next month, and why?"*

## When to break the method

- Learner already knows GitHub Actions cold and is here for the OIDC piece — collapse Phases 2–4 into a sketched walkthrough and spend the real time on Phase 1 + the security model.
- Learner's team uses Azure DevOps Pipelines, not GitHub Actions — acknowledge the difference *once* (same concepts, different YAML, ADO has stricter approval gates by default), then build in Actions anyway. The pattern transfers.
- Learner asks "can I auto-deploy on every push, no approval?" — yes, just remove the required reviewer from the Environment. Show them, then ask: "what failure mode are you accepting in exchange for the speed?" That conversation is the real lesson.
- Learner wants to add staging slot swap (project #7 Phase 5) into the pipeline — great extension. Add a `deploy-api-staging` job that deploys to the slot, then a `swap-slots` job behind a separate environment gate. Optional capstone-of-the-capstone.

## Definition of done

The learner can demonstrate, observably, all of:

1. Pushing a commit to a feature branch opens a PR; CI runs `build-and-test`; PR cannot deploy (verified by reading the workflow run page).
2. Merging the PR to `main` triggers `build-and-test` then queues `deploy-api` + `deploy-worker` for approval; clicking Approve runs them in parallel; `smoke-test` runs after both and the run goes green end-to-end.
3. Force-breaking `/health` to return 500 causes `smoke-test` to fail after 5 retries, marking the whole run red even though the deploys "succeeded."
4. No client secret exists anywhere — `gh secret list` shows zero secrets; the workflow authenticates to Azure entirely via OIDC.
5. Dependabot has opened at least one PR (or will, within a week of merging); that PR triggers CI just like a human-authored one.

## Next steps

This is the final project in the CAD track. Where to go from here:

- **Add staging slot deployment** to project #7's swap pattern (gate slot swap behind a separate environment with a smoke that runs against the slot before promoting).
- **Move infra to code** — rewrite the `az` commands from #7 and #8 as Bicep or Terraform, and add a `terraform apply` job behind its own environment.
- **Add observability** — wire Application Insights into the App Service and Function App, then add a workflow job that queries AI after each deploy to verify error rate hasn't spiked.
- **Try the SCA track** (Windows Server + Active Directory + AZ-104) or the **CSO track** (Entra ID + Defender + SC-200) — both will teach the *other* halves of the Microsoft cloud platform.
