# Tasks

Status: `todo`, `doing`, `done`, `blocked`. Milestones are in [PLAN.md](PLAN.md).

| ID | Milestone | Task | Status |
|---|---|---|---|
| T-001 | M0 | Write docs and AGENTS.md | done |
| T-002 | M0 | Add the guard hook and permission rules. Test the block cases. | done |
| T-003 | M0 | Owner reviews the docs | done |
| T-010 | M1 | api: FastAPI service, settings loader, endpoints, unit tests, Dockerfile, Makefile | done |
| T-011 | M1 | indexer: Functions app, HTTP triggers, unit tests, Dockerfile, Makefile | done |
| T-012 | M1 | Root Makefile, `.editorconfig`, Ruff config | done |
| T-020 | M2 | Check Azure OpenAI model and quota in the region. `gpt-5-mini` `GlobalStandard` capacity 10 deployed in `swedencentral`. | done |
| T-021 | M2 | Bicep: ACR, App Configuration (derived keys only), Key Vault, Azure OpenAI, issuer storage, identities with kind federated credentials, role assignments, budget | done |
| T-022 | M2 | Config seed file and `docs/RUNBOOK.md` M2 steps: resource group, deploy, secret, seed | done |
| T-023 | M2 | Make targets `infra-lint`, `infra-whatif`, `infra-deploy` with environment checks | done |
| T-030 | M3 | Helm charts for api and indexer | done |
| T-031 | M3 | `make publish`: build, push images, package and push charts | done |
| T-040 | M4 | kind cluster script and `make local-up`, `make local-down` | done |
| T-041 | M4 | Argo CD bootstrap and root app for `local` | done |
| T-042 | M4 | Envoy Gateway and the `gateway` chart | done |
| T-043 | M4 | Local identity wiring: projected token and `AZURE_*` env in the chart, Argo repo secret with workload identity | done |
| T-044 | M4 | kind OIDC issuer: service-account key pair, JWKS script, upload to the issuer storage, kind config, runbook steps | done |
| T-045 | M4 | Spike: External Secrets Operator `ACRAccessToken` generator makes the ACR pull secret. Fallback: scoped token in Key Vault. | done |
| T-050 | M5 | GitHub repository and Argo deploy key (owner) | done |
| T-051 | M5 | `apps.yml`: lint and test on pull requests and `main`; on a `vX.Y.Z` tag, publish images and charts and create the GitHub release | done |
| T-053 | M5 | Bicep: GitHub federated credential for the `release` environment, limited to `v*` tags | done |
| T-054 | M5 | Release job pins the chart version for `local` in git; the chart image tag defaults to `appVersion` | done |
| T-060 | M6 | Bicep: AKS, static public IP, AKS federated credentials, `AcrPull` for the kubelet identity | done |
| T-061 | M6 | Argo CD on AKS with workload identity for ACR | done |
| T-062 | M6 | Root app for `aks-dev` | done |
| T-063 | M6 | Release job pins the chart version for `aks-dev` in the same deploy commit as `local` | done |
| T-064 | M6 | Bicep by concern: shared names, per-resource owner roles, one federation module for both clusters | done |
| T-065 | M6 | Clusters as plugins: one deployment stack per cluster in `infra/clusters/`, `kind-*` and `aks-down` targets. Check: owner what-ifs show no Create or Delete on the live lab | done |
| T-070 | M7 | cert-manager, ClusterIssuer, HTTPS listener | done |
| T-080 | M8 | `docs/DEMO.md` and teardown targets | todo |
