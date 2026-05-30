---
name: sca-azure-vnet-vm
description: |
  SCA track project #5. Learner builds an Azure VNet with a subnet and NSG, deploys a Windows
  Server 2022 VM into it, RDPs in via a public IP (locked down by NSG), installs IIS, and
  proves "I built network infrastructure in the cloud" by hitting the web server from a
  browser. First Azure-IaaS project in the track. Auto-load when the learner is in
  `server-cloud-admin/sca-azure-vnet-vm` or asks to learn Azure networking, VNet, NSG, deploy
  an Azure VM, JIT access, or set up their first cloud server.
---

# Project: `sca-azure-vnet-vm`

> **Track:** Server & Cloud Administration · **Project:** 5 of 9 · **Time:** ~75 minutes (plus ~$2-5 in Azure spend if left running)
>
> The first Azure-side server in the lab. Networks before machines — build the VNet, restrict it with an NSG, then drop a VM in. By the end the learner has IIS serving HTTP from a public IP on a real Azure VM they built themselves.

## Project goal

When this project is done, the learner can:

- Create an Azure Resource Group, VNet, subnet, and NSG from PowerShell (`Az` module) and the portal.
- Deploy a Windows Server 2022 VM into that VNet, restricted to RDP only from their own IP.
- RDP into the VM, install IIS via PowerShell, and serve a default page back to their browser.
- Explain the precedence of NSG rules and the difference between NSGs at the subnet level vs the NIC level.
- **Deallocate** the VM cleanly to stop the bill — and explain why "stop" in the Windows sense costs money but "deallocated" in the Azure sense doesn't.

## Scope guardrail

This is **one VNet, one VM, one NSG**. We are not setting up VNet peering, not standing up an Application Gateway, not using Bastion (that's a $-saving alternative we name but don't deploy), not joining this VM to AD (project #6). One workload, one entry point, one demonstration that "I can build network infrastructure in the cloud."

If the learner asks "where's the load balancer / autoscale / DDoS protection?" — answer honestly: *out of scope for this project, but every concept here scales up to those*. The lesson is the network-first habit.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Azure subscription | `Connect-AzAccount` succeeds, `Get-AzSubscription` shows at least one |
| Az PowerShell module installed | `Get-Module Az -ListAvailable` |
| Permission to create resources in a subscription | Contributor on the subscription or a resource group |
| Public IP address of the learner's own machine (for NSG allowlist) | `Invoke-RestMethod -Uri https://api.ipify.org` |

## Phases

### Phase 1 — Resource Group + VNet + subnet (~15 min)

**Goal:** A resource group exists, with a VNet `10.20.0.0/16` and a subnet `10.20.1.0/24` inside it.

**Commands the learner runs (PowerShell with Az):**
```powershell
Connect-AzAccount

# Pick a subscription if you have several
Get-AzSubscription | Select-Object Name, Id
Set-AzContext -SubscriptionId "<paste-id-here>"

# Variables — adjust prefix to anything unique
$rg       = "rg-mssa-azurevm"
$location = "eastus"
$vnetName = "vnet-mssa"
$subnetName = "snet-app"

# Create the resource group
New-AzResourceGroup -Name $rg -Location $location

# Create the VNet with a subnet in one shot
$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix "10.20.1.0/24"

$vnet = New-AzVirtualNetwork `
  -ResourceGroupName $rg `
  -Location $location `
  -Name $vnetName `
  -AddressPrefix "10.20.0.0/16" `
  -Subnet $subnet

# Verify
Get-AzVirtualNetwork -ResourceGroupName $rg | Select-Object Name, AddressSpace
Get-AzVirtualNetworkSubnetConfig -VirtualNetwork (Get-AzVirtualNetwork -ResourceGroupName $rg -Name $vnetName)
```

**Concepts to name out loud:**
- *This is **a resource group as a unit of lifecycle*** — every Azure resource belongs to exactly one. Deleting the resource group deletes everything in it (the cleanest way to teardown a lab). The choice of which resource group a resource lives in is mostly about lifecycle management and access control.
- *This is **a VNet as a private network in Azure*** — its address space is private (RFC1918). Pick a non-overlapping range with your on-prem network if you'll ever peer them. `10.20.0.0/16` gives you 65k addresses; that's plenty for a lab.
- *This is **a subnet as a slice of the VNet*** — every VM lives in a subnet. Subnets are where NSGs are typically associated. `10.20.1.0/24` gives you 256 addresses (Azure reserves 5 per subnet for its own use).

**Common gotchas:**
- VNet name has to be unique within the resource group, not globally — but storage account names are globally unique. Don't conflate.
- Address range overlaps with your home network (`192.168.1.0/24`) → when you later peer or VPN, routing breaks. Pick something distinct like `10.20.0.0/16`.

**After-action prompt:** *"You created a VNet and a subnet. In your own words: what's the difference, and what would happen if you put two VMs in two different subnets of the same VNet?"*

### Phase 2 — Network Security Group (~15 min)

**Goal:** An NSG exists, associated with the subnet, allowing **only RDP from your own IP** and nothing else inbound.

**Commands the learner runs:**
```powershell
# Get your own public IP
$myIp = (Invoke-RestMethod -Uri https://api.ipify.org)
$myIp

# Create the NSG
$nsgName = "nsg-app"
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $rg -Location $location -Name $nsgName

# Add a rule: allow RDP from your IP only
$nsg | Add-AzNetworkSecurityRuleConfig `
  -Name "AllowRDPFromMyIP" `
  -Description "RDP from my home IP" `
  -Access Allow `
  -Protocol Tcp `
  -Direction Inbound `
  -Priority 100 `
  -SourceAddressPrefix "$myIp/32" `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 3389

$nsg | Set-AzNetworkSecurityGroup

# Associate the NSG with the subnet
$vnet = Get-AzVirtualNetwork -ResourceGroupName $rg -Name $vnetName
$subnet = $vnet.Subnets | Where-Object Name -eq $subnetName
$subnet.NetworkSecurityGroup = $nsg
$vnet | Set-AzVirtualNetwork

# Verify
Get-AzNetworkSecurityGroup -ResourceGroupName $rg -Name $nsgName |
  Select-Object -ExpandProperty SecurityRules |
  Format-Table Name, Access, Priority, SourceAddressPrefix, DestinationPortRange
```

**Concepts to name out loud:**
- *This is **an NSG as a stateful firewall*** — applied to a subnet (or a NIC), it allows or denies traffic by 5-tuple (source, source port, destination, destination port, protocol). Stateful means: if you allow an outbound connection, the response is automatically allowed back in without a separate rule.
- *This is **NSG priority*** — lower numbers win. Rules evaluated in priority order; first match wins. Default rules sit at 65000-65500 and allow VNet-to-VNet traffic, allow outbound to the internet, and deny everything else inbound.
- *This is **subnet-level NSG vs NIC-level NSG*** — you can apply an NSG at either level. If both exist, **both** rule sets evaluate. Subnet-level is the default best practice; NIC-level is for special cases.
- *This is **why "RDP from any" is the cardinal sin*** — every Azure VM with port 3389 open to `0.0.0.0/0` is being brute-forced right now. Allowlisting your specific IP is the bare minimum. Better: Azure Bastion (covered in concept, not deployed here, costs $$).

**Common gotchas:**
- Your home IP changed → the rule doesn't allow you anymore. Update the rule with the new IP. Make this part of the standard "I can't RDP in" debug checklist.
- NSG associated with the wrong subnet → check `(Get-AzVirtualNetworkSubnetConfig ...).NetworkSecurityGroup`.
- Forgot priority — duplicate priorities aren't allowed. Pick 100, 200, 300 spacing for easy insertion later.

**After-action prompt:** *"You allowed RDP from your specific IP only. What concretely happens to a connection attempt from a different IP — and where can you see that happening in Azure?"*

### Phase 3 — Deploy the VM (~20 min)

**Goal:** A Windows Server 2022 VM is deployed into the subnet, RDP works, the learner is logged into the desktop.

**Commands the learner runs:**
```powershell
$vmName = "vm-app01"
$adminUser = "labadmin"
$adminPwd = Read-Host "VM admin password (12+ chars, complex, NOT used anywhere else)" -AsSecureString

# Deploy — this takes ~5 min
New-AzVM `
  -ResourceGroupName $rg `
  -Location $location `
  -Name $vmName `
  -VirtualNetworkName $vnetName `
  -SubnetName $subnetName `
  -SecurityGroupName $nsgName `
  -PublicIpAddressName "pip-$vmName" `
  -Image "Win2022Datacenter" `
  -Size "Standard_B2s" `
  -Credential (New-Object PSCredential($adminUser, $adminPwd)) `
  -OpenPorts 3389

# Get the public IP
$publicIp = (Get-AzPublicIpAddress -ResourceGroupName $rg -Name "pip-$vmName").IpAddress
$publicIp

# RDP — Windows
mstsc.exe /v:$publicIp
# Log in with labadmin / your-password
```

**Concepts to name out loud:**
- *This is **a VM size as a SKU*** — `Standard_B2s` = burstable, 2 vCPU, 4 GB RAM, ~$30/mo if left running 24/7. Burstable means CPU performance is throttled to a baseline with bursts available, which is perfect for labs (cheaper than a steady-state SKU).
- *This is **a public IP as a separately billable resource*** — even with the VM deallocated, a static public IP keeps costing pennies. For lab VMs use *dynamic* IPs (default) — they're free and only assigned when the VM is running.
- *This is **`New-AzVM`'s "convenience" mode*** — when you pass `-VirtualNetworkName` and `-SecurityGroupName` of existing resources, it wires them all up. If you omit them, it creates new ones with defaults (and you end up with three NSGs you didn't mean to make).
- *This is **`-OpenPorts 3389` adding to the NSG, not replacing*** — convenience flag. In production you'd manage NSG rules explicitly; for labs this is fine.

**Common gotchas:**
- "Admin password fails complexity" → 12+ chars, mix of upper/lower/digit/symbol, can't contain the username.
- "RDP timeout" → either (a) NSG isn't allowing your current IP, (b) the VM is still booting (give it 2-3 min), or (c) your local firewall is blocking outbound 3389. Test in order.
- "The VM is in Azure West Europe and I'm in Texas" → 200ms RDP latency feels awful. Pick a region close to you in `$location`.

**After-action prompt:** *"You deployed a VM and RDP'd in. List the resources Azure created for you in this one operation — there are more than just 'a VM.'"*

### Phase 4 — Install IIS, serve a page (~10 min)

**Goal:** IIS is installed on the VM, it's serving the default page, and the learner can hit it from their own browser via the VM's public IP.

**Inside the VM (PowerShell as Admin):**
```powershell
# Install IIS
Install-WindowsFeature -Name Web-Server -IncludeManagementTools

# Verify the service
Get-Service -Name W3SVC

# Drop a custom page so you can prove it's YOUR server
Set-Content -Path "C:\inetpub\wwwroot\index.html" -Value @"
<!DOCTYPE html>
<html><head><title>MSSA Lab</title></head>
<body>
  <h1>Hello from $(hostname)</h1>
  <p>Built during sca-azure-vnet-vm at $(Get-Date)</p>
</body></html>
"@
```

**Now from your local machine, add port 80 to the NSG and try to hit it:**
```powershell
# Add an NSG rule for HTTP from your IP
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $rg -Name "nsg-app"
$nsg | Add-AzNetworkSecurityRuleConfig `
  -Name "AllowHTTPFromMyIP" `
  -Access Allow -Protocol Tcp -Direction Inbound -Priority 110 `
  -SourceAddressPrefix "$myIp/32" -SourcePortRange * `
  -DestinationAddressPrefix * -DestinationPortRange 80
$nsg | Set-AzNetworkSecurityGroup

# In a browser: http://<publicIp>
# Or test from PowerShell
$publicIp = (Get-AzPublicIpAddress -ResourceGroupName $rg -Name "pip-vm-app01").IpAddress
Invoke-WebRequest -Uri "http://$publicIp" -UseBasicParsing | Select-Object -ExpandProperty Content
```

**Concepts to name out loud:**
- *This is **end-to-end traffic working*** — the request from your browser hit Azure's edge, was forwarded through the public IP, evaluated by the NSG rule (allow HTTP from your IP), reached the VM's NIC, was handled by IIS, and the response came back the same way. Five hops, two firewalls (NSG and Windows Firewall), one happy GET.
- *This is **Windows Firewall on the VM*** — `Install-WindowsFeature Web-Server` automatically opens 80 in the local firewall. If it doesn't, that's the second place to look when "I added an NSG rule but it still doesn't work."
- *This is **IIS as the simplest web server demo*** — one role install, one HTML file, real HTTP. Same shape as Apache/nginx but with PowerShell management.

**Common gotchas:**
- NSG rule says allow but browser still times out → check the Windows Firewall inside the VM. `Get-NetFirewallRule -DisplayGroup 'World Wide Web Services (HTTP)'` should show enabled.
- Hit the public IP from inside the VM → loops back to localhost, may look like it works when external doesn't. Always test from your real machine.

**After-action prompt:** *"A request from your browser to the VM's IP passes through several security layers. Name each one in order and what would happen if any of them denied the traffic."*

### Phase 5 — Deallocate (do not skip this) (~5 min)

**Goal:** The VM is deallocated. The learner sees the difference between "stopped" and "deallocated" in the portal, and has a habit of doing this at the end of every Azure session.

**Commands the learner runs:**
```powershell
# Inside the VM, you could shut it down...
# Stop-Computer -Force
# ...but a Windows shutdown alone leaves the VM in "Stopped" state — STILL BILLED.

# From your local machine, properly deallocate:
Stop-AzVM -ResourceGroupName $rg -Name "vm-app01" -Force

# Verify status shows "VM deallocated"
Get-AzVM -ResourceGroupName $rg -Name "vm-app01" -Status | Select-Object -ExpandProperty Statuses
```

**To start back up next session:**
```powershell
Start-AzVM -ResourceGroupName $rg -Name "vm-app01"
# Wait 1-2 min, then RDP again
```

**To delete the WHOLE LAB at the end of the track (when you're done):**
```powershell
Remove-AzResourceGroup -Name $rg -Force
```

**Concepts to name out loud:**
- *This is **"stopped" vs "deallocated"*** — stopping the VM from inside Windows (Start menu → Shut down) leaves the VM in "Stopped" state in Azure. The compute is still reserved for you and **you are still billed for it**. Deallocating releases the compute back to Azure. Storage (the disk) still costs pennies/month either way, but the bulk of VM cost is the compute. Habit: end every session with `Stop-AzVM -Force`.
- *This is **why deallocation may change the public IP*** — dynamic IPs are released on deallocation. The next time you start the VM, you may get a different IP. If that matters for testing, use a static IP (paid) or update your NSG rule each session.
- *This is **`Remove-AzResourceGroup` as the nuclear cleanup*** — deletes the resource group and everything in it. Cleanest possible teardown when you're truly done.

**Common gotchas:**
- Forgot to deallocate, got billed $50 for the month → it happens. Set a budget alert (Cost Management) for $10 to catch this early.
- Static public IP that you forgot about → it costs even when nothing's attached. `Get-AzPublicIpAddress | Where-Object IpConfiguration -eq $null` finds orphans.

**After-action prompt:** *"You deallocated the VM. What's still costing money in this resource group, and what would you do to bring monthly cost to near-zero between sessions?"*

## When to break the method

- Learner already has Azure experience → skim phases 1-2 (they know VNets), focus on the NSG specifics (phase 2) and IIS plumbing (phase 4), spend most time on cost discipline (phase 5).
- Learner has zero Azure budget → use the Microsoft Learn sandbox for the relevant module. Same UI, same commands, no billing risk.
- Learner is going to keep this VM around for project #6 (hybrid identity) → start it back up at the beginning of #6 rather than deleting; just deallocate between sessions.

## Definition of done

Observable, the learner can:

- [ ] Show the resource group with `Get-AzResource -ResourceGroupName $rg` listing VNet, subnet, NSG, NIC, public IP, VM, disk.
- [ ] Hit `http://<publicIp>` from their browser and see the custom HTML page that includes the VM's hostname.
- [ ] Explain what NSG rule allows the request, in priority order.
- [ ] Run `Stop-AzVM -Force` and show the VM in "deallocated" state.
- [ ] Explain in one sentence each: VNet, subnet, NSG, public IP, deallocation.

## Next project

→ [`sca-entra-hybrid-identity`](../sca-entra-hybrid-identity/SKILL.md) — bridge the on-prem AD from project #3 to Entra ID, so users created in `mssa.lab` can sign in to Azure resources.
