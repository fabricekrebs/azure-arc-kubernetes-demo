// main.bicepparam
// Central parameter file — all values are read from environment variables.
// Configure everything in .env (copy from .env.example), then run: source .env

using 'main.bicep'

// ─── General ────────────────────────────────────────────────────────────────
param location = readEnvironmentVariable('LOCATION', 'westeurope')
param resourceGroupName = readEnvironmentVariable('RESOURCE_GROUP_NAME', 'rg-arc-k8s-demo')

// ─── VM ─────────────────────────────────────────────────────────────────────
param vmName = readEnvironmentVariable('VM_NAME', 'vm-arc-k8s')
param vmSize = readEnvironmentVariable('VM_SIZE', 'Standard_D4s_v5')
param adminUsername = readEnvironmentVariable('ADMIN_USERNAME', 'arcadmin')
param adminPassword = readEnvironmentVariable('ADMIN_PASSWORD', '')

// ─── Networking ─────────────────────────────────────────────────────────────
param vnetAddressPrefix = readEnvironmentVariable('VNET_ADDRESS_PREFIX', '10.0.0.0/16')
param subnetAddressPrefix = readEnvironmentVariable('SUBNET_ADDRESS_PREFIX', '10.0.1.0/24')

// ─── Arc / Kubernetes ───────────────────────────────────────────────────────
param clusterName = readEnvironmentVariable('CLUSTER_NAME', 'arc-k8s-demo')
param connectedRegistryServiceClusterIp = readEnvironmentVariable('CONNECTED_REGISTRY_SERVICE_CLUSTER_IP', '10.43.0.100')

// ─── Supporting services (names must be globally unique) ────────────────────
param acrName = readEnvironmentVariable('ACR_NAME', 'arck8sdemoacr')
param keyVaultName = readEnvironmentVariable('KEY_VAULT_NAME', 'arck8sdemokv')

// ─── Monitoring ─────────────────────────────────────────────────────────────
param azureMonitorWorkspaceName = readEnvironmentVariable('AZURE_MONITOR_WORKSPACE_NAME', 'amw-arc-k8s-demo')
param logAnalyticsWorkspaceName = readEnvironmentVariable('LOG_ANALYTICS_WORKSPACE_NAME', 'law-arc-k8s-demo')
