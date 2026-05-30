---
name: sca-arm-bicep-iac
description: |
  SCA track project #9 (capstone). Learner converts the VNet + NSG + Windows VM from project #5
  into a Bicep template, parameterizes it, runs a `what-if` deployment, deploys it for real
  via the Azure CLI, then tears it down and redeploys to prove the template is repeatable.
  Auto-load when the learner is in `server-cloud-admin/sca-arm-bicep-iac` or asks to learn
  Bicep, ARM templates, Infrastructure as Code, `az deployment group create`, parameterized
  templates, modules, or `what-if`.
---

# Project: `sca-arm-bicep-iac`

> **Track:** Server & Cloud Administration · **Project:** 9 of 9 · **Time:** ~90 minutes
>
> The capstone. Everything the learner clicked through in project #5 (VNet, subnet, NSG, VM) is rewritten as Bicep code, parameterized, deployed via CLI, torn down, and redeployed. The lesson is "infrastructure that can be re-created in 10 minutes is infrastructure you can trust."

## Project goal

When this project is done, the learner can:

- Read and write Bicep — resources, parameters, variables, modules, dependencies, outputs.
- Use `az bicep build` to compile Bicep to ARM JSON, and `az deployment group what-if` to see what a deployment will change *before* it changes it.
- Deploy a stack with `az deployment group create` and inspect the deployment in the portal.
- Tear down (`az group delete`) and redeploy from the same Bicep — and explain why this is the litmus test of IaC.
- Refactor a single Bicep file into a **module** + a **main** that consumes it.

## Scope guardrail

This is **one Bicep template + one optional module + one deployment**. We are not setting up an Azure DevOps Pipeline, not adopting a Terraform comparison, not using deployment stacks, not implementing `existing` resources, not building a multi-environment promotion model. The point is muscle memory in the syntax and the deploy loop.

If the learner asks "why Bicep and not Terraform?" — answer honestly: *both work; Bicep is first-party Microsoft, no state file to manage, free from drift between Bicep and ARM. Terraform is cross-cloud. Most Microsoft-only shops pick Bicep*.

## Prerequisites

| Prereq | Verify with |
|---|---|
| Azure CLI installed | `az --version` |
| Bicep CLI installed (Azure CLI auto-installs on first use) | `az bicep version` |
| VS Code with the **Bicep extension** | Extensions sidebar → search "Bicep" → Microsoft publisher |
| Completed [`sca-azure-vnet-vm`](../sca-azure-vnet-vm/SKILL.md) | The original click-deployed VNet/VM is the reference |
| Personal directory for the lab files | `mkdir -p ~\source\mssa-iac` (PowerShell) |

## Phases

### Phase 1 — Write the first single-file template (~20 min)

**Goal:** A `main.bicep` file deploys a Resource Group's contents — VNet, subnet, NSG with one RDP rule, a Windows VM, a public IP, a NIC.

**Create `main.bicep` in `~\source\mssa-iac`:**
```bicep
// =============================================================
// SCA #9 capstone — single-file VNet + VM
// =============================================================

param location string = resourceGroup().location
param vmName string = 'vm-iac01'
param vmSize string = 'Standard_B2s'
param adminUsername string = 'labadmin'
@secure()
param adminPassword string
@description('Your public IP for RDP allowlist, e.g. 203.0.113.45/32')
param allowedRdpSource string

var vnetName = 'vnet-${vmName}'
var subnetName = 'snet-app'
var nsgName = 'nsg-${vmName}'
var pipName = 'pip-${vmName}'
var nicName = 'nic-${vmName}'

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowRDPFromMyIP'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: allowedRdpSource
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: { addressPrefixes: [ '10.20.0.0/16' ] }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.20.1.0/24'
          networkSecurityGroup: { id: nsg.id }
        }
      }
    ]
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: pipName
  location: location
  sku: { name: 'Basic' }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: { id: '${vnet.id}/subnets/${subnetName}' }
          publicIPAddress: { id: pip.id }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'Standard_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [ { id: nic.id } ]
    }
  }
}

output publicIp string = pip.properties.ipAddress
output vmResourceId string = vm.id
```

**Compile and review:**
```powershell
cd ~\source\mssa-iac
az bicep build --file main.bicep
# Produces main.json — the underlying ARM template. Open it briefly to see what Bicep saves you from writing.
```

**Concepts to name out loud:**
- *This is **Bicep as a thin DSL over ARM*** — every resource type, property, and API version matches the underlying ARM resource provider. Bicep compiles 1:1 to ARM JSON. There's no runtime translation — it's a build-time syntax improvement.
- *This is **parameters (`param`) vs variables (`var`)*** — parameters come from outside (CLI args, parameter files). Variables are computed in-template. Use parameters for "things that change per environment"; variables for "things derived from parameters."
- *This is **`@secure()` as the password marker*** — tells Bicep this value is sensitive. It won't be logged, displayed in portal, or stored in deployment history. Same effect as ARM's `secureString` type.
- *This is **`resourceGroup().location` as the implicit default*** — uses the location of the RG you're deploying into. Avoids hard-coding `eastus` and creates portability.
- *This is **outputs as the return values of a deployment*** — `output publicIp string = ...` lets CI/CD pipelines or scripts read the IP for next steps. Use sparingly; outputs become part of deployment history.

**Common gotchas:**
- Resource name conflict → `vmName` defaults to `vm-iac01`. If you already have a `vm-app01` and forget to change the param, you'll create a *new* VM, not collide. Read the `what-if` (next phase) carefully.
- Trying to reference a subnet resource that doesn't have its own `resource` block → with inline subnets (as above), you reference by string interpolation: `'${vnet.id}/subnets/${subnetName}'`. The Bicep linter will warn you to split out subnets as separate resources for better dependency tracking; the inline form works fine for a one-file lab.
- VM `osDisk.name` is auto-generated. If you want a specific name, add `name: '${vmName}-osdisk'`.

**After-action prompt:** *"You wrote one Bicep file that creates 5 resources. Walk me through which ones depend on which others — and how Bicep knows about those dependencies."*

### Phase 2 — `what-if` before deploy (~15 min)

**Goal:** The learner uses `what-if` to preview the deployment, sees the resources that will be created, then deploys.

**Set up a separate resource group for IaC (don't mix with project #5):**
```powershell
$rg = "rg-mssa-iac"
$location = "eastus"
az group create --name $rg --location $location
```

**Run `what-if` to preview:**
```powershell
$myIp = (Invoke-RestMethod -Uri https://api.ipify.org)

# Prompt for password securely
$pw = Read-Host "VM password (12+ chars)" -AsSecureString
$pwPlain = (New-Object PSCredential('x', $pw)).GetNetworkCredential().Password

az deployment group what-if `
  --resource-group $rg `
  --template-file main.bicep `
  --parameters allowedRdpSource="$myIp/32" adminPassword="$pwPlain"
```

You should see output like:
```
Resource changes: 5 to create.
  + Microsoft.Compute/virtualMachines/vm-iac01
  + Microsoft.Network/networkInterfaces/nic-vm-iac01
  + Microsoft.Network/networkSecurityGroups/nsg-vm-iac01
  + Microsoft.Network/publicIPAddresses/pip-vm-iac01
  + Microsoft.Network/virtualNetworks/vnet-vm-iac01
```

**If that looks right, deploy for real:**
```powershell
az deployment group create `
  --resource-group $rg `
  --template-file main.bicep `
  --parameters allowedRdpSource="$myIp/32" adminPassword="$pwPlain" `
  --name "deploy-$(Get-Date -Format yyyy-MM-dd-HHmm)"
```

Watch for the green checkmark per resource. Total time ~5-7 min.

**Read the outputs:**
```powershell
az deployment group show `
  --resource-group $rg `
  --name (az deployment group list -g $rg --query "[0].name" -o tsv) `
  --query "properties.outputs"
```

**RDP using the output IP** to prove it actually works.

**Concepts to name out loud:**
- *This is **`what-if` as the deployment dry-run*** — shows you exactly what changes. Always run before any destructive deployment. The blue (`~`), yellow (`!`), green (`+`), red (`-`) markers tell you create/modify/no-change/delete intent.
- *This is **incremental vs complete deployment mode*** — default is `incremental`: existing resources not in the template are left alone. `--mode complete` deletes any resource in the RG that isn't in the template. Almost never use complete in lab. Even in production, use rarely and only with `what-if` first.
- *This is **deployment history*** — every deployment is recorded in the RG's deployment list (visible in portal). Use unique names (`deploy-2026-05-29-1430`) so you can find them.

**Common gotchas:**
- `what-if` says everything will change even on a re-deploy → almost always means you accidentally changed a parameter (different password). `what-if` evaluates the *exact* template; if the password changed, the VM has to be redeployed.
- Password parameter logged to terminal history → that's why we use `Read-Host -AsSecureString`. Avoid `--parameters adminPassword="literal-password-here"` in scripts.
- Deployment fails halfway → `az deployment group show ... --query "properties.error"` for the cause. Some resources may have been created and need manual cleanup.

**After-action prompt:** *"You ran `what-if` and then deployed. If the same template said `~ Microsoft.Compute/virtualMachines/vm-iac01` (a modify) instead of `+ ... (create)`, what would you check before saying yes?"*

### Phase 3 — Tear down and redeploy (~10 min)

**Goal:** Prove the template is repeatable. Delete the whole resource group, then redeploy from the same Bicep file and verify everything comes back identical.

**Tear down:**
```powershell
az group delete --name $rg --yes --no-wait
# --no-wait returns immediately; deletion runs in background (5-10 min)

# Watch for completion
do {
  Start-Sleep -Seconds 30
  $exists = az group exists --name $rg
  Write-Host "RG exists: $exists at $(Get-Date)"
} while ($exists -eq 'true')
```

**Redeploy from the same template:**
```powershell
az group create --name $rg --location $location

az deployment group create `
  --resource-group $rg `
  --template-file main.bicep `
  --parameters allowedRdpSource="$myIp/32" adminPassword="$pwPlain" `
  --name "redeploy-$(Get-Date -Format yyyy-MM-dd-HHmm)"
```

Check: the same VM, NIC, NSG, public IP, VNet all came back. The public IP value may differ (Dynamic), but everything else is identical.

**Concepts to name out loud:**
- *This is **the litmus test of IaC*** — your infrastructure description is the infrastructure. If you can tear it down and rebuild it in minutes with no manual steps, you have IaC. If you can't, you have documentation that pretends to be IaC.
- *This is **why disaster recovery and dev/test environments depend on this property*** — "redeploy in another region" is the same operation as "deploy here twice."

**Common gotchas:**
- Forgot to recreate the RG before redeploy → `az group create` first.
- Resource group has a name collision (someone else used it) → unique-ify the name with your initials.

**After-action prompt:** *"You proved the template is repeatable. Describe a scenario where having this property would save you from a serious outage."*

### Phase 4 — Refactor into a module (~25 min)

**Goal:** Pull the networking resources (VNet, NSG, PIP, NIC) into a separate Bicep **module**, and have `main.bicep` consume that module.

**Create `modules/networking.bicep`:**
```bicep
@description('VM-suffix used in resource names')
param namePrefix string
param location string
@description('Source IP allowed for RDP')
param allowedRdpSource string

var vnetName = 'vnet-${namePrefix}'
var subnetName = 'snet-app'
var nsgName = 'nsg-${namePrefix}'
var pipName = 'pip-${namePrefix}'
var nicName = 'nic-${namePrefix}'

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowRDPFromMyIP'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: allowedRdpSource
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: { addressPrefixes: [ '10.20.0.0/16' ] }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.20.1.0/24'
          networkSecurityGroup: { id: nsg.id }
        }
      }
    ]
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: pipName
  location: location
  sku: { name: 'Basic' }
  properties: { publicIPAllocationMethod: 'Dynamic' }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: { id: '${vnet.id}/subnets/${subnetName}' }
          publicIPAddress: { id: pip.id }
        }
      }
    ]
  }
}

output nicId string = nic.id
output publicIpId string = pip.id
output vnetId string = vnet.id
```

**Rewrite `main.bicep` to consume the module:**
```bicep
param location string = resourceGroup().location
param vmName string = 'vm-iac01'
param vmSize string = 'Standard_B2s'
param adminUsername string = 'labadmin'
@secure()
param adminPassword string
param allowedRdpSource string

module networking 'modules/networking.bicep' = {
  name: 'networking-${vmName}'
  params: {
    namePrefix: vmName
    location: location
    allowedRdpSource: allowedRdpSource
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'Standard_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [ { id: networking.outputs.nicId } ]
    }
  }
}

output publicIpId string = networking.outputs.publicIpId
output vmResourceId string = vm.id
```

**Redeploy** (after a teardown again, or `what-if` first):
```powershell
az deployment group what-if `
  --resource-group $rg `
  --template-file main.bicep `
  --parameters allowedRdpSource="$myIp/32" adminPassword="$pwPlain"
```

The what-if should show no changes if the resources already match the refactored template — the **same resources** are being produced just from a different code organization.

**Concepts to name out loud:**
- *This is **a module as a reusable Bicep package*** — define once, call many times. Equivalent to a function in code. Modules can live in the same repo, in another repo, or in an **Azure Container Registry** as a registry-published module.
- *This is **module outputs as the interface*** — main uses `networking.outputs.nicId` instead of knowing how the module's NIC is named. The module can change internals without breaking main, as long as the output names stay stable.
- *This is **why network-then-compute as separate modules is a real pattern*** — networks and compute have different lifecycles in production. Networks change rarely; VMs come and go. Separate templates / pipelines for each.

**Common gotchas:**
- Module path wrong (forgot `modules/`) → `az bicep build` fails. Bicep relative paths are from the file doing the import.
- Output name typo (`nicID` vs `nicId`) → compile error. Bicep is case-sensitive.

**After-action prompt:** *"You moved 4 resources into a module. List two real-world situations where this refactor would pay off — and one where it would be over-engineering."*

### Phase 5 — Production-grade habits to take to AZ-104 prep (~5 min)

**Verbal walkthrough (no commands):**

1. **A parameter file (`.bicepparam`) per environment.** `main.dev.bicepparam`, `main.prod.bicepparam` — same template, different values, different lifecycle.
2. **Source control (git).** Bicep + parameters lives in a repo. Every deployment maps to a commit SHA. Auditable.
3. **`what-if` in CI.** A PR pipeline runs `az deployment group what-if`; the diff is posted as a PR comment. No deploys without review.
4. **`az deployment group create --confirm-with-what-if`** for higher-stakes deployments — runs what-if, requires explicit confirmation before deploying.
5. **Deployment Stacks** for newer scenarios — protects resources from being deleted out from under the stack.

**After-action prompt:** *"You now have one Bicep template, one module, and a clean redeploy. Walk me through how this practice changes your day-to-day work as an Azure Admin compared to clicking through the portal."*

## When to break the method

- Learner already knows Terraform → spend phase 1 on the syntactic differences (no state file, no `terraform init`, no providers block), then phases 2-4 land instantly.
- Learner is short on time → skip phase 4 (module refactor). Phases 1-3 cover the AZ-104 IaC objective at exam depth.
- Learner has a corporate proxy that blocks Bicep registry downloads → run `az bicep install` once with explicit version, or use a portable Bicep binary download.

## Definition of done

Observable, the learner can:

- [ ] Show a single-file `main.bicep` that creates VNet + subnet + NSG + PIP + NIC + VM.
- [ ] Run `az deployment group what-if` and read the output.
- [ ] Deploy successfully, RDP into the resulting VM.
- [ ] Tear down with `az group delete`, redeploy from the same file, verify identity.
- [ ] Show the same template refactored into `main.bicep` + `modules/networking.bicep`.
- [ ] Explain in one sentence each: parameter vs variable, what-if, incremental vs complete mode, module output.

## Track complete

🎯 **You finished the SCA track.** The lab you built across these 9 projects is everything an AZ-104 candidate needs to *say they've done it*: PowerShell admin, Windows Server with AD, GPO, Azure VNets and VMs, hybrid identity, storage and backup, monitoring, and IaC. The certification is now repetition and exam mechanics — the muscle memory is already in your hands.

**What to do next:**
- Run a full lab teardown with `Remove-AzResourceGroup -Name rg-mssa-azurevm -Force` and `Remove-AzResourceGroup -Name rg-mssa-iac -Force` to stop billing.
- Keep your on-prem Hyper-V lab (DC01 + workstation) for project review.
- Sit AZ-104 within ~3 months while it's fresh.
