---
name: sca-monitoring
description: |
  SCA track project #8. Learner stands up a Log Analytics workspace, onboards the VM from
  project #5 via the Azure Monitor Agent and a Data Collection Rule, writes their first KQL
  queries against the collected logs, then creates an alert rule that emails them when CPU
  stays above 80% for 5 minutes. Auto-load when the learner is in `server-cloud-admin/sca-monitoring`
  or asks to learn Azure Monitor, Log Analytics, KQL basics, Azure Monitor Agent, Data
  Collection Rules, or how to alert on a VM metric.
---

# Project: `sca-monitoring`

> **Track:** Server & Cloud Administration · **Project:** 8 of 9 · **Time:** ~75 minutes
>
> Visibility for the lab built in projects #5–#7. By the end the learner has a Log Analytics workspace receiving logs from the VM, can answer "what happened" with a KQL query, and gets an email when CPU spikes. The query language used here is the same KQL used everywhere in the Microsoft cloud — Sentinel, Defender, App Insights, Resource Graph. Investment compounds.

## Project goal

When this project is done, the learner can:

- Create a **Log Analytics workspace** and explain the difference between *workspace-based* logs and *metric-based* signals.
- Onboard a VM using the modern **Azure Monitor Agent (AMA)** with a **Data Collection Rule (DCR)** — and explain why AMA replaces the older MMA/OMS agent.
- Write KQL queries with `where`, `project`, `summarize`, and `render` — and explain what each one does.
- Create a **metric alert rule** on CPU that emails an **action group** when thresholds breach for 5 minutes — and trigger the alert deliberately so they've seen it fire.

## Scope guardrail

This is **single-workspace monitoring with metric + log alerts**. We are not setting up Application Insights, not building cross-workspace queries, not configuring custom log ingestion (HTTP Data Collector or Custom Logs), not deploying Workbooks. One workspace, one VM, one CPU alert, ~5 KQL queries. The learner exits with their hands on the keyboard.

If the learner asks "what about distributed tracing?" — answer honestly: *that's App Insights territory*. Same workspace concept, different agent, different schema.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`sca-azure-vnet-vm`](../sca-azure-vnet-vm/SKILL.md) — VM `vm-app01` running | `Get-AzVM -ResourceGroupName rg-mssa-azurevm -Status` |
| Az.OperationalInsights and Az.Monitor modules | `Get-Module Az.OperationalInsights, Az.Monitor -ListAvailable` |
| Personal email address you can receive at | For the action group |

## Phases

### Phase 1 — Create the Log Analytics workspace (~10 min)

**Goal:** A new Log Analytics workspace exists in the same region as the VM.

**Commands:**
```powershell
$rg        = "rg-mssa-azurevm"
$location  = "eastus"
$wsName    = "law-mssa"

New-AzOperationalInsightsWorkspace `
  -ResourceGroupName $rg `
  -Name $wsName `
  -Location $location `
  -Sku "PerGB2018" `
  -RetentionInDays 30

# Verify
Get-AzOperationalInsightsWorkspace -ResourceGroupName $rg -Name $wsName |
  Select-Object Name, Sku, RetentionInDays, CustomerId
```

**Concepts to name out loud:**
- *This is **a Log Analytics workspace as the database*** — every log emitted by any Azure resource you point at this workspace lands in tables you can query with KQL. The workspace is billed per GB ingested and per GB-day retained.
- *This is **"PerGB2018" pricing*** — the modern pay-as-you-go tier. Roughly $2.30/GB ingested. A small lab VM emits ~50-150 MB/day. Realistically a few dollars a month if you're frugal. There's also a **Commitment Tier** (cheaper per GB if you commit to volume) and **Free** (now retired) and **Standalone** (legacy).
- *This is **retention as a separate cost*** — the first 31 days are included. Beyond that, you pay per GB-month. Default 30 keeps the lab cost minimal.

**Common gotchas:**
- Workspace name has to be unique within the subscription, not globally. Random suffix not required.
- Don't pick a region different from the VM unless you have a reason — cross-region ingestion has more failure modes.

**After-action prompt:** *"You picked PerGB2018 and 30-day retention. If you collected 10 GB/month of logs, roughly what would you pay? What would push it up tenfold?"*

### Phase 2 — Onboard the VM with AMA + a Data Collection Rule (~25 min)

**Goal:** Azure Monitor Agent is installed on the VM, a DCR sends Windows perf counters and System event log entries to the workspace.

**The mental model first:** With AMA, the agent itself collects nothing by default. A **Data Collection Rule** says *which* data sources (perf counters, event logs, syslog, etc.) get collected and *where* they go (your workspace). One agent can serve many DCRs; one DCR can target many VMs. Decoupling is the point.

**Install the AMA on the VM:**
```powershell
# Set the AMA extension on vm-app01 (idempotent — safe to re-run)
Set-AzVMExtension `
  -ResourceGroupName $rg `
  -VMName "vm-app01" `
  -Name "AzureMonitorWindowsAgent" `
  -Publisher "Microsoft.Azure.Monitor" `
  -ExtensionType "AzureMonitorWindowsAgent" `
  -TypeHandlerVersion "1.0" `
  -EnableAutomaticUpgrade $true `
  -Location $location
```

**Create a Data Collection Rule** — the JSON approach is verbose, the portal is easier the first time:

1. portal.azure.com → search **Monitor** → **Data Collection Rules** → **+ Create**.
2. **Basics:** name `dcr-mssa-vm`, region `eastus`, platform type **Windows**.
3. **Resources:** + Add resources → select `vm-app01`.
4. **Collect and deliver:**
   - **+ Add data source** → Data source type: **Performance Counters** → Sampling rate 60s → keep defaults (CPU, Memory, Disk, Network) → **Destination**: your `law-mssa` workspace → Add.
   - **+ Add data source** → Data source type: **Windows Event Logs** → keep defaults (System, Application errors) → Destination: `law-mssa` → Add.
5. Review + create.

**Verify ingestion (wait ~5-10 min for first data):**
1. portal.azure.com → **Log Analytics workspaces** → `law-mssa` → **Logs**.
2. Try this query (paste into the query editor):
```kql
Perf
| where TimeGenerated > ago(15m)
| where Computer == "vm-app01"
| summarize count() by ObjectName, CounterName
```

If you see rows, ingestion is working. If nothing returns, wait 5 more minutes (initial collection can be delayed).

**Concepts to name out loud:**
- *This is **AMA (Azure Monitor Agent) replacing MMA (Microsoft Monitoring Agent) and OMS Agent*** — Microsoft retired MMA in August 2024. AMA is the only future-proof option. Anything you read older that says "OMS workspace" or "MMA" is dated.
- *This is **a DCR as the "what gets collected" contract*** — same agent, different DCR = different data. Run a fleet of 1000 VMs against one DCR and your collection is consistent.
- *This is **the `Perf` and `Event` tables*** — the most common starting points. Perf has performance counters; Event has Windows event log entries. Each table has a fixed schema you can `getschema` to inspect.

**Common gotchas:**
- AMA installed but no data → DCR isn't associated, or wrong destination, or perf counters aren't selected. Open the DCR in portal and re-confirm.
- Data appearing in `Heartbeat` table but not `Perf` → AMA is alive but DCR isn't sending perf. Common after a DCR edit.
- Confused old docs say install OMS agent → ignore; AMA is the answer.

**After-action prompt:** *"You installed one agent and created one DCR. If management said 'now do the same for 50 VMs,' what do you do — install AMA on 50 VMs and create 50 DCRs, or something smarter?"*

### Phase 3 — KQL basics: ask real questions (~20 min)

**Goal:** The learner writes five KQL queries that answer questions about the VM, by hand, without copy-paste.

**Open Logs in the workspace and run each in order:**

**Q1 — "Is the agent alive?"**
```kql
Heartbeat
| where TimeGenerated > ago(1h)
| where Computer == "vm-app01"
| summarize last_seen=max(TimeGenerated)
```

**Q2 — "What's the CPU been doing?"**
```kql
Perf
| where TimeGenerated > ago(1h)
| where Computer == "vm-app01"
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| where InstanceName == "_Total"
| summarize avg(CounterValue), max(CounterValue) by bin(TimeGenerated, 5m)
| render timechart
```

**Q3 — "Top 5 disk-using counters right now"**
```kql
Perf
| where TimeGenerated > ago(15m)
| where Computer == "vm-app01"
| where ObjectName == "LogicalDisk"
| summarize avg(CounterValue) by CounterName
| top 5 by avg_CounterValue
```

**Q4 — "Any error or critical events from System log in the last 24h?"**
```kql
Event
| where TimeGenerated > ago(24h)
| where Computer == "vm-app01"
| where EventLog == "System"
| where EventLevelName in ("Error", "Critical")
| project TimeGenerated, EventID, Source, RenderedDescription
| order by TimeGenerated desc
| take 20
```

**Q5 — "Count of distinct event sources writing errors in the last day"**
```kql
Event
| where TimeGenerated > ago(24h)
| where Computer == "vm-app01"
| where EventLevelName == "Error"
| summarize errors=count() by Source
| order by errors desc
```

**Concepts to name out loud:**
- *This is **KQL as pipe-and-table*** — every query starts with a table name (`Perf`, `Heartbeat`, `Event`), then `|` chains operators. Each operator transforms the table.
- *This is **the core operators: `where`, `project`, `summarize`, `order by`, `top`, `render`*** — `where` filters rows, `project` picks columns, `summarize` is GROUP BY, `order by` sorts, `top` is "top N", `render` chooses a visualization.
- *This is **`bin(TimeGenerated, 5m)` as time bucketing*** — group your data into 5-minute buckets for charting. Replace 5m with 1h, 1d, etc.
- *This is **`render timechart`*** — KQL renders a time-series chart inline. Useful for spotting patterns the table view hides.

**Common gotchas:**
- "Could not parse query" → KQL is case-sensitive on operators (lowercase) and table names (PascalCase).
- `summarize` requires an aggregation function — `count()`, `avg(x)`, `max(x)`, `min(x)`, `percentile(x, 95)`, etc.
- `render` only works in the portal (and a few other clients), not via API. For programmatic queries, drop `render`.

**After-action prompt:** *"You ran 5 KQL queries. If asked 'are there any unusual events on this VM in the last hour,' what query would you write — and which operators would you definitely use?"*

### Phase 4 — Alert on CPU spike, prove it fires (~15 min)

**Goal:** A metric alert rule emails the learner when CPU > 80% for 5 minutes. The learner triggers it deliberately to confirm the email arrives.

**Step 1 — Create an Action Group (where alerts go):**
```powershell
$agName = "ag-mssa-email"
$emailReceiver = New-AzActionGroupReceiver -Name "me" -EmailReceiver -EmailAddress "your.email@example.com"

Set-AzActionGroup `
  -ResourceGroupName $rg `
  -Name $agName `
  -ShortName "mssa" `
  -Receiver $emailReceiver `
  -Location "Global"
```

**Step 2 — Create the metric alert rule:**
```powershell
$vm = Get-AzVM -ResourceGroupName $rg -Name "vm-app01"
$ag = Get-AzActionGroup -ResourceGroupName $rg -Name $agName

# The metric criterion: CPU > 80% averaged over the window
$criteria = New-AzMetricAlertRuleV2Criteria `
  -MetricName "Percentage CPU" `
  -MetricNamespace "Microsoft.Compute/virtualMachines" `
  -TimeAggregation Average `
  -Operator GreaterThan `
  -Threshold 80

# Create the alert: evaluates every 1 min, window of 5 min, severity 2 (Warning)
Add-AzMetricAlertRuleV2 `
  -Name "alert-cpu-high" `
  -ResourceGroupName $rg `
  -WindowSize (New-TimeSpan -Minutes 5) `
  -Frequency (New-TimeSpan -Minutes 1) `
  -TargetResourceId $vm.Id `
  -Condition $criteria `
  -ActionGroupId $ag.Id `
  -Severity 2 `
  -Description "vm-app01 CPU > 80% for 5 minutes"

# Verify
Get-AzMetricAlertRuleV2 -ResourceGroupName $rg -Name "alert-cpu-high"
```

**Step 3 — Trigger it on purpose (on the VM, PowerShell as Admin):**
```powershell
# A 7-minute CPU burner — exceeds the 5-min window
1..8 | ForEach-Object -Parallel {
  $end = (Get-Date).AddMinutes(7)
  while ((Get-Date) -lt $end) {
    1..1000000 | ForEach-Object { [math]::Sqrt($_) } | Out-Null
  }
} -ThrottleLimit 8
```

Watch the metric in the portal: **VM → Monitoring → Metrics → Percentage CPU**. After ~5 minutes above 80% you should get an email.

**Step 4 — Verify the fire:**
```powershell
# All alerts fired in the last hour
Get-AzMetricAlertStatus -ResourceGroupName $rg -Name "alert-cpu-high"
```

**Concepts to name out loud:**
- *This is **a metric alert vs a log alert*** — metric alerts evaluate **numeric metrics** (CPU %, disk IOPS, request count) at fast cadence (1 min) with low cost. Log alerts run a KQL query at slower cadence (5/15 min) and can express anything KQL can express. Use metric when possible (cheaper, faster).
- *This is **action groups as the reusable destination*** — write the action group once, attach it to many alerts. Channels: email, SMS, voice, webhook, Logic App, Azure Function, ITSM, runbook.
- *This is **severity as a soft contract with operators*** — Sev 0/1 = wake someone up. Sev 2 = handle today. Sev 3/4 = log and review. Use it consistently or it's noise.
- *This is **window vs frequency*** — `Frequency 1m` = "check every 1 min." `WindowSize 5m` = "across the last 5 min of data." Both matter. Window must be ≥ frequency.

**Common gotchas:**
- Alert fires but no email → bad email address, or it went to spam. Check the action group's email receiver delivery status.
- Alert never fires → CPU burn wasn't intense enough. The PowerShell parallel-loop above usually hits 100% on a B2s. If not, increase ThrottleLimit.
- Email arrived 7+ minutes after threshold breach → expected. There's metric ingestion lag (~1-2 min) plus the 5-min window plus delivery time. Tune window down for tighter alerting if needed (with more false positives).

**After-action prompt:** *"You got an alert email. Walk me through the timeline from 'CPU went above 80%' to 'email arrived in inbox' — and what you'd change if 7 minutes was too slow for production."*

### Phase 5 — Clean up the noisy stuff (~5 min)

**Goal:** The alert is disabled if you don't want a flood of emails, the workspace cost is bounded, and the learner knows how to keep the lab cheap.

**Disable (don't delete) the alert:**
```powershell
$alert = Get-AzMetricAlertRuleV2 -ResourceGroupName $rg -Name "alert-cpu-high"
$alert.Enabled = $false
$alert | Set-AzMetricAlertRuleV2
```

**Cap workspace daily ingestion (cost guard):**
```powershell
# Set a daily cap at 1 GB/day — ingestion stops after that
Set-AzOperationalInsightsWorkspace -ResourceGroupName $rg -Name $wsName -DailyQuotaGb 1
```

**After-action prompt:** *"You've now seen how to monitor and alert. If you owned this VM for a year, what cost guardrails would you set up so an outage doesn't double as a billing event?"*

## When to break the method

- Learner already knows KQL from Sentinel or another product → skim phase 3, focus on phase 4 (the alerting mechanics most people fumble).
- Strict budget → use the free 5-GB/month allowance plus 31-day default retention. The whole lab here costs single-digit dollars/month at this volume.
- Time short → phases 1-2-4 are the must-do. Phase 3 (KQL) can be a follow-up exercise; phase 5 a hygiene reminder.

## Definition of done

Observable, the learner can:

- [ ] Show the Log Analytics workspace receiving heartbeats with `Heartbeat | where Computer == "vm-app01" | take 5`.
- [ ] Run the CPU `Perf | render timechart` query and see the chart.
- [ ] Show the DCR in the portal with vm-app01 as a resource and Performance Counters + System events as data sources.
- [ ] Show the alert rule, trigger it with the CPU loop, and produce the email it generated.
- [ ] Explain in one sentence each: workspace, DCR, action group, metric alert vs log alert.

## Next project

→ [`sca-arm-bicep-iac`](../sca-arm-bicep-iac/SKILL.md) — the capstone: take everything built across the track and express it as **Bicep** code. Tear down and redeploy in minutes.
