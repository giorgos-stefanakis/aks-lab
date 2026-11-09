#!/usr/bin/env bash
# Deletes the kind cluster. The key pair in .local/oidc stays, so the published issuer keeps working.
set -euo pipefail

kind delete cluster --name aks-lab
