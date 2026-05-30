# SCA — Server & Cloud Administration tracker

Build progression for the **SCA** MSSA track. Each row is one project skill — one buildable thing the learner ships in 1-3 mentor sessions. The mentor picks a project based on what the learner wants to learn next; the ride-along method drives *how* the build happens.

**Target certification:** AZ-104 (Microsoft Azure Administrator).
**Stack:** Windows Server 2022, Active Directory Domain Services, Group Policy, PowerShell 7, Azure VMs, Azure VNets, Entra ID, Azure Files, Recovery Services Vault, Azure Monitor / Log Analytics, Bicep.

## Projects

The track builds **one coherent hybrid lab**: a local-server side (Hyper-V VM running Windows Server + AD) and an Azure side (VNet, VMs, storage, monitoring), eventually joined by hybrid identity. Each project adds one capability to that lab.

| # | Skill | Builds | Core concepts | Status |
|---|---|---|---|---|
| 1 | [`sca-powershell-foundations`](./sca-powershell-foundations/SKILL.md) | The PowerShell muscle memory used in every later project | Cmdlets, pipeline, objects vs text, help system, modules, profile | **ready** |
| 2 | [`sca-local-system-admin`](./sca-local-system-admin/SKILL.md) | Manage the local Windows box with PowerShell — services, processes, users, scheduled tasks, event logs | Service control, process inspection, local accounts, scheduled tasks, event log filtering | **ready** |
| 3 | [`sca-server-vm-setup`](./sca-server-vm-setup/SKILL.md) | Spin up a Windows Server 2022 VM (Hyper-V or Azure), install AD DS, promote to domain controller | Hyper-V / Azure VM, AD DS role, forest/domain, DNS, OU design | **ready** |
| 4 | [`sca-ad-and-gpo`](./sca-ad-and-gpo/SKILL.md) | Populate AD with users, groups, OUs and apply Group Policy for password rules + drive mapping | Users, groups, OUs, GPO inheritance, security filtering, `gpupdate` | **ready** |
| 5 | [`sca-azure-vnet-vm`](./sca-azure-vnet-vm/SKILL.md) | Build an Azure VNet + subnet + NSG, deploy a Windows VM, RDP in, install IIS | VNet, subnet, NSG rules, public IP, JIT access, VM SKUs | **ready** |
| 6 | [`sca-entra-hybrid-identity`](./sca-entra-hybrid-identity/SKILL.md) | Install Entra Connect, sync on-prem AD users to Entra ID, sign in to Azure as a synced user | Entra Connect, password hash sync, UPN suffix, sync rules, sync errors | **ready** |
| 7 | [`sca-storage-and-backup`](./sca-storage-and-backup/SKILL.md) | Create an Azure Files share, mount from the VM, back up the VM with Recovery Services Vault, test restore | Storage account tiers, Azure Files, SMB auth, RSV, backup policy, restore | **ready** |
| 8 | [`sca-monitoring`](./sca-monitoring/SKILL.md) | Stand up a Log Analytics workspace, install the agent on the VM, write a KQL query, build an alert rule | Log Analytics, AMA agent, KQL basics (`where`, `summarize`), metric vs log alerts, action groups | **ready** |
| 9 | [`sca-arm-bicep-iac`](./sca-arm-bicep-iac/SKILL.md) | Convert the VNet+VM from project #5 into a Bicep template, deploy via `az deployment group create`, parameterize | ARM vs Bicep, resource graph, parameters/variables, modules, what-if deployments | **ready** |

## How the mentor uses this

1. Learner says what they want to learn (e.g. *"I want to understand Group Policy"*).
2. Mentor scans the table — matches the goal to project #4 (`sca-ad-and-gpo`).
3. Mentor checks prerequisites — #4 needs a working domain controller from #3, which needs PowerShell comfort from #1/#2. Mentor offers the right starting point.
4. Mentor loads the project SKILL.md and runs a [ride-along](../../methods/ride-along/SKILL.md) session against the project's phases.

## Lab requirements

This track is more infrastructure-heavy than CAD. Real prerequisites:

| Requirement | Used in projects | Workaround |
|---|---|---|
| Windows 10/11 Pro or Enterprise (for Hyper-V) | 3, 4 | Skip Hyper-V, use an Azure VM for the DC (more $) |
| 16 GB RAM minimum | 3, 4, 6 | An Azure-only path works with less local RAM |
| Azure subscription with $50-$100 budget | 5, 6, 7, 8, 9 | Microsoft Learn sandboxes cover some of this for free |
| Local admin on the learner's machine | All | None — bootcamp expects this |

The mentor names cost honestly at the start of any Azure-touching project. Lab VMs left running quietly burn money; teach the "deallocate when done" habit in project #5.

## Status legend

| Status | Meaning |
|---|---|
| **ready** | SKILL.md drafted and reviewed against the ride-along method + completeness bar; safe to run in a real session |
| **drafted** | SKILL.md exists, ready to use in a session, but has not been through a Kimberly-led review yet |
| planned | Listed here, not yet authored |
| revising | Authored, but needs rework before next use |

## Out of scope for this tracker

- Curriculum lecture notes — Microsoft Learn and the MSSA program own those.
- Per-session lesson plans — those are emergent, driven by the ride-along method.
- AZ-104 cram material — projects align to AZ-104 objectives, but this is not a study guide.
- Linux administration — the SCA track is Windows-Server-and-Azure focused.
