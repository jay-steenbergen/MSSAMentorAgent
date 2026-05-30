---
name: cybersecurity-ops-track
description: |
  Index and tracker for the MSSA Cybersecurity Operations (CSO) track. Lists the 9 projects in
  recommended order, each project's status, and the target Microsoft certification. Auto-load
  when the learner is in `tracks/cybersecurity-ops/` (any project) or asks "what's the cyber
  track" or "what should I build next on cyber" or "I'm in the CSO MSSA program."
---

# MSSA Track: Cybersecurity Operations (CSO)

> **Target cert:** Microsoft SC-200 (Microsoft Security Operations Analyst)
> **Stack:** Microsoft Entra ID · Microsoft Defender XDR (Endpoint, Identity, Office 365) · Microsoft Sentinel · KQL · Logic Apps · Microsoft Defender Threat Intelligence

## What this track teaches

By the end of this track, the learner has stood up a small but real defender's environment: hardened identity in Entra, onboarded endpoints to Defender, ingested logs into Sentinel, written detection rules and hunt queries in KQL, walked an incident from alert to closure, and automated a response with a Logic App playbook. Same shape a SOC analyst lives in on day one — minus the volume.

The teaching method is `methods/ride-along` — explained at three altitudes (why, what, how), concepts named out loud, after-action review at each milestone. The learner stays at the keyboard.

## Projects (in order)

| # | Project | What you build | Time | Status |
|---|---|---|---|---|
| 1 | [`cso-kql-foundations`](cso-kql-foundations/SKILL.md) | KQL basics against a demo workspace — `where`, `summarize`, `join`, `render` | ~60 min | **ready** |
| 2 | [`cso-entra-identity-hardening`](cso-entra-identity-hardening/SKILL.md) | Conditional Access policy enforcing MFA, named locations, KQL hunt on sign-in logs | ~75 min | **ready** |
| 3 | [`cso-defender-endpoint-onboard`](cso-defender-endpoint-onboard/SKILL.md) | Onboard a Windows VM to Defender for Endpoint, run an evaluation attack, inspect the alert | ~90 min | **ready** |
| 4 | [`cso-incident-investigation`](cso-incident-investigation/SKILL.md) | Walk an incident: alerts → entities → evidence → timeline → IR report markdown | ~75 min | **ready** |
| 5 | [`cso-sentinel-workspace`](cso-sentinel-workspace/SKILL.md) | Stand up Sentinel on a Log Analytics workspace, connect Entra + Defender data connectors | ~75 min | **ready** |
| 6 | [`cso-detection-rule`](cso-detection-rule/SKILL.md) | Write a scheduled analytics rule — impossible travel from sign-in logs, tune false positives | ~75 min | **ready** |
| 7 | [`cso-hunting-query`](cso-hunting-query/SKILL.md) | Hunt query on `DeviceProcessEvents` for LOLBins, save as hunt, bookmark suspicious results | ~60 min | **ready** |
| 8 | [`cso-soar-playbook`](cso-soar-playbook/SKILL.md) | Logic App playbook — auto-disable user on high-risk sign-in, triggered from Sentinel incident | ~90 min | **ready** |
| 9 | [`cso-threat-intel-integration`](cso-threat-intel-integration/SKILL.md) | Defender TI / TAXII connector, Watchlists, IndicatorMatch alert rule | ~75 min | **ready** |

**Status legend:** **ready** = drafted, self-reviewed, runs end-to-end · *drafted* = first pass, not reviewed · *planned* = scoped, not written

## Lab requirements (be honest about cost & access)

Cyber operations needs more cloud surface area than the other tracks. Be upfront with the learner about what's required.

| Requirement | Why | How |
|---|---|---|
| **Entra tenant** with security roles (`Security Administrator`, `Conditional Access Administrator`) | Configure CA policies, manage detections | Use a personal Entra tenant or M365 Developer tenant (`developer.microsoft.com/microsoft-365/dev-program`, free) |
| **Microsoft 365 E5 trial** or **A5 trial** | Unlocks Defender XDR (Endpoint, Identity, Office) | 30-day trial via the Microsoft 365 admin center; can extend once |
| **Azure subscription** with Sentinel-enabled Log Analytics workspace | Required for projects #5–#9 | ~$5-15/month if frugal (small ingestion volume, 31-day default retention) |
| **At least one Windows VM** to onboard to Defender for Endpoint | Endpoint detection demos | Reuse the VM from `server-cloud-admin/sca-azure-vnet-vm` or build a fresh Windows 10/11 VM |
| **Personal email address** for action group testing | Alert delivery in projects #6, #8 | Any address |

**Cost discipline:** Sentinel + Defender at lab volumes is single-digit dollars/month if you cap ingestion. The mentor names cost honestly in every project that touches paid services. Don't leave Defender for Cloud or premium SKUs enabled by accident.

## Out of scope

The CSO track does NOT teach:

- **Red team / offensive security** — penetration testing, exploit development, RE. (Adjacent skill, different curriculum.)
- **On-prem-only SIEMs** — Splunk, QRadar, ArcSight. The skills translate; the buttons differ.
- **Network security devices** — firewalls, IDS appliances, packet capture. (Network admin / network security adjacent skill set.)
- **Advanced UEBA tuning** — custom anomaly rules, ML model tuning. (Out of SC-200 scope; live there in SC-100/200 advanced or AI-102.)
- **Compliance frameworks deep-dive** — NIST 800-53, ISO 27001 controls. Named only where relevant; SC-200 is operations-first.
- **DFIR forensics** — disk imaging, memory analysis. Mentioned in incident investigation; not the project goal.

## How to use this track

1. Do projects in order. Each one builds on the one before it (especially #5 → #6 → #7 → #8).
2. Spin up the Microsoft 365 E5 trial **before** project #2 — onboarding takes a few hours to propagate.
3. Set a budget alert in Azure (Cost Management → Budgets → $20 alert) before project #5.
4. After each project, do the after-action prompt at the end of the SKILL. The reflection is half the learning.
5. After the track, sit the SC-200 within 3 months while the lab is still in your head.

## When you finish

You will have a real story for any SOC L1 interview: "I stood up a Sentinel workspace, wrote a detection rule in KQL for impossible travel, walked a real incident through the investigation portal, and automated user-disable as a SOAR playbook." That's the bar for entry-level security operations roles, plus the SC-200 to back it up.
