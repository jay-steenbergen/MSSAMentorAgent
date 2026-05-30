---
name: cso-defender-endpoint-onboard
description: |
  CSO track project #3. Learner onboards a Windows VM to Microsoft Defender for Endpoint, runs
  the built-in attack simulation evaluation lab, watches an alert fire in the Defender XDR
  portal, then drills into the alert: process tree, evidence, MITRE techniques, recommended
  actions. Auto-load when the learner is in `cybersecurity-ops/cso-defender-endpoint-onboard`
  or asks to learn endpoint onboarding, MDE, Defender XDR, attack simulation, process tree
  analysis, or alert triage.
---

# Project: `cso-defender-endpoint-onboard`

> **Track:** Cybersecurity Operations · **Project:** 3 of 9 · **Time:** ~90 minutes (plus ~24 hours for endpoint sensor activation lag)
>
> The first "real" defender's project: a Windows endpoint streaming telemetry to Microsoft Defender for Endpoint, an attacker pattern run against it, and an alert in the portal the learner walks end-to-end. By the end the learner has used the Defender XDR portal in anger and can read a real alert.

## Project goal

When this project is done, the learner can:

- Onboard a Windows VM to Defender for Endpoint via the **onboarding script** and verify the sensor is reporting.
- Run the **Evaluation Lab** built-in attack simulation against the VM.
- Open the resulting alert in Defender XDR, walk the **process tree**, read the **evidence**, identify the **MITRE ATT&CK techniques** referenced.
- Take a basic response action (isolate device, collect investigation package) — and explain when each is appropriate.
- Query `DeviceProcessEvents` and `DeviceFileEvents` in Advanced Hunting and link an alert back to its underlying telemetry.

## Scope guardrail

This is **one endpoint, one onboarding method, one evaluation attack, end-to-end alert walk**. We are not deploying via Intune at scale, not configuring custom indicators, not building suppression rules, not configuring Web content filtering. One sensor, one attack, one alert read like a defender reads it.

If the learner asks "how do I deploy to 10,000 endpoints?" — answer honestly: *the onboarding methods are documented; the management mechanics are an Intune/SCCM admin concern. The detection knowledge you're building is the durable part*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| **Microsoft 365 E5 trial** or A5 trial active in your tenant | M365 admin center → Licenses |
| **Security Administrator** or **Global Administrator** role | Entra → Roles and administrators |
| A Windows 10 or Server 2019+ VM you control (project #5 SCA VM works) | RDP/console access |
| Defender for Endpoint provisioned in the tenant | `security.microsoft.com` → Settings → Endpoints → Onboarding (this triggers provisioning on first visit) |
| ~24 hours of patience for first sensor activation | One-time delay after onboarding; subsequent VMs are faster |

## Phases

### Phase 1 — Set up the Defender portal & generate the onboarding package (~15 min)

**Goal:** The learner navigates to the Defender XDR portal, generates the Windows onboarding script, and understands the relationship between Defender for Endpoint (the sensor product) and Defender XDR (the unified portal).

**Steps:**
1. Navigate to **security.microsoft.com**. Sign in with your admin account.
2. Left nav → **Settings → Endpoints → Onboarding**.
3. **Deployment method:** Local Script (for testing). **Operating system:** Windows 10 and 11 (or Windows Server depending on your VM).
4. Click **Download onboarding package**. Save the zip locally.
5. Read the warning carefully — the script bakes in your tenant's MDE workspace ID. Don't share it.

**Concepts to name out loud:**
- *This is **Defender for Endpoint (MDE) as the sensor*** — the agent on the endpoint that collects file, process, network, registry, and behavioral telemetry.
- *This is **Defender XDR as the unified portal*** — `security.microsoft.com` surfaces alerts and incidents from Defender for Endpoint, Defender for Identity, Defender for Office, and (with the Sentinel data connector — project #5) Microsoft Sentinel.
- *This is **the onboarding script as a tenant-specific bootstrap*** — same script for any VM in your tenant. Different tenant = different script. Don't reuse across customers.
- *This is **why "local script" is for testing not production*** — production uses Intune, Group Policy, SCCM, or VDI golden images so onboarding is automatic and recoverable.

**After-action prompt:** *"You downloaded a script that knows about your tenant. What three things would change if you accidentally ran it on a VM that belongs to a different customer's tenant?"*

### Phase 2 — Onboard the VM (~10 min plus ~24h sensor activation lag)

**Goal:** Run the onboarding script on the VM and verify the sensor is reporting.

**Steps on the Windows VM (PowerShell as Admin):**
1. Copy the onboarding `.zip` to the VM (RDP, share, OneDrive, whatever).
2. Extract it. You'll see a `WindowsDefenderATPLocalOnboardingScript.cmd` file.
3. Run it:
```powershell
# In PowerShell as Admin from the extracted directory:
.\WindowsDefenderATPLocalOnboardingScript.cmd
# Type 'Y' when prompted
```

**Verify the sensor is healthy:**
```powershell
# Check the sensor status (registry-based)
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Advanced Threat Protection\Status" |
  Select-Object OnboardingState, SenseIsRunning, OrgId, LastConnected
```

`OnboardingState` should be `1`. `SenseIsRunning` should be `1`.

**Trigger a detection test (built-in by Microsoft):**
```powershell
# Microsoft-supported test to verify MDE detection pipeline
powershell.exe -NoExit -ExecutionPolicy Bypass -WindowStyle Hidden $ErrorActionPreference= 'silentlycontinue';(New-Object System.Net.WebClient).DownloadFile('http://127.0.0.1/1.exe', 'C:\\test-WDATP-test\\invoice.exe');Start-Process 'C:\\test-WDATP-test\\invoice.exe'
```

**Verify in the portal:**
1. Wait 5-10 min.
2. **security.microsoft.com → Assets → Devices**. Your VM should appear with sensor health "Active".
3. **Incidents & alerts → Alerts** — the test should show as a low-severity alert within 15-30 min.

**Common gotchas:**
- VM shows in portal but no telemetry → sensor is registered but inactive. Restart the **Windows Defender Advanced Threat Protection Service** service.
- Device never appears → onboarding script didn't elevate, or proxy/firewall blocks outbound to `*.dm.microsoft.com`. Check Windows Event Log for Source `SENSE`.
- Brand-new tenant takes 24h+ for first sensor → expected. Subsequent VMs onboard in minutes.

**After-action prompt:** *"You triggered a detection with a Microsoft-supplied test. What does it tell you about the path from 'something happened on the endpoint' to 'something showed up in the portal'?"*

### Phase 3 — Run an Evaluation Lab attack (~20 min)

**Goal:** Use Microsoft's built-in Evaluation Lab to run a realistic attack simulation against the onboarded VM, then see the alerts in the portal.

**Steps:**
1. **security.microsoft.com → Endpoints → Evaluation & Tutorials → Evaluation lab**.
2. If first use: **+ Setup lab** → pick small (3 devices, 24 hours). Microsoft provisions disposable test VMs for you (separate from your onboarded VM).
3. Once provisioned: **Simulations → + Create simulation**.
4. Pick a simulation — e.g. "Document drops backdoor" (uses SafeBreach attack chain).
5. Target device: pick one of the Evaluation Lab devices.
6. Run. Wait ~10-15 min for the attack chain to execute end-to-end.

**Alternative — if Evaluation Lab isn't available** (some trial SKUs lack it): use the Microsoft-supported test script from the [official MDE evaluation page](https://learn.microsoft.com/en-us/defender-endpoint/run-detection-test):
```powershell
# On your onboarded VM
powershell.exe -NoExit -ExecutionPolicy Bypass -WindowStyle Hidden ((new-object System.Net.WebClient).DownloadFile('http://127.0.0.1/1.exe', 'C:\test-MDATP-test\invoice.exe'));Start-Process 'C:\test-MDATP-test\invoice.exe'
```

**View the alerts:**
1. **security.microsoft.com → Incidents & alerts → Incidents**. Within ~15 min after the attack, an Incident appears that bundles the related alerts.
2. Click into the Incident.

**Concepts to name out loud:**
- *This is **Evaluation Lab as a safe sandbox*** — Microsoft provisions disposable devices, runs canned attacks, generates real alerts. The alerts behave identically to production alerts in the same portal.
- *This is **an Incident as a bundle of related alerts*** — Defender XDR correlates alerts that share entities (same device, same user, same process tree) and groups them into one Incident. Investigators work the Incident, not individual alerts.
- *This is **MITRE ATT&CK as the shared vocabulary*** — every Defender alert maps to a MITRE technique (`T1059.001 - PowerShell`, `T1566 - Phishing`, etc.). The technique IDs are how teams across companies talk about the same attacker behavior.

**After-action prompt:** *"You watched a fake attack and got real alerts. List three things the Defender team had to do behind the scenes for that 30-second timeline to work."*

### Phase 4 — Walk the alert end to end (~25 min)

**Goal:** The learner clicks into a real alert and reads every section of it, narrating what they see.

**Inside the Incident, open one Alert. Walk these sections in order:**

1. **Alert title and severity.** Microsoft assigns Sev. Read the description.
2. **MITRE ATT&CK techniques** referenced. Click into one. Read the technique description. (Make this a habit — you learn ATT&CK by encountering it in real alerts, not by memorizing it cold.)
3. **Impacted assets:** which device, which user, which app/process.
4. **Evidence:** files, processes, registry keys, network connections involved. Each is clickable for deeper investigation.
5. **Process tree:** the parent → child execution chain. The visual that makes "what actually happened" concrete. Click each process for command-line, file hash, signature info.
6. **Timeline:** every action on the endpoint, ordered. Filter by entity (e.g. only this process's actions).
7. **Recommended actions:** Microsoft's suggested response steps.

**Then take ONE response action** (the lowest-risk one available):
- **Collect investigation package** — gathers logs, running processes, network connections from the endpoint. Useful for forensic analysis. Doesn't disrupt the device.
- (More aggressive — not for the eval VM you might still need: **Isolate device** cuts the device off the network except for Defender management.)

**Concepts to name out loud:**
- *This is **the process tree as the most underrated tool in the portal*** — every "what did this malware actually do" question is answered by walking parent → children → grandchildren and reading command lines. New SOC analysts who learn to read process trees outpace peers who memorize alert types.
- *This is **the timeline as the cinematic view*** — every action on the device, ordered. You'll spend more time here than anywhere else once you're hunting.
- *This is **"investigation package" as the forensic snapshot*** — collected once, archived. Doesn't disrupt the device. Always reach for it before isolation or remediation.
- *This is **isolation as containment*** — cuts the endpoint off the network but keeps the Defender sensor reachable for further investigation. Pulled back when remediation is done. Different from "wipe the machine," which is the next escalation.

**Common gotchas:**
- Process tree empty → telemetry hasn't fully ingested yet. Wait 5-10 min.
- Recommendations include "block this hash globally" → only do this in production, never on lab data. You'll auto-block actual files in real ops accidentally.

**After-action prompt:** *"You walked one alert end-to-end. If you had to choose one section to skip and one section to spend twice as long on, which would each be — and why?"*

### Phase 5 — Pivot from alert to Advanced Hunting (~20 min)

**Goal:** The learner uses the **Advanced Hunting** KQL editor (the same KQL from project #1, against MDE's tables) to find the underlying telemetry that produced the alert.

**Find process creations on the attacked device in the last hour:**
```kql
DeviceProcessEvents
| where Timestamp > ago(1h)
| where DeviceName == "<your-VM-name>"
| project Timestamp, AccountName, FileName, ProcessCommandLine, InitiatingProcessFileName
| order by Timestamp desc
| take 100
```

**Find PowerShell or scripting executions specifically (a frequent attacker tool):**
```kql
DeviceProcessEvents
| where Timestamp > ago(1d)
| where DeviceName == "<your-VM-name>"
| where FileName in~ ("powershell.exe", "pwsh.exe", "cscript.exe", "wscript.exe", "mshta.exe")
| project Timestamp, FileName, ProcessCommandLine, InitiatingProcessFileName, AccountName
| order by Timestamp desc
| take 50
```

**Find file creations matching the simulation:**
```kql
DeviceFileEvents
| where Timestamp > ago(1d)
| where DeviceName == "<your-VM-name>"
| where ActionType == "FileCreated"
| where FolderPath has_any ("\\Downloads\\", "\\Temp\\", "\\AppData\\")
| project Timestamp, FileName, FolderPath, InitiatingProcessFileName, InitiatingProcessAccountName
| order by Timestamp desc
| take 50
```

**Concepts to name out loud:**
- *This is **Advanced Hunting as the raw-telemetry escape hatch*** — Defender alerts are Microsoft's pre-built detections. AH lets you write your own. The same KQL, different tables.
- *This is **MDE's core tables: `DeviceProcessEvents`, `DeviceFileEvents`, `DeviceNetworkEvents`, `DeviceRegistryEvents`, `DeviceLogonEvents`, `DeviceImageLoadEvents`*** — process, file, network, registry, logon, DLL/EXE load events respectively. Memorize the names; you'll use all of them.
- *This is **the alert → AH pivot habit*** — every senior analyst does this: see an alert, immediately pivot to AH to see what surrounded it. "Show me everything else on this device for the 30 minutes around the alert."

**Common gotchas:**
- `DeviceName` is case-sensitive in some renderings — use `=~` for case-insensitive: `where DeviceName =~ "WS01"`.
- AH retention is 30 days by default — old alerts may have no underlying telemetry to pivot to.

**After-action prompt:** *"You pivoted from an alert to raw telemetry. If a colleague said 'we got an alert but it's a false positive,' walk me through the AH queries you'd run to prove or disprove that."*

## When to break the method

- Learner doesn't have an M365 E5 trial → still do phases 1, 3 (with the Microsoft test script instead of Evaluation Lab — works on any onboarded MDE endpoint), phase 4 (use the alert the test script generated), phase 5 (AH against your VM's telemetry).
- Learner has prior SOC experience → skip phase 4 detail; spend most of the time on phase 5 (AH writing is where the senior analysts level up).
- Time short — first sensor activation took longer than expected → split across two sessions. Session 1: onboarding + first detection. Session 2: alert walk + AH pivots.

## Definition of done

Observable, the learner can:

- [ ] Show their VM in the Defender XDR Assets page with sensor health "Active".
- [ ] Show at least one Incident in the portal generated from the evaluation attack or test script.
- [ ] Walk the alert's process tree, evidence, and timeline while narrating what each shows.
- [ ] Name at least one MITRE ATT&CK technique referenced in the alert, and explain what it means.
- [ ] Run a KQL query in Advanced Hunting against `DeviceProcessEvents` and explain the columns.
- [ ] Explain in one sentence each: MDE, Defender XDR, Evaluation Lab, MITRE ATT&CK, process tree, Advanced Hunting.

## Next project

→ [`cso-incident-investigation`](../cso-incident-investigation/SKILL.md) — take the incident from this project and walk it as an investigator: alerts → entities → evidence → timeline → impact → IR report markdown.
