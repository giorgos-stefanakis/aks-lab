#!/usr/bin/env bash
# Installs Argo CD on a lab cluster, registers the git repo and the chart registries, and applies the root app.
# Usage: argocd-bootstrap.sh <cluster dir under gitops/clusters> <kube context>
# Needs the deploy key (private half) at .local/argocd-deploy-key. Never commit it.
set -euo pipefail

cluster="${1:?cluster, e.g. local}"
context="${2:?kube context}"
root="$(cd "$(dirname "$0")/.." && pwd)"
dir="$root/gitops/clusters/$cluster"
key="$root/.local/argocd-deploy-key"
repo="$(sed -n 's|^ *- repoURL: \(git@.*\)$|\1|p' "$dir/root.yaml" | head -1)"

test -f "$key" || { echo "Missing $key. Create the deploy key first (docs/RUNBOOK.md, M4)." >&2; exit 1; }
case "$repo" in *OWNER*|"") echo "Set the repo URL in gitops/ first (it still has a placeholder)." >&2; exit 1 ;; esac

helm upgrade --install argocd argo-cd --repo https://argoproj.github.io/argo-helm --version 10.17.0 \
  --kube-context "$context" --namespace argocd --create-namespace \
  --values "$dir/argocd-values.yaml" --wait --timeout 5m

repo_secret() {
  local name="$1"
  shift
  kubectl --context "$context" -n argocd create secret generic "$name" "$@" --dry-run=client -o yaml \
    | kubectl --context "$context" label --local -f - argocd.argoproj.io/secret-type=repository -o yaml \
    | kubectl --context "$context" apply -f -
}

repo_secret repo-git --from-literal=type=git --from-literal=url="$repo" --from-file=sshPrivateKey="$key"

# Argo pulls OCI Helm charts only from registered repositories. Public, so no credentials.
repo_secret repo-envoyproxy --from-literal=type=helm --from-literal=name=envoyproxy \
  --from-literal=url=docker.io/envoyproxy --from-literal=enableOCI=true

repo_secret repo-acr-charts --from-literal=type=helm --from-literal=name=acr-charts \
  --from-literal=url=acrlabyntm5u.azurecr.io/charts --from-literal=enableOCI=true --from-literal=useAzureWorkloadIdentity=true

kubectl --context "$context" apply -f "$dir/root.yaml"
