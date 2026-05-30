---
name: cso-sentinel-workspace
description: |
  CSO track project #5. Learner enables Microsoft Sentinel on a Log Analytics workspace, wires
  in the Entra ID and Microsoft Defender XDR data connectors, verifies ingestion with KQL,
  and reads the cost meter. By the end the learner has a real SIEM ingesting real logs, ready
  for detection rules (project #6), hunts (#7), and playbooks (#8). Auto-load when the learner
  is in `cybersecurity-ops/cso-sentinel-workspace` or asks to set up Sentinel, enable data
  connectors, ingest sign-in logs into Sentinel, or estimate Sentinel cost.
---

# Project: `cso-sentinel-workspace`

> **Track:** Cybersecurity Operations · **Project:** 5 of 9 · **Time:** ~75 minutes
>
> The SIEM gets real. Microsoft Sentinel sits on a Log Analytics workspace; you flip it on, point your data sources at it, and a SIEM appears. By the end the learner has Entra ID sign-in logs and Defender for Endpoint alerts flowing into a workspace they own, and has watched both ingestion and billing meters move.

## Project goal

When this project is done, the learner can:

- Enable **Microsoft Sentinel** on a new or existing Log Analytics workspace.
- Install and configure the **Microsoft Entra ID** data connector (sign-in logs, audit logs).
- Install and configure the **Microsoft Defender XDR** data connector (Defender for Endpoint alerts and raw telemetry tables).
- Verify ingestion with KQL queries against `SigninLogs`, `AuditLogs`, `SecurityAlert`, `DeviceProcessEvents`.
- Read the **cost** of Sentinel (per GB ingested + per GB retained beyond 31 days) and set a **daily cap** to avoid surprise bills.

## Scope guardrail

This is **one workspace, two data connectors, basic ingestion verification + cost cap**. We are not configuring the Threat Intelligence connector (project #9), not building analytics rules (project #6), not configuring UEBA, not setting up Watchlists. The point: a real Sentinel + real data, ready to build on.

If the learner asks "what about Defender for Cloud / Azure Activity / Office 365 connectors?" — answer honestly: *same pattern, more connectors. The two we install today are the minimum needed for the rest of the track*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Azure subscription with **Owner** or **Contributor + User Access Administrator** on the resource group | Azure portal → Subscriptions → IAM |
| **Security Administrator** in Entra (for the Defender XDR connector setup) | Entra → Roles and administrators |
| Microsoft Defender for Endpoint already onboarded (from project #3) | `security.microsoft.com` → Devices |
| ~$5-15/month budget for Sentinel ingestion (1-3 GB/month at lab volume) | Set a budget alert before starting |

## Phases

### Phase 1 — Create the workspace + enable Sentinel (~15 min)

**Goal:** A Log Analytics workspace exists with Sentinel enabled.

**Commands (PowerShell):**
```powershell
Connect-AzAccount
$rg = "rg-mssa-sec"
$location = "eastus"
$wsName = "law-mssa-sec"

New-AzResourceGroup -Name $rg -Location $location -Force

# Create the workspace
$ws = New-AzOperationalInsightsWorkspace `
  -ResourceGroupName $rg -Name $wsName -Location $location `
  -Sku "PerGB2018" -RetentionInDays 90

# Enable Sentinel on the workspace
# Az.SecurityInsights module needed; install if missing:
# Install-Module -Name Az.SecurityInsights -Scope CurrentUser

New-AzSentinelOnboardingState `
  -ResourceGroupName $rg `
  -WorkspaceName $wsName `
  -CustomerManagedKey:$false
```

**Verify in the portal:**
1. portal.azure.com → search **Sentinel** → select the new workspace from the list.
2. You should land in the Sentinel overview blade.

**Concepts to name out loud:**
- *This is **Sentinel as a layer on top of Log Analytics*** — same workspace, same KQL, same cost model — Sentinel adds the SIEM/SOAR capabilities (analytics rules, hunting, playbooks, incidents). Ingestion is billed by Log Analytics AND by Sentinel (the Sentinel meter is added on top). Combined, ~$4-5/GB ingested at lab scale.
- *This is **why 90-day retention*** — long enough to investigate an incident weeks after the fact, short enough to avoid runaway billing. Production typically pairs 30-90 days of "hot" retention with longer-term archive in cheaper storage tiers.
- *This is **why one workspace for security*** — many small workspaces split security data across silos. One workspace for all security telemetry simplifies queries and avoids cross-workspace join performance problems.

**Common gotchas:**
- Sentinel pricing isn't enabled by default → enabling Sentinel turns on the *Sentinel meter*, which is separate from the Log Analytics meter. Both bill per GB.
- Sentinel on a free workspace tier → not allowed. Must be PerGB2018.

**After-action prompt:** *"You enabled Sentinel on a 90-day retention workspace. If you ingested 5 GB/month, walk me through what you'd pay roughly — and what would change at 50 GB/month."*

### Phase 2 — Entra ID data connector (~15 min)

**Goal:** Sign-in logs and audit logs from Entra are flowing into the workspace.

**Steps:**
1. portal.azure.com → **Microsoft Sentinel → law-mssa-sec → Configuration → Data connectors**.
2. Search **"Microsoft Entra ID"** → click → **Open connector page**.
3. **Prerequisites:** confirm you have Security Administrator AND the tenant has an Entra ID P1+ license (or trial).
4. **Configuration:** check **Sign-in logs**, **Audit logs**, **Non-interactive user sign-in logs**, **Service principal sign-in logs**. Click **Apply Changes**.

**Wait 15-30 min for first data**, then verify:
```kql
SigninLogs
| where TimeGenerated > ago(30m)
| take 5
```

```kql
AuditLogs
| where TimeGenerated > ago(1d)
| project TimeGenerated, OperationName, InitiatedBy, TargetResources, Result
| take 10
```

**Concepts to name out loud:**
- *This is **the Entra ID data connector as a configuration toggle, not an agent*** — Entra natively pushes its logs to Log Analytics via Diagnostic Settings. The "connector" just sets up the diagnostic setting wiring.
- *This is **`SigninLogs` as the table you'll live in*** — interactive user sign-ins. Most identity hunting starts here. Companion tables: `AADNonInteractiveUserSignInLogs`, `AADServicePrincipalSignInLogs`, `AADManagedIdentitySignInLogs` — non-interactive, service principal, managed identity respectively.
- *This is **`AuditLogs` as the "who changed what in Entra"*** — user creates/deletes, role assignments, group memberships, policy changes. Vital for insider-threat hunts.

**Common gotchas:**
- No data after 30 min → diagnostic settings didn't apply, or P1 license missing. Check the Diagnostic settings blade on the Entra ID resource directly.
- See data but missing categories → fewer checkboxes than wanted. Re-open the connector page, re-check the categories.

**After-action prompt:** *"You wired up Entra logs. List two ways the connector could appear to succeed but produce no data, and how you'd debug each."*

### Phase 3 — Defender XDR data connector (~15 min)

**Goal:** Alerts AND raw telemetry tables (DeviceProcessEvents, etc.) from Defender for Endpoint are flowing into Sentinel.

**Steps:**
1. **Data connectors → Search "Microsoft Defender XDR"** → click → **Open connector page**.
2. **Prerequisites:** confirm M365 E5 trial active, Sentinel Contributor role on the workspace.
3. **Connect incidents and alerts:** click **Connect incidents & alerts**. (This makes Defender XDR push its incidents + alerts to Sentinel as `SecurityAlert` and `SecurityIncident` rows.)
4. **Connect raw telemetry tables** (optional but recommended): check `DeviceProcessEvents`, `DeviceFileEvents`, `DeviceNetworkEvents`, `DeviceLogonEvents`, `DeviceRegistryEvents`, `DeviceImageLoadEvents`, `DeviceEvents`. Click **Apply Changes**.

**Wait 15-30 min**, then verify:
```kql
// Defender XDR alerts as Sentinel rows
SecurityAlert
| where TimeGenerated > ago(7d)
| where ProviderName == "MDATP"
| project TimeGenerated, AlertName, Severity, DisplayName, Description
| take 10
```

```kql
// Raw MDE telemetry now in Sentinel
DeviceProcessEvents
| where Timestamp > ago(30m)
| take 5
```

**Concepts to name out loud:**
- *This is **a bi-directional integration*** — Defender XDR pushes incidents into Sentinel; Sentinel can sync incident updates (status, classification, tags) back to Defender XDR. Your IR team can work in either portal without losing changes.
- *This is **the "duplicate cost" decision*** — raw MDE telemetry is already in Defender Advanced Hunting (free, 30-day retention). Ingesting it into Sentinel costs Sentinel ingestion + retention dollars. Trade-off: long retention (>30d), cross-source joins, custom analytics rules → ingest into Sentinel. Just need basic AH → don't. Many shops ingest only the tables they actively query.
- *This is **`SecurityAlert` as the cross-product alert table*** — alerts from Defender XDR, Defender for Cloud, Defender for Identity, Microsoft Cloud App Security all land here. `ProviderName` tells you which.

**Common gotchas:**
- Raw telemetry ingestion blows up the bill → easy to ingest 100+ GB/month for a few VMs at full telemetry. Pick only the tables you'll actually use; reconsider monthly.
- `SecurityAlert` rows appear but no `SecurityIncident` rows → incident sync isn't enabled. Re-check the connector configuration.

**After-action prompt:** *"You enabled both connectors. Which one would you turn on first in a brand-new tenant, and which one would you delay until you had budget?"*

### Phase 4 — Verify and chart ingestion (~10 min)

**Goal:** Two queries: one showing data is flowing (heartbeat-style), one showing how much.

**Are all the expected tables alive?**
```kql
union withsource=TableName
  SigninLogs, AuditLogs, SecurityAlert, DeviceProcessEvents
| where TimeGenerated > ago(1h)
| summarize rows=count(), last_seen=max(TimeGenerated) by TableName
| order by TableName
```

**How much volume per table per day?**
```kql
Usage
| where TimeGenerated > ago(7d)
| where IsBillable == true
| summarize MBingested=sum(Quantity)/1024 by DataType, bin(TimeGenerated, 1d)
| render columnchart
```

The `Usage` table is the **cost meter**. Every row is "this table ingested this many MB." Sum it to project monthly cost.

**Concepts to name out loud:**
- *This is **`Usage` as the cost-eye*** — every workspace has it. Query it to find the noisiest table before it surprises you on the bill.
- *This is **how you find the cost villain*** — `Usage | summarize sum(Quantity) by DataType | top 5 by sum_Quantity` shows you the top 5 most expensive tables. Often one obscure table accounts for 80% of cost.

**After-action prompt:** *"You charted ingestion by table. If you saw `DeviceImageLoadEvents` was 50% of your cost, what three things would you check before deciding what to do about it?"*

### Phase 5 — Set a daily cap (the cost discipline that saves jobs) (~5 min)

**Goal:** The workspace has a daily ingestion cap that hard-stops billing if a misconfig floods data in.

**In the portal:**
1. **Log Analytics workspaces → law-mssa-sec → Settings → Usage and estimated costs → Daily cap**.
2. **On**. Daily cap: **1 GB** for a lab. (Adjust upward for real deployments — 1 GB is a single bad day.)
3. Set up an **email alert** at 90% of cap. Save.

**Why both:**
- Cap stops the bleed: once you hit the cap for the day, ingestion HALTS until midnight UTC. You may MISS DATA. Critical to know.
- The 90% alert gives you a window to investigate before the cap kicks in.

**Concepts to name out loud:**
- *This is **the cost-vs-coverage trade-off*** — caps stop the bill but cause data loss. In production, monitor for cost growth so you raise the cap *deliberately* before it triggers. For a lab, missing a few hours of data is fine.
- *This is **the "I left it on over the weekend" incident*** — a misconfigured diagnostic setting or runaway log source can ingest 100+ GB overnight. Caps protect against this. Always.

**After-action prompt:** *"You set a 1 GB daily cap. In production what would you do differently — cap value, alert recipients, escalation path?"*

## When to break the method

- Learner is on a tenant with no E5 trial → skip phase 3 (Defender XDR connector). Do phases 1, 2, 4, 5. The rest of the track works without Defender data; lower fidelity but workable.
- Learner has an existing Sentinel workspace at work → use it (instead of creating a new one). Don't risk ingesting noise into a paid workspace; check budget first.
- Time short → phases 1, 2, 5 are the must-do. Phase 3 (raw MDE telemetry) is optional and the most expensive step.

## Definition of done

Observable, the learner can:

- [ ] Show the Sentinel portal pointing at `law-mssa-sec`.
- [ ] Show the Data Connectors page with both Entra ID and Defender XDR connectors in **Connected** state.
- [ ] Run `SigninLogs | take 5` and `SecurityAlert | take 5` and see real rows.
- [ ] Show the daily cap on Usage and estimated costs page.
- [ ] Run a `Usage` query showing which tables cost the most.
- [ ] Explain in one sentence each: data connector, daily cap, Usage table, dual-meter (LA + Sentinel) billing.

## Next project

→ [`cso-detection-rule`](../cso-detection-rule/SKILL.md) — now that data is flowing, write the first analytics rule: detect impossible travel in `SigninLogs` and have it spawn Sentinel incidents.
