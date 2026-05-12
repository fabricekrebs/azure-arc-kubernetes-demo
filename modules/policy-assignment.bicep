// modules/policy-assignment.bicep
// Assigns the custom "no latest image tag" policy to the resource group.

@description('Resource ID of the custom policy definition to assign.')
param policyDefinitionId string

@description('Effect for the policy: Audit, Deny, or Disabled.')
@allowed([
  'Audit'
  'Deny'
  'Disabled'
])
param policyEffect string = 'Audit'

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2024-05-01' = {
  name: 'k8s-no-latest-image-tag'
  properties: {
    displayName: '[Custom] Kubernetes – Containers must not use the latest image tag (AKS + Arc)'
    policyDefinitionId: policyDefinitionId
    parameters: {
      effect: {
        value: policyEffect
      }
    }
  }
}
