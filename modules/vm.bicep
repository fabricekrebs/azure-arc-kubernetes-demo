// modules/vm.bicep
// Deploys an Ubuntu 24.04 VM with system-assigned managed identity.
// The Custom Script Extension is deployed separately (vm-setup.bicep)
// after the role assignment is in place.

param location string
param vmName string
param vmSize string
param adminUsername string
@secure()
param adminPassword string
param nicId string

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}-osdisk'
        createOption: 'FromImage'
        diskSizeGB: 128
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicId
        }
      ]
    }
  }
}

output vmPrincipalId string = vm.identity.principalId
output vmName string = vm.name
