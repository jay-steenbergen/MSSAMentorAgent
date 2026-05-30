---
name: cso-threat-intel-integration
description: |
  CSO track project #9 (capstone). Learner integrates threat intelligence into Sentinel —
  connects the Microsoft Defender Threat Intelligence data connector, manually adds a few
  indicators, creates a Watchlist for a custom IOC list, then writes an analytics rule on
  `ThreatIntelligenceIndicator` joined with `DeviceNetworkEvents` to alert when telemetry
  matches an indicator. Auto-load when the learner is in
  `cybersecurity-ops/cso-threat-intel-integration` or asks to learn threat intelligence,
  Sentinel TI, indicators, Watchlists, IOC matching, or TAXII/Defender TI connector.
---

# Project: `cso-threat-intel-integration`

> **Track:** Cybersecurity Operations · **Project:** 9 of 9 (capstone) · **Time:** ~75 minutes
>
> The capstone: threat intelligence makes detection contextual. By the end of this project the learner has TI indicators (URLs, IPs, file hashes) flowing into Sentinel, a custom Watchlist of "our company's known-bad list," and an analytics rule that fires when the lab's MDE telemetry matches an indicator.

## Project goal

When this project is done, the learner can:

- Enable the **Microsoft Defender Threat Intelligence** data connector (and identify alternatives: TAXII, Threat Intelligence Platform/MISP, manual STIX upload).
- Manually add a **TI indicator** in Sentinel and explain the STIX fields (`patternType`, `pattern`, `validFrom`, `validUntil`, `confidence`, `threatTypes`).
- Create a **Watchlist** from a CSV (e.g. internal-known-bad IPs).
- Write an analytics rule that joins `ThreatIntelligenceIndicator` against `DeviceNetworkEvents` (or `DeviceFileEvents`) to detect endpoint contact with a known-bad IOC.
- Trigger the rule (curl a known-bad IP from the VM) and watch an incident appear.

## Scope guardrail

This is **one TI connector, one manual indicator, one Watchlist, one matching analytics rule**. We are not setting up MISP, not building a custom STIX feed, not pivoting to TI workbooks. The point: by the end, the learner has connected the "what's evil out in the world" data to "what's happening on my endpoints."

If the learner asks "what about high-end TIPs like ThreatConnect?" — answer honestly: *Sentinel speaks STIX/TAXII; any TIP that speaks STIX can feed Sentinel. The patterns are identical*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`cso-sentinel-workspace`](../cso-sentinel-workspace/SKILL.md) — Sentinel + MDE flowing | `DeviceNetworkEvents | take 5` returns rows |
| At least one MDE-onboarded VM you can run commands on | RDP to it works |
| **Sentinel Contributor** on the workspace | portal → Sentinel → IAM |

## Phases

### Phase 1 — Enable a TI data connector (~10 min)

**Goal:** A TI data connector is connected; indicators start appearing in `ThreatIntelligenceIndicator`.

**Choose your path:**
- **Path A — Microsoft Defender Threat Intelligence (Premium)** — paid, rich. Skip if no budget.
- **Path B — Threat Intelligence - TAXII** — connect a free public TAXII feed (e.g. AlienVault OTX, Anomali Limo). Pick one for the lab.
- **Path C — Threat Intelligence Upload Indicators API** — programmatic upload; out of scope today.

**Path B steps (free TAXII feed example):**
1. **Sentinel → Configuration → Data connectors → search "Threat Intelligence - TAXII"**.
2. Open connector page → **Add server**.
3. Server fields (example — verify against the feed's current docs):
   - Friendly name: `Anomali Limo`
   - API root URL: `https://limo.anomali.com/api/v1/taxii2/feeds/`
   - Collection ID: `135` (example: Mandiant indicators)
   - Username: `guest`
   - Password: `guest`
4. Save.

**Verify ingestion (wait 30-60 min for first poll):**
```kql
ThreatIntelligenceIndicator
| where TimeGenerated > ago(2h)
| project TimeGenerated, NetworkIP, Url, FileHashValue, Description, ConfidenceScore, ThreatType
| take 20
```

**Concepts to name out loud:**
- *This is **STIX/TAXII as the standard*** — STIX (Structured Threat Information Expression) is the format. TAXII (Trusted Automated Exchange of Indicator Information) is the transport. Most modern TI feeds speak both.
- *This is **`ThreatIntelligenceIndicator` as the universal landing table*** — regardless of the TI source, indicators end up in this one Sentinel table with normalized columns.
- *This is **TI feed quality varying wildly*** — some feeds are gold (validated, current, scored). Some are noise (mass-scraped, stale, no provenance). Always inspect what's coming in before trusting it for detections.

**Common gotchas:**
- TAXII feed connects but no rows appear → poll interval is hourly; wait. Or feed has no recent updates.
- Anomali feed credentials change → check their docs; many feeds rotate guest creds.
- Free feeds rate-limited → don't poll aggressively.

**After-action prompt:** *"You enabled a free TI feed. What three questions would you ask before trusting any indicator from this feed for an auto-blocking detection?"*

### Phase 2 — Manually add an indicator (~10 min)

**Goal:** The learner adds one indicator by hand to see the schema and as a guaranteed match for phase 4.

**Steps:**
1. **Sentinel → Threat intelligence → + Add new → Indicator**.
2. **Indicator type:** `IP`. **Value:** pick an IP you can `curl` from the test VM (e.g. `93.184.216.34` — that's `example.com`'s long-time IP; safe to use as a test target).
3. **Description:** `MSSA test indicator - example.com IP - safe for lab testing only`.
4. **Confidence:** 80 (out of 100).
5. **Threat types:** `malicious-activity`.
6. **Valid from:** now. **Valid until:** now + 30 days.
7. Save.

**Verify:**
```kql
ThreatIntelligenceIndicator
| where TimeGenerated > ago(15m)
| where NetworkIP == "93.184.216.34"
| project TimeGenerated, NetworkIP, Description, ConfidenceScore, ThreatType, ValidFrom, ValidUntil, Active
```

You should see your indicator with `Active = true`.

**Concepts to name out loud:**
- *This is **the STIX indicator field set*** — every indicator has a value (the IP/URL/hash), a type, validity window, confidence, threat type, and free-text description. Get used to these — you'll see them in every TI source.
- *This is **`Active = true` and validity window*** — indicators expire automatically when `ValidUntil` passes. Old stale indicators don't fire false positives forever.

**After-action prompt:** *"You added an indicator with confidence 80. If a colleague said 'we should auto-block anything with confidence > 50,' what's the trade-off in that threshold?"*

### Phase 3 — Create a Watchlist (~15 min)

**Goal:** A Sentinel Watchlist exists with a small CSV of "internal high-confidence" IOCs.

**Steps:**
1. Create a CSV locally — `internal-iocs.csv`:
```csv
IPAddress,Description,Severity
198.51.100.42,Known phishing landing - 2026-Q2 incident,High
203.0.113.99,C2 server - 2026-Q1 incident,High
93.184.216.34,Test indicator for project #9,Low
```

2. **Sentinel → Configuration → Watchlist → + New → Local file**.
3. **General:** Name `Internal Known Bad IOCs`. Alias: `InternalKnownBadIOCs`.
4. **Source:** upload the CSV. SearchKey: `IPAddress`.
5. Create.

**Wait ~1 min, then query:**
```kql
_GetWatchlist('InternalKnownBadIOCs')
| project IPAddress, Description, Severity
```

**Concepts to name out loud:**
- *This is **a Watchlist as a managed lookup table*** — you maintain it in CSV form, Sentinel exposes it as a queryable table via `_GetWatchlist()`. Updates take effect quickly.
- *This is **why Watchlists vs hardcoded lists in queries*** — Watchlists separate the data (what's bad) from the logic (what to do about it). The detection rule doesn't change when the list does.
- *This is **the SearchKey field*** — Sentinel indexes the Watchlist on this column for fast lookups. Pick the column you'll most often join on.
- *This is **`_GetWatchlist()` as the function syntax*** — quotes around the alias. Returns a table you can join, filter, project as normal.

**Common gotchas:**
- CSV with BOM (byte order mark) breaks parsing → save as plain UTF-8 without BOM.
- SearchKey column has duplicates → Watchlist creation fails. Deduplicate first.
- Schema changes (added a column to the CSV) → upload a new version; doesn't auto-update existing.

**After-action prompt:** *"You uploaded a Watchlist. When would you prefer this approach over the TI feed from phase 1?"*

### Phase 4 — Write the matching analytics rule (~20 min)

**Goal:** An analytics rule joins TI indicators (and your Watchlist) against MDE network telemetry to detect contact with known-bad infrastructure.

**Step 1 — develop the query in the Logs editor:**

```kql
let ti_ips = ThreatIntelligenceIndicator
  | where TimeGenerated > ago(7d)
  | where Active == true
  | where isnotempty(NetworkIP)
  | summarize arg_max(TimeGenerated, *) by NetworkIP   // latest indicator per IP
  | project NetworkIP, IndicatorSource = "Sentinel TI", Description, ConfidenceScore;

let watchlist_ips = _GetWatchlist('InternalKnownBadIOCs')
  | project NetworkIP = IPAddress, IndicatorSource = "Internal Watchlist", Description, ConfidenceScore = 100;

let all_ips = union ti_ips, watchlist_ips;

DeviceNetworkEvents
| where Timestamp > ago(1h)
| where ActionType == "ConnectionSuccess"
| where isnotempty(RemoteIP)
| join kind=inner all_ips on $left.RemoteIP == $right.NetworkIP
| project Timestamp, DeviceName, RemoteIP, RemoteUrl, RemotePort, InitiatingProcessFileName, InitiatingProcessCommandLine, IndicatorSource, Description, ConfidenceScore
| extend AccountName = tostring(split(InitiatingProcessAccountName, "\\")[1])
```

**Step 2 — wrap in a scheduled rule:**

1. **Sentinel → Configuration → Analytics → + Create → Scheduled query rule**.
2. **Name:** `Endpoint contact with TI/Watchlist IOC`.
3. **Severity:** Medium.
4. **MITRE tactics:** `Command and Control`. Techniques: `T1071`.
5. **Query:** paste from step 1.
6. **Query period / frequency:** 1 hour / 1 hour.
7. **Threshold:** > 0.
8. **Entity mapping:**
   - Host → HostName → `DeviceName`
   - IP → Address → `RemoteIP`
   - Account → Name → `AccountName` (may be null; that's OK)
9. **Alert details:**
   - Alert name format: `IOC contact: {{DeviceName}} → {{RemoteIP}} ({{IndicatorSource}})`
10. **Incident settings:** enabled, group within 5h.
11. Review and create.

**Concepts to name out loud:**
- *This is **`union` as the way to combine TI + Watchlist*** — gives you a single table to join against, regardless of source. Easy to add more sources (Defender for Cloud TI, custom feeds) the same way.
- *This is **`arg_max(TimeGenerated, *)`*** — for each IP, keep the most recent indicator row. Same IP may be reported multiple times by a TI feed; you want the latest.
- *This is **`ActionType == "ConnectionSuccess"`*** — only successful connections, not blocked/attempted ones. Tune to your needs; "ConnectionAttempt" is broader and noisier.
- *This is **`join kind=inner` vs `lookup`*** — `lookup` is optimized for "enrich left side with right side." Often more efficient than `join` for "enrich every event with TI." Try both; profile in your workspace.

**Common gotchas:**
- 0 rows from the join → no MDE network events to a TI indicator IP in the last hour. Wait or trigger in phase 5.
- Multiple matches per IP cause duplicate alerts → ensure `arg_max` is keeping only one row per IP.
- Watchlist alias spelled wrong in `_GetWatchlist('...')` → KQL error. Case-sensitive.

**After-action prompt:** *"You joined TI + Watchlist + telemetry. Walk me through which of the three would you tune first if the rule was generating false positives."*

### Phase 5 — Trigger and watch (~10 min)

**Goal:** From your MDE-onboarded VM, contact one of your indicator IPs. Verify the rule fires.

**On the VM (PowerShell):**
```powershell
# This contacts 93.184.216.34 (example.com) over HTTPS — perfectly safe
Invoke-WebRequest -Uri "https://93.184.216.34" -UseBasicParsing -SkipCertificateCheck
```

**Wait** for:
1. MDE telemetry to ingest the `DeviceNetworkEvents` row (~5-15 min).
2. The analytics rule's next scheduled run (max 60 min from creation).

**Verify:**
1. **Sentinel → Incidents** → new incident `IOC contact: ...`.
2. Open it → Account/IP/Host entities populated.
3. Inspect the underlying alert → contains the `IndicatorSource` and `Description` fields you mapped.

**Re-run the contact query manually to confirm match:**
```kql
DeviceNetworkEvents
| where Timestamp > ago(1h)
| where RemoteIP == "93.184.216.34"
| project Timestamp, DeviceName, RemoteIP, InitiatingProcessFileName, InitiatingProcessCommandLine
```

If this returns rows, telemetry is good. If not, MDE hasn't ingested yet — wait longer.

**Concepts to name out loud:**
- *This is **the end-to-end TI loop closing*** — TI feed → indicator → matched against telemetry → incident → investigator pivots. Same loop scales to 10,000 indicators and 100,000 devices.
- *This is **why the lab IP is safe*** — `93.184.216.34` is `example.com`'s long-standing IP, IANA-owned for documentation. Contacting it is harmless. Use this exact IP for IOC testing; don't pick a random one that's actually malicious.

**After-action prompt:** *"You closed the TI loop end-to-end. Walk me through what would change if this scaled to 50,000 indicators and 5,000 endpoints — cost, query performance, false positive rate."*

## When to break the method

- Learner has no TAXII feed access → still do phase 2 (manual indicator) + phase 3 (Watchlist) + phase 4 (rule). The rule will match on manual indicator + Watchlist entries. Phase 1 can be a follow-up.
- Learner already has TI experience from another SIEM → spend most time on phases 3-4 (Watchlist + the union-join pattern is the most Sentinel-specific knowledge).
- Time short → phases 2-3-4-5 are the must-do. Phase 1 (TAXII connector) is the easiest to defer.

## Definition of done

Observable, the learner can:

- [ ] Show at least one indicator in `ThreatIntelligenceIndicator` (manual or from the TI connector).
- [ ] Show a Sentinel Watchlist with at least 3 rows.
- [ ] Show an analytics rule that joins TI + Watchlist + `DeviceNetworkEvents`.
- [ ] Trigger the rule by hitting one of the indicator IPs from the VM.
- [ ] Open the resulting Sentinel incident and confirm Host/IP entities populated.
- [ ] Explain in one sentence each: STIX/TAXII, Watchlist, `_GetWatchlist()`, `union`, `arg_max`, `ThreatIntelligenceIndicator` table.

## Track complete

🎯 **You finished the CSO track.**

Across these 9 projects you have:
1. Written KQL queries against a real workspace.
2. Hardened Entra identity with a Conditional Access policy.
3. Onboarded a Windows endpoint to MDE and walked an alert end-to-end.
4. Written a one-page IR report from a real incident.
5. Stood up Sentinel with two data connectors.
6. Written a custom analytics rule (impossible travel).
7. Built and saved a threat hunt (LOLBins).
8. Wired a SOAR playbook that auto-disables a user.
9. Integrated threat intelligence into a matching analytics rule.

That is a real SOC analyst's portfolio — minus the volume and the on-call rotation. The story you can tell in any SOC interview is concrete and verifiable.

**What to do next:**
- Sit the **SC-200** within 3 months while the lab is fresh.
- Clean up the cost: disable Sentinel on the workspace (`Remove-AzSentinelOnboardingState`), delete the resource group (`Remove-AzResourceGroup -Name rg-mssa-sec -Force`), keep just the documentation and KQL queries you wrote.
- For deeper specialization, look at: SC-100 (security architect), AZ-500 (Azure security), AI-102 (responsible AI / Copilot security) depending on where your interest lands.
