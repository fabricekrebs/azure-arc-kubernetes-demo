// modules/k8s-metrics-workbook.bicep
// Deploys an Azure Monitor Workbook that visualises Container Insights metrics
// for Arc-enabled K8s clusters: cluster, node, and pod tabs with timecharts.

param location string

var workbookName = guid(resourceGroup().id, 'arc-k8s-metrics-workbook')
var workbookDisplayName = 'Arc K8s Metrics Dashboard'

var serializedContent = loadTextContent('k8s-metrics-workbook-content.json')

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
