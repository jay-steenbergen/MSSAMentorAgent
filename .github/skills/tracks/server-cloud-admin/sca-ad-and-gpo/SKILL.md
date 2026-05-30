---
name: sca-ad-and-gpo
description: |
  SCA track project #4. Learner populates the `mssa.lab` domain (from project #3) with real
  users, groups, and computers via PowerShell, then writes their first Group Policy Objects
  to enforce a password policy and map a drive at logon. By the end the learner can sign in
  to a domain-joined workstation as a domain user and watch a drive map automatically. Auto-load
  when the learner is in `server-cloud-admin/sca-ad-and-gpo` or asks to learn about Active
  Directory user/group management, Group Policy, GPO targeting, security filtering, or `gpupdate`.
---

# Project: `sca-ad-and-gpo`

> **Track:** Server & Cloud Administration · **Project:** 4 of 9 · **Time:** ~90 minutes
>
> Real Active Directory administration on the DC built in project #3. By the end the learner has 10 domain users in the right OUs, two security groups, one workstation joined to the domain, a password policy GPO, and a drive-map GPO — and can prove they all work end-to-end.

## Project goal

When this project is done, the learner can:

- Create domain users and security groups in the right OUs using the `ActiveDirectory` PowerShell module.
- Join a Windows 10/11 workstation VM to the `mssa.lab` domain.
- Create a Group Policy Object, link it to an OU, and **target** it precisely with security filtering.
- Enforce a real policy (password complexity) and a real automation (drive mapping at logon).
- Use `gpupdate /force`, `gpresult /r`, and event logs to verify a GPO actually applied — without guessing.

## Scope guardrail

This is **single-domain GPO administration**. We are not federating with Azure (project #6), not building loopback processing chains, not configuring preferences vs policies in depth, not using GPO Central Store. Two real policies, one real automation, one workstation. Enough that the next time the learner sees Group Policy in the field they recognize the shape.

If the learner asks "how does this scale to 1,000 users?" — answer honestly: *exactly like this, with delegation and tighter OU targeting*. The mechanics are identical.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`sca-server-vm-setup`](../sca-server-vm-setup/SKILL.md) — a working DC named DC01 in `mssa.lab` | `Get-ADDomain` on the DC |
| A second VM running Windows 10/11 Pro (the workstation) | Created fresh in Hyper-V or Azure |
| Both VMs on the same virtual network and can ping each other | `Test-NetConnection DC01 -Port 389` from workstation |
| Workstation DNS points at DC01's IP | `Get-DnsClientServerAddress` on workstation |

## Phases

### Phase 1 — Create users and groups in the right OUs (~20 min)

**Goal:** Ten real domain users land in `OU=Users,OU=MSSA,DC=mssa,DC=lab` and two security groups land in `OU=Groups,OU=MSSA,DC=mssa,DC=lab`.

**On DC01 as `MSSA\Administrator` (PowerShell):**
```powershell
# A starter password every account gets — they'll be forced to change at first logon
$initialPwd = ConvertTo-SecureString "ChangeMe!2026" -AsPlainText -Force

# Create 10 users in the Users OU
$users = @(
  @{ First = "Alice";  Last = "Anderson"; Department = "Helpdesk" }
  @{ First = "Bob";    Last = "Baker";    Department = "Helpdesk" }
  @{ First = "Cara";   Last = "Chen";     Department = "Network"  }
  @{ First = "Dave";   Last = "Davis";    Department = "Network"  }
  @{ First = "Eve";    Last = "Edwards";  Department = "DevOps"   }
  @{ First = "Frank";  Last = "Foster";   Department = "DevOps"   }
  @{ First = "Gina";   Last = "Garcia";   Department = "Security" }
  @{ First = "Hank";   Last = "Hayes";    Department = "Security" }
  @{ First = "Ivy";    Last = "Iverson";  Department = "Exec"     }
  @{ First = "Jay";    Last = "Jones";    Department = "Exec"     }
)

foreach ($u in $users) {
  $sam = ($u.First.Substring(0,1) + $u.Last).ToLower()
  New-ADUser `
    -Name "$($u.First) $($u.Last)" `
    -GivenName $u.First `
    -Surname $u.Last `
    -SamAccountName $sam `
    -UserPrincipalName "$sam@mssa.lab" `
    -Department $u.Department `
    -Path "OU=Users,OU=MSSA,DC=mssa,DC=lab" `
    -AccountPassword $initialPwd `
    -Enabled $true `
    -ChangePasswordAtLogon $true
}

# Verify
Get-ADUser -Filter * -SearchBase "OU=Users,OU=MSSA,DC=mssa,DC=lab" |
  Select-Object SamAccountName, Department, Enabled

# Create two security groups
New-ADGroup -Name "Helpdesk Staff"  -GroupScope Global -GroupCategory Security -Path "OU=Groups,OU=MSSA,DC=mssa,DC=lab"
New-ADGroup -Name "Network Engineers" -GroupScope Global -GroupCategory Security -Path "OU=Groups,OU=MSSA,DC=mssa,DC=lab"

# Add users to groups by department
Get-ADUser -Filter "Department -eq 'Helpdesk'" -SearchBase "OU=Users,OU=MSSA,DC=mssa,DC=lab" |
  ForEach-Object { Add-ADGroupMember -Identity "Helpdesk Staff" -Members $_ }

Get-ADUser -Filter "Department -eq 'Network'" -SearchBase "OU=Users,OU=MSSA,DC=mssa,DC=lab" |
  ForEach-Object { Add-ADGroupMember -Identity "Network Engineers" -Members $_ }

# Verify
Get-ADGroupMember "Helpdesk Staff"
```

**Concepts to name out loud:**
- *This is **the `ActiveDirectory` PowerShell module*** — the same module is on every domain-joined Windows box (install with RSAT). Once you know `Get-ADUser`, `New-ADUser`, `Get-ADGroup`, `Add-ADGroupMember`, you can administer AD from anywhere.
- *This is **sAMAccountName vs UserPrincipalName*** — sAM is the legacy `MSSA\aanderson` form (≤20 chars, no spaces). UPN is the email-like `aanderson@mssa.lab` form. Modern apps prefer UPN; legacy apps still use sAM. Both are valid logon names.
- *This is **`-ChangePasswordAtLogon $true`*** — the admin sets a temporary password the user must change on first login. The admin never knows the user's permanent password — that's a security baseline.
- *This is **group scope: Global vs Universal vs DomainLocal*** — Global groups hold users from one domain. Universal groups hold users from any domain in the forest. DomainLocal groups grant permissions in one domain. The Microsoft convention is **AGDLP**: put **A**ccounts in **G**lobal groups, put Global groups in **D**omain**L**ocal groups, assign **P**ermissions to DomainLocal groups. Out of scope to enforce here; name it so it's not a surprise on the exam.

**Common gotchas:**
- `New-ADUser` fails with "password does not meet complexity" → the default domain password policy is enforced. Pick a stronger initial password.
- Users created in the wrong OU (Path defaulted to `CN=Users` not `OU=Users,OU=MSSA,...`) → check `Get-ADUser <name> | Select-Object DistinguishedName`. Move with `Move-ADObject` if needed.
- Forgot `-Enabled $true` → users created in disabled state, can't log in. Re-enable with `Enable-ADAccount`.

**After-action prompt:** *"You created 10 users and two groups in one PowerShell session. On a real onboarding day for 50 new hires, what would you do differently — and what part of this script would you keep exactly as it is?"*

### Phase 2 — Join a workstation to the domain (~15 min)

**Goal:** A Windows 10/11 VM successfully joins `mssa.lab` and lands a Computer object in `OU=Computers,OU=MSSA`.

**Prereqs on the workstation VM:**
- Built a Windows 10/11 Pro VM (Hyper-V or Azure) in the same network as DC01.
- DNS on the workstation points at DC01's IP. (Critical — see project #3 phase 2.)

**On the workstation (PowerShell as Admin):**
```powershell
# Verify it can resolve the domain
Resolve-DnsName mssa.lab
Resolve-DnsName _ldap._tcp.dc._msdcs.mssa.lab

# Rename and join in one go
$cred = Get-Credential -Message "Enter MSSA\Administrator credentials"
Add-Computer `
  -DomainName "mssa.lab" `
  -NewName "WS01" `
  -OUPath "OU=Computers,OU=MSSA,DC=mssa,DC=lab" `
  -Credential $cred `
  -Restart -Force
```

**After reboot, log in as a domain user (e.g. `MSSA\aanderson`) using the initial password. Windows will force a password change.**

**Back on DC01, verify the computer landed:**
```powershell
Get-ADComputer -Filter * -SearchBase "OU=Computers,OU=MSSA,DC=mssa,DC=lab"
```

**Concepts to name out loud:**
- *This is **a Computer object in AD*** — joining a workstation creates a domain account *for the machine*. The machine gets a SID, a password (rotated automatically every 30 days), and a place in the OU tree. From now on the machine authenticates to the domain at every boot.
- *This is **`-OUPath` saving you a step*** — without it, the new computer lands in the default `CN=Computers` container, which is **not an OU** and **cannot have GPOs linked to it**. Always specify `-OUPath` to land the computer in a real OU where you can target policy.
- *This is **the chain of trust*** — once joined, the workstation trusts the domain controller for authentication. A domain user can now log in anywhere in the domain with one password.

**Common gotchas:**
- DNS on the workstation pointing at a public DNS → `Resolve-DnsName mssa.lab` fails. Fix DNS first.
- Wrong OU path → computer lands in `CN=Computers`. Move with `Move-ADObject` and add a sticky note: "always specify OUPath."
- Time skew >5 minutes between workstation and DC → Kerberos authentication fails with "clock skew too great." Fix time sync on both ends (`w32tm /resync`).

**After-action prompt:** *"You joined a workstation to the domain in one command. Walk me through what changed on three computers — the workstation, the DC, and any caching server in the middle."*

### Phase 3 — Group Policy: enforce a password policy (~20 min)

**Goal:** Create a GPO that enforces a stronger password policy on users in the MSSA OU, link it, and verify it applied.

**On DC01 (PowerShell as Administrator):**
```powershell
# Create the GPO
$gpo = New-GPO -Name "MSSA - Password Policy" -Comment "12-char min, 90-day max age, no reuse of last 10"

# Set the settings (these write into the GPO's registry-style backing store)
Set-GPRegistryValue -Name $gpo.DisplayName -Key "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" -ValueName "PasswordComplexity" -Type DWord -Value 1

# Modern best practice: use the GUI for password policy because it's actually a SPECIAL fine-grained policy
# Open Group Policy Management (gpmc.msc) → MSSA Password Policy → Edit
# Computer Configuration → Policies → Windows Settings → Security Settings → Account Policies → Password Policy
# Set: Minimum password length = 12
# Set: Maximum password age = 90 days
# Set: Enforce password history = 10 passwords
```

**Important note for the learner:** In a real AD, the **Default Domain Policy** is the only GPO that can change password policy for ALL domain users (it has to be linked at the *domain root*, not an OU). For per-group password policies, you use **Fine-Grained Password Policies** (FGPP) instead. The mentor should name both options out loud.

**Simpler path: edit the Default Domain Policy GPO directly:**
```powershell
# Find the Default Domain Policy
Get-GPO -Name "Default Domain Policy"

# Edit via GUI
gpmc.msc
# Default Domain Policy → Edit → Computer Configuration → Policies → Windows Settings → Security Settings → Account Policies → Password Policy
# Bump: Min length 12, Max age 90, History 10, Complexity Enabled
```

**Force a refresh on the workstation:**
```powershell
# On the workstation (as the logged-in domain user)
gpupdate /force

# Verify the policy is in effect by checking which GPOs applied to the user
gpresult /r

# Try to change your password to a weak one to prove the policy works
# Press Ctrl-Alt-Del → Change Password → try "weak" → should be rejected
```

**Concepts to name out loud:**
- *This is **the Default Domain Policy as a special case*** — it's the only GPO whose password policy applies domain-wide. Linking other GPOs with password policy settings to OUs has **no effect** on those settings (this surprises every new admin once).
- *This is **Fine-Grained Password Policies (FGPP)*** — the modern way to have different password policies for different groups (e.g. stricter for admins, looser for guests). Configured via the **Password Settings Container** in AD, not via GPO. Out of scope today; name it.
- *This is **`gpupdate /force` vs the 90-minute background refresh*** — GPOs apply automatically every ~90 minutes (plus random offset) and at logon/boot. `gpupdate /force` ignores caching and re-applies everything immediately. Use during troubleshooting; don't add to scripts.
- *This is **`gpresult /r`*** — shows which GPOs *actually* applied to the current user/computer and which were filtered out. The first thing to run when "the policy isn't working."

**Common gotchas:**
- Setting password policy in a non-Default-Domain GPO and wondering why it doesn't apply → it can't. Move the setting to the Default Domain Policy or use FGPP.
- `gpupdate /force` shows "errors during processing" with no detail → check the Application event log on the workstation for source `Group Policy`.
- Password complexity rule expects 3 of 4 categories (upper, lower, digit, symbol). A 12-character lowercase-only password fails the *complexity* rule even if it passes the *length* rule.

**After-action prompt:** *"You forced a GPO refresh and saw it apply on the workstation. If a colleague says 'I set a GPO at the OU level and nothing happened,' walk me through the first three things you'd check."*

### Phase 4 — Group Policy: map a drive at logon (~20 min)

**Goal:** Create a GPO that maps a network drive when a Helpdesk Staff user logs on, link it, target with security filtering, verify.

**Prereq:** Create a shared folder on DC01 (or any reachable server):
```powershell
# On DC01
New-Item -Path "C:\Shares\Helpdesk" -ItemType Directory -Force
New-SmbShare -Name "Helpdesk" -Path "C:\Shares\Helpdesk" -FullAccess "MSSA\Administrators" -ReadAccess "MSSA\Helpdesk Staff"

# Verify
Get-SmbShare -Name "Helpdesk"
Test-Path "\\DC01\Helpdesk"
```

**Create and link the GPO:**
```powershell
$gpo = New-GPO -Name "MSSA - Helpdesk Drive Map"
New-GPLink -Name $gpo.DisplayName -Target "OU=Users,OU=MSSA,DC=mssa,DC=lab" -LinkEnabled Yes
```

**Edit the GPO in GPMC** (`gpmc.msc`):
1. Navigate to **MSSA - Helpdesk Drive Map → Edit**.
2. **User Configuration → Preferences → Windows Settings → Drive Maps → New → Mapped Drive**.
3. **Action:** Update. **Location:** `\\DC01\Helpdesk`. **Reconnect:** checked. **Label:** Helpdesk Share. **Drive Letter:** H.
4. **Common tab:** check **Item-level targeting → Targeting...** → **New Item → Security Group** → select `MSSA\Helpdesk Staff`. OK.

**Security filtering** so only Helpdesk Staff get the GPO applied at all:
1. In GPMC, click the **MSSA - Helpdesk Drive Map** GPO.
2. **Scope tab → Security Filtering** → Remove **Authenticated Users** → Add **Helpdesk Staff**.
3. **Delegation tab** → Add → **Authenticated Users** → Read (without Apply Group Policy).

**Test:**
```powershell
# On the workstation, log out and log back in as aanderson (Helpdesk)
# Open File Explorer → should see H: drive labeled "Helpdesk Share"

# Now log out and log in as cchen (Network) — should NOT see H: drive
```

**Concepts to name out loud:**
- *This is **GPO Preferences vs Policies*** — *Policies* (under Policies node) are enforced and removed when the GPO no longer applies. *Preferences* (under Preferences node) are applied once and persist even after the GPO is unlinked. Drive maps are typically preferences with "Update" action so they re-create at logon but don't fight a user who renames them.
- *This is **security filtering*** — by default a GPO applies to "Authenticated Users" (everyone). Removing that and adding a specific group makes the GPO target only that group. Critical for any per-team policy.
- *This is **item-level targeting*** — even finer-grained than security filtering. The GPO itself applies to many people, but individual settings inside it only apply when the targeting rule matches (group membership, OS version, day of week). Powerful and overused; teach it once, name when to reach for it.
- *This is **`-LinkEnabled Yes`*** — a linked-but-disabled GPO is in the list but inert. Useful for "stage the GPO before turning it on." Forgetting to set this to Yes is a common reason for "my GPO doesn't apply."

**Common gotchas:**
- Drive map doesn't appear → check `gpresult /r` on the workstation. If the GPO isn't listed, it was filtered out. If it IS listed but no drive, check the Group Policy event log on the workstation.
- Item-level targeting against a group → user has to log off and log back on for new group membership to take effect. Tokens are issued at logon.
- Read permission on the share is wrong → drive maps but the user gets "Access Denied." Test with `\\DC01\Helpdesk` directly first.

**After-action prompt:** *"You mapped a drive for Helpdesk staff using a GPO with security filtering and item-level targeting. If management asks 'add the Exec users to this drive map too,' which knob do you turn — the security filter, the item-level targeting, or both?"*

### Phase 5 — Investigate and prove it works end-to-end (~15 min)

**Goal:** The learner can answer "did this policy actually apply?" from logs and command-line tools, not assumptions.

**On the workstation (as a domain user):**
```powershell
# Comprehensive GPO report — HTML version
gpresult /h "$HOME\gpo-report.html"
Start-Process "$HOME\gpo-report.html"

# Text-mode summary
gpresult /r

# Event Viewer log specifically for Group Policy
Get-WinEvent -LogName "Microsoft-Windows-GroupPolicy/Operational" -MaxEvents 20

# Filter to just errors and warnings
Get-WinEvent -FilterHashtable @{
  LogName = "Microsoft-Windows-GroupPolicy/Operational"
  Level   = 1,2,3   # Critical, Error, Warning
} -MaxEvents 50
```

**On DC01, find the GPOs you've created and their status:**
```powershell
Get-GPO -All | Select-Object DisplayName, GpoStatus, ModificationTime

# Show what's linked where
Get-GPInheritance -Target "OU=Users,OU=MSSA,DC=mssa,DC=lab"

# Backup all GPOs (real-world habit: GPOs are change-controlled, back them up before edits)
Backup-GPO -All -Path "C:\GPO-Backups\$(Get-Date -Format yyyy-MM-dd)"
```

**Concepts to name out loud:**
- *This is **the GPO troubleshooting trio: `gpresult /r`, the Operational event log, `gpresult /h`*** — start with `/r` for the summary, drill into events for failures, generate `/h` HTML for evidence you can hand to someone else.
- *This is **Backup-GPO as the version control of AD*** — every production GPO change should have a backup. AD doesn't have git; this is the closest thing. Schedule it.

**Common gotchas:**
- GPO shows applied but settings don't take effect → could be a registry value override, a conflicting GPO higher in the precedence, or a setting that requires reboot (not just logoff).
- Event log shows "RSoP processing failed" → permissions issue. Domain user can't read the GPO's SYSVOL files. Check NTFS perms on `\\mssa.lab\SYSVOL`.

**After-action prompt:** *"You confirmed both GPOs applied. Walk me through how you'd use the same three tools to prove a colleague was wrong who said 'the password policy GPO isn't working.'"*

## When to break the method

- Learner is already comfortable with AD users/groups from a prior job → skip phase 1, do phase 2 quickly, spend most of the session on phases 3-5 (the GPO mechanics most new admins haven't done themselves).
- No second workstation VM available → use DC01 itself for testing (less ideal — Domain Admins are excluded from many policies by default — but workable).
- Time short → skip the drive-map GPO (phase 4), do password policy (phase 3) + investigation (phase 5). That covers 80% of what gets asked on the exam and in real interviews.

## Definition of done

Observable, the learner can:

- [ ] Show 10 users in `OU=Users,OU=MSSA` and two groups in `OU=Groups,OU=MSSA` with `Get-ADUser` and `Get-ADGroup`.
- [ ] RDP into a workstation as a domain user and watch the H: drive appear in File Explorer.
- [ ] Run `gpresult /r` and read off which GPOs are applied to the user.
- [ ] Try to set a too-short password and see the password-policy GPO reject it.
- [ ] Open the Group Policy operational event log and explain what one error or warning means.

## Next project

→ [`sca-azure-vnet-vm`](../sca-azure-vnet-vm/SKILL.md) — leave the on-prem lab for now and stand up the same kind of infrastructure in Azure: VNet, subnet, NSG, Windows VM, IIS. The hybrid-identity bridge between the two comes in project #6.
