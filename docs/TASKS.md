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
| T-040 | M4 | kind cluster script and `make local-up`, `make local-down` | todo |
| T-041 | M4 | Argo CD bootstrap and root app for `local` | todo |
| T-042 | M4 | Envoy Gateway and the `gateway` chart | todo |
| T-043 | M4 | Local identity wiring: projected token and `AZURE_*` env in the chart, Argo repo secret with workload identity | todo |
| T-044 | M4 | kind OIDC issuer: service-account key pair, JWKS script, upload to the issuer storage, kind config, runbook steps | todo |
| T-045 | M4 | Spike: External Secrets Operator `ACRAccessToken` generator makes the ACR pull secret. Fallback: scoped token in Key Vault. | todo |
| T-050 | M5 | GitHub repository and Argo deploy key (owner) | todo |
| T-051 | M5 | `apps.yml`: lint, test, build, push, bump versions | todo |
| T-052 | M5 | `infra.yml`: what-if on pull requests, deploy on `main` | todo |
| T-060 | M6 | Bicep: AKS, static public IP, AKS federated credentials, `AcrPull` for the kubelet identity | todo |
| T-061 | M6 | Argo CD on AKS with workload identity for ACR | todo |
| T-062 | M6 | Root app for `aks-dev` | todo |
| T-070 | M7 | cert-manager, ClusterIssuer, HTTPS listener | todo |
| T-080 | M8 | `docs/DEMO.md` and teardown targets | todo |
