#!/usr/bin/env bash
set -euo pipefail

NONPROD_RG="rg-nexus-nonprod"
NONPROD_CLUSTER="aks-nexus-nonprod"
PROD_RG="rg-nexus-prod"
PROD_CLUSTER="aks-nexus-prod"
CHART_VERSION="10.10.3"
ROOT_DIR=$(cd -- "$(dirname -- "$0")/.." && pwd)
APPSET="$ROOT_DIR/argocd/appset.yaml"

if [[ $(< "$APPSET") == *YOUR_ORG* ]]; then
  echo "Set repoURL in $APPSET before running this script." >&2
  exit 1
fi

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
export KUBECONFIG="$WORK_DIR/kubeconfig"

# Load cluster credentials into a temporary kubeconfig.
az aks get-credentials \
  --resource-group "$NONPROD_RG" \
  --name "$NONPROD_CLUSTER" \
  --context "$NONPROD_CLUSTER" \
  --file "$KUBECONFIG" \
  --overwrite-existing --output none

az aks get-credentials \
  --resource-group "$PROD_RG" \
  --name "$PROD_CLUSTER" \
  --context "$PROD_CLUSTER" \
  --file "$KUBECONFIG" \
  --overwrite-existing --output none

# Install or update Argo CD on nonprod.
helm upgrade --install argocd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --version "$CHART_VERSION" \
  --kube-context "$NONPROD_CLUSTER" \
  --namespace argocd --create-namespace --wait

# Use Kubernetes access instead of an Argo CD admin login.
kubectl config set-context "$NONPROD_CLUSTER" --namespace argocd

argocd cluster add "$PROD_CLUSTER" \
  --name "$PROD_CLUSTER" \
  --core --kube-context "$NONPROD_CLUSTER" \
  --upsert --yes

# Create or update the ApplicationSet.
kubectl --context "$NONPROD_CLUSTER" apply -f "$APPSET"

echo "Argo CD and the orders-api ApplicationSet are configured."
