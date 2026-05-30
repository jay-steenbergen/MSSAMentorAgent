---
name: cso-kql-foundations
description: |
  CSO track project #1. Learner writes their first 8-10 KQL queries against the free Log
  Analytics demo workspace — `where`, `project`, `summarize`, `bin`, `join`, `top`, `render`.
  By the end the learner can read a security-relevant table, ask "who logged in from where"
  type questions, and explain why KQL is the lingua franca of the Microsoft security stack.
  Auto-load when the learner is in `cybersecurity-ops/cso-kql-foundations` or asks to learn
  KQL basics, write security queries, or use the LA demo workspace.
---

# Project: `cso-kql-foundations`

> **Track:** Cybersecurity Operations · **Project:** 1 of 9 · **Time:** ~60 minutes
>
> Before you can hunt, detect, or investigate, you need to be able to ask the data a question. This project gets the learner past the activation energy of KQL — using Microsoft's free, world-public demo workspace so there's nothing to set up. By the end they've written 8-10 queries hands-on and read the output.

## Project goal

When this project is done, the learner can:

- Open the **Log Analytics demo workspace** in the Azure portal and run queries against it without setting anything up.
- Write and explain queries using `where`, `project`, `summarize`, `count`, `bin`, `top`, `join`, `order by`, and `render`.
- Inspect a table's schema with `getschema` and pick the right table for a question.
- Read a `SecurityEvent`, `SigninLogs`, or `DeviceProcessEvents` row and identify the entities (user, host, IP, process) in it.
- State in their own words why KQL is the query language they'll see in Sentinel, Defender XDR, Resource Graph, App Insights, and Azure Monitor — and how that compounds investment.

## Scope guardrail

This is **read-only queries against a demo workspace**. We are not building dashboards, not creating saved queries, not parameterizing with `let`, not writing functions, not setting alerts. We're building muscle memory in "table → pipe → operator." 8-10 queries; each one answers a real security question.

If the learner asks "how do I write a function?" — answer honestly: *the `let` and function syntax is one project away (#6 detection rules)*. Today: read and aggregate, not abstract.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Any Azure account (sign-in only — no resources created) | Sign in at portal.azure.com |
| Access to the public demo workspace | URL: `https://portal.azure.com/#view/Microsoft_Azure_Monitoring_Logs/DemoLogsBlade` — Microsoft hosts a world-readable workspace with sample data |
| Optional: VS Code with the **Kusto** extension | Run queries from VS Code instead of the portal |

## Phases

### Phase 1 — Open the demo workspace, count rows (~10 min)

**Goal:** The learner gets to the Logs blade in the demo workspace and runs the simplest possible query.

**Steps:**
1. Navigate to https://aka.ms/lademo (redirects to the official Demo Logs page in the Azure portal). Sign in.
2. You should see the Logs query editor with the demo workspace selected.
3. In the editor, paste:
```kql
Heartbeat
| count
```
4. Click **Run** (or Shift+Enter). A single number returns — the total Heartbeat rows in the workspace.

**Then list the tables:**
```kql
search "*"
| where TimeGenerated > ago(1d)
| distinct $table
| order by $table asc
```

**Concepts to name out loud:**
- *This is **a workspace as the database*** — every table is a "logical table" the platform creates from streaming log data. The demo workspace has dozens of pre-populated tables.
- *This is **the pipe (`|`) as the chain operator*** — every operator after a pipe transforms the previous result. Read left-to-right: "Heartbeat, then count."
- *This is **`search`*** as a special operator that scans across tables — slow and expensive in production, useful for exploration. Don't reach for it once you know which table to query.

**Common gotchas:**
- "Workspace not found" → demo URL changed or session expired. Search "Azure Monitor Logs Demo" in the portal.
- Run button greyed out → paste landed in the wrong place. Click into the query editor first.

**After-action prompt:** *"You just ran two queries — count and search. Which one would you run in production at 3 AM during an incident, and which one would you save for casual exploration on a slow day?"*

### Phase 2 — `where` and `project` (~10 min)

**Goal:** The learner filters rows and picks columns — the two operations they'll use most.

**Try this:**
```kql
SecurityEvent
| where TimeGenerated > ago(7d)
| where EventID == 4624   // Successful login
| project TimeGenerated, Account, Computer, LogonType, IpAddress
| take 20
```

**Then narrow it further:**
```kql
SecurityEvent
| where TimeGenerated > ago(7d)
| where EventID == 4624
| where LogonType in (2, 10)   // Interactive (2) or RemoteInteractive (10)
| project TimeGenerated, Account, Computer, LogonType, IpAddress
| take 20
```

**Concepts to name out loud:**
- *This is **`where` as the row filter*** — only rows matching the condition pass through. Chain multiple `where` clauses with `and`; KQL combines them.
- *This is **`project` as the column picker*** — pick the columns you want to see (and the order). Without it, you get every column the row has (often dozens).
- *This is **`take 20` as the safety bound*** — query editors show only ~30K rows max anyway, but `take` makes the intent explicit and cheaper.
- *This is **EventID 4624 as a Microsoft-specific Windows event*** — every Windows Security log event has an EventID. 4624 = successful login, 4625 = failed, 4634 = logoff. Memorize the top 10 if you want to hunt fast.

**Common gotchas:**
- `where Account = "admin"` → KQL uses `==` for equality. Single `=` is assignment (in some contexts).
- Case sensitivity → string equality is case-sensitive by default. Use `=~` for case-insensitive: `where Account =~ "ADMIN"`.

**After-action prompt:** *"You filtered to interactive logons in the last 7 days. If you wanted only failed logons from external IPs, what two filters would you add?"*

### Phase 3 — `summarize` and `bin` (~10 min)

**Goal:** The learner groups by a column and aggregates — the heart of any security analysis.

**Try this:**
```kql
SecurityEvent
| where TimeGenerated > ago(7d)
| where EventID == 4624
| summarize logon_count=count() by Account
| top 10 by logon_count
```

**Group by time:**
```kql
SecurityEvent
| where TimeGenerated > ago(7d)
| where EventID == 4625   // Failed logon
| summarize failures=count() by bin(TimeGenerated, 1h), Account
| order by TimeGenerated desc, failures desc
```

**Render a time chart:**
```kql
SecurityEvent
| where TimeGenerated > ago(7d)
| where EventID == 4625
| summarize failures=count() by bin(TimeGenerated, 1h)
| render timechart
```

**Concepts to name out loud:**
- *This is **`summarize` as GROUP BY*** — same idea as SQL. `summarize <agg> by <columns>` produces one row per unique combination of the `by` columns.
- *This is **`bin(TimeGenerated, 1h)` as time bucketing*** — round timestamps down to hour boundaries (or 1m, 1d, 7d). Critical for time-series charts.
- *This is **`top N by <column>`*** — "give me the top N rows sorted by this column descending." Cleaner than `order by ... | take N`.
- *This is **`render timechart`*** — turn an aggregated table into a line chart in the portal. `barchart`, `piechart`, `columnchart`, `scatterchart` also exist.

**Common gotchas:**
- `summarize` without aggregation function → error. You need `count()`, `avg(x)`, `sum(x)`, `min(x)`, `max(x)`, `dcount(x)`, etc.
- `bin(TimeGenerated, 60)` → 60 seconds, not 60 minutes. Use `1h` for hours.
- Forgot to `order by` and the chart looks scrambled → most viz operators auto-sort; some don't. Sort to be safe.

**After-action prompt:** *"You aggregated failed logons by hour. If you saw a spike of 500 failures from one account in one hour, what's the next query you'd write?"*

### Phase 4 — `join` (~10 min)

**Goal:** The learner combines two tables on a shared column — answering questions a single table can't.

**Find accounts with both successful and failed logons in the same window:**
```kql
let failed = SecurityEvent
  | where TimeGenerated > ago(1d)
  | where EventID == 4625
  | distinct Account;

let succeeded = SecurityEvent
  | where TimeGenerated > ago(1d)
  | where EventID == 4624
  | distinct Account;

failed
| join kind=inner succeeded on Account
| project Account
```

**Or in one pipeline:**
```kql
SecurityEvent
| where TimeGenerated > ago(1d)
| where EventID in (4624, 4625)
| summarize succeeded=countif(EventID==4624), failed=countif(EventID==4625) by Account
| where succeeded > 0 and failed > 5
| order by failed desc
```

**Concepts to name out loud:**
- *This is **`let` as a variable*** — assign a sub-query (or scalar) a name, then use it below. Same pattern as a SQL CTE.
- *This is **`join kind=inner`*** — only rows that match in both sides come through. Other kinds: `leftouter`, `rightouter`, `fullouter`, `leftanti` (rows in left that don't match right), `leftsemi` (rows in left that DO match right).
- *This is **`countif(condition)` as conditional aggregation*** — count only rows where the condition is true. Often eliminates the need for a join.
- *This is **"is a join the right shape?"*** — for "rows that exist in both," yes. For "two metrics on the same group," often `countif` is simpler.

**Common gotchas:**
- Join on differently-named columns → use `on $left.A == $right.B` syntax.
- Result has duplicate column names → KQL renames the right side's duplicates with a suffix. Use `project` after to clean up.

**After-action prompt:** *"You used both a join and a `countif` approach to answer the same question. Which one would you teach a colleague first and why?"*

### Phase 5 — Apply: 3 real security questions (~20 min)

**Goal:** The learner writes 3 queries answering security-relevant questions without copy-paste from the SKILL — using only the operators they just learned.

**Question 1 — "Show me hosts with the most unique users logging into them in the last 24 hours."**

Hint: `SecurityEvent` table, EventID 4624, `summarize dcount(Account) by Computer | top 10 by ...`

**Question 2 — "For each user, show their logon count, the number of distinct hosts they logged into, and the number of distinct source IPs."**

Hint: `summarize total_logons=count(), hosts=dcount(Computer), ips=dcount(IpAddress) by Account`

**Question 3 — "Which IP addresses had more than 100 failed logons in any single hour?"**

Hint: `summarize failures=count() by bin(TimeGenerated, 1h), IpAddress | where failures > 100`

The learner writes these themselves, debugs their own typos, and runs each one. The mentor coaches but does not paste the answer.

**After-action prompt:** *"You wrote three queries from scratch. Walk me through which operator you'd reach for first if a colleague said 'find me anything weird in the last hour' — and why."*

## When to break the method

- Learner already knows SQL → 80% transfer. Spend phase 1 quickly, phase 4 on the `let`-vs-CTE differences, more time on `summarize` patterns that don't exist in SQL (e.g. `make_set`, `make_list`).
- Learner has no programming background at all → slow down phase 3. Aggregation is the conceptual jump most non-programmers struggle with.
- Time short → phases 1-3 are the must-do. The whole rest of the track depends on `where`, `project`, `summarize`, `bin`.

## Definition of done

Observable, the learner can:

- [ ] Open the demo workspace and successfully run at least 5 queries.
- [ ] Write a query without copy-paste that filters, projects, and summarizes.
- [ ] Write a query that uses `bin(TimeGenerated, 1h)` and `render timechart`.
- [ ] Solve at least 2 of the 3 phase-5 questions without looking at the hints.
- [ ] Explain in one sentence each: `where`, `project`, `summarize`, `bin`, `top`, `join kind=inner`, `let`.

## Next project

→ [`cso-entra-identity-hardening`](../cso-entra-identity-hardening/SKILL.md) — apply KQL to a real defender's job: harden identity in Entra ID, enforce MFA via Conditional Access, and hunt the sign-in logs for risky logins.
