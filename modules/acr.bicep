// modules/acr.bicep
// Deploys an Azure Container Registry (Premium SKU) with data endpoints
// enabled, required for the Connected Registry extension.

param location string
param acrName string

resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: false
    dataEndpointEnabled: true
  }
}

output acrLoginServer string = acr.properties.loginServer
output acrName string = acr.name
