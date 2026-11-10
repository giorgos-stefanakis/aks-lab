#!/usr/bin/env bash
# Creates the kind cluster `aks-lab` with the lab issuer. Needs the issuer documents published first.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
issuer="${LAB_ISSUER_URL:?Set LAB_ISSUER_URL in .lab.env (output issuerUrl of the kind stack)}"
issuer="${issuer%/}"
context="kind-aks-lab"

"$root/scripts/kind-issuer.sh" > /dev/null

# Entra reads this document when a pod exchanges its token. A cluster that starts before it exists gets no tokens.
if ! curl -fsS --max-time 10 "$issuer/.well-known/openid-configuration" | cmp -s - "$root/.local/oidc/.well-known/openid-configuration"; then
  echo "The issuer document at $issuer is missing or differs from .local/oidc. Publish it first (docs/RUNBOOK.md, M4)." >&2
  exit 1
fi

if kind get clusters | grep -qx aks-lab; then
  # The cluster must sign with the key that is published, or Entra rejects every token.
  # The API server prints compact JSON, so compare the parsed documents.
  live="$(kubectl --context "$context" get --raw /.well-known/openid-configuration | jq -cS .)"
  if [[ "$live" != "$(jq -cS . "$root/.local/oidc/.well-known/openid-configuration")" ]]; then
    echo "Cluster aks-lab uses a different issuer than .local/oidc. Run make local-down, then make local-up." >&2
    exit 1
  fi
  echo "Cluster aks-lab exists."
else
  sed -e "s|@OIDC_DIR@|$root/.local/oidc|g" -e "s|@ISSUER@|$issuer|g" "$root/scripts/kind-config.yaml.tpl" > "$root/.local/kind-config.yaml"
  kind create cluster --config "$root/.local/kind-config.yaml" --wait 120s
fi

kubectl --context "$context" get nodes

"$root/scripts/argocd-bootstrap.sh" local "$context"
