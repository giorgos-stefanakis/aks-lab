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

## 2026-11-09 (M2 draft)

- Decided with the owner: the local service principal comes from an owner-run script (`scripts/local-sp.sh`), not
  the Bicep Graph extension. The script writes the secret to `.env.local-sp` and never prints it.
- Decided with the owner: Azure OpenAI defaults to `gpt-4o-mini` (version 2024-07-18, `GlobalStandard`, capacity 10) in
  `swedencentral`. Quota and model availability are NOT verified (T-020 is `blocked` until an `az` check is approved).
- The Bicep in `infra/` is written but not yet compiled or linted: the Bicep CLI is not installed here.
  Unverified until what-if: App Configuration key names that contain `:` and `$` in the `keyValues` resource name.
- The `github` identity has only `AcrPush`. Roles for what-if on pull requests come with M5.
- The guard hook scans heredoc text. A shell command that only writes a file mentioning `az` mutations is blocked.
  Write such files with the Write tool.

## 2026-11-09 (M2 design)

- Decision: no Entra service principal and no stored credential for pods. Both clusters use workload identity
  federation. kind's issuer is published to a public-read blob container in a Standard LRS storage account.
  Each workload identity carries a second federated credential for kind (`system:serviceaccount:<ns>:<sa>`).
- Decision: Bicep owns structure and values derived from other resources. Secret values and tunable settings stay
  out of templates. Tunables load from `config/seed.json` (kvset import), so portal edits survive a redeploy.
  The Key Vault reference uses a versionless URI that Bicep builds before the secret exists.
- Decision: External Secrets Operator runs on kind only, to generate the ACR pull secret from a federated identity
  (`ACRAccessToken` generator). AKS pulls with the kubelet identity and `AcrPull`. Argo chart pulls use workload
  identity on the repo server on both clusters. The kubelet `AcrPull` role is added with AKS (T-060).
- Source check: kubelet service-account-token support for credential providers reached beta in Kubernetes 1.34.
  Azure's `acr-credential-provider` is documented as alpha with no federated-token flow. The ESO generator docs found
  were for v0.8.3. Verify both against pinned versions in M4 (T-045).
- Source check: Microsoft says ACR repository-scoped tokens work in all tiers. One third-party guide says Premium
  only. Unverified for Basic. This matters only for the fallback.
- Bicep 0.49.2 has no `flatMap`. Use `flatten(map(...))`. For-expressions are not allowed inside function calls.
- Unverified until what-if: the built-in role IDs in `identities.bicep` were written from memory (a wrong
  `Key Vault Secrets Officer` ID is the likeliest slip), and whether App Configuration accepts `:` and `$` in the
  `keyValues` resource name.
- `make infra-lint` and the template compile with no warnings. Not deployed.

## 2026-11-09 (subscription check)

- The lab runs on a personal account in a separate tenant. `az account list --all` shows one subscription, so nothing
  from another organisation is visible. The signed-in user is `Owner` on the subscription, which covers the role
  assignments the deployment creates.
- The subscription already holds a resource group `lab-onboarding-rg` with a Key Vault. The lab did not create them.
  Leave them alone.
- Resource providers `Microsoft.AppConfiguration`, `CognitiveServices`, `ContainerRegistry`, `ContainerService` and
  `Storage` were `NotRegistered`. The deploy fails until the owner registers them (runbook step 0).
- `gpt-4o-mini` 2024-07-18 is available in `swedencentral` with `GlobalStandard`. Its lifecycle is `Deprecating`
  with inference retirement on 2027-04-14. That is enough for the lab. The quota listing returned nothing, most likely
  because `Microsoft.CognitiveServices` is not registered. Re-check after registration.

## 2026-11-09 (role ID check)

- All eight built-in role IDs in `identities.bicep` were checked against the subscription. Seven were right. The
  `AcrPush` ID was wrong (written from memory) and is now `8311e382-0749-4cb8-b61a-304f252e45ec`. This corrects the
  role ID caveat in the M2 design entry. Never write role IDs from memory: look them up.

## 2026-11-09 (OpenAI model)

- Correction: `gpt-4o-mini` is not usable. A deployment fails with `ServiceModelDeprecating`: a model in `Deprecating`
  state cannot be created, even though `az cognitiveservices model list` still lists it. Check `lifecycleStatus`
  before choosing a model. `Deprecating` blocks new deployments.
- Available in `swedencentral` with `GlobalStandard`: `gpt-5-mini` 2025-08-07 (`GenerallyAvailable`, inference
  retirement 2027-07-13). `gpt-4.1-mini` and `gpt-4.1-nano` are `Legacy`. The default is now `gpt-5-mini`.
- Unverified: whether API version `2024-10-21`, set in `apps/api/app/main.py`, accepts `gpt-5-mini`. It is a
  reasoning model. Check with `POST /chat` once the stack runs, and raise the API version if the call is rejected.
- A failed module deployment leaves earlier resources in place. Rerunning the same deployment is safe because the
  mode is incremental.

## 2026-11-09 (App Configuration pass-through)

- With `disableLocalAuth: true`, ARM cannot write key values and the deploy fails with `Conflict`: "local authentication
  is disabled ... use pass-through authentication mode". Fix: `dataPlaneProxy.authenticationMode: 'Pass-through'` on
  the store (API 2024-05-01).
- In pass-through mode the caller needs an ARM role and an App Configuration data-plane role. The deployer's
  `App Configuration Data Owner` assignment now lives in the same module as the store, and the key values depend on
  it. Role propagation can take minutes, so a first deploy may fail with 403 on the key values. Rerun it.
  Source: https://learn.microsoft.com/azure/templates/microsoft.appconfiguration/configurationstores
- Unverified: how `disableLocalAuth` and `authenticationMode` interact in the newest preview API. The store uses the
  GA 2024-05-01 version.

## 2026-11-09 (role assignments in one module)

- Corrects the pass-through entry above: the owner's `App Configuration Data Owner` role no longer lives in the
  App Configuration module. All ten role assignments are in `identities.bicep`. The key values moved to
  `appconfig-values.bicep`, which `resources.bicep` runs after `identities`. Order: store, identities (roles),
  key values.

## 2026-11-09 (what-if after a failed first deploy)

- After the failed deploy, a what-if fails with six `Conflict` errors (one per key value) about local authentication.
  The what-if reads the live key values through the existing store, which still runs in `Local` mode. The template
  already sets pass-through. A fresh deploy is not affected.
- Fix used: delete the empty Free-tier store, then run the what-if again. Changing the mode on a store that already
  holds key values would hit the same limit, so set pass-through when the store is first created.

## 2026-11-09 (soft delete reserves names)

- Correction to the entry above: deleting an App Configuration store soft-deletes it, even on the Free tier. The
  redeploy fails with `NameUnavailable: The specified name ... is already in use` until the owner purges it
  (`az appconfig purge`, with `az appconfig show-deleted` to list). Key Vault does the same for its name.
- Impact on M8: a teardown that deletes the resource group leaves both names reserved. Teardown steps must purge
  the vault and the store, or the next deploy needs a different suffix.

## 2026-11-09 (M2 deployed)

- The subscription-scope deployment `main` succeeded. Verified read-only: no failed operations in any module
  deployment; the resource group holds the App Configuration store, OpenAI account, ACR, Key Vault, storage account
  and five managed identities; `gpt-5-mini` 2025-08-07 (`GlobalStandard`, capacity 10) is `Succeeded`; the store runs
  in pass-through mode; App Configuration holds the six Bicep-derived keys (three keys, two labels); the four
  `kind` federated credentials have the expected subjects.
- Not yet done: the Key Vault secret (runbook step 2) and the config seed (step 3). Until the secret exists, `lab:secret`
  does not resolve.
- Not yet verified: the budget resource (it does not appear in a resource listing) and whether `gpt-5-mini` accepts API
  version `2024-10-21`.

## 2026-11-09 (subscription-scope deploy)

- Decision: every Azure resource comes from Bicep, so the resource group is declared too. `infra/main.bicep` now has
  subscription scope: it creates the group and calls `infra/resources.bicep` (group scope) as a module. The Make
  targets deploy at subscription scope, and the runbook no longer has a manual group step.
- A what-if against a missing resource group crashes the Azure CLI error handler (`AttributeError` and
  `RuntimeError: The content for this response was already consumed`) instead of printing
  `ResourceGroupNotFound`. Run it with `--debug` and filter for `"code"` and `"message"` to see the real error.
- Bicep cannot register resource providers. A deployment registers the ones it needs. The runbook keeps a one-line
  fallback for a what-if that reports a missing registration.
- `/bin/sh` is dash on this system. Make recipes must not use bash-only syntax such as `${!var}`.
