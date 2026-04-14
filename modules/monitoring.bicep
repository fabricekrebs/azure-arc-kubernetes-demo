// modules/monitoring.bicep
// Deploys Azure Monitor workspace (Prometheus) + Log Analytics workspace
// (Container Insights) required for Arc "Dashboard with Grafana" feature.

param location string
param azureMonitorWorkspaceName string
param logAnalyticsWorkspaceName string

// ─── Azure Monitor Workspace (receives Prometheus metrics) ──────────────────
resource monitorWorkspace 'Microsoft.Monitor/accounts@2023-04-03' = {
  name: azureMonitorWorkspaceName
  location: location
}

// ─── Log Analytics Workspace (receives Container Insights logs) ─────────────
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// ─── Outputs ────────────────────────────────────────────────────────────────
output monitorWorkspaceId string = monitorWorkspace.id
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
