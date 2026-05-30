---
name: sca-local-system-admin
description: |
  SCA track project #2. Learner uses PowerShell to actually administer their local Windows
  machine — start/stop services, find and kill rogue processes, manage local user accounts,
  schedule a recurring task, and search the event log to investigate something that happened.
  This is the bridge from "I know PowerShell as a language" to "I am a sysadmin." Auto-load
  when the learner is in `server-cloud-admin/sca-local-system-admin` or asks to learn how
  to manage Windows services, processes, local users, scheduled tasks, or event logs.
---

# Project: `sca-local-system-admin`

> **Track:** Server & Cloud Administration · **Project:** 2 of 9 · **Time:** ~75 minutes
>
> Real Windows administration on the box the learner is sitting at. Five common admin tasks done by hand: services, processes, users, scheduled tasks, event logs. Same shape they'll do on a real server — just safer to learn on a laptop first.

## Project goal

When this project is done, the learner can:

- Start, stop, restart, and inspect a Windows service from PowerShell — and explain when to use `Restart-Service` vs `Stop-Service` + `Start-Service`.
- Find a runaway process by CPU or memory and terminate it safely.
- Create, modify, and remove a local user account, and add it to a local group.
- Schedule a recurring task that runs a PowerShell script daily at a specific time.
- Filter the Windows Event Log to answer a real question: *"what happened at 2 AM last night?"*

## Scope guardrail

This is **local administration only**. We are not joining a domain (project #3), not touching Active Directory cmdlets, not connecting to Azure, not configuring remote PowerShell sessions. Everything runs on the laptop the learner is already using — which keeps the blast radius small and the feedback loop fast.

If the learner asks "when do we admin a real server?" — answer honestly: *project #3*. The skills are the same; the only difference is which machine is on the other end of the prompt.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`sca-powershell-foundations`](../sca-powershell-foundations/SKILL.md) | Learner can use `Get-Help`, `Get-Member`, pipeline |
| Local administrator rights on the machine | `whoami /groups | findstr Administrators` |
| PowerShell 7 OR 5.1 running **as Administrator** | Title bar shows "Administrator" |

## Phases

### Phase 1 — Services: start, stop, inspect (~15 min)

**Goal:** The learner can find any service, inspect its current state, and change it without breaking the machine.

**Commands the learner runs (as Admin):**
```powershell
# List all services and their status
Get-Service

# Find a specific service — the Windows Update service
Get-Service -Name wuauserv

# Inspect what it can tell you
Get-Service -Name wuauserv | Format-List *

# Pick a safe-to-restart service for practice — the Print Spooler
Get-Service -Name Spooler

# Stop it
Stop-Service -Name Spooler -WhatIf       # See what WOULD happen first
Stop-Service -Name Spooler               # Actually do it
Get-Service -Name Spooler                # Verify status = Stopped

# Start it back up
Start-Service -Name Spooler
Get-Service -Name Spooler                # Verify status = Running

# Or do both in one step
Restart-Service -Name Spooler
```

**Concepts to name out loud:**
- *This is **a Windows service*** — a long-running program managed by the OS, not by a logged-in user. Services start at boot, run in the background, get restarted by the OS if they crash. Web servers, databases, antivirus, print spooler — all services.
- *This is **`-WhatIf` as a safety net*** — every destructive cmdlet supports it. Run with `-WhatIf` first to see what *would* happen. Then run for real. This habit will save the learner's career at least once.
- *This is **`Restart-Service` vs `Stop-Service` + `Start-Service`*** — `Restart-Service` does both in sequence. Use it for routine restarts. Use the two-step version when you need to do something *between* the stop and the start (clear a cache, swap a config file, check that nothing's blocking the port).

**Common gotchas:**
- Not running as Admin → "Cannot open Service Control Manager." Close the window, reopen "as Administrator." This is the #1 mistake.
- Stopped a service something else depends on → cascading errors. `Get-Service -Name X -DependentServices` shows the chain before you stop.
- `Spooler` doesn't exist on a printer-less machine. Substitute with `wuauserv` (Windows Update) but be careful — pause/resume rather than stop/start.

**After-action prompt:** *"You stopped a service and started it again. What's the smallest production change that could go wrong if you forgot `-WhatIf` and the service had dependencies?"*

### Phase 2 — Processes: find and kill (~10 min)

**Goal:** The learner can identify what's burning CPU or memory and stop a specific process safely.

**Commands the learner runs:**
```powershell
# All processes
Get-Process

# Sort by CPU, top 10
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10

# Sort by memory (working set) in MB
Get-Process |
  Sort-Object WS -Descending |
  Select-Object -First 10 Name, Id, @{N='MB';E={[math]::Round($_.WS/1MB,1)}}

# Find every instance of notepad
Get-Process -Name notepad -ErrorAction SilentlyContinue

# Open Notepad twice manually (Win+R notepad, twice), then:
Get-Process -Name notepad

# Kill one specific instance by Id
$p = Get-Process -Name notepad | Select-Object -First 1
Stop-Process -Id $p.Id -WhatIf       # See first
Stop-Process -Id $p.Id

# Kill all instances of a process by name
Get-Process -Name notepad | Stop-Process
```

**Concepts to name out loud:**
- *This is **a process*** — a running instance of a program. One executable can have many processes (open Notepad twice → two processes). Each has a unique **process ID (PID)** assigned by the OS at start.
- *This is **a calculated property*** — `@{N='MB';E={[math]::Round($_.WS/1MB,1)}}` builds a column on the fly. `N` = name, `E` = expression. Useful when the raw property (working set in bytes) isn't human-readable.
- *This is **the difference between killing by ID and killing by name*** — by ID is precise (one process). By name kills all matches — dangerous if the name is something common (`svchost`, `powershell`).

**Common gotchas:**
- `Stop-Process` on critical processes (lsass.exe, csrss.exe) will crash the machine. The OS protects most of these but not all. Stick to user-launched processes during learning.
- Killing the parent of the current shell — yes, you can stop the PowerShell window you're sitting in. Don't do this on purpose.
- Some processes won't die without `-Force`. Use `-Force` only after a normal stop fails — it skips the graceful shutdown.

**After-action prompt:** *"You found the top CPU process and killed it. What would have happened if the same process showed up at 90% CPU on a production server you don't own — what would you check before killing it?"*

### Phase 3 — Local users and groups (~15 min)

**Goal:** The learner creates a local account, sets a password, adds it to a group, and removes it cleanly.

**Commands the learner runs (as Admin):**
```powershell
# List all local user accounts
Get-LocalUser

# List all local groups
Get-LocalGroup

# Create a new user
$pw = Read-Host "Enter password for new user" -AsSecureString
New-LocalUser -Name "mssa-test" -Password $pw -FullName "MSSA Test User" -Description "Created during sca-local-system-admin"

# Verify it exists
Get-LocalUser -Name "mssa-test"

# Add to the local Administrators group
Add-LocalGroupMember -Group "Administrators" -Member "mssa-test"

# Verify membership
Get-LocalGroupMember -Group "Administrators"

# Remove from the group
Remove-LocalGroupMember -Group "Administrators" -Member "mssa-test"

# Remove the user entirely
Remove-LocalUser -Name "mssa-test"
Get-LocalUser -Name "mssa-test"   # Should error: user not found
```

**Concepts to name out loud:**
- *This is **the local SAM database*** — Windows keeps its own user accounts in a file called the SAM (Security Accounts Manager). These accounts only exist on this machine. Domain users (project #3) are a completely different system.
- *This is **a SecureString*** — `Read-Host -AsSecureString` returns the password as an encrypted object in memory, not a plain string. Plain-text passwords leave traces in command history and memory dumps. Treat this as a habit, not a special case.
- *This is **groups as the right level of authorization*** — never assign permissions to individual users. Assign to groups; add users to groups. Fewer places to change when someone joins or leaves a role.

**Common gotchas:**
- `New-LocalUser` fails with "password does not meet complexity requirements" — Windows enforces minimum complexity by default. Use a real password (8+ chars, mixed case + number) even for test accounts.
- `Add-LocalGroupMember` on a non-existent group → silent error in some PowerShell versions. Always `Get-LocalGroup` first to confirm.
- Forgetting to remove the test user → next admin finds an orphaned account. Clean up at the end of every practice session.

**After-action prompt:** *"You created a local user, added them to Administrators, then removed them. On a real machine you'd never assign permissions to a user directly — always to a group. Why?"*

### Phase 4 — Scheduled tasks: run something automatically (~15 min)

**Goal:** The learner schedules a small PowerShell script to run daily, sees it actually run, then removes it.

**Commands the learner runs:**
```powershell
# Make a tiny script the task will run
$scriptPath = "$HOME\sca-hello.ps1"
Set-Content -Path $scriptPath -Value 'Add-Content -Path "$HOME\sca-hello.log" -Value "Ran at $(Get-Date)"'

# Build the task definition piece by piece
$action    = New-ScheduledTaskAction `
  -Execute 'pwsh.exe' `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

$trigger   = New-ScheduledTaskTrigger -Daily -At "9:00AM"

$settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries

$principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -LogonType Interactive

Register-ScheduledTask `
  -TaskName "MSSA Hello" `
  -Action $action `
  -Trigger $trigger `
  -Settings $settings `
  -Principal $principal `
  -Description "Practice task from sca-local-system-admin"

# Verify
Get-ScheduledTask -TaskName "MSSA Hello"

# Run it NOW, don't wait until 9 AM
Start-ScheduledTask -TaskName "MSSA Hello"

# Wait a few seconds, then check the log file the script wrote
Get-Content "$HOME\sca-hello.log"

# Clean up when done practicing
Unregister-ScheduledTask -TaskName "MSSA Hello" -Confirm:$false
Remove-Item -Path $scriptPath
Remove-Item -Path "$HOME\sca-hello.log"
```

**Concepts to name out loud:**
- *This is **a scheduled task built from four pieces*** — action (what to run), trigger (when), settings (extras like "run if late"), principal (who it runs as). Every task in Task Scheduler is built from this same recipe.
- *This is **`-ExecutionPolicy Bypass` on a per-script basis*** — overrides the system policy for this one invocation. Safer than changing the machine-wide policy.
- *This is **the principal as a security identity*** — "who is this task running as?" Interactive user vs SYSTEM is a huge difference. SYSTEM has full access to everything; interactive runs as the logged-in user with that user's permissions.
- *This is **Start-ScheduledTask to bypass the trigger*** — don't wait until 9 AM to verify a daily task works. Trigger it manually now.

**Common gotchas:**
- `pwsh.exe` not on PATH (PowerShell 7 not installed) → fall back to `powershell.exe` (5.1). Both work; pick the one on the box.
- Task runs but does nothing visible → that's expected. The script writes to a log file, not the console. Check the log to confirm it ran.
- Leaving practice tasks registered → clutters Task Scheduler and may run unexpectedly. Always `Unregister-ScheduledTask` at the end.

**After-action prompt:** *"You scheduled a task and triggered it manually. On a production server, what would change about the script you'd schedule — what would you write to a log, and where would you write it so the next admin could find it?"*

### Phase 5 — Event log: investigate what happened (~15 min)

**Goal:** The learner filters the Windows Event Log to answer a real question with real data.

**Commands the learner runs:**
```powershell
# What logs even exist?
Get-WinEvent -ListLog * | Where-Object RecordCount -gt 0 | Sort-Object RecordCount -Descending | Select-Object -First 10

# Look at the System log, most recent 20 events
Get-WinEvent -LogName System -MaxEvents 20

# Filter: only errors from System log in the last 24 hours
Get-WinEvent -FilterHashtable @{
    LogName   = 'System'
    Level     = 2          # 2 = Error
    StartTime = (Get-Date).AddDays(-1)
}

# Group errors by source to see what's noisy
Get-WinEvent -FilterHashtable @{
    LogName   = 'System'
    Level     = 2
    StartTime = (Get-Date).AddDays(-7)
} | Group-Object ProviderName | Sort-Object Count -Descending

# Find your most recent logon (the actual event 4624 in Security log requires admin)
Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    Id      = 4624
} -MaxEvents 5
```

**Concepts to name out loud:**
- *This is **the Windows Event Log as the OS's audit trail*** — every interesting thing the OS does (boot, shutdown, service start, logon, hardware error) writes an event. Categorized by log (`System`, `Application`, `Security`) and source (which component wrote it).
- *This is **`-FilterHashtable` as the fast way to query*** — pulling the whole log and filtering with `Where-Object` is slow. The hashtable lets the underlying Windows API filter at the source. Always use it on big logs.
- *This is **levels as severity*** — `1` = Critical, `2` = Error, `3` = Warning, `4` = Information. Filter to errors first when investigating.
- *This is **events as the data behind every "why did this break?" investigation*** — start at the time of the failure, look 5 minutes before, find the first thing that went wrong.

**Common gotchas:**
- Security log requires admin to read. Run elevated.
- `Get-EventLog` (without `Win`) is the old API — slower, doesn't see modern event channels. Use `Get-WinEvent`.
- Time filter not narrowing as expected — `StartTime` is inclusive. `(Get-Date).AddDays(-1)` means "from 24 hours ago through now."

**After-action prompt:** *"You filtered the System log for errors in the last 24 hours. Walk me through how you'd use the same technique to investigate 'the machine rebooted at 3 AM and I want to know why.'"*

## When to break the method

- The learner is an experienced Windows admin (Active Directory background) — skim phases 1-3, do phase 4 (scheduled tasks via PowerShell, not GUI) and phase 5 properly, move on.
- The machine doesn't have admin rights (locked-down corporate laptop) — most of this project requires Admin. Either get a personal lab machine or move directly to project #5 (Azure VM, where they own the box).
- Phase 4 (scheduled tasks) is frequently the most-used skill in real jobs — if time is short, prioritize phase 4 over phase 3.

## Definition of done

Observable, the learner can:

- [ ] Stop and start a Windows service and explain when `Restart-Service` is the wrong choice.
- [ ] Find the top CPU-consuming process and kill it by ID — not by name.
- [ ] Create a local user, add them to a group, remove them, and explain why permissions go on groups, not users.
- [ ] Register a scheduled task that runs a PowerShell script daily, trigger it manually, and verify it ran.
- [ ] Filter the Event Log for errors in a time window using `-FilterHashtable`.

## Next project

→ [`sca-server-vm-setup`](../sca-server-vm-setup/SKILL.md) — spin up a Windows Server 2022 VM, install AD DS, and promote it to a domain controller. Same PowerShell muscle memory, much bigger box.
