// modules/network.bicep
// Deploys NSG, VNet, Subnet, Public IP, and NIC for the Arc demo VM.

param location string
param vmName string
param vnetAddressPrefix string
param subnetAddressPrefix string

var nsgName = '${vmName}-nsg'
var vnetName = '${vmName}-vnet'
var subnetName = '${vmName}-subnet'
var publicIpName = '${vmName}-pip'
var nicName = '${vmName}-nic'

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

output nicId string = nic.id
output publicIpAddress string = publicIp.properties.ipAddress
