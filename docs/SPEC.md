---
author: "Georgios Stefanakis"
date: 2026-11-09
status: accepted
---

# Spec

## Goal

Show that a Python platform can run on Kubernetes with Azure as its control plane:

- Workloads run as Deployments from Helm charts, delivered by Argo CD from git.
- Images and charts are built once by CI and stored in ACR.
- Pods reach App Configuration, Key Vault and Azure OpenAI with an Entra identity, without stored keys on AKS.
- The same charts and the same Gateway API routes run on a local kind cluster and on AKS.
- An Entra app registration with a federated credential replaces a managed identity for a workload. A pod can use
  both at once: the managed identity for Azure resources and the registration for Microsoft Graph.

## Non-goals

- Production readiness: high availability, backups, hardening, scaling.
- Data stores, queues and the Functions trigger backends that need them.
- Observability.
- In-cluster AI inference.
- A secrets operator (External Secrets Operator or the Secrets Store CSI driver).
- Mirroring for air-gapped clusters.
- User sign-in.
- Microsoft 365 services such as SharePoint. The Graph probe reads organisation data only.

## Workloads

**api**: a FastAPI service.

| Endpoint | Behaviour |
|---|---|
| `GET /healthz` | Liveness. Returns 200 when the process runs. |
| `GET /readyz` | Readiness. Returns 200 after configuration is loaded. |
| `GET /config` | Shows non-secret settings, their App Configuration label, the feature flag state, and whether the Key Vault secret resolved. Never shows the secret value. |
| `POST /chat` | Sends a prompt to Azure OpenAI. The endpoint and deployment name come from App Configuration. |
| `POST /index` | Forwards a document to the indexer and returns its result. |
| `GET /graph` | Calls Microsoft Graph `GET /organization`. Returns the credential kind (`default` or `workload-identity`), the `appid` or `azp` claim of the token it used, and `graph: ok`. Returns 502 with the error class on failure. Never returns a token or tenant data. |

`GRAPH_CLIENT_ID` is an optional environment variable. When it is unset, every Azure call uses the default credential
chain. When it is set, `GET /graph` uses a workload identity credential for that client ID. The other calls stay on
the default chain.

**indexer**: an Azure Functions app (Python v2 model) on the Functions base image, run as a Deployment.

| Endpoint | Behaviour |
|---|---|
| `POST /api/index` | Splits the document into chunks with settings from App Configuration and returns the chunk count. Mock only. |
| `GET /api/health` | Liveness and readiness. |

The indexer has HTTP triggers only. It has no public route. Only the api calls it, inside the cluster.

**Configuration model.** Both workloads load App Configuration at startup through the Azure SDK.
Keys use the prefix `lab:`. Labels select the environment (`local`, `aks-dev`).
A sentinel key triggers a refresh without a restart. One key is a Key Vault reference.

## Azure resources (Bicep)

All resources sit in one resource group, tagged `purpose=lab`.

| Resource | Use |
|---|---|
| Container Registry, Basic | Images and Helm charts |
| App Configuration, Free | Settings, feature flag, Key Vault reference, sentinel |
| Key Vault, Standard, RBAC mode | One demo secret |
| Azure OpenAI, one model deployment | External AI dependency |
| User-assigned managed identities | `api`, `indexer`, `argocd`, `github` |
| Federated identity credentials | AKS service accounts and GitHub Actions |
| Entra app registration `app-lab-api` with a service principal and federated credentials | M9. Tests the app registration path. No client secret and no certificate. Holds the roles of the `api` identity and the Graph application permission `Organization.Read.All`. |
| AKS, Free tier, 3 small nodes | Cloud cluster with the OIDC issuer, workload identity, managed Gateway API CRDs and app routing Istio |
| Static public IP with a DNS label | Public hostname for the AKS gateway |
| Budget with an email alert | Cost guard on the resource group |

## Cluster components

| Component | local | aks-dev | Installed by |
|---|---|---|---|
| Argo CD | yes | yes | Helm once, then Argo manages itself |
| Envoy Gateway | yes | no | Argo, upstream chart |
| Gateway API CRDs | via Envoy Gateway | AKS managed | |
| Istio gateway control plane | no | AKS managed | `--enable-app-routing-istio` |
| Workload identity webhook | no | AKS managed | `--enable-workload-identity` |
| cert-manager | no | yes | Argo, upstream chart |
| `gateway` chart: Gateway, HTTPRoutes, ClusterIssuer | yes | yes | Argo, from git |
| `api` and `indexer` charts | yes | yes | Argo, chart from ACR, values from git |

## Environments

| | local | aks-dev |
|---|---|---|
| Cluster | kind | AKS |
| Pod identity | Service principal secret in a K8s Secret, created by a script, never in git | Workload identity |
| Image pull | Pull secret with the service principal | Kubelet identity with `AcrPull` |
| Argo chart pull from ACR | Repository secret with the service principal | Workload identity on the repo server |
| GatewayClass | `envoy` | `approuting-istio` |
| Access | `kubectl port-forward`, HTTP | Public HTTPS on `<label>.<region>.cloudapp.azure.com` |

## Delivery

- A pull request runs lint, tests, chart lint and Bicep lint. The owner runs the Bicep what-if and deploy with `make`.
- A merge to `main` builds and pushes images, packages and pushes charts, deploys Bicep, and commits the new
  chart versions to `gitops/envs/`.
- Argo CD syncs each cluster from `gitops/`.

## Acceptance checks

1. `make local-up` creates a kind cluster. Argo syncs every app to `Healthy` with no manual `kubectl apply`.
2. `GET /config` on both clusters shows values with the right label and `secret: resolved`.
3. Changing a value and the sentinel in App Configuration changes `GET /config` within the refresh interval,
   without a restart.
4. `POST /chat` returns an answer from Azure OpenAI on both clusters.
5. `POST /index` returns a chunk count from the indexer on both clusters.
6. Pushing a `vX.Y.Z` tag on `main` changes a running pod's image without further steps.
7. On AKS, no workload has a stored Azure credential. `GET /config` still works.
8. On AKS, `https://<host>/healthz` returns 200 with a publicly trusted certificate.
9. `make local-down` and `make aks-down` remove everything they created.
10. Test A, identity swap. On both clusters, `identity.clientId` of the api names the app registration.
    `GET /config` shows `secret: resolved`, and `GET /graph` returns that client ID with `graph: ok`.
    The registration has no client secret and no certificate.
11. Test B, dual identity. On both clusters, the api keeps the managed identity and `GRAPH_CLIENT_ID` names the
    registration. In one pod, `GET /config` resolves through the managed identity, and `GET /graph` calls Graph as
    the registration.
12. The documented teardown removes the app registration. The Entra portal lists no `app-lab-api` afterwards.
