# Log

Verified findings, newest last. Never edit an old entry; add a new one that corrects it.

## 2026-11-09

- Latest releases: kind v0.33.0 (default node image Kubernetes v1.37.0), Helm v4.3.1, Argo CD v3.6.1
  (argo-helm chart `argo-cd-10.17.0`), Envoy Gateway v1.10.0 (v1.9.3 is the previous minor), cert-manager v1.21.3,
  Gateway API v1.7.0, kubelogin v0.2.22. Pin versions at least two weeks old where possible.
- AKS app routing with Gateway API is GA since AKS release v20260428. Enable with
  `--enable-gateway-api --enable-app-routing-istio`. GatewayClass is `approuting-istio`. It needs the managed
  Gateway API CRDs; self-managed CRDs are unsupported with it.
  Source: https://learn.microsoft.com/azure/aks/app-routing-gateway-api
- Managed NGINX in the app routing add-on loses support on 2026-11-30. Upstream ingress-nginx stopped in March 2026.
- AKS docs do not mention cert-manager. Their TLS path uses Key Vault certificates. A publicly trusted certificate
  without a purchase needs cert-manager and Let's Encrypt.
- `spec.infrastructure.annotations` on a Gateway sets load balancer annotations. `azure-dns-label-name` is not
  documented for it, so the plan uses a static public IP that has a DNS label.
- Azure CNI powered by Cilium does not provide a Gateway API implementation on AKS.
- Argo CD 3.x supports Azure workload identity for Helm OCI repositories: a repository Secret with
  `enableOCI: "true"` and `useAzureWorkloadIdentity: "true"`. The kubelet `AcrPull` role does not cover chart pulls.
  Source: https://argo-cd.readthedocs.io/en/release-3.0/user-guide/private-repositories/
- Claude Code reads `AGENTS.md` natively from v2.1.277 when no `CLAUDE.md` exists in the folder or above.
- Claude Code permission rules do not match `bash -c '…'` and are not a security boundary. A PreToolUse hook that
  exits 2 blocks before permission rules apply. Deny and ask rules apply from any settings scope.
  Source: https://code.claude.com/docs/en/permissions.md

## 2026-11-09 (M1)

- `azure-functions` 2.x needs Python 3.13. The indexer pins `azure-functions` 1.26.0 to stay on Python 3.12.
- The versioned Functions base image tags stopped at `4.1036.0-python3.12` (built 2024-08). The `4-python3.12` tag is
  current (built 2026-11-06) but floats, so the indexer Dockerfile pins it by digest.
- A Poetry venv copied between Docker stages breaks its script shebangs. Build and run at the same path (`/srv`).
- Ruff config lives once in the root `ruff.toml`. Per-file globs in it are relative to the root.
- Both images run against a stub config file (`LAB_CONFIG_STUB`): api `/healthz`, `/readyz` and `/config` answer;
  indexer `/api/health` and `/api/index` answer inside the Functions host.
- Not yet exercised: the real App Configuration provider path (`load(...)`), Key Vault resolution and Azure OpenAI.
  These need M2.

## 2026-11-09 (M1 review)

- Each failure path from the M1 code review reproduced as a failing test before its fix. Both suites now pass
  (api 18, indexer 22). Fixed: non-object JSON bodies, invalid chunk config (now 503), redundant last chunk,
  Entra auth errors on `/chat` (now 502), non-JSON indexer replies (now 502), per-request client creation,
  and the `/config` deny-list (now an allow-list).
- The Functions base image runs as uid 10001 on port 80. The Dockerfile now sets `USER 10001`.
- In a container with no Azure credential, `/chat` returns 502 `ClientAuthenticationError`, not 500.
