---
name: sca-storage-and-backup
description: |
  SCA track project #7. Learner creates an Azure Storage account, stands up an Azure Files
  SMB share, mounts it from the Azure VM (project #5) and the on-prem domain workstation,
  then protects the VM with a Recovery Services Vault — including running a real backup and
  performing a file-level restore. Auto-load when the learner is in
  `server-cloud-admin/sca-storage-and-backup` or asks to learn Azure storage tiers, Azure
  Files, SMB authentication, Recovery Services Vault, VM backup, or restoring files from
  an Azure backup.
---

# Project: `sca-storage-and-backup`

> **Track:** Server & Cloud Administration · **Project:** 7 of 9 · **Time:** ~90 minutes
>
> Two production-grade essentials in one project: shared file storage that crosses machine and OS boundaries (Azure Files) and a real backup of a real VM with a real restore (Recovery Services Vault). By the end the learner has an SMB share mounted from two different operating systems and has restored a file they deliberately broke.

## Project goal

When this project is done, the learner can:

- Create an Azure **Storage Account**, choose the right **redundancy tier** (LRS/ZRS/GRS), and explain the cost/durability trade-off.
- Create an **Azure Files** SMB share and mount it from a Windows VM via storage account key.
- Create a **Recovery Services Vault**, define a backup policy, run an on-demand backup of the project-#5 VM, then **restore a single file** to prove the backup works.
- Read the backup job history and tell whether a backup actually succeeded.

## Scope guardrail

This is **standard storage account + Azure Files SMB + RSV VM backup**. We are not setting up Azure NetApp Files, not configuring Azure Files identity-based auth (Entra Kerberos), not deploying Azure Backup Server, not configuring file-level immutability. The goal: the learner has done a backup *and a restore* once. The restore is the half admins skip.

If the learner asks "what about ransomware-resistant backups?" — answer honestly: *RSV has soft-delete and Multi-User Authorization (MUA); both deserve their own project*. Today the lesson is "backup means nothing if you've never restored."

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`sca-azure-vnet-vm`](../sca-azure-vnet-vm/SKILL.md) — VM `vm-app01` exists | `Get-AzVM -ResourceGroupName rg-mssa-azurevm` |
| Az PowerShell modules: Az.Storage, Az.RecoveryServices | `Get-Module Az.Storage, Az.RecoveryServices -ListAvailable` |
| VM is **running** for backup steps | `Get-AzVM ... -Status` shows VM running |

## Phases

### Phase 1 — Storage Account: pick the right tier (~15 min)

**Goal:** A new storage account exists with Standard tier and the right redundancy for a lab.

**Commands:**
```powershell
Connect-AzAccount
$rg       = "rg-mssa-azurevm"          # Same RG as project #5
$location = "eastus"
$saName   = "stmssa$(Get-Random -Maximum 99999)"  # Must be globally unique, lowercase, 3-24 chars

# Create the storage account — Standard, LRS (cheapest, single-region 3-copy)
$sa = New-AzStorageAccount `
  -ResourceGroupName $rg `
  -Name $saName `
  -Location $location `
  -SkuName "Standard_LRS" `
  -Kind "StorageV2" `
  -AccessTier "Hot"

# Verify
$sa | Select-Object StorageAccountName, Sku, AccessTier
```

**Concepts to name out loud:**
- *This is **redundancy tiers as durability vs cost*** — LRS (3 copies in 1 zone), ZRS (3 copies across 3 zones in 1 region), GRS (LRS + LRS in a paired region), RA-GRS (GRS + read access to secondary). LRS is cheapest, ~$0.02/GB/mo for Standard Hot. GRS is ~2x. For labs LRS is fine; for production data with low recovery time objectives, GRS or ZRS is the baseline.
- *This is **access tier as cost-per-GB vs cost-per-operation*** — Hot tier is cheap to read/write, more expensive to store. Cool tier is cheaper to store, more expensive to read. Cold/Archive are even cheaper-to-store, deeply slow to retrieve. For a lab, Hot is the right default.
- *This is **the name being globally unique*** — a storage account becomes `https://<saname>.blob.core.windows.net/`. The name has to be globally unique across all of Azure. Hence the random suffix.

**Common gotchas:**
- "Storage account name already taken" → try a different random suffix.
- Picked GRS by accident → triple the storage cost. Recreate as LRS or change the tier post-creation (some restrictions on changing post-create).

**After-action prompt:** *"You picked LRS for a lab. If this stored payroll records for a real company, which tier would you pick and what number would you put in front of the cost increase?"*

### Phase 2 — Azure Files: SMB share that crosses machines (~20 min)

**Goal:** An Azure Files share exists and is mounted on the project-#5 VM as a drive letter.

**Create the share (PowerShell):**
```powershell
# Create a 100-GiB file share inside the storage account
$ctx = (Get-AzStorageAccount -ResourceGroupName $rg -Name $saName).Context
New-AzStorageShare -Name "mssa-share" -Context $ctx -Quota 100

# Get the storage account key (needed for mount)
$key = (Get-AzStorageAccountKey -ResourceGroupName $rg -Name $saName)[0].Value
$key   # Treat this like a password
```

**Mount from the Azure VM (RDP into `vm-app01`, then PowerShell as Admin):**
```powershell
# Replace YOUR-STORAGE-ACCOUNT-NAME and YOUR-KEY
$saName = "YOUR-STORAGE-ACCOUNT-NAME"
$key    = "YOUR-KEY"

# Save the credential in the user's secret store (no password prompt next time)
cmd.exe /C "cmdkey /add:`"$saName.file.core.windows.net`" /user:`"localhost\$saName`" /pass:`"$key`""

# Mount the share as Z:
New-PSDrive -Name Z -PSProvider FileSystem -Root "\\$saName.file.core.windows.net\mssa-share" -Persist

# Verify
Get-PSDrive -Name Z
Set-Content -Path "Z:\hello-from-vm.txt" -Value "Hi from $(hostname) at $(Get-Date)"
Get-ChildItem Z:\
```

**Mount from the on-prem domain workstation (from project #4, optional):**
```powershell
# Same commands work — Azure Files SMB is reachable from anywhere with TCP 445 outbound
# Many ISPs and corporate networks block outbound 445. If it fails:
Test-NetConnection -ComputerName "$saName.file.core.windows.net" -Port 445
# False = blocked. In production, fix with private endpoint or Azure File Sync.
```

**Concepts to name out loud:**
- *This is **Azure Files as managed SMB*** — protocol you know (SMB 3.0), no servers to patch, no quorums to configure, scales to PB. Mount it like any other share.
- *This is **the storage account key as a long password*** — anyone with the key has full access to everything in the storage account. Treat it like root. For production, prefer Entra Kerberos identity-based access or RBAC + SAS tokens. For lab, key auth is fine.
- *This is **port 445 being commonly blocked*** — many ISPs block outbound 445 (it's a historical malware vector). Symptom: mount times out. Workarounds: VPN, private endpoint (extra cost), or VPN-from-home to your Azure VNet.

**Common gotchas:**
- "System error 53" or timeout → port 445 blocked. Test with `Test-NetConnection -Port 445`.
- "Access denied" → key changed. Get the current key with `Get-AzStorageAccountKey`.
- Drive doesn't persist across reboots → forgot `-Persist` flag. Add it.

**After-action prompt:** *"You mounted the same share from two different machines. What problem does Azure Files actually solve that an on-prem file server doesn't? What does it NOT solve?"*

### Phase 3 — Recovery Services Vault: protect the VM (~20 min)

**Goal:** An RSV exists, the project-#5 VM is enrolled in a backup policy, and the first backup has run.

**Commands:**
```powershell
$rsvName = "rsv-mssa"

# Create the vault
$vault = New-AzRecoveryServicesVault -ResourceGroupName $rg -Name $rsvName -Location $location

# Set the context (subsequent commands act on this vault)
Set-AzRecoveryServicesVaultContext -Vault $vault

# Optional: set redundancy. Default = GRS. For a lab, LRS is fine and cheaper.
Set-AzRecoveryServicesBackupProperty -Vault $vault -BackupStorageRedundancy LocallyRedundant

# Inspect built-in backup policies
$policy = Get-AzRecoveryServicesBackupProtectionPolicy -Name "DefaultPolicy" -WorkloadType AzureVM
$policy | Format-List

# Enable backup on vm-app01 with the default daily policy
Enable-AzRecoveryServicesBackupProtection `
  -ResourceGroupName $rg `
  -Name "vm-app01" `
  -Policy $policy

# Trigger an on-demand backup (don't wait for the scheduled run)
$container = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -FriendlyName "vm-app01"
$item = Get-AzRecoveryServicesBackupItem -Container $container -WorkloadType AzureVM
$job = Backup-AzRecoveryServicesBackupItem -Item $item

# Wait for completion (5-15 min for a small VM)
Wait-AzRecoveryServicesBackupJob -Job $job -Timeout 1800

# Check status
Get-AzRecoveryServicesBackupJob -JobId $job.JobId | Select-Object Status, StartTime, EndTime, Duration
```

**Concepts to name out loud:**
- *This is **the Recovery Services Vault as a separate billing and security boundary*** — RSV is its own resource, its own access scope (you can grant "RSV admin" without giving "VM admin"). Critical for ransomware resilience: an attacker with VM access shouldn't have RSV access.
- *This is **a backup policy as a schedule plus a retention rule*** — when to back up (e.g. daily at 2 AM), how long to keep each kind of recovery point (e.g. daily for 30 days, weekly for 12 weeks, monthly for 60 months). The default policy is reasonable for most workloads.
- *This is **an on-demand backup vs a scheduled backup*** — `Backup-AzRecoveryServicesBackupItem` runs one immediately, in addition to the policy schedule. Useful for testing or before risky changes.
- *This is **soft-delete by default*** — Azure RSV keeps deleted backups for 14 days minimum (can extend to 180). An attacker who runs "delete backup" doesn't actually destroy it. Costs slightly more during the soft-delete window; cheaper than ransomware.

**Common gotchas:**
- VM is deallocated → backup still works (it uses VM snapshots), but the agent install (one-time, automatic) requires the VM to be running once.
- Forgot to set vault context → most cmdlets fail with "no vault selected." Always `Set-AzRecoveryServicesVaultContext -Vault $vault` first.
- First backup takes 30+ minutes for a typical VM → normal. Subsequent backups are incremental and much faster.

**After-action prompt:** *"You enabled backup with the default policy. If you had to defend this choice to a compliance auditor — 'why daily, why 30/12/60?' — what would you say is the trade-off?"*

### Phase 4 — Restore a single file (the half admins skip) (~20 min)

**Goal:** Delete a file on the VM, then restore it from the backup taken in phase 3. Prove the backup actually contains usable data.

**On the VM (RDP in):**
```powershell
# Create a file you'll deliberately delete
Set-Content -Path "C:\important-doc.txt" -Value "MSSA SCA #7 critical data - $(Get-Date)"
Get-FileHash "C:\important-doc.txt"   # Record this; you'll verify it after restore

# Delete it (don't peek in the recycle bin)
Remove-Item "C:\important-doc.txt"
Test-Path "C:\important-doc.txt"  # False
```

**From your local machine (PowerShell):**
```powershell
# Find the latest recovery point
$rp = Get-AzRecoveryServicesBackupRecoveryPoint -Item $item | Sort-Object RecoveryPointTime -Descending | Select-Object -First 1
$rp | Select-Object RecoveryPointTime, RecoveryPointType

# Mount the recovery point as a network drive on the VM
$mount = Mount-AzRecoveryServicesBackupItemFile -RecoveryPoint $rp -TargetVM "vm-app01"

# This generates a script. Download and run on the VM.
$mount | Format-List
```

**Follow the cmdlet's instructions** — it produces a connection script and a temporary password, both shown in the output. On the VM, run the script. It mounts the recovery-point disk as a new drive letter (e.g. F:) on the VM.

**On the VM:**
```powershell
# The mounted recovery point appears as e.g. F:\
Get-PSDrive -PSProvider FileSystem
# Look for the temporary drive

# Copy the file back
Copy-Item -Path "F:\important-doc.txt" -Destination "C:\important-doc.txt"

# Verify hash matches what you recorded earlier
Get-FileHash "C:\important-doc.txt"
```

**Dismount the recovery point:**
```powershell
# Back on your local machine
Dismount-AzRecoveryServicesBackupItemFile -RecoveryPoint $rp
```

**Concepts to name out loud:**
- *This is **file-level restore vs full VM restore*** — full VM restore (also possible) creates a brand-new VM from the backup. File-level restore mounts the backup as a drive on the existing VM (or any VM) so you can copy just what you need. File-level is fast and surgical; VM restore is for catastrophic recovery.
- *This is **the recovery point as a snapshot moment*** — every backup creates a recovery point. You can restore to any point in time you still have. Retention policy determines how far back you can go.
- *This is **"backup is verification, not aspiration"*** — restoring proves the backup contains usable data. Plenty of orgs have backups that fail silently for months. A test restore quarterly is a real production habit.

**Common gotchas:**
- Mount script downloaded but won't run → execution policy on the VM. Set per-session: `Set-ExecutionPolicy -Scope Process Bypass`.
- Drive letter conflict → script picks the next free letter; if everything is in use, free one up.
- Recovery point still mounted past need → it has a 12-hour timeout but dismount manually when done to free resources.

**After-action prompt:** *"You backed up, deleted, and restored a single file. Walk me through how this protects against three different threat scenarios: hardware failure, user mistake, ransomware."*

### Phase 5 — Verify and bill-check (~15 min)

**Goal:** The learner can read the backup job history, understand the cost they've incurred, and clean up everything if they're done with the lab.

**Backup job history:**
```powershell
# All jobs in the last 7 days
Get-AzRecoveryServicesBackupJob -From (Get-Date).AddDays(-7) | Select-Object Operation, Status, StartTime, EndTime, Duration

# Just failures
Get-AzRecoveryServicesBackupJob -Status Failed | Select-Object Operation, StartTime, ErrorDetails
```

**Cost check (rough):**
- A 30-GB Windows VM with daily backup, default policy, LRS RSV redundancy → about **$5-10/month** in backup storage.
- Storage account with 1 GB of Azure Files → about **$0.06/month**.
- Combined this whole project's running cost: **<$15/month** if you leave it running. Halve it by deallocating VMs between sessions (compute is the dominant cost — covered in project #5).

**Clean up when truly done with the track:**
```powershell
# Disable protection on the VM (with delete option to remove backup data)
$item = Get-AzRecoveryServicesBackupItem -Container $container -WorkloadType AzureVM
Disable-AzRecoveryServicesBackupProtection -Item $item -RemoveRecoveryPoints -Force

# Then delete the whole resource group (nukes everything)
# Don't do this until truly done — project #8 reuses the VM
# Remove-AzResourceGroup -Name $rg -Force
```

**Concepts to name out loud:**
- *This is **the cost discipline of backup storage*** — backup capacity is small per VM but grows linearly with retention. A 100-GB VM with 7-year retention and daily backups isn't cheap. Plan retention to actual restore needs.

**After-action prompt:** *"You ran one backup, did one restore, and saw the job history. If asked 'how do we know backups are working tomorrow?', what's the smallest monitoring you'd add?"*

## When to break the method

- Learner has port 445 blocked locally and Azure Files isn't reachable from their workstation → that's normal. Mount only from the Azure VM (still meets the learning goal) and discuss workarounds (VPN, private endpoint).
- Learner already does backups professionally → skip phases 1-2, focus on phase 4 (file-level restore is rarer than full VM restore in practice; the muscle memory is valuable).
- Time short → skip phase 5 (the cost check is a 5-minute Loop instead). Phases 3 and 4 are the must-do; the rest is supporting cast.

## Definition of done

Observable, the learner can:

- [ ] Show a storage account with `Get-AzStorageAccount` and an Azure Files share mounted as a drive letter inside the VM.
- [ ] Show an RSV with `Get-AzRecoveryServicesVault` and at least one recovery point on the VM.
- [ ] Demonstrate file-level restore: deliberately delete a file, mount the recovery point, copy the file back, verify hash matches.
- [ ] Read backup job history and identify what succeeded vs failed.
- [ ] Explain in one sentence each: LRS vs GRS, soft-delete, file-level restore, recovery point.

## Next project

→ [`sca-monitoring`](../sca-monitoring/SKILL.md) — connect the same VM to Azure Monitor, write a KQL query against its logs, and build an alert that fires when CPU spikes.
