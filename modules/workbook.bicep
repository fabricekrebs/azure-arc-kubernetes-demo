// modules/workbook.bicep
// Deploys an Azure Monitor Workbook that visualizes Arc-enabled Kubernetes
// cluster information: cluster overview, extensions, connectivity, and resources.

param location string
param clusterName string
param resourceGroupName string

var workbookName = guid(resourceGroup().id, 'arc-k8s-workbook')
var workbookDisplayName = 'Arc K8s Dashboard - ${clusterName}'

var serializedContent = replace(replace(replace(loadTextContent('workbook-content.json'), '{CLUSTER_NAME}', clusterName), '{RESOURCE_GROUP}', resourceGroupName), '{SUBSCRIPTION_ID}', subscription().subscriptionId)

resource workbook 'Microsoft.Insights/workbooks@2023-06-01' = {
  name: workbookName
  location: location
  kind: 'shared'
  properties: {
    displayName: workbookDisplayName
    category: 'workbook'
    sourceId: 'azure monitor'
    serializedData: serializedContent
  }
}

output workbookId string = workbook.id
output workbookUrl string = 'https://portal.azure.com/#@/resource${workbook.id}/workbook'
