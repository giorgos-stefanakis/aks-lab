#!/usr/bin/env bash
# Fetches the AKS credentials into context `aks-lab` and installs Argo CD. Runs after the Bicep deploy in `make aks-up`.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
sub="${LAB_SUBSCRIPTION_ID:?Set LAB_SUBSCRIPTION_ID in .lab.env}"
rg="${LAB_RESOURCE_GROUP:?Set LAB_RESOURCE_GROUP in .lab.env}"
context="aks-lab"

az aks get-credentials --subscription "$sub" --resource-group "$rg" --name aks-lab --context "$context" --overwrite-existing
# Local accounts are off. kubelogin reuses the az CLI sign-in for the Entra token.
kubelogin convert-kubeconfig --login azurecli --context "$context"

kubectl --context "$context" get nodes

"$root/scripts/argocd-bootstrap.sh" aks-dev "$context"
