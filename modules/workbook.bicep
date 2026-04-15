// modules/workbook.bicep
// Deploys an Azure Monitor Workbook that visualizes all Arc-enabled Kubernetes
// clusters: cluster overview, extensions, connectivity, and Arc resources.

param location string

var workbookName = guid(resourceGroup().id, 'arc-k8s-workbook')
var workbookDisplayName = 'Arc K8s Dashboard'

var serializedContent = replace(loadTextContent('workbook-content.json'), '{SUBSCRIPTION_ID}', subscription().subscriptionId)

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
