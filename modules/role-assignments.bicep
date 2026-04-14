// modules/role-assignments.bicep
// Grants the VM's system-assigned managed identity the Contributor role
// on the resource group so it can create Arc resources, extensions,
// custom locations, and connected environments.

param vmPrincipalId string

// Contributor built-in role
var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

resource contributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, vmPrincipalId, contributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalId: vmPrincipalId
    principalType: 'ServicePrincipal'
  }
}
