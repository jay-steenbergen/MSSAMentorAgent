---
name: sca-entra-hybrid-identity
description: |
  SCA track project #6. Learner installs Microsoft Entra Connect on the DC built in project #3,
  syncs on-prem AD users to Entra ID, fixes the inevitable first-sync errors, and signs into
  the Azure portal as a synced user. By the end the learner understands how a single
  identity can authenticate to both an on-prem AD domain and Azure cloud services. Auto-load
  when the learner is in `server-cloud-admin/sca-entra-hybrid-identity` or asks to learn
  about hybrid identity, Entra Connect, password hash sync, UPN suffixes, or syncing on-prem
  AD users to Azure.
---

# Project: `sca-entra-hybrid-identity`

> **Track:** Server & Cloud Administration · **Project:** 6 of 9 · **Time:** ~120 minutes (longer the first time — the install is non-trivial)
>
> Bridge the on-prem domain (project #3) to Entra ID. By the end of this project a user created in `mssa.lab` can sign into the Azure portal with their `@yourtenantdomain.onmicrosoft.com` (or verified custom domain) identity and the same password. This is the foundational hybrid-identity pattern used by every Microsoft 365 + on-prem AD environment in the world.

## Project goal

When this project is done, the learner can:

- Add a custom DNS-verified domain to Entra ID and explain why UPN suffixes have to match.
- Install Microsoft **Entra Connect** (formerly Azure AD Connect) on the DC and configure **Password Hash Sync (PHS)** as the auth method.
- Sync users from `OU=Users,OU=MSSA,DC=mssa,DC=lab` to Entra ID, then sign in to portal.azure.com as one of them.
- Read the **Entra Connect Synchronization Service Manager** and diagnose at least one common sync error.
- Force an on-demand sync with `Start-ADSyncSyncCycle` and explain when to use `Delta` vs `Initial`.

## Scope guardrail

This is **PHS-based one-way sync from on-prem → Entra**. We are not implementing pass-through authentication (PTA), not federating with ADFS, not setting up writeback (out of scope at this tier). One direction, one sync method, one sync server. That covers >80% of real-world deployments.

If the learner asks "what about seamless single sign-on?" — answer honestly: *Entra Connect can enable it as a checkbox during install; we leave it default-off for clarity*. Domain-joined machines get the experience automatically with PHS + the user's same password.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`sca-server-vm-setup`](../sca-server-vm-setup/SKILL.md) and [`sca-ad-and-gpo`](../sca-ad-and-gpo/SKILL.md) | DC01 up, 10 users in `OU=Users,OU=MSSA` |
| An Azure tenant with Global Administrator (or Hybrid Identity Administrator) rights | `Connect-AzAccount`, then check role in portal |
| Internet access from DC01 (or a dedicated Entra Connect server) | `Test-NetConnection portal.azure.com -Port 443` from DC01 |
| A domain you own OR willingness to use the default `.onmicrosoft.com` UPN suffix | Pick one before starting |
| 4 GB+ free RAM on the sync server | Check Task Manager |

**Important:** In production you'd run Entra Connect on a dedicated server, not a DC. For lab purposes installing on DC01 is acceptable and Microsoft explicitly supports it. Name the deviation from best practice out loud.

## Phases

### Phase 1 — Plan the UPN suffix and add a verified domain to Entra (~20 min)

**Goal:** Either (a) verify a real domain in the Entra tenant so synced users get `user@yourdomain.com` UPNs, or (b) accept the default `user@yourtenant.onmicrosoft.com` UPN and update the on-prem users' UPN suffixes to match.

**Decide the path:**
- **Path A (real domain):** You own `mssa-yourname.dev` (or similar). You'll prove ownership via a DNS TXT record and Entra accepts it. Users sync as `aanderson@mssa-yourname.dev`.
- **Path B (no real domain):** Use the tenant's default `xxx.onmicrosoft.com`. Update on-prem users' UPN suffix to match before sync. Users sync as `aanderson@xxx.onmicrosoft.com`.

**Path A — verify a custom domain:**
1. In the Azure portal, search for **Microsoft Entra ID** → **Custom domain names** → **+ Add custom domain**.
2. Type your domain (e.g. `mssa-yourname.dev`) → **Add domain**.
3. Entra shows a TXT or MX record to add. At your DNS registrar, add the record exactly as shown.
4. Wait ~5-15 min for DNS propagation. Click **Verify**.

**Then add `mssa-yourname.dev` as a UPN suffix in your on-prem AD:**
```powershell
# On DC01 (PowerShell as Admin)
Get-ADForest | Set-ADForest -UPNSuffixes @{Add="mssa-yourname.dev"}

# Update the 10 users to use the new suffix
Get-ADUser -Filter * -SearchBase "OU=Users,OU=MSSA,DC=mssa,DC=lab" |
  ForEach-Object {
    $newUpn = "$($_.SamAccountName)@mssa-yourname.dev"
    Set-ADUser -Identity $_ -UserPrincipalName $newUpn
  }

# Verify
Get-ADUser -Filter * -SearchBase "OU=Users,OU=MSSA,DC=mssa,DC=lab" |
  Select-Object SamAccountName, UserPrincipalName
```

**Path B — use `.onmicrosoft.com`:**
```powershell
# Find your tenant's onmicrosoft suffix in the portal first (Entra ID overview)
$tenantSuffix = "xxx.onmicrosoft.com"   # Replace xxx with yours

Get-ADForest | Set-ADForest -UPNSuffixes @{Add=$tenantSuffix}

Get-ADUser -Filter * -SearchBase "OU=Users,OU=MSSA,DC=mssa,DC=lab" |
  ForEach-Object {
    $newUpn = "$($_.SamAccountName)@$tenantSuffix"
    Set-ADUser -Identity $_ -UserPrincipalName $newUpn
  }
```

**Concepts to name out loud:**
- *This is **the UPN suffix as the routing hint*** — when a user signs in as `aanderson@mssa-yourname.dev`, Entra matches the `mssa-yourname.dev` part to figure out which tenant and which authentication path to use. If the UPN suffix in on-prem doesn't match any verified domain in Entra, the user gets synced as `aanderson@xxx.onmicrosoft.com` instead — usable but ugly.
- *This is **why the on-prem UPN must match the Entra verified domain*** — sync copies the UPN. No match = the default fallback. Mismatch is one of the most common new-admin questions.
- *This is **DNS as the proof of domain ownership*** — Entra (like every modern cloud) won't let you claim a domain unless you can prove you control its DNS. TXT/MX record validation is the universal pattern.

**Common gotchas:**
- DNS TXT record added but verification fails → propagation can take up to 24 hours, usually 5-15 min. `Resolve-DnsName -Type TXT mssa-yourname.dev -Server 8.8.8.8` to check from outside your DNS.
- Updated UPN on user but the user is logged in somewhere → existing Kerberos tickets keep the old UPN. Log off and back on after UPN changes.

**After-action prompt:** *"You changed the UPN suffix of 10 users. From the user's perspective, what changes when they next try to sign in to a domain-joined workstation? What stays the same?"*

### Phase 2 — Download and install Entra Connect (~30 min)

**Goal:** Entra Connect is installed on DC01 with the **Express** install path, configured for Password Hash Sync, syncing the `OU=MSSA` OU only.

**On DC01:**
1. Download the latest Entra Connect from [https://aka.ms/aadconnect](https://aka.ms/aadconnect). Save as `AzureADConnect.msi`.
2. Right-click → Run as administrator → Install.
3. **Welcome** → check **Agree** → **Continue**.

**Express settings (recommended for first install):**
- This path picks PHS, syncs all users, and sets up sync every 30 minutes. We'll customize the OU filter after install.
- Provide:
  - **Azure AD Global Admin credentials** (your tenant admin)
  - **AD Enterprise Admin credentials** for `MSSA\Administrator`
- Click **Install**. This takes ~5-10 minutes.

**Don't start initial sync yet — close the wizard at the end with "Configure" unchecked if offered.**

**Then re-open Entra Connect to scope the sync to just the MSSA OU:**
1. Start menu → **Azure AD Connect** → **Configure** → **Customize synchronization options** → Next.
2. Re-enter Entra and AD credentials.
3. **Domain and OU filtering** → **Sync selected domains and OUs** → uncheck everything → check only `OU=MSSA,DC=mssa,DC=lab` → Next.
4. Leave other settings default → **Configure**.
5. Check the box to **Start the synchronization process when configuration completes** → Exit.

**Verify the sync engine is happy (PowerShell):**
```powershell
# Confirm the AD Sync service is running
Get-Service -Name ADSync

# Show the current sync status
Get-ADSyncConnectorRunStatus

# Show recent sync runs
Get-ADSyncScheduler
```

**Verify in the portal:**
1. portal.azure.com → **Microsoft Entra ID** → **Users**.
2. You should see the 10 MSSA users listed with **Directory synced = Yes** within ~5-10 minutes.

**Concepts to name out loud:**
- *This is **Express vs Custom install*** — Express picks safe defaults: PHS, all OUs, no writeback. Custom lets you pick PTA, ADFS, writeback, etc. Always start with Express for the first install; reconfigure after.
- *This is **OU filtering*** — by default Entra Connect syncs everything. Scoping to just the OU you care about (`OU=MSSA`) keeps test data out of your tenant. Critical for shared tenants.
- *This is **Password Hash Sync (PHS) as a hash of a hash*** — the on-prem AD stores a hash of the password. Entra Connect sends a *hash of that hash* to Entra ID. The plaintext password never leaves on-prem. When the user signs in to Entra, Entra hashes the password the same way and compares. Secure, simple, no auth dependency on on-prem network availability.
- *This is **sync running every 30 minutes by default*** — not instantaneous. For testing, force a sync with `Start-ADSyncSyncCycle -PolicyType Delta`.

**Common gotchas:**
- "Cannot connect to Entra ID" during install → either credentials wrong (try the global admin login from a regular browser first) or proxy issues. `Test-NetConnection portal.azure.com -Port 443`.
- "AD account doesn't have required permissions" → the install requires *Enterprise Admin* (forest-level), not just Domain Admin.
- Users not appearing in Entra after install → forgot to start the initial sync. Run `Start-ADSyncSyncCycle -PolicyType Initial` from PowerShell.

**After-action prompt:** *"Entra Connect uses PHS. Walk me through what travels over the wire when a user changes their password on the on-prem workstation, and where the security boundaries are."*

### Phase 3 — Verify sync, fix common errors (~25 min)

**Goal:** The learner uses **Synchronization Service Manager** to view sync stats, finds at least one warning or error in their environment, and resolves it.

**On DC01:**
1. Start menu → **Synchronization Service** (or `miisclient.exe`).
2. **Operations** tab → see the recent runs.
3. Click any run → see counts: **Adds**, **Updates**, **Deletes**, **Renames**, **Disconnectors** (objects not currently synced).
4. **Connectors** tab → see your two connectors: one for on-prem AD, one for Entra ID. Right-click → **Search Connector Space** → search for a specific user to inspect their sync state.

**Force a delta sync (the normal manual sync):**
```powershell
Start-ADSyncSyncCycle -PolicyType Delta

# Wait, then verify
Get-ADSyncConnectorRunStatus
```

**Force a full sync (use when sync rules changed, not for routine refresh):**
```powershell
Start-ADSyncSyncCycle -PolicyType Initial
```

**Common errors to look for** (the learner can deliberately cause one if their lab is too clean):

| Error | Cause | Fix |
|---|---|---|
| **AttributeValueMustBeUnique** | Two on-prem users have the same proxyAddress/mail | Find the duplicate, fix on-prem |
| **InvalidSoftMatch** | Existing cloud-only user has same UPN as a synced user | Delete cloud-only user, re-sync |
| **DataValidationFailedDomain** | UPN suffix in on-prem isn't verified in Entra | Verify the domain in Entra (phase 1) |
| **LargeObject** | Group has too many members (>15k for cross-org sync) | Reduce membership; out of scope for lab |

**Deliberately cause and fix one error** (so the learner has done it once):
```powershell
# On DC01 — set a duplicate email on two users
Set-ADUser -Identity aanderson -EmailAddress "test@mssa-yourname.dev"
Set-ADUser -Identity bbaker    -EmailAddress "test@mssa-yourname.dev"

# Force a sync
Start-ADSyncSyncCycle -PolicyType Delta

# In Sync Service Manager → look at the Updates / Errors counts
# You should see one of them fail with AttributeValueMustBeUnique

# Fix: remove the duplicate
Set-ADUser -Identity bbaker -EmailAddress "bbaker@mssa-yourname.dev"
Start-ADSyncSyncCycle -PolicyType Delta
```

**Concepts to name out loud:**
- *This is **Sync Service Manager as the dashboard*** — every sync run shows you what changed and what failed. The first place to look when "user X isn't in Entra" or "user Y's email is wrong."
- *This is **Delta vs Initial sync*** — Delta picks up only what's changed since last run (fast). Initial re-evaluates everything against the sync rules (slow). Run Initial after rule changes or when troubleshooting "this rule isn't taking effect."
- *This is **a connector space*** — Entra Connect's local cache of what AD/Entra each contain. The actual sync compares the two connector spaces against the metaverse (a third, joined view) to decide what to add/update/delete.

**Common gotchas:**
- Error said "duplicate" but you fixed only one side → the sync caches errors for a while. Re-run sync, wait 5 min, re-check.
- Cannot reach Entra mid-sync → connection retried automatically, usually self-resolves.

**After-action prompt:** *"You deliberately broke sync with a duplicate email, watched it fail, then fixed it. Walk me through how you'd notice this error in production where you didn't cause it on purpose."*

### Phase 4 — Sign in to Azure as a synced user (~10 min)

**Goal:** The learner signs into portal.azure.com as one of the synced users and proves the password is the same as the on-prem one.

**Steps:**
1. Open a fresh browser window (or InPrivate / Incognito) — to avoid your admin session interfering.
2. Go to portal.azure.com.
3. Sign in as `aanderson@mssa-yourname.dev` (or whichever UPN you set).
4. Use the on-prem password the user has on the workstation.
5. You should land in the Entra portal as that user.

**If you assigned them an Azure RBAC role earlier, they have access. Otherwise:**
```powershell
# As global admin, give Alice Reader rights on the resource group from project #5
$user = Get-AzADUser -UserPrincipalName "aanderson@mssa-yourname.dev"
New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName Reader -ResourceGroupName "rg-mssa-azurevm"
```

**Now log in as Alice and confirm she can see the VM resource group (but not edit it).**

**Concepts to name out loud:**
- *This is **one identity, two stores*** — the user object lives in on-prem AD (source of truth) and in Entra ID (synced copy). Password lives in on-prem; Entra has the hash-of-the-hash. The user perceives one identity.
- *This is **RBAC built on Entra identities*** — once a user exists in Entra (synced or cloud-only), Azure RBAC can grant them access to subscriptions, resource groups, and individual resources.

**Common gotchas:**
- Sign-in fails with "AADSTS50034: user does not exist in tenant" → sync hasn't picked up the user yet, or the UPN suffix is wrong. Verify both.
- Sign-in fails with "wrong password" → password was changed on-prem but sync hasn't propagated yet. Force `Start-ADSyncSyncCycle -PolicyType Delta`.
- Sign-in works but no access to anything → expected. You haven't assigned RBAC roles. Synced ≠ authorized.

**After-action prompt:** *"You signed in to Azure as a user you created in on-prem AD. The password is the same. Walk me through which system actually validated that password and how."*

### Phase 5 — Operational habits (~10 min)

**Goal:** Three habits the learner takes away: schedule visibility, error monitoring, a clean approach to user lifecycle.

**Sync schedule visibility:**
```powershell
Get-ADSyncScheduler
# Note: NextSyncCyclePolicyType (usually Delta), NextSyncCycleStartTimeInUTC
```

**Disable a synced user:**
- **The wrong way:** disable in Entra. Sync will re-enable from on-prem within 30 min.
- **The right way:** disable in on-prem AD (`Disable-ADAccount -Identity aanderson`). Sync propagates the disable to Entra within minutes.

**Delete a synced user:**
- The right way: delete in on-prem. The Entra object goes to soft-delete (recoverable for 30 days).

**Sync errors notification:**
- In production: configure **Azure AD Connect Health** (in portal, requires a license) to email on sync failures.
- For lab: a scheduled task that runs `Get-ADSyncConnectorRunStatus` and emails you on errors is a viable cheap alternative.

**After-action prompt:** *"You learned that disabling a synced user in Entra doesn't stick. Walk me through what would happen on a real onboarding/offboarding workflow — where does the human change the account, and how do all the systems catch up?"*

## When to break the method

- Learner doesn't own a domain and the `.onmicrosoft.com` suffix is acceptable → skip Path A in phase 1, use Path B. The mechanics are identical; aesthetics differ.
- Learner already has Entra Connect installed at work and is familiar → skip phase 2, dive straight into phase 3 (errors) and phase 5 (operational habits). That's the depth most working admins lack.
- The Entra Connect install fails repeatedly on DC01 (rare, but happens with corporate proxies) → stand up a separate Windows Server 2022 member server (domain-joined) and install there. Production best practice anyway.

## Definition of done

Observable, the learner can:

- [ ] Show 10 users in the Entra portal with **Directory synced = Yes**.
- [ ] Sign into portal.azure.com as a synced user using their on-prem password.
- [ ] Open Synchronization Service Manager and explain what a Delta sync run shows.
- [ ] Force a sync with `Start-ADSyncSyncCycle -PolicyType Delta` and verify it ran.
- [ ] Explain in one sentence each: PHS, UPN suffix, Sync Service Manager, soft-delete in Entra.

## Next project

→ [`sca-storage-and-backup`](../sca-storage-and-backup/SKILL.md) — add Azure Files as shared storage the VMs can mount, and protect everything with a Recovery Services Vault.
