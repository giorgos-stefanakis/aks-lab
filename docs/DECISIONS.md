---
author: "Georgios Stefanakis"
date: 2026-11-09
status: accepted
---

# Decisions

Prototype decisions. **None of them is final.** Each one is the simplest choice that lets the lab show the idea.
A real platform would revisit each one.

| ID | Decision | Why |
|---|---|---|
| D-01 | **kind locally, AKS in the cloud, same charts.** | Shows the workloads do not depend on AKS. |
| D-02 | **Azure is the control plane.** Entra ID, App Configuration, Key Vault and ACR stay on Azure. Pods reach them over HTTPS. | Config, secrets and identity are not workload data. Only compute moves. |
| D-03 | **Workload identity on AKS**, one user-assigned managed identity per workload. Locally, a short-lived service principal secret. | `DefaultAzureCredential` picks up both without code changes. kind has no public OIDC issuer. |
| D-04 | **Apps load App Configuration through the SDK.** The SDK resolves Key Vault references. A sentinel key drives refresh. Labels select the environment. | No secrets operator needed. One store serves every environment. |
| D-05 | **Build once, deliver artifacts.** CI pushes images and charts to ACR as OCI. Argo CD pulls them. Values live in git. | Clusters need registry and git access only. CI never reaches into a cluster. |
| D-06 | **Argo CD, app-of-apps**, one root app per cluster. Our apps use two sources: the chart from ACR and the values from git. | The common Argo pattern. The UI helps the demo. |
| D-07 | **External charts are pinned and consumed from upstream**, not vendored. | Less code to own. Upgrades are a version bump. |
| D-08 | **The Functions host image runs as a plain Deployment** with HTTP triggers only. No storage account. | Tests the host on Kubernetes without the trigger backends. |
| D-09 | **Gateway API for ingress.** AKS uses the app routing add-on with Istio (Microsoft's recommended path). kind uses Envoy Gateway. One chart holds the Gateway and routes; only the class and TLS differ. | ingress-nginx is retired. Routes stay portable across implementations. |
| D-10 | **cert-manager with Let's Encrypt on AKS only.** The hostname is the DNS label of a static public IP. | Free, publicly trusted certificates. No domain to buy. |
| D-11 | **Azure OpenAI is an external dependency.** Endpoint and deployment name live in App Configuration. Auth uses Entra. | Swapping the AI provider is a config change. |
| D-12 | **Bicep for Azure only**, incremental mode, what-if before deploy. Everything inside a cluster goes through GitOps. | One tool per layer. No hidden changes. |
| D-13 | **GitHub Actions with OIDC** to Azure. CI commits new chart versions to `gitops/envs/`. | No stored cloud secrets. Git records every release. |
| D-14 | **Cheapest AKS:** Free tier, 3 small nodes, one resource group, a budget alert, stopped when idle. | The lab runs for days, not months. |
| D-15 | **Monorepo** for source, charts, Bicep and GitOps config. | Easy to read in a demo. A real setup would give each client cluster read access to its own config only. |
| D-16 | **Python tooling:** pyenv, Poetry, Ruff, pytest, a Makefile per component. | Common, well-known tools. |
