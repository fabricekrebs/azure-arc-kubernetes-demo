// modules/vm-setup.bicep
// Deploys the Custom Script Extension on the VM to bootstrap K3s,
// connect to Azure Arc, and install extensions.
// Must be deployed AFTER the VM's managed identity has the Contributor role.

param location string
param vmName string
param setupScript string

// Parameters injected as environment variables into the bootstrap script
param resourceGroupName string
param clusterName string
param acrName string
param keyVaultName string
param connectedRegistryServiceClusterIp string
param arcRbacAssigneeId string
param azureMonitorWorkspaceId string
param logAnalyticsWorkspaceId string

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' existing = {
  name: vmName
}

var envBlock = join([
  'export RESOURCE_GROUP="${resourceGroupName}"'
  'export CLUSTER_NAME="${clusterName}"'
  'export LOCATION="${location}"'
  'export ACR_NAME="${acrName}"'
  'export KEY_VAULT_NAME="${keyVaultName}"'
  'export CONNECTED_REGISTRY_SERVICE_CLUSTER_IP="${connectedRegistryServiceClusterIp}"'
  'export ARC_RBAC_ASSIGNEE_ID="${arcRbacAssigneeId}"'
  'export AZURE_MONITOR_WORKSPACE_ID="${azureMonitorWorkspaceId}"'
  'export LOG_ANALYTICS_WORKSPACE_ID="${logAnalyticsWorkspaceId}"'
], '\n')

var fullScript = '#!/bin/bash\n${envBlock}\n${setupScript}'

resource customScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm
  name: 'setup-arc'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      script: base64(fullScript)
    }
  }
}
