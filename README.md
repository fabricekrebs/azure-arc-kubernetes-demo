# Azure Arc-enabled Kubernetes Demo

Fully automated deployment of an Azure Arc-enabled K3s cluster with extensions, monitoring, and GitOps, using a single Bicep deployment command.

## What gets deployed

| Resource | Purpose |
|---|---|
| **Resource Group** | Contains all resources |
| **Ubuntu 24.04 VM** | Runs K3s, Standard_D4s_v5 (4 vCPU / 16 GB) |
| **VNet + NSG + Public IP** | Networking with SSH access |
| **Azure Container Registry** | Premium SKU (required for Connected Registry) |
| **Azure Key Vault** | With RBAC + demo secret for Secrets Provider |
| **Azure Monitor Workspace** | Receives Prometheus metrics from the cluster |
| **Log Analytics Workspace** | Receives Container Insights logs |
| **Azure Workbook** | Resource Graph dashboard for cluster & extensions |
| **Arc-connected K3s cluster** | Connected to Azure Arc |

### Arc Extensions installed

1. **Azure Key Vault Secrets Provider** (`Microsoft.AzureKeyVaultSecretsProvider`) — CSI driver for mounting Key Vault secrets into pods
2. **Azure Connected Registry** (`Microsoft.ContainerRegistry.ConnectedRegistry`) — On-premises replica of ACR for fast image pulls
3. **Azure Monitor Metrics** (`Microsoft.AzureMonitor.Containers.Metrics`) — Prometheus metrics collection
4. **Container Insights** (`Microsoft.AzureMonitor.Containers`) — Container logs collection

> Once deployed, open the Arc cluster in the Azure portal → **Monitoring** → **Dashboard with Grafana** to access the built-in Kubernetes Grafana dashboards.

### GitOps (Flux v2)

- **Repository**: `https://github.com/fabricekrebs/fluxv2-demo-app`
- **Kustomization**: `fluxv2-podinfo-demo` → `apps/fluxv2-podinfo-demo` (prune enabled)

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (v2.60+)
- An Azure subscription with **Owner** or **Contributor + User Access Administrator** permissions
- The following resource providers registered:
  ```
  Microsoft.Kubernetes
  Microsoft.KubernetesConfiguration
  Microsoft.ExtendedLocation
  Microsoft.Monitor
  Microsoft.OperationalInsights
  ```

## Quick Start

### 1. Login and register resource providers

```bash
az login
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait
az provider register --namespace Microsoft.Monitor --wait
az provider register --namespace Microsoft.OperationalInsights --wait
```

> This is a one-time operation per subscription. Subsequent runs are near-instant.

### 2. Create your `.env` file

```bash
cp .env.example .env
```

Edit `.env` and fill in the required values (`ADMIN_PASSWORD`).

### 3. Load environment and deploy

```bash
source .env
az deployment sub create \
  --name arc-k8s-demo \
  --location northeurope \
  --template-file main.bicep \
  --parameters main.bicepparam
```

The deployment takes **15–25 minutes** (most time is the bootstrap script installing K3s + Arc + extensions on the VM).

### 4. Verify

```bash
# Resource group contents
az resource list --resource-group rg-arc-k8s-demo -o table

# Arc cluster status
az connectedk8s show --name arc-k8s-demo --resource-group rg-arc-k8s-demo

# Installed extensions
az k8s-extension list \
  --cluster-type connectedClusters \
  --cluster-name arc-k8s-demo \
  --resource-group rg-arc-k8s-demo -o table

# Open the workbook dashboard
WORKBOOK_URL=$(az deployment sub show --name arc-k8s-demo --query properties.outputs.workbookUrl.value -o tsv)
echo "Open in browser: $WORKBOOK_URL"

# Check GitOps status
az k8s-configuration flux show \
  --name fluxv2-podinfo-demo \
  --cluster-type connectedClusters \
  --cluster-name arc-k8s-demo \
  --resource-group rg-arc-k8s-demo
```

### 5. SSH into the VM

```bash
VM_IP=$(az deployment sub show --name main --query properties.outputs.vmPublicIp.value -o tsv)
ssh arcadmin@$VM_IP

# On the VM:
sudo kubectl get nodes
```

### 6. Check bootstrap logs (on the VM)

```bash
sudo cat /var/log/setup-arc.log
```

## Cleanup

```bash
az group delete --name rg-arc-k8s-demo --yes --no-wait
```

## Configuration

All values are configured in [`.env`](.env.example) (copy from `.env.example`). The [`main.bicepparam`](main.bicepparam) reads them via `readEnvironmentVariable()`.

| Environment Variable | Default | Description |
|---|---|---|
| `ADMIN_PASSWORD` | *(required)* | VM admin password |
| `LOCATION` | `westeurope` | Azure region |
| `RESOURCE_GROUP_NAME` | `rg-arc-k8s-demo` | Resource group name |
| `VM_NAME` | `vm-arc-k8s` | VM name |
| `VM_SIZE` | `Standard_D4s_v5` | VM size (min 4 vCPU/16 GB recommended) |
| `ADMIN_USERNAME` | `arcadmin` | VM admin user |
| `VNET_ADDRESS_PREFIX` | `10.0.0.0/16` | VNet CIDR |
| `SUBNET_ADDRESS_PREFIX` | `10.0.1.0/24` | Subnet CIDR |
| `CLUSTER_NAME` | `arc-k8s-demo` | Arc connected cluster name |
| `CONNECTED_REGISTRY_SERVICE_CLUSTER_IP` | `10.43.0.100` | K3s service IP for Connected Registry |
| `ACR_NAME` | `arck8sdemoacr` | ACR name (globally unique, alphanumeric) |
| `KEY_VAULT_NAME` | `arck8sdemokv` | Key Vault name (globally unique) |
| `AZURE_MONITOR_WORKSPACE_NAME` | `amw-arc-k8s-demo` | Azure Monitor workspace (Prometheus) |
| `LOG_ANALYTICS_WORKSPACE_NAME` | `law-arc-k8s-demo` | Log Analytics workspace (Container Insights) |

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│  Resource Group: rg-arc-k8s-demo                                         │
│                                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────┐  ┌───────────────┐  │
│  │  ACR Premium │  │  Key Vault   │  │  Azure     │  │  Azure        │  │
│  │  (Connected  │  │  (Secrets    │  │  Monitor   │  │  Managed      │  │
│  │   Registry)  │  │   Provider)  │  │  Workspace │  │  Grafana      │  │
│  └──────┬───────┘  └──────┬───────┘  └─────┬──────┘  └───────┬───────┘  │
│         │                 │                 │ Prometheus       │ Dashboards│
│  ┌──────┴─────────────────┴─────────────────┴─────────────────┘          │
│  │  Ubuntu 24.04 VM (Standard_D4s_v5)                                    │
│  │  ┌──────────────────────────────────────────────────────────────────┐ │
│  │  │  K3s Cluster → Azure Arc Connected Cluster                      │ │
│  │  │  ┌────────────────────────────────────────────────────────────┐  │ │
│  │  │  │  Extensions:                                               │  │ │
│  │  │  │  • Key Vault Secrets Provider (CSI Driver)                 │  │ │
│  │  │  │  • Connected Registry (ACR sync)                           │  │ │
│  │  │  │  • Azure Monitor Metrics (Prometheus → Grafana)            │  │ │
│  │  │  │  GitOps (Flux v2):                                         │  │ │
│  │  │  │  • fluxv2-podinfo-demo → apps/fluxv2-podinfo-demo         │  │ │
│  │  │  └────────────────────────────────────────────────────────────┘  │ │
│  │  └──────────────────────────────────────────────────────────────────┘ │
│  └───────────────────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────────────┘
```

## File Structure

```
├── .env.example               # Environment variables template (copy to .env)
├── .gitignore                 # Excludes .env from version control
├── main.bicep                 # Subscription-scope entry point
├── main.bicepparam            # All parameters (single source of truth)
├── modules/
│   ├── network.bicep          # NSG, VNet, Subnet, Public IP, NIC
│   ├── vm.bicep               # Ubuntu 24.04 VM (managed identity)
│   ├── vm-setup.bicep         # Custom Script Extension (K3s + Arc bootstrap)
│   ├── keyvault.bicep         # Key Vault + demo secret + RBAC
│   ├── acr.bicep              # ACR Premium (data endpoints enabled)
│   ├── monitoring.bicep       # Azure Monitor workspace + Managed Grafana
│   ├── workbook.bicep         # Azure Monitor Workbook (Arc K8s dashboard)
│   ├── workbook-content.json  # Workbook layout & Resource Graph queries
│   └── role-assignments.bicep # VM MI → Contributor on RG
├── scripts/
│   └── setup-arc.sh           # Bootstrap: K3s → Arc → Extensions → Flux GitOps
└── README.md
```
