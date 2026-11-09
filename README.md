# aks-lab

A small lab that runs a Python platform on Kubernetes, with Azure as its control plane.

- A FastAPI service and an Azure Functions app run as plain Kubernetes Deployments.
- Pods get configuration from Azure App Configuration and secrets from Key Vault, using Entra workload identity.
- CI builds images and Helm charts once and pushes both to Azure Container Registry.
- Argo CD pulls them and deploys the same charts to a local kind cluster and to AKS.
- Azure OpenAI is an external dependency that the service calls.

This is a prototype. The decisions behind it are provisional. See [docs/DECISIONS.md](docs/DECISIONS.md).

## Docs

| File | Content |
|---|---|
| [docs/SPEC.md](docs/SPEC.md) | Scope, components, environments, acceptance checks |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Prototype decisions |
| [docs/PLAN.md](docs/PLAN.md) | Milestones |
| [docs/TASKS.md](docs/TASKS.md) | Work items and status |
| [docs/LOG.md](docs/LOG.md) | Findings |

## Setup

Copy `.lab.env.example` to `.lab.env` and fill in your tenant and subscription. The file stays out of git.
Run instructions follow as the milestones land.
