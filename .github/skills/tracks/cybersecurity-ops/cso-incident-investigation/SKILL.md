---
name: cso-incident-investigation
description: |
  CSO track project #4. Learner takes a real or simulated incident in Defender XDR, walks
  alerts → entities → evidence → timeline → impact assessment, and writes a one-page IR
  (Incident Response) report in markdown. The output is the artifact you'd actually deliver
  to a SOC lead at end of shift. Auto-load when the learner is in
  `cybersecurity-ops/cso-incident-investigation` or asks to learn incident triage, IR report
  writing, alert correlation, impact assessment, or how to investigate a Defender incident.
---

# Project: `cso-incident-investigation`

> **Track:** Cybersecurity Operations · **Project:** 4 of 9 · **Time:** ~75 minutes
>
> Triage is a craft. By the end of this project the learner has walked one incident through a repeatable method (Lockheed Martin's kill-chain meets NIST SP 800-61's IR steps) and produced an IR report in markdown that a SOC lead would actually accept.

## Project goal

When this project is done, the learner can:

- Work through the **investigation pane** in Defender XDR — alerts → entities → evidence → timeline → impact.
- Categorize an incident: **true positive / benign positive / false positive** and explain why.
- Identify **affected entities** (users, devices, IPs, files) and **scope** the blast radius.
- Trace activity to the **earliest known compromise time** (the "patient zero" moment).
- Write a one-page **IR report** with five sections: Summary, Scope, Timeline, Root cause, Recommended actions.
- Close an incident with the correct **classification + tags + summary** so the metrics roll up cleanly.

## Scope guardrail

This is **one incident, one investigation, one IR report**. We are not doing memory forensics, not setting up DFIR tooling, not writing custom analytics rules (project #6), not building automated containment (project #8). The point is the muscle memory of "walk an incident end-to-end and write it up."

If the learner asks "how do I do disk imaging / memory analysis?" — answer honestly: *that's DFIR, a separate specialty. SOC analysts triage and escalate; DFIR specialists do deep forensics. Both have their place*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`cso-defender-endpoint-onboard`](../cso-defender-endpoint-onboard/SKILL.md) — VM is onboarded, at least one incident in the portal | `security.microsoft.com` → Incidents & alerts → Incidents |
| **Security Reader** or higher role in Defender XDR | Required for read access to incidents |
| Markdown editor (VS Code is perfect) | For the IR report |

## Phases

### Phase 1 — Pick an incident, set the stopwatch (~10 min)

**Goal:** Pick one incident to investigate, set up the IR report template, time-box the investigation.

**Steps:**
1. **security.microsoft.com → Incidents & alerts → Incidents → Active**.
2. Pick the most interesting one from project #3 (the evaluation attack will work well). If you have nothing real, run another simulation first.
3. Click the incident title. Read the auto-generated summary at the top — Microsoft Copilot for Security writes a starter summary on most incidents.
4. Open a new file: `~/source/mssa-iac/ir-reports/ir-<YYYY-MM-DD>-<incident-title>.md`. Paste the IR template at the end of this SKILL.
5. Time-box: 45 minutes for the rest of this project. Start the clock.

**Concepts to name out loud:**
- *This is **time-boxing as the realistic discipline*** — in production, you can't spend a day on every alert. SOC L1 investigations typically run 15-45 minutes. Practicing within a time-box builds the right pace.
- *This is **the incident summary as the executive view*** — what you'd say to a non-technical stakeholder in one sentence. Refine it as you learn more.

**After-action prompt:** *"You picked one incident out of several. What did you use to choose — severity, time, asset value, novelty? In production, what should drive that choice?"*

### Phase 2 — Walk the alerts (~10 min)

**Goal:** The learner reads every alert in the incident and notes (a) which entity each alert is about, (b) which MITRE technique each maps to, (c) the order of events.

**In the Defender portal:**
1. Click the **Alerts** tab inside the incident.
2. For each alert, click in and note:
   - **Alert name + severity**
   - **MITRE technique(s)** referenced
   - **First-seen timestamp**
   - **Primary entity** (the device, user, or file the alert centers on)

**In the IR report**, fill in the "Alerts" table.

**Concepts to name out loud:**
- *This is **an incident as the bundle, alerts as the chapters*** — each alert tells one part of the story. Read them in chronological order to see how the attack unfolded.
- *This is **MITRE technique as the "what" without the "how"*** — `T1059.001 - PowerShell` tells you the attacker used PowerShell. The specific command-line is in the alert evidence.

**After-action prompt:** *"You listed every alert. Which one would you read FIRST in production if you only had time for one?"*

### Phase 3 — Map the entities (~10 min)

**Goal:** The learner builds the entity map — all devices, users, IPs, files, processes involved — and decides which are *compromised*, which are *touched but clean*, and which are *innocent bystanders*.

**In the Defender portal:**
1. **Assets** tab → see all devices and users tied to the incident.
2. **Evidence and response** tab → see all files, processes, IPs, URLs.

**In the IR report**, fill in the "Entities" table — for each entity, classify:
- **Compromised** — attacker had control
- **Touched** — attacker interacted with but didn't compromise
- **Bystander** — appeared in logs incidentally

**Concepts to name out loud:**
- *This is **entity classification as the basis of scope*** — your "scope" is the set of compromised + touched entities. Everything else is noise. Getting this right is what determines whether you over-respond (isolate 20 machines when 1 is compromised) or under-respond (miss the lateral movement).
- *This is **"blast radius" in IR vocabulary*** — the set of entities the attacker could have affected. Often larger than what you can prove they did affect.

**After-action prompt:** *"You classified entities into three buckets. If your colleague said 'just isolate everything that showed up in the alerts,' what's wrong with that approach?"*

### Phase 4 — Build the timeline (~15 min)

**Goal:** A clean chronological timeline of the attack from first observed action to last.

**In the Defender portal:**
1. **Investigation graph** (visual) — see the relationship between entities and actions.
2. **Device timeline** (for each affected device) — every action ordered by time.
3. **User timeline** (for each affected user) — sign-ins, role assignments, mailbox actions.

**Run an Advanced Hunting query for the bracketing window:**
```kql
union DeviceProcessEvents, DeviceFileEvents, DeviceNetworkEvents, DeviceLogonEvents
| where Timestamp between (datetime(2026-MM-DDTHH:00:00Z) .. datetime(2026-MM-DDTHH:30:00Z))
| where DeviceName == "<your-VM-name>"
| project Timestamp, $table, FileName, ProcessCommandLine, RemoteIP, RemoteUrl, AccountName
| order by Timestamp asc
```

**In the IR report**, fill in the "Timeline" table. Each row: timestamp (UTC), entity, action, source (alert / AH).

**Concepts to name out loud:**
- *This is **the timeline as the narrative spine of the IR report*** — once you have a clean timeline, the rest of the report writes itself. Without one, every section drifts.
- *This is **"patient zero" or "earliest known compromise"*** — the first action the attacker took. Often hours or days before the first alert fired. Sometimes you can't find it; document the earliest you DID find.
- *This is **UTC as the default*** — security teams across regions standardize on UTC. Don't write local time in the report; you'll confuse readers.

**After-action prompt:** *"You built the timeline. If you could only show your lead THREE rows out of the dozens you collected, which three would you pick?"*

### Phase 5 — Classify, recommend, close (~15 min)

**Goal:** The learner picks a classification, writes recommendations, and closes the incident with proper tagging.

**Decide classification:**
- **True positive (Malicious)** — the activity was real attacker behavior.
- **True positive (Penetration test)** — real malicious behavior, but sanctioned (red team, evaluation lab).
- **Benign positive** — looked malicious but was legitimate (e.g. an admin running a legitimate but suspicious-looking PowerShell).
- **False positive** — the detection itself was wrong; the activity didn't happen as described.

For the Evaluation Lab incident from project #3, classification = **True positive — Penetration test**.

**Recommended actions** for the IR report:
- Containment actions (already taken): which response actions ran (auto-investigation, isolation, etc.)?
- Eradication actions (remediation): would you re-image, kill processes, reset passwords, block hashes?
- Recovery actions: bring the device back to production?
- Lessons learned: any detection or process gap this surfaced?

**Close the incident in the portal:**
1. Right pane → **Classify incident** → pick the classification.
2. **Determination** → choose subcategory (e.g. "Security testing" for a sanctioned simulation).
3. **Add tags** → e.g. `evaluation-lab`, `T1059.001`, `mssa-cso-04`. Tags drive metrics; use consistent ones.
4. **Summary** → 1-2 sentence executive summary.
5. **Resolve** → confirm.

**Concepts to name out loud:**
- *This is **classification as metrics gold*** — every incident classification rolls up into MTTR (mean time to resolve), TP rate, FP rate, detection effectiveness. Getting classifications right is what keeps the metrics honest.
- *This is **tags as the cross-cut*** — tags let you slice incidents by "ransomware," "insider," "phishing," "evaluation," any team-defined dimension. The first SOC discipline is consistent tagging.
- *This is **summary as the most-read thing you write*** — executives read summaries. They don't read 12-page reports. Get the summary right.

**After-action prompt:** *"You wrote the summary and closed the incident. If your CISO read only the summary, would they know what happened, what was at risk, and what to do next?"*

## When to break the method

- Learner has no Evaluation Lab incident → use one of the test-script alerts from project #3, or generate a small one (Microsoft test script, or `Invoke-MpScan` of the EICAR test file).
- Learner is already a working SOC analyst → spend most of the time on the IR report itself. Their portal navigation is fine; their report writing probably has gaps.
- Time short → phases 1-4 are the must-do. Phase 5 (classify + close) can be 5 minutes; the discipline matters more than the depth.

## Definition of done

Observable, the learner can:

- [ ] Show an incident in Defender XDR with a complete walk: alerts → entities → evidence → timeline.
- [ ] Produce a one-page IR report file (template below) with all five sections filled in.
- [ ] Correctly classify and close the incident in the portal with tags + summary.
- [ ] Identify the earliest observed action and the latest observed action in the timeline.
- [ ] Explain in one sentence each: true vs benign vs false positive, blast radius, patient zero, MTTR.

## Next project

→ [`cso-sentinel-workspace`](../cso-sentinel-workspace/SKILL.md) — stand up Microsoft Sentinel on a Log Analytics workspace and connect the Entra ID and Defender for Endpoint data sources, so future detections + hunts run on top of a real SIEM.

---

## Appendix — IR Report Template

```markdown
# Incident Report: <Incident title>

**Incident ID:** <Defender XDR incident ID>
**Author:** <your name>
**Date:** <YYYY-MM-DD UTC>
**Status:** <Open / Closed>
**Classification:** <True positive (Malicious) | True positive (Pen test) | Benign positive | False positive>
**Severity:** <High | Medium | Low | Informational>

## Summary
<1-2 sentence executive summary. Plain English. What happened, what was the impact.>

## Scope
- **Compromised entities:** <list of devices, users, files, IPs>
- **Touched entities:** <list>
- **Bystanders:** <list — optional, omit if obvious>
- **Time of first observed activity:** <YYYY-MM-DD HH:MM UTC>
- **Time of last observed activity:** <YYYY-MM-DD HH:MM UTC>
- **Detection-to-investigation gap:** <minutes / hours between first activity and first alert>

## Alerts
| Alert | Severity | MITRE | First seen | Primary entity |
|---|---|---|---|---|
| <name> | <Sev> | <Txxxx.xxx> | <UTC ts> | <entity> |

## Timeline
| Timestamp (UTC) | Entity | Action | Source |
|---|---|---|---|
| <ts> | <entity> | <action> | <Alert N / AH query / Device timeline> |

## Root cause
<1-2 paragraphs: what enabled the activity? Missing patch, weak credential, misconfig, social engineering, etc.>

## Recommended actions
- **Containment (taken):** <list>
- **Eradication:** <list — actions still needed>
- **Recovery:** <list>
- **Lessons learned / detection gaps:** <list>
```
