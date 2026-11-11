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
| T-080 | M8 | README: results of the acceptance checks, setup and try-it steps, clean-up. Teardown targets. | doing |
| T-090 | M9 | (owner) Check the Entra rights in the lab tenant: create an app registration and grant admin consent for a Graph application permission. Check: both work in the portal. | todo |
| T-091 | M9 | Verify that deployment stacks and what-if accept the Microsoft Graph resources in `infra/app-registration.bicep` (application, service principal, federated credential). The result decides whether the plugins can own the registration. Fallback: a plain deployment for the Entra part, or a script. Log the result. | doing |
| T-092 | M9 | Bicep: `infra/app-registration.bicep` creates `app-lab-api` with its service principal and a `kind` federated credential, and no secret and no certificate. Add the Graph application permission `Organization.Read.All`. Look the role ID up, never write it from memory. The owner grants consent. Check: the portal lists no secret and no certificate. | doing |
| T-093 | M9 | Bicep: give the service principal the roles of the `api` identity (App Configuration Data Reader, Key Vault Secrets User, Cognitive Services OpenAI User). Reuse the role IDs in `infra/common.bicep`. | doing |
| T-094 | M9 | Federated credential on the registration for `aks`, with the issuer, the subject (`system:serviceaccount:lab:api`) and the audience of the `api` identity credentials. The `kind` one is in `infra/app-registration.bicep`. Where each credential lives follows T-091. Check: what-if shows only creates. | doing |
| T-095 | M9 | api: switchable Graph credential. `GRAPH_CLIENT_ID` unset: the default chain. Set: `WorkloadIdentityCredential(client_id=...)`, with tenant and token file from the environment. Add `GET /graph`: it calls Graph `GET /organization` and returns the credential kind, the `appid` or `azp` claim of its token and `graph: ok`. On failure it returns 502 with the error class, as `/chat` does. It never returns a token or tenant data. Unit tests use a fake credential. | done |
| T-096 | M9 | api chart: optional `config.graphClientId` sets `GRAPH_CLIENT_ID`. Check: `make lint` passes. | done |
| T-097 | M9 | Test A, identity swap: set `identity.clientId` to the registration in `gitops/envs/local/api.yaml`, then in `aks-dev`. Check 10. Catch: on AKS the webhook reads the service-account annotation when a pod starts, so the owner recreates the pod. Agents never change AKS state. Restore the managed identity when done. | doing |
| T-098 | M9 | Test B, dual identity: keep the managed identity and set `config.graphClientId`. Check 11 on `local` and `aks-dev`. | todo |
| T-099 | M9 | Failure cases on kind, each logged with the error it returns: Graph call before admin consent (run this before the owner grants consent); a federated credential whose subject the owner edits in the portal to a wrong value; `GET /graph` on a managed-identity pod with `GRAPH_CLIENT_ID` unset. | todo |
| T-100 | M9 | Clean-up: remove the registration in the documented teardown, because an Entra object outlives the resource group. Check 12. | todo |
| T-101 | M9 | README: results of checks 10 to 12 and the failure cases. | todo |
