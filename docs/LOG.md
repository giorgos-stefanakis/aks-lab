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
