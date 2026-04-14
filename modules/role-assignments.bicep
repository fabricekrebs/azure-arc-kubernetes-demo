// modules/role-assignments.bicep
// Grants the VM's system-assigned managed identity the Contributor role
// on the resource group so it can create Arc resources, extensions,
// custom locations, and connected environments.
// Also grants Role Based Access Control Administrator so the VM can
// assign Azure Arc Kubernetes Cluster Admin to users.

param vmPrincipalId string

// Contributor built-in role
var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

// Role Based Access Control Administrator built-in role
var rbacAdminRoleId = 'f58310d9-a9f6-439a-9e8d-f62e7b41a168'

resource contributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, vmPrincipalId, contributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalId: vmPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource rbacAdminRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, vmPrincipalId, rbacAdminRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', rbacAdminRoleId)
    principalId: vmPrincipalId
    principalType: 'ServicePrincipal'
  }
}
