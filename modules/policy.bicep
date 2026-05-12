// modules/policy.bicep
// Deploys a custom Azure Policy definition (subscription-scoped) that ensures
// Kubernetes workloads do not use the "latest" container image tag across AKS
// and Azure Arc-enabled Kubernetes clusters.

targetScope = 'subscription'

// ═══════════════════════════════════════════════════════════════════════════
// Policy Definition
// ═══════════════════════════════════════════════════════════════════════════
resource policyDefinition 'Microsoft.Authorization/policyDefinitions@2024-05-01' = {
  name: 'custom-k8s-no-latest-image-tag'
  properties: {
    displayName: '[Custom] Kubernetes – Containers must not use the latest image tag (AKS + Arc)'
    policyType: 'Custom'
    mode: 'Microsoft.Kubernetes.Data'
    description: 'Ensures Kubernetes workloads do not use the \'latest\' container image tag, enforcing reproducibility and safer deployments across AKS and Azure Arc-enabled Kubernetes clusters.'
    metadata: {
      category: 'Kubernetes'
      version: '1.0.0'
    }
    version: '1.0.0'
    parameters: {
      effect: {
        type: 'String'
        metadata: {
          displayName: 'Effect'
        }
        allowedValues: [
          'Audit'
          'Deny'
          'Disabled'
        ]
        defaultValue: 'Audit'
      }
      source: {
        type: 'String'
        allowedValues: [
          'Original'
          'Generated'
          'All'
        ]
        defaultValue: 'Original'
      }
      warn: {
        type: 'Boolean'
        defaultValue: false
      }
      excludedNamespaces: {
        type: 'Array'
        defaultValue: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
        ]
      }
      namespaces: {
        type: 'Array'
        defaultValue: []
      }
    }
    policyRule: {
      if: {
        anyOf: [
          {
            field: 'type'
            equals: 'Microsoft.ContainerService/managedClusters'
          }
          {
            field: 'type'
            equals: 'Microsoft.Kubernetes/connectedClusters'
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          source: '[parameters(\'source\')]'
          warn: '[parameters(\'warn\')]'
          templateInfo: {
            sourceType: 'PublicURL'
            #disable-next-line no-hardcoded-env-urls
            url: 'https://store.policy.core.windows.net/kubernetes/container-no-latest-image/v2/template.yaml'
          }
          apiGroups: [
            ''
          ]
          kinds: [
            'Pod'
          ]
          namespaces: '[parameters(\'namespaces\')]'
          excludedNamespaces: '[parameters(\'excludedNamespaces\')]'
        }
      }
    }
    versions: [
      '1.0.0'
    ]
  }
}

output policyDefinitionId string = policyDefinition.id
