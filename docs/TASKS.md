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
| T-020 | M2 | Check Azure OpenAI model and quota in the region | todo |
| T-021 | M2 | Bicep: ACR, App Configuration with keys, Key Vault, Azure OpenAI, identities, role assignments, budget | todo |
| T-022 | M2 | Local service principal and its role assignments | todo |
| T-023 | M2 | `make infra-whatif` and `make infra-deploy` with subscription checks | todo |
| T-030 | M3 | Helm charts for api and indexer | todo |
| T-031 | M3 | `make publish`: build, push images, package and push charts | todo |
| T-040 | M4 | kind cluster script and `make local-up`, `make local-down` | todo |
| T-041 | M4 | Argo CD bootstrap and root app for `local` | todo |
| T-042 | M4 | Envoy Gateway and the `gateway` chart | todo |
| T-043 | M4 | Local secrets: service principal, pull secret, Argo repository secrets | todo |
| T-050 | M5 | GitHub repository and Argo deploy key (owner) | todo |
| T-051 | M5 | `apps.yml`: lint, test, build, push, bump versions | todo |
| T-052 | M5 | `infra.yml`: what-if on pull requests, deploy on `main` | todo |
| T-060 | M6 | Bicep: AKS, static public IP, federated credentials | todo |
| T-061 | M6 | Argo CD on AKS with workload identity for ACR | todo |
| T-062 | M6 | Root app for `aks-dev` | todo |
| T-070 | M7 | cert-manager, ClusterIssuer, HTTPS listener | todo |
| T-080 | M8 | `docs/DEMO.md` and teardown targets | todo |
