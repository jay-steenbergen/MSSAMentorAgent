---
name: sca-server-vm-setup
description: |
  SCA track project #3. Learner spins up a Windows Server 2022 VM (Hyper-V on a Pro/Enterprise
  laptop, or an Azure VM if Hyper-V isn't available), installs the Active Directory Domain
  Services role, and promotes the VM to the first domain controller of a new forest. By the
  end they have a real DC named DC01 in a domain like `mssa.lab`, with DNS working and a
  baseline OU structure. Auto-load when the learner is in `server-cloud-admin/sca-server-vm-setup`
  or asks to learn how to set up a Windows Server, install Active Directory, promote a domain
  controller, or build their first lab domain.
---

# Project: `sca-server-vm-setup`

> **Track:** Server & Cloud Administration · **Project:** 3 of 9 · **Time:** ~120 minutes (longer the first time)
>
> The first real server. By the end of this project the learner has a Windows Server 2022 VM running, joined to a brand-new Active Directory forest as the first domain controller. Everything in projects #4 and #6 (group policy, hybrid identity) depends on the DC built here.

## Project goal

When this project is done, the learner can:

- Create a Hyper-V virtual machine (or Azure VM) running Windows Server 2022 Datacenter, give it a static IP, and RDP into it.
- Install the **AD DS** server role from PowerShell, then promote the server to the first domain controller of a brand-new forest (`mssa.lab` or learner's choice).
- Explain what a **forest**, **domain**, **OU**, and **DC** each are — and why we picked the names we did.
- Create a baseline OU structure inside the new domain ready for project #4.

## Scope guardrail

This is **one server, one domain, one DC**. We are not building a second site, not configuring read-only DCs, not federating with Azure (that's project #6), not joining a workstation to the domain yet. The lesson is "go from zero infrastructure to a functioning AD forest" — everything else is project #4 and later.

If the learner asks "how does this work in a real enterprise with 50 DCs?" — answer honestly: *the same way, with replication and site links layered on top*. The single-DC version is the kernel of the same design.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Completed [`sca-powershell-foundations`](../sca-powershell-foundations/SKILL.md) and [`sca-local-system-admin`](../sca-local-system-admin/SKILL.md) | Learner is comfortable with services, `Get-Help`, pipeline |
| **Either** Windows 10/11 **Pro/Enterprise** with Hyper-V enabled **or** an Azure subscription | `Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V` (must be `Enabled`) OR `az account show` |
| 8 GB+ free RAM, 60 GB+ free disk (Hyper-V path) | `Get-PSDrive C` |
| Windows Server 2022 ISO downloaded (Hyper-V path) — from [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2022) | File on disk |

**Two paths through this project.** The mentor picks based on what the learner has:

- **Path A (Hyper-V)** — free, local, fast iteration, requires Pro/Enterprise Windows. Best for learners with a personal machine.
- **Path B (Azure VM)** — costs ~$3-5/day if left running (so deallocate when done), no Hyper-V needed, works on Home edition. Best for learners on a locked-down corporate laptop.

Confirm the path before phase 1.

## Phases

### Phase 1 — Enable Hyper-V (Path A) OR create Azure VM (Path B) (~30 min)

**Goal:** Have a Windows Server 2022 VM booted to the OOBE (out-of-box experience) screen, network connected.

**Path A — Hyper-V (PowerShell as Admin):**
```powershell
# Enable Hyper-V if it isn't already (REBOOT after this)
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All

# After reboot, create an internal switch so the VM can talk to your laptop and the internet
New-VMSwitch -Name "LabSwitch" -SwitchType Internal

# Create the VM (point -Path to where you want VMs stored)
$vmName = "DC01"
$vmPath = "C:\HyperV"
New-VM -Name $vmName -MemoryStartupBytes 4GB -Path $vmPath -NewVHDPath "$vmPath\$vmName.vhdx" -NewVHDSizeBytes 60GB -Generation 2 -SwitchName "LabSwitch"

# Attach the ISO
Set-VMDvdDrive -VMName $vmName -Path "C:\path\to\WindowsServer2022.iso"

# Tell it to boot from the DVD first
Set-VMFirmware -VMName $vmName -FirstBootDevice (Get-VMDvdDrive -VMName $vmName)

# Start the VM and connect to the console
Start-VM -Name $vmName
vmconnect.exe localhost $vmName
```

**Path B — Azure VM (PowerShell with Az module):**
```powershell
# One-time: install the Az module
Install-Module -Name Az -Scope CurrentUser -Force -AllowClobber

# Connect
Connect-AzAccount

# Variables
$rg       = "rg-mssa-lab"
$location = "eastus"
$vmName   = "DC01"
$vnetName = "vnet-mssa-lab"
$adminUser = "labadmin"
$adminPwd = Read-Host "VM admin password (12+ chars, complex)" -AsSecureString

# Resource group
New-AzResourceGroup -Name $rg -Location $location

# Network
$vnet = New-AzVirtualNetwork -ResourceGroupName $rg -Location $location -Name $vnetName -AddressPrefix "10.0.0.0/16"
$subnet = Add-AzVirtualNetworkSubnetConfig -Name "default" -AddressPrefix "10.0.0.0/24" -VirtualNetwork $vnet
$vnet | Set-AzVirtualNetwork

# Deploy the VM (this takes ~5 min)
New-AzVM `
  -ResourceGroupName $rg `
  -Location $location `
  -Name $vmName `
  -VirtualNetworkName $vnetName `
  -SubnetName "default" `
  -SecurityGroupName "nsg-$vmName" `
  -PublicIpAddressName "pip-$vmName" `
  -OpenPorts 3389 `
  -Image "Win2022Datacenter" `
  -Size "Standard_B2ms" `
  -Credential (New-Object PSCredential($adminUser, $adminPwd))

# Get the public IP and connect via RDP
Get-AzPublicIpAddress -ResourceGroupName $rg -Name "pip-$vmName" | Select-Object IpAddress
```

**Concepts to name out loud:**
- *This is **virtualization*** — your laptop's hardware (CPU, RAM, disk) is partitioned and exposed to the VM as if it were its own physical machine. Hyper-V is Microsoft's hypervisor (the layer that does this partitioning).
- *This is **a Generation 2 VM*** — UEFI boot, secure boot capable, supports modern OS features. Always pick Gen 2 for new Windows Server VMs.
- *This is **an Internal switch*** — Hyper-V networking has three switch types: External (bridges to your physical NIC, VM joins your home network), Internal (VM ↔ host only), Private (VM ↔ VM only, no host). Internal is the safest learning choice.
- *This is **the Azure marketplace image*** — `Win2022Datacenter` resolves to a Microsoft-published Windows Server 2022 base image. Saves you the ISO install.

**Common gotchas:**
- Hyper-V refuses to enable → CPU virtualization disabled in BIOS. Reboot into BIOS, enable Intel VT-x or AMD-V, save, reboot.
- VM has no network → in Hyper-V you need to manually assign an IP to the new switch on the *host* side, or also create an External switch. Path B sidesteps this entirely.
- Forgot to deallocate the Azure VM overnight → ~$3-5 surprise. Teach `Stop-AzVM -Force` at the end of every session and write a habit reminder.

**After-action prompt:** *"You have a Windows Server VM booted up. Walk me through what's running where: which CPU, which RAM, which disk. What's physical, what's virtual, and where does the boundary live?"*

### Phase 2 — Initial OS configuration (~20 min)

**Goal:** Complete OOBE, set a strong admin password, set a static IP (Hyper-V path), rename the computer, install updates, reboot.

**On first boot (console for Hyper-V, RDP for Azure):**
1. Pick **Windows Server 2022 Datacenter (Desktop Experience)** — Desktop Experience gives you the GUI; Core is for advanced learners.
2. Accept license, set admin password (≥12 chars, complex).
3. Log in.

**Inside the VM (PowerShell as Admin):**
```powershell
# Rename the computer (the OS default is random)
Rename-Computer -NewName "DC01" -Force
# Restart-Computer -Force   # Wait — do the IP step first, then one reboot for both

# Set a static IP (Hyper-V path only — Azure handles this for you)
# First find your interface
Get-NetAdapter
# Note the InterfaceIndex (often 5 or 6)

New-NetIPAddress `
  -InterfaceIndex 5 `
  -IPAddress "192.168.10.10" `
  -PrefixLength 24 `
  -DefaultGateway "192.168.10.1"

Set-DnsClientServerAddress -InterfaceIndex 5 -ServerAddresses "127.0.0.1"
# Note: We point DNS at LOCALHOST because this server will BE the DNS server (DC = DNS)

# Verify
Get-NetIPAddress -InterfaceIndex 5
Get-DnsClientServerAddress -InterfaceIndex 5

# Install updates (recommended before DCpromo)
Install-Module PSWindowsUpdate -Force -SkipPublisherCheck
Install-WindowsUpdate -AcceptAll -AutoReboot
# The -AutoReboot flag handles both the rename and the patch reboot together
```

**Concepts to name out loud:**
- *This is **a static IP for a domain controller*** — DCs must have static IPs. DHCP would change the IP on lease renewal, and every client and replication partner would lose them. Static IP is non-negotiable for DCs.
- *This is **DNS pointing at the DC itself*** — once we promote this box to DC, it *becomes* the authoritative DNS server for the domain. Every DC must use itself (or another DC in the domain) as its primary DNS server. Pointing at Google's 8.8.8.8 will break AD spectacularly.
- *This is **why we rename before DCpromo*** — changing a DC's name after promotion is painful (involves removing it from the domain and re-promoting). Rename now, while it's cheap.

**Common gotchas:**
- Picked Server Core by accident → no GUI. You *can* admin Core entirely from PowerShell (and many shops do), but for a first lab use Desktop Experience.
- Set DNS to public (8.8.8.8) → DCpromo will warn or fail. Always 127.0.0.1 on the DC itself.
- Updates take 30+ minutes the first time. That's normal for a fresh ISO; reduce friction by using a recent ISO if available.

**After-action prompt:** *"You set the DNS server to 127.0.0.1 instead of a public DNS. Why is that the right answer for a domain controller — and what would break tomorrow if you set it to 8.8.8.8?"*

### Phase 3 — Install AD DS role (~10 min)

**Goal:** The **Active Directory Domain Services** role is installed (but not yet configured) on the VM.

**Inside the VM (PowerShell as Admin):**
```powershell
# Inspect what roles are available and installed
Get-WindowsFeature | Where-Object Installed

# Install AD DS plus the management tools
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Verify
Get-WindowsFeature -Name AD-Domain-Services
# Installed = True
```

**Concepts to name out loud:**
- *This is **a server role*** — a role is a bundle of services Windows Server provides. AD DS, DNS, DHCP, IIS, File Server — each is a role you install separately. Keeping a server minimal (only the roles it needs) reduces attack surface.
- *This is **install vs configure*** — installing the role copies files and registers services. The server is **not yet a domain controller** — it still needs to be **promoted**, which is the next phase. This separation matters because you can install many roles and configure them on different days.
- *This is **`-IncludeManagementTools`*** — installs the PowerShell module (`ActiveDirectory`) and MMC snap-ins you'll use to manage the DC. Without it, the role works but you have no tools to drive it.

**Common gotchas:**
- Install fails with "source not found" → very rare on a freshly installed Server 2022, common on locked-down corporate images. Resolve with `Install-WindowsFeature -Source <path-to-sxs>` if needed.

**After-action prompt:** *"You installed the AD DS role but the box is still not a domain controller. What does 'promote' mean, and why is it a separate step?"*

### Phase 4 — Promote to first DC of a new forest (~30 min)

**Goal:** The VM is promoted to be the first domain controller of a brand-new forest. The learner can sign in as the new domain admin.

**Inside the VM (PowerShell as Admin):**
```powershell
# Define the new domain
$domain = "mssa.lab"               # NetBIOS will be auto-derived as MSSA
$dsrm   = Read-Host "Directory Services Restore Mode password (12+ chars)" -AsSecureString

# This command does the promotion. Server REBOOTS automatically when done.
Install-ADDSForest `
  -DomainName $domain `
  -DomainNetbiosName "MSSA" `
  -DomainMode "WinThreshold" `
  -ForestMode "WinThreshold" `
  -InstallDns `
  -SafeModeAdministratorPassword $dsrm `
  -NoRebootOnCompletion:$false `
  -Force
```

**After the reboot, log in as `MSSA\Administrator` with the same admin password from phase 2. Verify:**
```powershell
# Confirm domain is up
Get-ADDomain

# Confirm this VM is a DC
Get-ADDomainController

# Confirm DNS for the domain resolves
Resolve-DnsName mssa.lab
Resolve-DnsName _ldap._tcp.dc._msdcs.mssa.lab    # The SRV record AD clients use
```

**Concepts to name out loud:**
- *This is **a forest, a domain, a tree*** — the **forest** is the top-level security boundary (one schema, one trust root). A forest contains one or more **trees** (related namespaces, e.g. `mssa.lab` and `subsidiary.mssa.lab`). A tree contains one or more **domains** (administrative boundaries, password policies, etc.). For a single-domain lab, all three are the same box.
- *This is **the DSRM password*** — Directory Services Restore Mode. A separate "safe mode" password used when you boot the DC into recovery mode (e.g. to restore AD from backup). Different from the domain admin password on purpose. Lose it and recovery options narrow sharply.
- *This is **DNS as AD's nervous system*** — AD clients find DCs by looking up SRV records in DNS (`_ldap._tcp.dc._msdcs.<domain>`). If DNS is broken, AD is broken. The `-InstallDns` flag in `Install-ADDSForest` sets this up automatically.
- *This is **the first DC of the forest holds the FSMO roles*** — five special roles (schema master, domain naming master, RID master, infrastructure master, PDC emulator). Out of scope for the first lab; the mentor names them so the term isn't a mystery in the AZ-104 study guide later.

**Common gotchas:**
- DNS server set to 8.8.8.8 in phase 2 → DCpromo warns "could not register SRV records." Fix DNS to 127.0.0.1 first, then re-run.
- Domain name has a typo (`mssa.lba` instead of `mssa.lab`) → renaming a domain after the fact is *deeply* painful. Confirm the spelling before pressing enter.
- Server doesn't reboot automatically → run `Restart-Computer -Force` manually.

**After-action prompt:** *"You ran one PowerShell command and reboot later you had a working domain. Three things had to be in place for that one command to succeed: the AD DS role, a static IP, and DNS pointing at the right place. Walk me through what would have failed if any one of them was wrong."*

### Phase 5 — Baseline OU structure for project #4 (~15 min)

**Goal:** Create the OUs that project #4 will populate with users and apply Group Policy to.

**Logged in as `MSSA\Administrator` (PowerShell):**
```powershell
# A simple OU layout
New-ADOrganizationalUnit -Name "MSSA" -Path "DC=mssa,DC=lab" -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Users" -Path "OU=MSSA,DC=mssa,DC=lab"
New-ADOrganizationalUnit -Name "Groups" -Path "OU=MSSA,DC=mssa,DC=lab"
New-ADOrganizationalUnit -Name "Computers" -Path "OU=MSSA,DC=mssa,DC=lab"
New-ADOrganizationalUnit -Name "ServiceAccounts" -Path "OU=MSSA,DC=mssa,DC=lab"

# Verify
Get-ADOrganizationalUnit -Filter * -SearchBase "OU=MSSA,DC=mssa,DC=lab" |
  Select-Object Name, DistinguishedName
```

**Concepts to name out loud:**
- *This is **an OU as an admin container*** — Organizational Units let you group objects (users, computers, groups) for **delegation** (give an OU's helpdesk team rights to reset passwords only inside that OU) and for **Group Policy targeting** (apply this GPO only to users in this OU). Both topics live in project #4.
- *This is **a Distinguished Name (DN)*** — every AD object has one: `OU=Users,OU=MSSA,DC=mssa,DC=lab`. Read it right-to-left like a file path. The DC components are the domain; OU components are the path within.
- *This is **`-ProtectedFromAccidentalDeletion`*** — turns on a flag that prevents this OU from being deleted without first un-protecting it. A small thing that saves real production environments often. Default to ON for top-level OUs.

**Common gotchas:**
- Wrong `-Path` syntax → error. The path must use commas and `OU=` / `DC=` prefixes exactly. Test with `Get-ADOrganizationalUnit -Filter *` to see the DN of an existing OU.

**After-action prompt:** *"You created four OUs nested inside an MSSA OU. Why these four — what does separating Users from Computers from ServiceAccounts buy you when you start applying Group Policy in the next project?"*

## When to break the method

- Learner already runs an AD lab at home or work — skip to phase 5, confirm OU layout, move on.
- Hyper-V isn't an option AND there's no Azure budget → introduce **Microsoft Learn Sandbox** as a free temporary lab for project #5 onward, but acknowledge they can't complete projects #3/4/6 fully without their own DC.
- DCpromo fails partway → roll back with `Uninstall-ADDSDomainController -DemoteOperationMasterRole -ForceRemoval -Force`, fix the root cause, retry. Don't try to patch a half-promoted DC.

## Definition of done

Observable, the learner can:

- [ ] RDP into the new VM and show `Get-ADDomain` returning their `mssa.lab` (or chosen) domain.
- [ ] Show `Get-ADDomainController` returning DC01.
- [ ] Show `Resolve-DnsName _ldap._tcp.dc._msdcs.mssa.lab` returning a valid SRV record.
- [ ] Show their five-OU structure with `Get-ADOrganizationalUnit`.
- [ ] Explain in one sentence each: forest, domain, OU, DC.

## Next project

→ [`sca-ad-and-gpo`](../sca-ad-and-gpo/SKILL.md) — populate AD with real users and groups, then apply Group Policy to enforce password rules and map drives.
