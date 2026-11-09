#!/usr/bin/env bash
# Installs Argo CD on the kind cluster, gives it read access to the git repo and applies the root app.
# Needs the deploy key (private half) at .local/argocd-deploy-key. Never commit it.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
key="$root/.local/argocd-deploy-key"
repo="$(sed -n 's|^ *- repoURL: \(git@.*\)$|\1|p' "$root/gitops/bootstrap/root-local.yaml" | head -1)"

test -f "$key" || { echo "Missing $key. Create the deploy key first (docs/RUNBOOK.md, M4)." >&2; exit 1; }
case "$repo" in *OWNER*|"") echo "Set the repo URL in gitops/ first (it still has a placeholder)." >&2; exit 1 ;; esac

helm upgrade --install argocd argo-cd --repo https://argoproj.github.io/argo-helm --version 10.17.0 \
  --kube-context kind-aks-lab --namespace argocd --create-namespace \
  --values "$root/gitops/bootstrap/argocd-values.yaml" --wait --timeout 5m

kubectl --context kind-aks-lab -n argocd create secret generic repo-git \
  --from-literal=type=git --from-literal=url="$repo" --from-file=sshPrivateKey="$key" \
  --dry-run=client -o yaml \
  | kubectl --context kind-aks-lab label --local -f - argocd.argoproj.io/secret-type=repository -o yaml \
  | kubectl --context kind-aks-lab apply -f -

# Argo pulls OCI Helm charts only from registered repositories. Public, so no credentials.
kubectl --context kind-aks-lab -n argocd create secret generic repo-envoyproxy \
  --from-literal=type=helm --from-literal=name=envoyproxy --from-literal=url=docker.io/envoyproxy --from-literal=enableOCI=true \
  --dry-run=client -o yaml \
  | kubectl --context kind-aks-lab label --local -f - argocd.argoproj.io/secret-type=repository -o yaml \
  | kubectl --context kind-aks-lab apply -f -

kubectl --context kind-aks-lab apply -f "$root/gitops/bootstrap/root-local.yaml"
