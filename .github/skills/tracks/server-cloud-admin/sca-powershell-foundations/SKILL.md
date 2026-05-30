---
name: sca-powershell-foundations
description: |
  SCA track project #1. Learner builds PowerShell muscle memory: open a prompt, discover
  commands with `Get-Help` and `Get-Command`, read objects out of the pipeline, filter and
  sort them, and persist a personal profile. This is the keyboard the learner uses for every
  later SCA project. Auto-load when the learner is in `server-cloud-admin/sca-powershell-foundations`
  or asks to learn PowerShell, get started with Windows administration, or set up a sysadmin
  development environment for the first time.
---

# Project: `sca-powershell-foundations`

> **Track:** Server & Cloud Administration · **Project:** 1 of 9 · **Time:** ~60 minutes
>
> The PowerShell starter kit. By the end the learner can find any command they need, read what comes out of the pipeline, filter to what they care about, and save personal aliases that survive a reboot. Every later SCA project assumes this is reflex.

## Project goal

When this project is done, the learner can:

- Open PowerShell 7 (or 5.1) and explain the difference between the two.
- Use `Get-Command`, `Get-Help`, and `Get-Member` to discover a command they have never seen before — without Google.
- Read a pipeline value as an **object** (not a string), pick a property off it, and pipe it to the next command.
- Filter with `Where-Object`, sort with `Sort-Object`, select with `Select-Object`, and format with `Format-Table` — and name when to use each.
- Edit their own `$PROFILE` file so a custom function survives across PowerShell sessions.

## Scope guardrail

This is **PowerShell as a language**, not PowerShell as a remote-admin tool. We are not touching Active Directory cmdlets (that's projects #3-4), not connecting to Azure (project #5), not writing scripts longer than ~10 lines. One terminal window, the built-in cmdlets, the learner's own profile file.

If the learner asks "when do we automate real things?" — answer honestly: *project #2 (services, processes, scheduled tasks on this machine)*. The discipline of "know your shell before you ask it to do anything serious" is the lesson.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Windows 10/11 | `winver` |
| PowerShell 5.1 (ships with Windows) | `$PSVersionTable.PSVersion` in **Windows PowerShell** |
| PowerShell 7+ (recommended, optional) | `pwsh -Version` |
| Ability to write to user profile folder | `Test-Path $HOME` |

That's it. No admin rights yet, no Azure subscription, no IDE other than VS Code (optional, for editing the profile).

## Phases

### Phase 1 — Open the right shell and prove you know which one (~10 min)

**Goal:** The learner can distinguish Windows PowerShell 5.1 from PowerShell 7+, knows why both exist, and picks the right one on purpose.

**Commands the learner runs:**
```powershell
# In Start menu, open "Windows PowerShell" (the blue one)
$PSVersionTable.PSVersion
# Should print Major 5, Minor 1

# Now open "PowerShell 7" if installed (the black one), OR install it:
winget install Microsoft.PowerShell
# After install, open a new window labeled "PowerShell 7"
$PSVersionTable.PSVersion
# Should print Major 7
```

**Concepts to name out loud:**
- *This is **Windows PowerShell 5.1*** — the version that ships with every Windows install. Built on .NET Framework. Most legacy admin scripts target it. Will never get major updates again.
- *This is **PowerShell 7*** — the modern one, built on .NET (Core). Cross-platform, faster, gets new features. The version Microsoft recommends for new work.
- *This is **two parallel tools, not an upgrade*** — installing 7 does not remove 5.1. The taskbar icons are different colors on purpose. The shell prompt looks identical but the underlying engine is different.

**Common gotchas:**
- Learner thinks they upgraded — they didn't. Both exist side by side. Always check `$PSVersionTable.PSVersion`.
- Some Microsoft modules (older ones) only load in 5.1. Some new modules (Entra ID v2, Az) prefer 7. Name this now so it's not a mystery later.

**After-action prompt:** *"You have two PowerShells open. If I asked you to run a 2026 Azure cmdlet, which window would you use, and why?"*

### Phase 2 — Discover any command from scratch (~15 min)

**Goal:** Without searching the web, the learner can find the command that does what they want, read its parameters, and run a safe example.

**Commands the learner runs:**
```powershell
# Find any command containing "process"
Get-Command *process*

# Get help on one of them
Get-Help Get-Process

# Get the full help, including examples
Get-Help Get-Process -Examples

# Try one of the examples — list the top 5 processes by CPU
Get-Process | Sort-Object CPU -Descending | Select-Object -First 5
```

**Concepts to name out loud:**
- *This is **the verb-noun convention*** — `Get-Process`, `Set-Service`, `New-Item`, `Remove-Item`. Every cmdlet follows it. If you want to *get* something, the verb is `Get-`. If you want to *create* something, the verb is `New-`. Predictable on purpose.
- *This is **`Get-Help` as documentation that ships with the tool*** — no internet required. `-Examples` shows working samples. `-Full` shows everything. Learners who can read help are independent; learners who can't are stuck.
- *This is **`Get-Command` as the search engine*** — wildcards work (`*process*`). Filter by module (`-Module Microsoft.PowerShell.Management`). Filter by verb (`-Verb Get`).

**Common gotchas:**
- `Get-Help` returns only a summary the first time — that's intentional. Run `Update-Help` once (as admin) to download full help locally.
- Update-Help fails with HTTP errors on corporate networks — that's normal. The summary help is usually enough.
- Learner runs `Remove-*` commands without `-WhatIf`. Teach `-WhatIf` early and often.

**After-action prompt:** *"You found `Get-Process`, you read its help, and you ran an example. If I gave you a goal — 'show me everything listening on a network port' — walk me through how you'd find the right command without me telling you what it's called."*

### Phase 3 — Objects, not text (~15 min)

**Goal:** The learner internalizes that PowerShell passes **objects** through the pipe, not strings. They can pick a property, filter on it, and reshape the output.

**Commands the learner runs:**
```powershell
# Get all running services
Get-Service

# It LOOKS like a table. It isn't. Prove it:
Get-Service | Get-Member
# Scroll up: you'll see TypeName = System.ServiceProcess.ServiceController
# and a long list of Properties and Methods.

# Pick one property — the name
Get-Service | Select-Object -ExpandProperty Name

# Filter: only services that are running
Get-Service | Where-Object { $_.Status -eq 'Running' }

# Filter and shape: running services, just name and start type, sorted by name
Get-Service |
  Where-Object Status -eq 'Running' |
  Select-Object Name, StartType |
  Sort-Object Name
```

**Concepts to name out loud:**
- *This is **`Get-Member`*** — the most important command in PowerShell. Pipe anything to it and see what properties and methods that object has. When you don't know what's available, the answer is always `| Get-Member`.
- *This is **the pipeline carrying objects*** — in bash/cmd, pipes carry text and the next command has to parse it. In PowerShell, pipes carry typed objects. `$_.Status` is a real enum value, not the string "Running" the human-eye sees.
- *This is **`Where-Object` and `Select-Object` doing different jobs*** — `Where-Object` filters *which* objects pass through. `Select-Object` picks *which properties* on the objects you keep. Confuse them and your output is wrong.
- *This is **`$_` (or `$PSItem`) — the current pipeline item*** — `$_.Status` means "on the current object flowing through, give me its Status property."

**Common gotchas:**
- Learner writes `Where-Object Status = 'Running'` (single `=` is assignment). Has to be `-eq`. Use the same comparison operators everywhere: `-eq`, `-ne`, `-lt`, `-gt`, `-like`, `-match`.
- Output looks like a table but a column they expected is missing — PowerShell only shows the first ~5 properties by default. Use `| Format-List` or `| Select-Object *` to see them all.
- Piping to `Format-Table` and then trying to filter after it — once you `Format-*`, the objects become display-only. Filter and select *before* formatting.

**After-action prompt:** *"You typed `Get-Service | Get-Member` and saw a list of properties and methods. In your own words, what does that change about how you'll write PowerShell from now on?"*

### Phase 4 — Make it yours: profile and a tiny function (~10 min)

**Goal:** The learner edits their `$PROFILE`, drops in a custom function, restarts PowerShell, and sees the function still available. They now have a way to keep useful work.

**Commands the learner runs:**
```powershell
# Where does my profile live?
$PROFILE
# Should print a path like C:\Users\<you>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1

# Does the file exist?
Test-Path $PROFILE

# Create it if not
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force
}

# Open it in VS Code (or notepad if VS Code isn't installed)
code $PROFILE
# or: notepad $PROFILE
```

**Add this to the profile file and save:**
```powershell
function Get-TopCpu {
    param([int]$Count = 5)
    Get-Process |
        Sort-Object CPU -Descending |
        Select-Object -First $Count Name, Id, CPU, WS
}

Set-Alias top Get-TopCpu
```

**Reload and test:**
```powershell
# Reload the profile WITHOUT restarting the shell
. $PROFILE

# Try the new function
Get-TopCpu
Get-TopCpu -Count 3
top
```

**Concepts to name out loud:**
- *This is **`$PROFILE` — a script that runs every time PowerShell starts*** — anything you put here is available in every new session. Customizations belong here; one-off commands belong in the terminal.
- *This is **a function with a parameter*** — `param([int]$Count = 5)` says "this function takes a parameter named Count, an integer, defaulting to 5." Now `Get-TopCpu -Count 3` works.
- *This is **`Set-Alias`*** — a short name for a long one. `top` runs `Get-TopCpu`. Useful for personal shortcuts. Dangerous in shared scripts (the next admin doesn't know your aliases) — never use aliases in scripts, only at the prompt.
- *This is **`. $PROFILE` (dot-sourcing)*** — runs the script *in the current scope* so its functions stick around. Without the dot, the function would only exist while the script ran and then vanish.

**Common gotchas:**
- Execution policy blocks profile from loading. Fix: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`. Explain what it does before changing it.
- Learner edits the wrong profile file (PowerShell 5.1 and 7 each have their own). The path in `$PROFILE` is the right one *for the shell that's running*.
- Forgot to dot-source after editing. The function won't load until next shell start. `. $PROFILE` is the manual reload.

**After-action prompt:** *"You added a function to your profile. Restart PowerShell, run `top`, and tell me what's still true and what changed compared to your old terminal."*

## When to break the method

- The learner is already a working PowerShell admin from another job. Skip to phase 4, confirm they have a profile, move to project #2.
- The learner is on macOS or Linux (rare for MSSA). PowerShell 7 still works; the profile path differs; the verbs are the same. Adapt phase 1.
- The learner is stuck on execution policy and the discussion gets into security weeds — name it as "real production concern, not in scope for today," set `CurrentUser` to `RemoteSigned`, and move on.

## Definition of done

Observable, the learner can:

- [ ] Print `$PSVersionTable.PSVersion` and tell you which PowerShell version they're using and why.
- [ ] Find an unfamiliar command using `Get-Command` and read its help with `Get-Help`.
- [ ] Pipe a command into `Get-Member` and read off the properties of the resulting object.
- [ ] Filter with `Where-Object`, sort with `Sort-Object`, and pick properties with `Select-Object` — and name when to use each.
- [ ] Add a function to `$PROFILE`, reload it with `. $PROFILE`, and use it from a brand new terminal.

## Next project

→ [`sca-local-system-admin`](../sca-local-system-admin/SKILL.md) — turn that PowerShell muscle memory into real administration of the local Windows machine: services, processes, users, scheduled tasks, event logs.
