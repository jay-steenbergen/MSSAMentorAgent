---
name: cso-detection-rule
description: |
  CSO track project #6. Learner writes a scheduled analytics rule in Microsoft Sentinel that
  detects impossible travel in `SigninLogs`, maps entities (Account, IP), tunes false positives
  with allowlist patterns, then deliberately triggers it via a real VPN-change sign-in to
  verify an incident is created. Auto-load when the learner is in
  `cybersecurity-ops/cso-detection-rule` or asks to learn how to write Sentinel analytics
  rules, scheduled queries, entity mapping, impossible travel detection, or tuning a SIEM
  detection.
---

# Project: `cso-detection-rule`

> **Track:** Cybersecurity Operations · **Project:** 6 of 9 · **Time:** ~75 minutes
>
> The first homemade detection. The learner takes a known attacker pattern (impossible travel: two successful sign-ins from geographically distant locations in a window too short to physically travel), expresses it as KQL, wraps it in a scheduled analytics rule with proper entity mapping, then triggers it via a VPN switch to confirm an incident is created end-to-end.

## Project goal

When this project is done, the learner can:

- Write a KQL query that detects **impossible travel** in `SigninLogs` using `serialize` + `prev()` for self-joins on the same user.
- Wrap that query in a **scheduled analytics rule** with severity, run frequency, lookback window, and event grouping.
- Map result columns to **entities** (Account → AccountEntity, IPAddress → IPEntity) so incidents are pivot-ready.
- Suppress false positives with **allowlist filters** (corporate VPN exit IPs, known service accounts).
- Test the rule by **deliberately triggering it** (sign in from one IP, switch VPN to a foreign exit IP, sign in again) and watching an incident appear.
- Read the **rule run history** to see when the rule executed, how many rows matched, and what fired vs. was suppressed.

## Scope guardrail

This is **one scheduled rule, one query, one entity mapping, one round of tuning**. We are not using ML behavior analytics, not building NRT (near-real-time) rules, not configuring Fusion correlation, not writing a custom function library. One real detection, end-to-end.

If the learner asks "how do I detect more sophisticated attacker behavior?" — answer honestly: *Microsoft ships dozens of templates for that. This project teaches the mechanics so you can read, tune, and write your own. The templates are next*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`cso-sentinel-workspace`](../cso-sentinel-workspace/SKILL.md) — Sentinel up, Entra connector flowing | `SigninLogs | where TimeGenerated > ago(1h) | take 5` returns rows |
| **Sentinel Contributor** role on the workspace | portal → Sentinel → workspace → IAM |
| Ability to switch your apparent geographic IP (VPN with at least 2 country exit nodes, or a friend in a different country who can sign in) | For the trigger test in phase 5 |

## Phases

### Phase 1 — Write the query in the Logs editor (~20 min)

**Goal:** A KQL query that returns rows ONLY when impossible travel is detected, with all the columns the analytics rule will need.

**Open Sentinel → Logs (the KQL editor):**

**Step 1 — start simple — look at one user's sign-ins over time:**
```kql
SigninLogs
| where TimeGenerated > ago(7d)
| where ResultType == 0   // successful
| where UserPrincipalName == "your.user@yourtenant.onmicrosoft.com"
| project TimeGenerated, UserPrincipalName, IPAddress, Location, LocationDetails
| order by TimeGenerated asc
```

**Step 2 — `serialize` and `prev()` to compare each row with the previous one for the same user:**
```kql
SigninLogs
| where TimeGenerated > ago(7d)
| where ResultType == 0
| project TimeGenerated, UserPrincipalName, IPAddress, Location, City = tostring(LocationDetails.city)
| sort by UserPrincipalName asc, TimeGenerated asc
| serialize
| extend prev_user = prev(UserPrincipalName), prev_time = prev(TimeGenerated), prev_location = prev(Location), prev_city = prev(City), prev_ip = prev(IPAddress)
| where UserPrincipalName == prev_user   // only compare within the same user
| extend time_gap_min = datetime_diff('minute', TimeGenerated, prev_time)
| where prev_location != Location   // changed country
| where time_gap_min < 60            // within an hour
| project TimeGenerated, UserPrincipalName, IPAddress, Location, City, prev_time, prev_ip, prev_location, prev_city, time_gap_min
```

**Step 3 — add the entity columns the analytics rule needs:**
```kql
SigninLogs
| where TimeGenerated > ago(7d)
| where ResultType == 0
| project TimeGenerated, UserPrincipalName, IPAddress, Location, City = tostring(LocationDetails.city)
| sort by UserPrincipalName asc, TimeGenerated asc
| serialize
| extend prev_user = prev(UserPrincipalName), prev_time = prev(TimeGenerated), prev_location = prev(Location), prev_city = prev(City), prev_ip = prev(IPAddress)
| where UserPrincipalName == prev_user
| extend time_gap_min = datetime_diff('minute', TimeGenerated, prev_time)
| where prev_location != Location and time_gap_min < 60
| extend AccountName = tostring(split(UserPrincipalName, "@")[0]),
         AccountUPNSuffix = tostring(split(UserPrincipalName, "@")[1])
```

**Concepts to name out loud:**
- *This is **`serialize` as the row-order pin*** — KQL is parallelized by default, which means `prev()` is undefined unless you tell KQL "treat these rows as a sequence in this order." `serialize` does that.
- *This is **`prev()` as the previous-row reference*** — get the value from the immediately preceding row. After `serialize`, the order is whatever `sort by` produced. Without `sort by UserPrincipalName, TimeGenerated`, `prev()` would compare unrelated rows.
- *This is **entity columns as the contract with Sentinel*** — when the rule runs, Sentinel uses these columns to populate the Incident's entity panel (so investigators can pivot from "this incident" to "everything else involving this account/IP").
- *This is **why "impossible travel" is a heuristic, not a fact*** — VPNs make legitimate travel look impossible. Allowlist tuning (phase 4) is mandatory or you generate noise.

**Common gotchas:**
- `prev()` returns null on every row → forgot `serialize`. Add it before `extend`.
- Compared rows from different users → forgot `where UserPrincipalName == prev_user`. The filter happens AFTER prev, not as part of it.
- `Location` column is `null` for some rows → fallback: `extend Country = coalesce(Location, "unknown")`.

**After-action prompt:** *"You wrote a query that uses `serialize` + `prev()`. If your colleague asks 'isn't there a join-based way to do this,' what would you say — and which would you actually use?"*

### Phase 2 — Create the scheduled analytics rule (~15 min)

**Goal:** The query is wrapped in a scheduled analytics rule.

**Steps in Sentinel:**
1. **Configuration → Analytics → + Create → Scheduled query rule**.
2. **General tab:**
   - Name: `Impossible travel - country change within 60 min`
   - Description: `Detects successful sign-ins from two different countries within 60 minutes for the same user. Common indicators: account compromise, credential sharing, or VPN use.`
   - Tactics: `Initial Access`, `Credential Access` (MITRE)
   - Techniques: `T1078` (Valid Accounts)
   - Severity: **Medium**
3. **Set rule logic tab:**
   - Paste the final query from phase 1.
   - **Query period:** `Last 1 hour`
   - **Query frequency:** `1 hour`
   - **Threshold:** `Number of results > 0`
4. **Map entities:**
   - Account → Identifier: `Name` → Column: `AccountName`
   - Account → Identifier: `UPNSuffix` → Column: `AccountUPNSuffix`
   - IP → Identifier: `Address` → Column: `IPAddress`
5. **Custom details** (optional but helpful):
   - PreviousIP: `prev_ip`
   - TimeGap: `time_gap_min`
   - PreviousCountry: `prev_location`
6. **Alert details:**
   - Alert name format: `Impossible travel for {{AccountName}} - {{prev_location}} → {{Location}} in {{time_gap_min}} min`
   - This makes the alert title self-describing.
7. **Incident settings:**
   - Create incidents from alerts triggered by this rule: **Enabled**.
   - Alert grouping: **Enabled**. Group all alerts triggered by this rule within 5 hours into a single incident. Reopen closed matching incidents: Off.
8. **Automated response:** Leave empty (project #8 wires playbooks).
9. **Review and create**.

**Concepts to name out loud:**
- *This is **the run frequency vs lookback window relationship*** — frequency = how often the rule runs. Lookback = how far back it looks each time. They should be similar; if lookback > frequency, you double-count. If lookback < frequency, you miss events. 1h / 1h is the common starting point.
- *This is **entity mapping as the foundation of investigation*** — without entity mapping, alerts appear in Sentinel but don't connect to the Account or IP entities. Investigators can't pivot. New analysts who skip this step build noisy, dead-end alerts.
- *This is **the alert name format with `{{tokens}}`*** — the title is half the analyst's experience. A title like `Impossible travel for alice.anderson - US → CN in 12 min` tells the story before the analyst even opens the incident.
- *This is **alert grouping as noise reduction*** — without it, every match becomes a separate incident. With it, repeated detections within 5 hours bundle into one investigation. Tune the grouping window to your environment.

**After-action prompt:** *"You set 1h frequency / 1h lookback. Walk me through what happens if you change to 1h frequency / 4h lookback — and when that's the right call."*

### Phase 3 — Watch the first runs (~10 min)

**Goal:** Verify the rule actually runs on its schedule, even if it finds nothing.

**Steps:**
1. Wait ~5-10 minutes after rule creation for the first scheduled run.
2. **Configuration → Analytics → Active rules → click your rule → Rule run history** (right pane).
3. Each row: when the rule ran, how long it took, how many rows matched, whether an alert was generated.

**Or query the rule run history with KQL:**
```kql
SecurityAlert
| where TimeGenerated > ago(1d)
| where AlertName has "Impossible travel"
| project TimeGenerated, AlertName, Severity, Entities
| order by TimeGenerated desc
```

**Concepts to name out loud:**
- *This is **run history as the rule's daily standup*** — you should be able to answer "did this rule fire today?" without leaving the Analytics blade.
- *This is **the gap between query result and alert*** — query results > 0 in the editor doesn't always mean alerts in production (different time windows, grouping, suppression). Confirm in run history.

**After-action prompt:** *"The rule ran 6 times and found 0 matches. Is that a green light or a red light? What would you check?"*

### Phase 4 — Tune false positives (~15 min)

**Goal:** Add an allowlist filter to the query, redeploy, watch the run history.

**Discover your false positives first:**
- VPN exit IPs your team uses (corporate VPN).
- Globe-trotting executives (real impossible travel, expected).
- Service accounts that aren't actual people.

**Add the filter to the query:**
```kql
SigninLogs
| where TimeGenerated > ago(1h)
| where ResultType == 0
// EXCLUSION: corporate VPN exit IPs
| where IPAddress !in ("203.0.113.10", "203.0.113.11")
// EXCLUSION: known traveling executives
| where UserPrincipalName !in~ ("ceo@yourtenant.onmicrosoft.com", "vp@yourtenant.onmicrosoft.com")
// EXCLUSION: service accounts (often start with "svc-")
| where UserPrincipalName !startswith "svc-"
| project TimeGenerated, UserPrincipalName, IPAddress, Location, City = tostring(LocationDetails.city)
| sort by UserPrincipalName asc, TimeGenerated asc
| serialize
| extend prev_user = prev(UserPrincipalName), prev_time = prev(TimeGenerated), prev_location = prev(Location), prev_city = prev(City), prev_ip = prev(IPAddress)
| where UserPrincipalName == prev_user
| extend time_gap_min = datetime_diff('minute', TimeGenerated, prev_time)
| where prev_location != Location and time_gap_min < 60
| extend AccountName = tostring(split(UserPrincipalName, "@")[0]),
         AccountUPNSuffix = tostring(split(UserPrincipalName, "@")[1])
```

**Update the rule:**
1. **Analytics → your rule → Edit → Set rule logic → paste new query → Save.**

**Concepts to name out loud:**
- *This is **`!in` vs `!in~`*** — `!in` is case-sensitive, `!in~` is case-insensitive. Use `!in~` for UPNs (which may come in mixed case).
- *This is **the tuning trap*** — every exclusion you add lowers signal AND lowers noise. Over-tune and you blind yourself. Under-tune and the rule gets disabled by an annoyed SOC. There's no formula; it's judgment.
- *This is **`Watchlists` as the production allowlist mechanism*** — for production rules, you don't hardcode IPs in queries. You maintain a Watchlist (Sentinel feature, named CSVs you can `lookup` against) and reference it. Out of scope today; named.

**Common gotchas:**
- Excluded too much → rule fires zero times even on real attacks. Check by looking at the un-excluded version's results separately.
- Hardcoded IPs change → exclusions silently expire. Watchlists solve this by being editable independently of the rule.

**After-action prompt:** *"You added 3 exclusions. If your CISO asked 'how do I know you're not hiding real attacks behind those exclusions,' what's your answer?"*

### Phase 5 — Trigger the rule on purpose (~15 min)

**Goal:** Switch VPN to a different country, sign in, watch the rule fire an incident.

**Steps:**
1. Sign out of portal.azure.com.
2. Note your current IP/country.
3. Sign in to portal.azure.com (records sign-in #1 in `SigninLogs` from current country).
4. Sign out. Connect VPN to a different country (e.g. UK, Singapore, anywhere not your current country).
5. Sign in to portal.azure.com again (records sign-in #2 from new country).
6. Wait for the rule's next scheduled run (max 60 min, less if you triggered close to the top of the hour).
7. **Sentinel → Incidents** — a new incident with your alert title appears.
8. Open the incident — confirm entities show your Account and both IPs.

**Concepts to name out loud:**
- *This is **the "I tested it once" baseline*** — every detection rule should have proof it actually fires. Run history showing 0 matches forever is indistinguishable from a broken rule.
- *This is **deliberate triggering as production discipline*** — in production you'd document the trigger test in a runbook, run it monthly to confirm the rule still works after schema changes.

**Common gotchas:**
- Rule fires but no incident → incident creation toggled off in the rule. Re-check phase 2 step 7.
- Trigger sign-in 1 and 2 too far apart → query window misses one. Time-box the test to <30 min.
- VPN exit IP is in your exclusion list → trigger fails. Test with a fresh VPN exit.

**After-action prompt:** *"You triggered your own rule. Walk me through which parts of the test cycle would you bake into a permanent runbook so the next analyst can re-run it in 6 months."*

## When to break the method

- Learner doesn't have a VPN to trigger with → use a friend's sign-in from another country, or use `SigninLogs` from a past week that already contains impossible travel (just for the query test; can't validate the full incident creation without a real trigger).
- Learner already comfortable with KQL → skip phase 1's stepwise build, paste the final query, focus on phases 2, 4 (rule + tuning).
- Time short → phases 1-2-5 are the must-do. Phase 4 (tuning) can be a follow-up.

## Definition of done

Observable, the learner can:

- [ ] Show the analytics rule in Sentinel with status "Enabled."
- [ ] Show at least one rule run in the Rule run history (rows matched or not).
- [ ] Show the KQL query with at least one exclusion filter for false positives.
- [ ] Trigger the rule by switching VPN exits and produce a Sentinel incident.
- [ ] Open the incident and confirm Account and IP entities are populated.
- [ ] Explain in one sentence each: `serialize`, `prev()`, entity mapping, alert grouping, false positive tuning trade-off.

## Next project

→ [`cso-hunting-query`](../cso-hunting-query/SKILL.md) — flip the polarity from scheduled detection to proactive hunting: write a hunt against `DeviceProcessEvents` looking for living-off-the-land binaries (LOLBins), save the hunt, bookmark suspicious results.
