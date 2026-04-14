#!/bin/bash
###############################################################################
# setup-arc.sh
#
# Bootstraps K3s, connects the cluster to Azure Arc, and installs:
#   - Azure Key Vault Secrets Provider Extension
#   - Azure Connected Registry Extension
#   - Azure Monitor Metrics (Prometheus) Extension
#   - Flux v2 Extension + GitOps Configuration
#
# Environment variables are injected by the Bicep Custom Script Extension:
#   RESOURCE_GROUP, CLUSTER_NAME, LOCATION, ACR_NAME, KEY_VAULT_NAME,
#   CONNECTED_REGISTRY_SERVICE_CLUSTER_IP, ARC_RBAC_ASSIGNEE_ID,
#   AZURE_MONITOR_WORKSPACE_ID
###############################################################################
set -euo pipefail

LOG_FILE="/var/log/setup-arc.log"
exec > >(tee -a "$LOG_FILE") 2>&1

log() { echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*"; }

###############################################################################
# 1. System tuning — increase inotify limits for Arc extensions + fluent-bit
###############################################################################
log "=== Step 1: Tuning system limits ==="
sysctl -w fs.inotify.max_user_instances=1024
sysctl -w fs.inotify.max_user_watches=524288
cat > /etc/sysctl.d/99-arc-k8s.conf <<EOF
fs.inotify.max_user_instances = 1024
fs.inotify.max_user_watches = 524288
EOF
log "inotify limits set (instances=1024, watches=524288)."

###############################################################################
# 2. Install K3s
###############################################################################
log "=== Step 2: Installing K3s ==="
curl -sfL https://get.k3s.io | sh -

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
chmod 644 "$KUBECONFIG"

log "Waiting for K3s node to register..."
for i in $(seq 1 30); do
  if kubectl get nodes -o name 2>/dev/null | grep -q .; then
    break
  fi
  log "  Node not yet registered, retrying ($i/30)..."
  sleep 10
done

log "Waiting for K3s node to become Ready..."
kubectl wait --for=condition=Ready node --all --timeout=300s
log "K3s is ready."
kubectl get nodes -o wide

###############################################################################
# 3. Install Azure CLI and extensions
###############################################################################
log "=== Step 3: Installing Azure CLI ==="
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

log "Installing Azure CLI extensions..."
az extension add --name connectedk8s --upgrade --yes
az extension add --name k8s-extension --upgrade --yes
az extension add --name k8s-configuration --upgrade --yes

###############################################################################
# 4. Login via managed identity
###############################################################################
log "=== Step 4: Logging in via managed identity ==="
az login --identity --allow-no-subscriptions

###############################################################################
# 5. Connect cluster to Azure Arc
###############################################################################
log "=== Step 5: Connecting cluster to Azure Arc ==="
az connectedk8s connect \
  --name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --kube-config "$KUBECONFIG"

log "Waiting for Arc connection to stabilize..."
sleep 30
az connectedk8s show --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" -o table

log "Enabling Azure RBAC feature on Arc cluster..."
az connectedk8s enable-features \
  --name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --features azure-rbac
log "Azure RBAC feature enabled."

log "Assigning Azure Arc Kubernetes Cluster Admin role..."
ARC_CLUSTER_ID=$(az connectedk8s show \
  --name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query id -o tsv)

az role assignment create \
  --assignee "$ARC_RBAC_ASSIGNEE_ID" \
  --role "Azure Arc Kubernetes Cluster Admin" \
  --scope "$ARC_CLUSTER_ID"
log "Azure Arc Kubernetes Cluster Admin role assigned."

###############################################################################
# 6. Install Key Vault Secrets Provider Extension
###############################################################################
log "=== Step 6: Installing Key Vault Secrets Provider Extension ==="
az k8s-extension create \
  --cluster-type connectedClusters \
  --cluster-name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --extension-type Microsoft.AzureKeyVaultSecretsProvider \
  --name akvsecretsprovider \
  --configuration-settings \
    "secrets-store-csi-driver.enableSecretRotation=true" \
    "secrets-store-csi-driver.rotationPollInterval=3m"
log "Key Vault Secrets Provider extension installed."

###############################################################################
# 7. Install Connected Registry Extension
###############################################################################
log "=== Step 7: Installing Connected Registry Extension ==="

CONNECTED_REGISTRY_NAME="${CLUSTER_NAME}registry"
CONNECTED_REGISTRY_NAME=$(echo "$CONNECTED_REGISTRY_NAME" | tr -d '-')

log "Creating connected registry resource: $CONNECTED_REGISTRY_NAME"
az acr connected-registry create \
  --registry "$ACR_NAME" \
  --name "$CONNECTED_REGISTRY_NAME" \
  --repository "hello-world" || log "Connected registry may already exist, continuing..."

log "Generating connected registry connection string..."
CONNECTION_STRING=$(az acr connected-registry get-settings \
  --name "$CONNECTED_REGISTRY_NAME" \
  --registry "$ACR_NAME" \
  --parent-protocol https \
  --generate-password 1 \
  --query ACR_REGISTRY_CONNECTION_STRING \
  --output tsv --yes)

cat > /tmp/protected-settings-extension.json <<EOF
{
  "connectionString": "${CONNECTION_STRING}"
}
EOF

az k8s-extension create \
  --cluster-type connectedClusters \
  --cluster-name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --extension-type Microsoft.ContainerRegistry.ConnectedRegistry \
  --name connectedregistry \
  --config "service.clusterIP=${CONNECTED_REGISTRY_SERVICE_CLUSTER_IP}" \
  --config-protected-file /tmp/protected-settings-extension.json \
  --auto-upgrade-minor-version true

rm -f /tmp/protected-settings-extension.json
log "Connected Registry extension installed."

###############################################################################
# 8. Install Azure Monitor Metrics (Prometheus) Extension
###############################################################################
log "=== Step 8: Installing Azure Monitor Metrics Extension ==="
az k8s-extension create \
  --cluster-type connectedClusters \
  --cluster-name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --name azuremonitor-metrics \
  --extension-type Microsoft.AzureMonitor.Containers.Metrics \
  --configuration-settings \
    "azure-monitor-workspace-resource-id=${AZURE_MONITOR_WORKSPACE_ID}"
log "Azure Monitor Metrics extension installed."

###############################################################################
# 9. Install Container Insights Extension (logs → Log Analytics)
###############################################################################
log "=== Step 9: Installing Container Insights Extension ==="
az k8s-extension create \
  --cluster-type connectedClusters \
  --cluster-name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --name azuremonitor-containers \
  --extension-type Microsoft.AzureMonitor.Containers \
  --configuration-settings \
    "logAnalyticsWorkspaceResourceID=${LOG_ANALYTICS_WORKSPACE_ID}"
log "Container Insights extension installed."

###############################################################################
# 10. Install Flux v2 Extension + GitOps Configuration
###############################################################################
log "=== Step 10: Installing Flux extension ==="
az k8s-extension create \
  --cluster-type connectedClusters \
  --cluster-name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --name flux \
  --extension-type microsoft.flux
log "Flux extension installed."

log "Waiting for Flux pods to be ready..."
for i in $(seq 1 20); do
  READY=$(kubectl get pods -n flux-system --no-headers 2>/dev/null | awk '{print $2}' | grep -v '/' | wc -l || echo "0")
  NOT_READY=$(kubectl get pods -n flux-system --no-headers 2>/dev/null | awk '{split($2,a,"/"); if(a[1]!=a[2]) print}' | wc -l || echo "99")
  if [[ "$NOT_READY" -eq 0 ]] && [[ "$READY" -ne 99 ]]; then
    log "All Flux pods are ready."
    break
  fi
  log "  Flux pods not all ready yet ($i/20)..."
  sleep 15
done
kubectl get pods -n flux-system

log "=== Step 11: Configuring Flux v2 GitOps ==="
az k8s-configuration flux create \
  --name fluxv2-podinfo-demo \
  --cluster-name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-type connectedClusters \
  --namespace flux-system \
  --scope cluster \
  --url https://github.com/fabricekrebs/fluxv2-demo-app \
  --branch main \
  --kustomization name=fluxv2-podinfo-demo path=./apps/fluxv2-podinfo-demo prune=true
log "Flux GitOps configuration applied."

###############################################################################
# Done
###############################################################################
log "=========================================="
log "  Setup complete!"
log "=========================================="
log "Arc-enabled K3s cluster '$CLUSTER_NAME' is ready with:"
log "  Extensions:"
log "    - Key Vault Secrets Provider (akvsecretsprovider)"
log "    - Connected Registry (connectedregistry)"
log "    - Azure Monitor Metrics (azuremonitor-metrics)"
log "    - Container Insights (azuremonitor-containers)"
log "    - Flux (microsoft.flux)"
log "  GitOps:"
log "    - fluxv2-podinfo-demo -> apps/fluxv2-podinfo-demo"
log "=========================================="
