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

## 2026-11-09 (M3 charts)

- Helm is not installed here. The Makefile runs Helm v4.3.1 from the pinned `alpine/helm:4.3.1` image. Set `HELM=helm`
  to use a local binary. Unverified: whether `helm push` inside the container finds the registry credentials in
  `~/.docker`.
- Update: the owner installed Helm v4.3.1 at `/usr/local/bin/helm`. The Makefile now calls `helm` directly, and the
  Docker wrapper and the `~/.docker` credential question no longer apply. Lint and template pass with it.
- `make chart-lint` and `make chart-template` pass for `local` and `aks-dev` on both charts. The rendered output was
  read, not applied to a cluster.
- The Functions host runs on port 8080 with `ASPNETCORE_URLS`, all capabilities dropped and `no-new-privileges`.
  `/api/health` answers 200. The chart uses this, so the pod needs no `NET_BIND_SERVICE`.
- `local` values set `identity.projectedToken: true`. The chart then projects the service-account token and sets the
  `AZURE_*` variables. `aks-dev` relies on the AKS webhook through the `azure.workload.identity/use` label. This
  covers part of T-043. The Argo repo secret in that task is still open.
- Images and charts share one version, `0.1.0`, set in the root Makefile and in `gitops/envs/*`. ACR tags are mutable,
  so a second push replaces the first. M5 replaces this with commit-based tags.
- `gitops/envs/*` hold the ACR server, App Configuration endpoint, client IDs and tenant ID from the M2 outputs.
  They are identifiers, not secrets.
- The owner ran `make publish` and reports that both images and both charts reached ACR at `0.1.0`. Not checked by
  an agent: no repository listing was read.
- The guard hook scans the text of a Bash command, heredocs included. Edit the Makefile and docs with the Edit tool when
  the text names Azure-facing targets.

## 2026-11-09 (M4 cluster and issuer)

- `kind` v0.33.0 and `kubectl` v1.37.2 are installed in `/usr/local/bin`. kind creates the cluster `aks-lab` from
  `kindest/node:v1.37.0` in 16 s.
- Method: `scripts/kind-issuer.sh` makes an RSA key pair in `.local/oidc/` and writes the discovery document and the JWKS.
  kind mounts the pair over `/etc/kubernetes/pki/sa.key` and `sa.pub`, so kubeadm keeps it. The kubeadm patch sets
  `service-account-issuer` and `service-account-jwks-uri` with the `v1beta4` list form of `extraArgs`.
- Verified on kind: `/.well-known/openid-configuration` returns the lab issuer, and a token for audience
  `api://AzureADTokenExchange` carries that `iss`, `sub: system:serviceaccount:lab:probe` and a `kid` equal to the
  `kid` in the generated JWKS.
- Not yet verified: that Entra accepts the tokens. The documents are not published yet (the blob URL returns 404), and
  the first real token exchange comes with the api pod.
- The owner ran `make local-issuer-publish`. Verified by an agent: both documents answer 200 with
  `application/json` at the public URL and match `.local/oidc` byte for byte. `make local-up` passes its publish check.
  Entra acceptance of the tokens is still unverified until a pod exchanges one.
- Verified: `helm show chart` finds `gateway-helm` v1.10.0 on Docker Hub (OCI) and `argo-cd` 10.17.0 in argo-helm.
  Both projects are Apache 2.0. The `gateway` chart in `gitops/platform/gateway` lints and renders for both envs.
- Layout choice: the root app has two sources, `gitops/platform/local` (platform Applications) and `gitops/apps/local`
  (api and indexer). The Applications and the root app still carry the placeholder `git@github.com:OWNER/aks-lab.git`.
  Argo applies sync waves: Envoy Gateway 0, gateway chart 1, workloads 2.
- Unverified: Argo CD syncing an OCI Helm chart from `docker.io/envoyproxy` without a repository secret, and the
  multi-source `$values` reference with a chart from ACR. Both need the running cluster.
- The owner created the GitHub repository `giorgos-stefanakis/aks-lab`. The Applications now use its SSH URL.
- Supersedes the placeholder bullet above: the repo URL placeholder is gone, and every Application uses
  `git@github.com:giorgos-stefanakis/aks-lab.git`.
- Review fixes. Correction to the last bullet of this entry: the key file is mode 0600 now, not 0644. The kind API
  server reads it, because the cluster came up and a token carries the expected `kid`. The API server returns compact
  JSON for `/.well-known/openid-configuration`, so scripts compare parsed JSON (`jq -S`), not bytes.
- `local-up` now stops when an existing cluster serves a different issuer document than `.local/oidc`. The bootstrap
  also registers `docker.io/envoyproxy` as an OCI repository, because Argo CD pulls OCI Helm charts only from
  registered repositories. Unverified: that this is enough for Docker Hub.
- T-040 is back to `doing` until `make local-up` runs end to end, including the Argo CD install.
- Makefile cleanup: the root Makefile is the entry point. `make` prints the help. Public targets: `init`, `lint`,
  `test`, `format`, `infra-whatif`, `infra-deploy`, `publish`, `local-issuer-publish`, `local-up`, `local-down`.
  `lint` now includes Helm lint and render for all charts and both envs, and the Bicep lint. Removed `images`,
  `infra-lint`, `chart-lint`, `chart-template`, `local-issuer` and `check-lab-env`. The checks that remain are
  underscore targets and stay out of the help. Earlier entries use the old names. `make lint` exits 0.
- The private key file was mode 0644 when first written (see the correction above) so the API server can read it inside the node. It sits in `.local/`, which git ignores.

## 2026-11-09 (M4 Argo CD identity and image pull)

- The owner pushed `main` and ran `make local-up`. Verified on kind: Argo CD 3.x pods run, `root` and
  `envoy-gateway` are `Synced` and `Healthy`, and the Envoy Gateway pod runs. So Argo CD pulled the OCI chart
  `docker.io/envoyproxy/gateway-helm` v1.10.0 through the registered repo `repo-envoyproxy`.
- First run: `gateway`, `api` and `indexer` showed sync `Unknown` with `ComparisonError ... DeadlineExceeded`. No ACR
  repository was registered in Argo CD, and the `api` and `indexer` chart pulls from ACR hung.
- Fix (T-043): `gitops/clusters/local/argocd-values.yaml` gives the repo-server the `argocd` identity (service-account
  annotation, projected token, `AZURE_*` variables). The bootstrap registers `acrlabyntm5u.azurecr.io/charts` as an OCI
  repository with `useAzureWorkloadIdentity`. `make local-up` on the existing cluster applies both.
- Verified on kind after the fix: `api`, `indexer` and `gateway` are `Synced`. Argo CD pulled both charts from ACR with
  workload identity. So Entra accepts tokens from the kind issuer (T-044).
- Open: the `api` and `indexer` pods fail with `ImagePullBackOff`. The kubelet pulls anonymously and ACR returns 401.
  Workload identity covers pods, not the kubelet. T-045 adds the pull secret.
- T-045 written, not verified: External Secrets Operator chart 2.14.0 (app v2.14.0, Apache 2.0) from
  `charts.external-secrets.io`. An `ACRAccessToken` generator in `lab` writes the `acr-pull` secret, and the `api` and
  `indexer` local values reference it.
- Source check, ESO `main` (`generators/v1/acr/acr.go`): with `auth.workloadIdentity` and no `serviceAccountRef`, the
  generator reads `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` and `AZURE_FEDERATED_TOKEN_FILE` from the controller process. So
  the controller uses its own federated identity, `external-secrets:external-secrets`, which Bicep federates. With no
  `scope`, the password is an ACR refresh token and the username is the null GUID. In chart 2.14.0 `ExternalSecret` is
  served as `external-secrets.io/v1` and `ACRAccessToken` as `generators.external-secrets.io/v1alpha1`.
- `git ls-remote` over SSH hangs in the agent shell, most likely on a passphrase prompt. The agent cannot reach
  GitHub over SSH. Use the local `origin/main` ref, or ask the owner.
- Layout change, supersedes the layout bullet of the M4 cluster entry: Applications live in
  `gitops/clusters/<cluster>/{platform,apps}`, with `root.yaml` and `argocd-values.yaml` beside them. Content without
  an environment lives in `gitops/components/` (the `gateway` chart, the `acr-pull` manifests). Values stay in
  `gitops/envs/<env>/`, the path SPEC.md and D-13 name. The root app still has two sources, so it never parses
  `argocd-values.yaml`.
- The owner pushed `main` and re-applied the root app. Verified on kind: `external-secrets`, `acr-pull`, `api` and
  `indexer` are `Synced` and `Healthy`. The `acr-pull` ExternalSecret is `SecretSynced`, and both pods pulled their
  images from ACR with it. So the ESO `ACRAccessToken` generator works with the controller's own federated identity
  (T-045).
- Verified on kind: `GET /config` on the api returns label `local`, the App Configuration values, the feature flag and
  `secret: resolved`. So the api pod exchanges its projected token with Entra and reads App Configuration and Key Vault
  (T-043).
- Open: the indexer host reports `azure.functions.webjobs.storage` as `Unhealthy`. The HTTP triggers still answer.
- Open (T-042): the `gateway` app stays `Progressing`. The Gateway is `Accepted` but `Programmed=False` with
  `AddressNotAssigned`, because the Envoy proxy Service is `LoadBalancer` and kind has no load balancer. It stays
  `<pending>`.
- Fix (T-042): the local `gateway` values set `envoyServiceType: ClusterIP`. The chart then creates an `EnvoyProxy` and
  points the `envoy` GatewayClass at it. Verified on kind at `9a52f39`: the proxy Service is `ClusterIP`, the Gateway
  is `Programmed` with that IP as its address, and all seven Applications are `Synced` and `Healthy`. Through a
  port-forward to the Envoy Service, `/healthz` returns 200 and `/config` returns `secret: resolved`.

## 2026-11-09 (M4 acceptance checks on kind)

- Check 4 passes on kind at `9dc52da`. Through a port-forward to the Envoy Service, `POST /chat` returns 200 with an
  answer from deployment `gpt-5-mini`.
- Check 5 passes on kind at `9dc52da`. `POST /index` returns 200 with `chunks`, `chunk_size: 200` and
  `chunk_overlap: 20`. So the api reaches the indexer, and the indexer reads its values from App Configuration.
- The indexer storage warning: the Functions host logs `azure.functions.webjobs.storage` `Unhealthy` ("Unable to
  create client for AzureWebJobsStorage") about every 30 s. The indexer sets no `AzureWebJobsStorage`, and SPEC.md
  lists no storage for it. HTTP triggers do not need it, and the readiness probe on `/api/health` passes. Kept as is.
- Usage for the AKS node size: the kind node container uses 2.6 GiB of memory with Argo CD, Envoy Gateway, External
  Secrets Operator, api and indexer running. One `docker stats` sample, no metrics-server.
- Check 1 passes on kind. After `make local-down`, `make local-up` took 74 s. Argo CD then brought all seven
  Applications to `Synced` and `Healthy` in 173 s, with no manual `kubectl apply`. Check 2 passes again on the new
  cluster.
- Check 3 passes on kind. `GET /config` was polled every 5 s while the owner changed App Configuration. Sentinel `2`
  appeared at 22:44:42. The owner then set `lab:message` (label `local`) and sentinel `3`. Both appeared together at
  22:47:16. The api pod had 0 restarts. A value saved under another label does not show, because the provider selects
  label `local` only.
- M4 is done: acceptance checks 1 to 5 pass on kind.
- The guard hook also matches `kubectl apply` in heredoc text, even with no command. Append to docs with the Edit tool.

## 2026-11-09 (M5 release flow)

- Decided with the owner: a `vX.Y.Z` tag on `main` publishes images and charts at `X.Y.Z` and creates a GitHub
  release. The release job then pins the chart `targetRevision` for `local` in git and pushes that commit to `main`.
  `aks-dev` gets a promotion pull request in M6 (T-063). Git stays the record of what runs, and every version stays
  pinned. SPEC.md check 6 and D-13 say this. No release branch and no Poetry version bump: the apps have
  `package-mode = false`.
- The chart image tag defaults to the chart `appVersion`, so one `targetRevision` line sets both chart and image.
- The deploy step skips the commit when `local` already runs the same or a newer version (`sort -V`). Simulated on
  copies of the Application files: `0.2.0` and `0.10.0` deploy, `0.9.0` and a repeat of `0.10.0` are skipped, and the
  git source `targetRevision: main` is untouched. Unverified: that the bot push to `main` succeeds. It needs `main`
  unprotected, or a bypass for the job.
- Entra federated credentials match the subject exactly, with no wildcards. A tag subject would need one credential per
  tag, so the release job runs in the GitHub environment `release` (`repo:<owner>/<repo>:environment:release`). The
  environment admits only `v*` tags, because any job in it can sign in as `id-lab-github`.
- Pull requests get no credential on `id-lab-github`. It holds `AcrPush`, so a pull-request run could push a chart.
  T-052 adds a separate read-only identity for the what-if.
- `AcrPush` has no control-plane read. `publish` signs in with `az acr login --expose-token` and `docker login`.
  Unverified: that `az acr login` gets a token with `AcrPush` alone. The az CLI source falls back to `<name>.azurecr.io`
  when the registry lookup fails.
- The published `0.1.0` charts require `image.tag`. The values must keep `image.tag` until a release publishes charts
  that default to `appVersion`, so the gitops switch is a separate commit, pushed after the first release.
- Action pins, at least two weeks old, all MIT: `actions/checkout` v7.0.1, `actions/setup-python` v7.1.0,
  `azure/login` v3.1.0, `azure/setup-helm` v5.0.1. Poetry 2.5.1 comes from `pipx`. Unverified: that `pipx` is
  preinstalled on `ubuntu-24.04` runners, and that `setup-python` has Python 3.12.16 from `.python-version`.
- `make -n` runs recipe lines that contain `$(MAKE)`. A dry run of `publish` ran `az acr login`, which failed on a fake
  subscription ID. Do not dry-run targets that call Azure.
- `make publish` has no default `VERSION`. A default from `Chart.yaml` would overwrite the released `0.1.0`.

## 2026-11-10 (first release run)

- The `v0.2.0` release job failed at `azure/login` with `AADSTS700213`. GitHub presented the subject
  `repo:giorgos-stefanakis@351529295/aks-lab@1451541745:environment:release`, with the owner and repository IDs.
  This corrects the M5 entry: the subject is not `repo:<owner>/<repo>:...` for this repository. The IDs keep the
  subject valid across a rename or a re-created repository. `githubRepository` in `lab.bicepparam` now holds that form.
- The `check` job passed on GitHub: lint and test, Helm 4.3.1, Bicep 0.49.2, Poetry from `pipx`, Python from
  `.python-version`.
- After the owner deployed the subject fix, the re-run `v0.2.0` release passed. So `az acr login --expose-token`
  works with `AcrPush` alone, and the bot push to the unprotected `main` works. The job pushed
  `chore(gitops): deploy v0.2.0 to local` (`1e0b67c`). On kind both pods ran the `0.2.0` images.
- Check 6 passes on kind. The owner pushed tag `v0.2.1` on `12458b9`. With no further step, the job pushed the deploy
  commit `fd9840c`, and Argo synced `api` and `indexer` to chart `0.2.1`. Both pods ran the `0.2.1` images 258 s after
  the push, with all Applications `Synced` and `Healthy`.
- Decided with the owner: no Azure access from pull requests. T-052 (`infra.yml`, what-if with a read-only identity) is
  dropped. Pull requests still run `check` in `apps.yml`, which needs no Azure. The owner runs the what-if with `make`.
  M5 is done.
- Decided with the owner: `aks-dev` gets no promotion pull request. In M6 the release job pins `aks-dev` in the same
  deploy commit as `local` (T-063). This supersedes the promotion bullet in the M5 release flow entry.

## 2026-11-10 (M6 AKS)

- The owner asked for the Azure Verified Module for AKS. Latest is `avm/res/container-service/managed-cluster` 0.14.0
  (published 2026-07-20, MIT). It deploys `managedClusters@2025-10-01` and builds `ingressProfile` itself: only
  `webAppRouting` with NGINX. It has no input for the managed Gateway API CRDs or app routing Istio.
- Bicep 0.49.2 type check: `ingressProfile.gatewayAPI` and `webAppRouting.gatewayAPIImplementations.appRoutingIstio`
  give `BCP037` at API `2025-10-01` and `2026-01-01`, and are accepted from `2026-02-01`. So a raw resource could set
  them; AVM cannot.
- Decided with the owner: AVM for the cluster, and Envoy Gateway on AKS as on kind. GatewayClass `envoy` on both
  clusters. The Envoy LoadBalancer Service binds the static IP `pip-lab-gateway` in the lab resource group through the
  `azure-load-balancer-resource-group` and `azure-pip-name` annotations. This departs from SPEC.md (cluster
  components, `approuting-istio`) and D-09; the owner updates them.
- AVM 0.14.0 defaults that differ from the lab: `skuTier: Standard`, `publicNetworkAccess: Disabled`,
  `azurePolicyEnabled: true`, `omsAgentEnabled: true`, `enableTelemetry: true`, `autoUpgradeProfile: stable`.
  `infra/aks.bicep` overrides each. Workload identity has no flag of its own; it goes through `securityProfile`.
  `disableLocalAccounts` defaults to `true`, so the cluster uses Entra with Azure RBAC and `kubelogin`.
- AKS versions in `swedencentral` on 2026-11-10: 1.31 to 1.37, default 1.36 (latest patch 1.36.5). Pinned 1.36.5.
- Quota in `swedencentral`: 4 regional vCPU, 2 used by VM `lab-vm-test` outside the lab resource group. The Bsv2
  family limit is 4. Three `Standard_B2s_v2` nodes need 6. Decided with the owner: `LAB_AKS_NODE_COUNT` sets the node
  count, default 3. `Standard_B2s_v2` has no SKU restrictions for this subscription in `swedencentral`.
- The AVM module deployment is named `aks-cluster`, not `aks`, so it cannot clash with the top-level deployment
  `aks` in the same resource group. Not tested with the clashing name.
- The cluster is its own deployment (`infra/aks.bicep`, deployment name `aks`), so `make aks-down` can remove it
  without the control plane. The AKS federated credentials sit in it. ESO has none on AKS: the kubelet pulls images.
- `scripts/local-bootstrap.sh` is now `scripts/argocd-bootstrap.sh <cluster> <context>`. Re-run on kind: every repo
  secret and the root app report `unchanged`.
- The gateway chart takes `envoyService.type` and `envoyService.annotations` instead of `envoyServiceType`. The
  `local` render is byte-identical to the one before.
- Unverified until the owner deploys: that `Network Contributor` on the resource group lets the cloud provider bind
  the IP; that the cloud provider leaves the DNS label set by Bicep; that `kubelogin convert-kubeconfig` accepts
  `--context`; that Envoy Gateway's default `externalTrafficPolicy: Local` gives a healthy Azure load balancer probe.

## 2026-11-10 (Bicep by concern)

- Layout: `infra/names.bicep` exports the shared names, role IDs and token audience. Each resource module grants the
  owner's role on its own resource (App Configuration, Key Vault, issuer storage). `identities.bicep` holds the three
  workload identities and their data roles. `github.bicep` and `kind.bicep` (issuer storage, ESO identity) hold what
  only GitHub or kind needs. `federation.bicep` writes one credential per identity for one issuer; `resources.bicep`
  calls it for kind and `aks.bicep` for AKS.
- `appconfig-values.bicep` is gone. It existed only to run the key values after the owner's Data Owner role, which
  lived in `identities.bicep`. The role is now in `appconfig.bicep`, and the key values depend on it there.
  This supersedes the module split in the "role assignments in one module" entry.
- Verified: `az deployment sub what-if` of the refactored `main.bicep` against the live lab equals the what-if of the
  committed templates: the same 36 resources, no Create or Delete, the same property diffs. So every resource ID and
  role-assignment name is unchanged. The 21 `Modify` entries in both are what-if noise: references it cannot resolve
  across modules, and server-side defaults.
- Found with what-if: passing the nullable AVM output `oidcIssuerUrl` as a module parameter fails with
  `InvalidTemplate ... parameter 'issuer' ... is not provided` while the cluster does not exist. The same output in a
  resource property passes. `aks.bicep` reads the issuer from an `existing` reference to the cluster instead. Its
  what-if then succeeds: 8 creates (cluster, public IP, three role assignments, three `aks` credentials).
- Federation order: the kind and AKS credentials sit in separate deployments, so they never write to the same
  identity at the same time.
- Renamed `infra/names.bicep` to `infra/common.bicep`, because it also holds role IDs and the token audience.

## 2026-11-10 (Clusters as plugins)

- Decided with the owner: each cluster is a plugin. `infra/clusters/kind.bicep` and `infra/clusters/aks.bicep` each
  hold everything only that cluster needs: federated credentials, cluster-only identities and roles, and the derived
  key values of its App Configuration label. `main.bicep` keeps only what every cluster shares. This supersedes the
  layout bullet of the "Bicep by concern" entry, where the kind federation sat in `resources.bicep`.
- Decided with the owner: each plugin deploys as a deployment stack with `--action-on-unmanage deleteResources` and
  `--deny-settings-mode none`, so deleting the stack deletes what the plugin added. `main` stays a plain incremental
  deployment. This departs from D-12 (incremental mode only); the owner updates it.
- A stack has no `--confirm-with-what-if`, as far as known. The `kind-deploy` and `aks-up` targets run a deployment
  group what-if on the same template and ask for confirmation first. Unverified: the stack CLI flags, and whether its
  `--parameters` takes a `.bicepparam` file. The guard hook blocks agents from reading the stack CLI help.
- Bicep 0.49.2: a loop collection that references `existing` resource properties fails with `BCP178`.
  `modules/appconfig-values.bicep` loops over static keys and reads the runtime values from a separate map.
- `federation.bicep` finds identities by name, so Bicep sees no dependency on the ESO identity in the same template.
  The kind plugin sets `dependsOn: [eso]` on the federation call. A what-if against the live lab cannot show this,
  because the identity exists.
- Verified locally: `az bicep lint` and `build-params` pass for `main.bicep` and both plugins. The compiled
  non-`existing` resources of the new `main.bicep` plus the kind plugin match the committed `main.bicep` one to one.
  The name and GUID expressions differ only in form: functions from `common.bicep` instead of module parameters, and
  one credential loop instead of four resources. Not verified against Azure: that needs the owner's what-ifs
  (docs/RUNBOOK.md, "Moving the live lab to plugins").

## 2026-11-10 (AKS first deploy)

- The `aks` stack deployed and the cluster has two nodes, both `Ready` on v1.36.5 (Ubuntu 24.04, containerd 2.3.7).
  The pinned version is the live version.
- Argo CD installed. The `root` app reports `Sync Unknown`: `gitops/clusters/aks-dev/platform: app path does not exist`.
  The repo server reaches GitHub and checks out `main`, but `main` does not hold `gitops/clusters/aks-dev` yet. The
  Gateway CRDs are missing for the same reason. Fix: push the `aks-dev` gitops files to `main`.
- After `main` held `gitops/clusters/aks-dev`: all five Applications `Synced` and `Healthy`. Gateway `lab` (class
  `envoy`) is `Programmed` at `4.165.97.175`, the external IP of the Envoy LoadBalancer Service.
  `curl http://4.165.97.175/config` returns 200 with label `aks-dev` and `secret: resolved`.
- Settles two of the unverified items: `kubelogin convert-kubeconfig` accepts `--context`, and the Azure load balancer
  probe is healthy with Envoy's default `externalTrafficPolicy: Local`. Still open: that the address is the static
  `pip-lab-gateway` and not a dynamic IP, and that the cloud provider left the DNS label.
- `pip-lab-gateway` has IP `4.165.97.175` and FQDN `aks-lab-yntm5u.swedencentral.cloudapp.azure.com`. The gateway
  address is the static IP, so `Network Contributor` on the resource group lets the cloud provider bind it, and the
  cloud provider leaves the DNS label set by Bicep. This closes the M6 unverified items. The endpoint serves plain
  HTTP only until M7.
- The owner ran the plugin migration on the live lab: the `main` what-if and the `kind` what-if both passed, and both
  deploys worked. The `aks` stack was a first deploy, so it did not exercise adoption. This closes T-065.
- Release v0.2.2: the release job pushed one deploy commit, `d2fa728`, that pins `local` and `aks-dev` to `0.2.2`. AKS
  pulled both charts and runs `api:0.2.2` and `indexer:0.2.2`, and `/config` still returns label `aks-dev`. This
  closes T-063.
- On kind the `api` and `indexer` Applications carry target `0.2.2` but stay `Sync Unknown` with `DeadlineExceeded` while
  the repo server generates the chart source. Pods still run `0.2.1`. DNS for ACR, Entra, the issuer storage and GitHub
  resolves from the repo server, and git sources render. Cause not found. Entra resolves to an IPv6 address first.
- Correction: kind caught up to `0.2.2` minutes later without further action. All seven Applications are `Synced` and
  `Healthy` and both pods run `0.2.2`. The `DeadlineExceeded` was transient, most likely the repo server after the
  restart 141 minutes earlier. The IPv6 lead is unproven and not needed.

## M7: public ingress

- `helm lint` passes on the `gateway` chart with the `aks-dev` values, and the `local` render holds no TLS objects.
- Cause of the recurring kind `DeadlineExceeded` (supersedes the "transient" and IPv6 notes above): the repo server
  cannot open TCP port 22 to GitHub. Its log shows `failed to list refs: dial tcp 140.82.121.3:22: connect: connection
  timed out`, after about 135 s, which exceeds the 60 s manifest deadline. From the repo-server pod and from the host,
  `github.com:22` times out, while `github.com:443`, `ssh.github.com:443` and the ACR endpoint on 443 connect. So the
  block is on the workstation network, not in Argo CD. Apps served from the manifest cache stay `Synced`. Apps that
  need a fresh git fetch (`acr-pull`) or a fresh resolve (`api`) go `Unknown`. AKS is not affected.
- Verified on AKS (check 8): cert-manager v1.21.3 issued `lab-tls` through the http-01 `gatewayHTTPRoute` solver, first from
  Let's Encrypt staging and then from production after the issuer switched and the Secret was reissued. `curl
  https://aks-lab-yntm5u.swedencentral.cloudapp.azure.com/healthz` returns 200 with certificate verification passing.
  The issuer is `Let's Encrypt` CN=YR1 and the certificate expires 2027-02-08. Staging certificates do not satisfy the
  browser, so the staging step cost one extra commit. This closes T-070 and M7.
- kind recovered after the repo URL moved to `ssh.github.com:443`: all seven Applications are `Synced` and `Healthy`.

## M9: app registration path

- The owner deployed the draft `infra/app-registration.bicep`. The tenant lists one application `app-lab-api` with
  client ID `35fc1cca-944b-4519-9822-f1de2e1c422e`. The draft requests no Graph permission, so no consent step exists
  yet. The `az ad` commands take no `--subscription`, so `guard-bash` blocks them and the owner runs them.
- The kind `api` runs chart and image `0.2.2`, which have no `/graph` and no `graphClientId`. Argo CD self-heals the
  Deployment. M9 tests on kind need a release first.
- Release v0.3.0 reached kind: the `api` pod runs `0.3.0`. Failure case 3 (T-099), `GET /graph` on a managed-identity
  pod with `GRAPH_CLIENT_ID` unset: the response is 502 `Graph call failed: HTTPStatusError`. The log shows `403
  Forbidden` from `GET /v1.0/organization`. The token request succeeds and Graph refuses it, because the managed
  identity holds no Graph role.
- Failure case 1 (T-099), Graph call before admin consent: kind with `config.graphClientId` set to the registration
  and the managed identity kept. `GET /graph` returns 502 `Graph call failed: HTTPStatusError`, and the log shows `403
  Forbidden` from `GET /v1.0/organization`. The token request succeeded, so the kind federated credential (issuer,
  subject, audience) works. Only the Graph permission is missing.
