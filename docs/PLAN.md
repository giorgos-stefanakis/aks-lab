---
author: "Georgios Stefanakis"
date: 2026-11-09
status: accepted
---

# Plan

Milestones run in order. Each one ends with a check from [SPEC.md](SPEC.md#acceptance-checks) or a local check.
Tasks live in [TASKS.md](TASKS.md).

| ID | Milestone | Done when | Azure touch |
|---|---|---|---|
| M0 | Docs and guardrails | Docs reviewed. The guard hook blocks the test cases. | None |
| M1 | Apps | `make test` and `make lint` pass. Both images build. The api runs in Docker against a stub config. | None |
| M2 | Azure control plane | Bicep what-if is clean. The owner deploys. ACR, App Configuration, Key Vault, Azure OpenAI and identities exist. | Owner deploys |
| M3 | Charts and publish | `make publish` pushes images and charts to ACR. `helm template` renders for both environments. | Push to ACR |
| M4 | Local cluster | Acceptance checks 1 to 5 pass on kind. | Reads only |
| M5 | CI/CD | Acceptance check 6 passes. | Owner deploys the GitHub identity |
| M6 | AKS | Acceptance checks 2 to 5 and 7 pass on AKS. | Owner deploys AKS |
| M7 | Public ingress | Acceptance check 8 passes. | None beyond M6 |
| M8 | Demo | `docs/DEMO.md` walks through the checks. Check 9 passes. | Owner tears down |

## Repository layout

```
aks-lab/
├── AGENTS.md, README.md, Makefile
├── .github/workflows/        apps.yml, infra.yml
├── apps/
│   ├── api/                  FastAPI
│   └── indexer/              Azure Functions
├── charts/                   api, indexer: published to ACR
├── infra/                    main.bicep, modules/, params/
├── gitops/
│   ├── bootstrap/            root app per cluster
│   ├── platform/             argocd, envoy-gateway, cert-manager, gateway
│   ├── apps/                 Argo Applications for api and indexer
│   └── envs/                 local/, aks-dev/: values per workload
├── scripts/
└── docs/
```

## Cut order

If time runs out, drop work in this order:

1. M8 polish. Demo from the acceptance checks instead.
2. M7. Use `kubectl port-forward` on AKS.
3. Automated Bicep deploy in M5. Keep the what-if on pull requests; the owner deploys with `make`.

## Open points

- How the local service principal is created: the Bicep Graph extension or an owner-run script. Decide in M2.
- Model and region for Azure OpenAI: check quota before M2.
- Node size for AKS: measure kind usage in M4 first.
