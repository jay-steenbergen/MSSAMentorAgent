---
name: cso-soar-playbook
description: |
  CSO track project #8. Learner builds a Logic App playbook that triggers from a Sentinel
  incident, parses the user entity, calls the Microsoft Graph API to disable the user, and
  posts back into the incident with an action note. Auto-load when the learner is in
  `cybersecurity-ops/cso-soar-playbook` or asks to learn SOAR, Logic Apps as playbooks,
  Sentinel automation rules, disabling a user via Graph, or auto-response patterns.
---

# Project: `cso-soar-playbook`

> **Track:** Cybersecurity Operations · **Project:** 8 of 9 · **Time:** ~90 minutes
>
> Auto-response — the "R" in SOAR. By the end of this project the learner has a Logic App that, when triggered by a Sentinel incident, identifies the user entity, calls Microsoft Graph to disable that user, then posts a comment back into the Sentinel incident with a success/failure note and a link. The playbook is wired to an automation rule that triggers on the impossible-travel detection from project #6.

## Project goal

When this project is done, the learner can:

- Create a **Logic App playbook** with the Sentinel "When a Sentinel incident is created" trigger.
- Parse the **Account entity** out of the incident payload.
- Call **Microsoft Graph API** (`PATCH /users/{id}` with `{ "accountEnabled": false }`) authenticated via a **managed identity**.
- Post a comment back to the Sentinel incident with the action's result.
- Wire the playbook to an **automation rule** that runs it on every "Impossible travel" incident (from project #6).
- Explain why **manual approval** is the safer first step before going fully automated.

## Scope guardrail

This is **one playbook, one auto-action (disable user), one automation rule**. We are not building approval gates (covered conceptually, not built — Logic Apps' "Send approval email" connector is one block away), not orchestrating multi-step responses, not building cross-tenant SOAR. The point: the auto-response loop is wired end-to-end.

If the learner asks "how do I add a 'human approves before disable' step?" — answer honestly: *insert a `Send approval email` Logic Apps action before the Graph call. The pattern is identical; only the conditional gate differs. Recommended in production*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`cso-detection-rule`](../cso-detection-rule/SKILL.md) — impossible-travel rule exists | Sentinel → Analytics → Active rules |
| Permission to create Logic Apps and Microsoft Graph permissions | Azure portal IAM + Entra admin consent |
| **Sentinel Contributor** on the workspace | portal → Sentinel → IAM |
| A test Entra user you're willing to temporarily disable | Anyone non-admin |

## Phases

### Phase 1 — Decide the action (~5 min, verbal)

**Concept block:**

The first SOAR question is "what action are we automating?" The candidates, ranked by reversibility:

| Action | Reversibility | Right for first auto-action? |
|---|---|---|
| Post comment to incident | Trivial | Yes (low-risk practice) |
| Send Teams / email notification | Trivial | Yes |
| Add user to a "watchlist" group | Easy | Yes |
| Disable user (`accountEnabled = false`) | Easy (re-enable in portal) | **Yes — this project** |
| Revoke all user sessions | Easy (user re-signs in) | Yes |
| Force password reset | Medium (user needs to set new password) | Eventually |
| Isolate device (MDE) | Easy (un-isolate in portal) | Yes |
| Delete user, delete data | Hard / destructive | No, ever, without human approval |

**For this project:** disable user. It's stoppable, reversible in 30 seconds, and high-impact enough that getting it right matters.

**After-action prompt:** *"You picked 'disable user' over 'post comment.' Why is that the right first action even though it's higher risk?"*

### Phase 2 — Create the Logic App skeleton (~15 min)

**Goal:** A Logic App exists with the Sentinel incident trigger and a managed identity assigned.

**Steps (PowerShell):**
```powershell
$rg = "rg-mssa-sec"
$location = "eastus"
$laName = "la-mssa-disable-user"

# Create empty Logic App
$logicApp = New-AzLogicApp `
  -ResourceGroupName $rg `
  -Name $laName `
  -Location $location `
  -State "Disabled"   # Keep disabled while you build it
```

**Assign a system-managed identity:**
1. portal.azure.com → search **Logic Apps** → click `la-mssa-disable-user`.
2. **Identity → System assigned → On → Save**.
3. Note the **Object (principal) ID** that appears — you'll grant Graph permissions to this.

**Grant Microsoft Graph User.ReadWrite.All to the managed identity** (the playbook needs this to disable users):
```powershell
$miObjectId = "<paste-object-id-here>"
$graphAppId = "00000003-0000-0000-c000-000000000000"   # Microsoft Graph well-known app ID
$permission = "User.ReadWrite.All"

# Get the Graph SP in your tenant
$graphSP = Get-AzADServicePrincipal -ApplicationId $graphAppId
$appRole = $graphSP.AppRole | Where-Object Value -eq $permission

# Grant the app role to the managed identity
$body = @{
  principalId = $miObjectId
  resourceId = $graphSP.Id
  appRoleId = $appRole.Id
} | ConvertTo-Json

az rest --method POST `
  --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$miObjectId/appRoleAssignments" `
  --headers "Content-Type=application/json" `
  --body $body
```

**Concepts to name out loud:**
- *This is **a system-assigned managed identity*** — Azure creates an Entra identity tied to the Logic App's lifecycle. No password to manage; no secret to leak. Use them for every service-to-service call from a Logic App.
- *This is **Microsoft Graph as the unified API surface*** — for users, groups, mail, Teams, devices, anything Microsoft 365. `https://graph.microsoft.com/v1.0/users/{id}` is the canonical endpoint.
- *This is **the `User.ReadWrite.All` permission as application permission*** — the managed identity acts on its own (not on behalf of a user). Application permissions need admin consent (you granted it above via the appRoleAssignments call).
- *This is **why we left the Logic App Disabled*** — until the workflow is built and tested, an enabled Logic App + a trigger = risk of running on every existing incident.

**Common gotchas:**
- Permission grant fails with "insufficient privileges" → you need Global Admin (or Privileged Role Admin) to grant Graph application permissions.
- Logic App identity Object ID confused with the Logic App's resource ID → use the GUID under Identity, not the resource ID.

**After-action prompt:** *"You granted User.ReadWrite.All to the managed identity. What's the smallest other permission you could have granted instead — and why is this one worth the broader scope?"*

### Phase 3 — Build the workflow (~30 min)

**Goal:** The Logic App has these steps in order: Sentinel trigger → Parse account entity → HTTP call to Graph → Add comment back to incident.

**In the portal: Logic App → Logic app designer → start with a blank workflow.**

**Step 1 — Trigger: "Microsoft Sentinel incident (preview)"**
- Search "Sentinel" in the connectors panel.
- Pick **Microsoft Sentinel incident (Preview)**. (There's also "alert" — we want incident.)
- Sign in (or use managed identity if the connector supports it).

**Step 2 — Action: "Entities - Get Accounts"** (Sentinel connector)
- This pulls all Account entities out of the incident.
- Input: Entities (from trigger output).

**Step 3 — Action: "For each"** loop over the accounts
- Inside the loop:

**Step 4 — Compose: build the user lookup string**
- Action: `Compose`.
- Inputs: `@items('For_each')?['Name']@items('For_each')?['UPNSuffix']` (concatenates `name` + `@` + `upnsuffix` → full UPN).

Or simpler: use the `AadUserId` field if available in the entity payload (already a GUID).

**Step 5 — HTTP action to disable the user**
- Action: `HTTP`.
- Method: `PATCH`
- URI: `https://graph.microsoft.com/v1.0/users/<UPN from compose>`
- Headers: `Content-Type: application/json`
- Body:
  ```json
  { "accountEnabled": false }
  ```
- **Authentication:** Managed Identity → System-assigned → Audience: `https://graph.microsoft.com`.

**Step 6 — Condition: check the HTTP response**
- If `@equals(outputs('HTTP')['statusCode'], 204)` (Graph returns 204 No Content on success):

**Step 7 (success branch) — Add comment to incident** (Sentinel connector → "Add comment to incident")
- Incident ARM ID: from trigger.
- Comment: `Auto-disabled user @{outputs('Compose')} per impossible-travel detection. Re-enable in Entra: https://portal.azure.com/...`

**Step 7 (failure branch) — Add comment to incident**
- Comment: `Failed to auto-disable user @{outputs('Compose')}. HTTP @{outputs('HTTP')['statusCode']}. Body: @{outputs('HTTP')['body']}. Manual action required.`

**Save**. **Switch the Logic App to Enabled.**

**Concepts to name out loud:**
- *This is **the Sentinel connector for Logic Apps*** — Microsoft maintains a library of Sentinel-specific actions (get entities, add comment, update incident, run playbook, etc.). Don't write these yourself.
- *This is **`@items('For_each')` as the Logic Apps current-iteration reference*** — inside a foreach loop, this refers to the current iteration's item. The squiggly-bracket syntax is Logic Apps expression language.
- *This is **the conditional after HTTP*** — never assume an HTTP call succeeded. Check status code. Branch on success/failure. Audit either way.
- *This is **commenting back to the incident as the audit habit*** — every automated action should leave a trail in the incident. The SOC analyst reading the incident next should be able to see what already happened.

**Common gotchas:**
- HTTP returns 401 → managed identity didn't get admin-consented to User.ReadWrite.All. Re-grant the role.
- HTTP returns 403 → permission too narrow (e.g. you granted User.Read.All instead of User.ReadWrite.All).
- For-each doesn't iterate → entities array is empty for this incident. Check the trigger output JSON to see what came through.
- Disable succeeded but no comment back → Sentinel connector auth issue. The connector needs its own connection in the Logic App (might be reused from the trigger).

**After-action prompt:** *"You added success and failure branches. If you removed the failure branch, how would you discover that the auto-disable silently failed?"*

### Phase 4 — Wire to automation rule (~10 min)

**Goal:** A Sentinel automation rule runs the playbook on every new incident from the "Impossible travel" detection.

**Steps:**
1. **Sentinel → Configuration → Automation → + Create → Automation rule**.
2. **Name:** `Run disable-user playbook on impossible-travel incidents`.
3. **Trigger:** When incident is created.
4. **Conditions:**
   - Analytics rule name → Contains → `Impossible travel`
5. **Actions:**
   - Action → Run playbook → Select `la-mssa-disable-user`.
6. **Order:** 1.
7. **Expiration:** Indefinitely (or set an end date for safety during testing).
8. Save.

**Permission warning:** Sentinel will ask whether to grant the playbook permissions to its resource group. Approve.

**Concepts to name out loud:**
- *This is **an automation rule as the orchestrator*** — it watches for conditions and runs playbooks. You can have many automation rules; they run in order.
- *This is **the order field as concurrency control*** — order 1 runs first. Important when multiple rules might both match the same incident.
- *This is **expiration as a safety net during pilot*** — set "expire in 7 days" when first deploying. Forces you to re-approve consciously before extending.

**After-action prompt:** *"You wired the playbook to fire on impossible-travel incidents. What would you check before flipping the same wire onto a 'failed sign-in burst' rule?"*

### Phase 5 — Trigger end-to-end and verify (~15 min)

**Goal:** Repeat the project-#6 trigger test (VPN switch + double sign-in) and watch the user get auto-disabled.

**Choose a test user**:
- Create a fresh test user `automation-test@yourtenant.onmicrosoft.com`.
- Sign in as that user from one location, switch VPN, sign in again.

**Wait for:**
1. The impossible-travel detection rule to fire (max 60 min).
2. Sentinel to create the incident.
3. Automation rule to run the playbook.
4. Playbook to disable the user.
5. Playbook to post a comment.

**Verify:**
1. **Sentinel → Incidents → click the incident** — comment visible at the bottom.
2. **Entra → Users → search the test user** — `Account enabled = No`.
3. **Sign in as the test user** → should fail with "Your account is disabled."

**Re-enable the user when done testing:**
```powershell
Update-AzADUser -UPN "automation-test@yourtenant.onmicrosoft.com" -AccountEnabled $true
```

Or in the portal: User → Properties → Account enabled → Yes.

**Concepts to name out loud:**
- *This is **end-to-end automation working*** — six independent systems (Entra sign-in service, sign-in log shipping, Sentinel rule scheduler, automation rule engine, Logic Apps runtime, Microsoft Graph) all cooperated to disable the user. When it works, it works; when it breaks, finding the broken link is a real skill.
- *This is **the production-readiness checklist*** — before you'd put this on prod: (a) approval gate before disable, (b) exception list (don't auto-disable CEOs), (c) alert when the playbook fails, (d) MTTR tracking.

**Common gotchas:**
- Incident created but playbook didn't run → automation rule isn't matching. Open the rule, click Run history.
- Playbook ran but user not disabled → Graph permission issue. Open the Logic App's run history → click the failed run → inspect the HTTP response body for the exact error.
- Comment didn't appear in incident → Sentinel connector permission. The Logic App might need explicit Sentinel Responder role.

**After-action prompt:** *"You watched the playbook auto-disable a user. If your manager asked 'what's the worst that could happen with this in production,' what would you say — and what mitigation would you add first?"*

## When to break the method

- Learner has limited Logic Apps experience → spend phase 3 more carefully. The visual designer is intuitive but the expression language has gotchas.
- Learner is from a Power Automate background → Logic Apps shares the runtime. The actions and triggers differ; concepts transfer cleanly.
- Time short → phases 1-2-3 are the must-do. Phases 4-5 (wire + trigger) can be a follow-up exercise.

## Definition of done

Observable, the learner can:

- [ ] Show a Logic App with system-managed identity and User.ReadWrite.All Graph permission.
- [ ] Show the workflow with Sentinel trigger, account parse, Graph PATCH, and comment-back actions.
- [ ] Show an automation rule wired to the playbook.
- [ ] Trigger an impossible-travel incident and watch the user get auto-disabled.
- [ ] Re-enable the user from the portal.
- [ ] Explain in one sentence each: SOAR, managed identity, automation rule, Logic Apps `@items()`, Graph `PATCH /users/{id}`.

## Next project

→ [`cso-threat-intel-integration`](../cso-threat-intel-integration/SKILL.md) — the final project: integrate threat intelligence into Sentinel via the Defender Threat Intelligence data connector, create a Watchlist for high-confidence indicators, and write an analytics rule that fires when telemetry matches an indicator.
