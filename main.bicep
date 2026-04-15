// main.bicep
// Subscription-scope deployment for Azure Arc K8s demo.
// Deploys: Resource Group, VNet, VM (Ubuntu 24.04 + K3s), ACR Premium,
// Key Vault, and bootstraps Arc + extensions via Custom Script.
//
// Usage:
//   az deployment sub create \
//     --location westeurope \
//     --template-file main.bicep \
//     --parameters main.bicepparam

targetScope = 'subscription'

// ─── General ────────────────────────────────────────────────────────────────
@description('Azure region for all resources.')
param location string

@description('Name of the resource group to create.')
param resourceGroupName string

// ─── VM ─────────────────────────────────────────────────────────────────────
@description('Name of the virtual machine.')
param vmName string

@description('VM size. Must have at least 4 vCPU / 16 GB for K3s + Arc extensions.')
param vmSize string

@description('Admin username for the VM.')
param adminUsername string

@secure()
@description('Admin password for the VM.')
param adminPassword string

// ─── Networking ─────────────────────────────────────────────────────────────
@description('Address prefix for the virtual network.')
param vnetAddressPrefix string

@description('Address prefix for the subnet.')
param subnetAddressPrefix string

// ─── Arc / Kubernetes ───────────────────────────────────────────────────────
@description('Name of the Azure Arc connected cluster resource.')
param clusterName string

@description('K3s service CIDR IP for the Connected Registry extension (must be in 10.43.0.0/16 range).')
param connectedRegistryServiceClusterIp string

// ─── RBAC ───────────────────────────────────────────────────────────────────
@description('Entra Object ID of the user/group to assign Azure Arc Kubernetes Cluster Admin on the Arc cluster.')
param arcRbacAssigneeId string

// ─── Supporting services ────────────────────────────────────────────────────
@description('Globally unique name for the Azure Container Registry (Premium SKU).')
param acrName string

@description('Globally unique name for the Azure Key Vault.')
param keyVaultName string

// ─── Monitoring ─────────────────────────────────────────────────────────────
@description('Name for the Azure Monitor workspace (Prometheus metrics).')
param azureMonitorWorkspaceName string

@description('Name for the Log Analytics workspace (Container Insights logs).')
param logAnalyticsWorkspaceName string

// ─── Load the bootstrap script ──────────────────────────────────────────────
var setupScript = loadTextContent('scripts/setup-arc.sh')

// ═══════════════════════════════════════════════════════════════════════════
// Resource Group
// ═══════════════════════════════════════════════════════════════════════════
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

// ═══════════════════════════════════════════════════════════════════════════
// Modules — infrastructure (no dependencies on VM identity)
// ═══════════════════════════════════════════════════════════════════════════
module network 'modules/network.bicep' = {
  name: 'network'
  scope: rg
  params: {
    location: location
    vmName: vmName
    vnetAddressPrefix: vnetAddressPrefix
    subnetAddressPrefix: subnetAddressPrefix
  }
}

module acr 'modules/acr.bicep' = {
  name: 'acr'
  scope: rg
  params: {
    location: location
    acrName: acrName
  }
}

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    azureMonitorWorkspaceName: azureMonitorWorkspaceName
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// VM — creates the VM and outputs its managed identity principalId
// ═══════════════════════════════════════════════════════════════════════════
module vm 'modules/vm.bicep' = {
  name: 'vm'
  scope: rg
  params: {
    location: location
    vmName: vmName
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    nicId: network.outputs.nicId
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Role assignments — VM MI needs Contributor on the RG for Arc operations
// ═══════════════════════════════════════════════════════════════════════════
module roleAssignments 'modules/role-assignments.bicep' = {
  name: 'role-assignments'
  scope: rg
  params: {
    vmPrincipalId: vm.outputs.vmPrincipalId
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Key Vault — deployed after VM so we can assign KV Secrets User to VM MI
// ═══════════════════════════════════════════════════════════════════════════
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    location: location
    keyVaultName: keyVaultName
    tenantId: subscription().tenantId
    vmPrincipalId: vm.outputs.vmPrincipalId
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// VM Setup — Custom Script Extension (runs AFTER role assignment is ready)
// ═══════════════════════════════════════════════════════════════════════════
module vmSetup 'modules/vm-setup.bicep' = {
  name: 'vm-setup'
  scope: rg
  dependsOn: [
    roleAssignments
    keyVault
    acr
  ]
  params: {
    location: location
    vmName: vm.outputs.vmName
    setupScript: setupScript
    resourceGroupName: resourceGroupName
    clusterName: clusterName
    acrName: acrName
    keyVaultName: keyVaultName
    connectedRegistryServiceClusterIp: connectedRegistryServiceClusterIp
    arcRbacAssigneeId: arcRbacAssigneeId
    azureMonitorWorkspaceId: monitoring.outputs.monitorWorkspaceId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Workbook — Arc K8s dashboard (deployed early, queries populate after Arc connects)
// ═══════════════════════════════════════════════════════════════════════════
module workbook 'modules/workbook.bicep' = {
  name: 'workbook'
  scope: rg
  params: {
    location: location
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Outputs
// ═══════════════════════════════════════════════════════════════════════════
output resourceGroupName string = rg.name
output vmPublicIp string = network.outputs.publicIpAddress
output acrLoginServer string = acr.outputs.acrLoginServer
output keyVaultUri string = keyVault.outputs.keyVaultUri
output workbookUrl string = workbook.outputs.workbookUrl
