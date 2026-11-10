# Runbook

Setup steps the owner runs by hand. Agents do not run them. Sections are added as milestones land.
The acceptance walk-through lives in `docs/DEMO.md`.

## M2: Azure control plane

Fill in `.lab.env` first (see `.lab.env.example`), then load it:

```bash
set -a; source .lab.env; set +a
SUB=(--subscription "$LAB_SUBSCRIPTION_ID")
```

### 1. Deploy

The template runs at subscription scope. It creates the resource group and the control plane: what every cluster
shares. Each cluster adds its own Azure resources as a plugin, a deployment stack from `infra/clusters/` (M4, M6).
Dropping a plugin deletes exactly what it added. Never deploy two plugins at once: both write federated credentials on
the same identities.

```bash
make infra-whatif
make infra-deploy
```

`infra-deploy` shows the what-if again and waits for your confirmation.

A deployment registers the resource providers it needs. If the what-if reports a missing registration, register that
provider once and run it again: `az provider register "${SUB[@]}" --namespace <Microsoft.Provider>`.
Bicep cannot declare provider registration.

Read the names that later steps need:

```bash
out() { az deployment sub show "${SUB[@]}" -n main --query "properties.outputs.$1.value" -o tsv; }
VAULT=$(out keyVaultName); SECRET=$(out secretName); CONFIG=$(out appConfigName)
```

Role assignments can take a few minutes to take effect. Retry a data-plane command that fails with 403.

### 2. Set the Key Vault secret

Bicep never holds this value. The apps fail at startup until the secret exists.

```bash
read -rs -p "Secret value: " value; echo
printf %s "$value" | az keyvault secret set "${SUB[@]}" --vault-name "$VAULT" --name "$SECRET" \
  --file /dev/stdin --encoding utf-8 --output none
unset value
```

### 3. Seed App Configuration

`config/seed.json` holds the values you tune: message, sentinel, chunk settings and the feature flag.
Bicep owns only the values that derive from other resources. A later import overwrites the keys it lists,
so run it again only to reset them. Portal edits survive a redeploy.

```bash
az appconfig kv import "${SUB[@]}" --name "$CONFIG" --auth-mode login --yes \
  --source file --path config/seed.json --format json --profile appconfig/kvset
az appconfig kv list "${SUB[@]}" --name "$CONFIG" --auth-mode login --label local --query "[].key" -o tsv
```

The list shows the seeded keys. Each cluster plugin adds three keys for its label: the OpenAI endpoint and deployment,
and the Key Vault reference.

## M3: Publish images and charts

Needs M2 deployed and Docker running. Load `.lab.env` as in M2.

```bash
make lint
make publish VERSION=0.1.0
```

`publish` builds both images, signs in to ACR with your Azure login, pushes `api` and `indexer` at `VERSION`, and
pushes the two charts to `oci://<acr>/charts`. From M5 on, releases come from tags, not from this target. Never
publish a version that already exists: ACR tags are mutable, and the push replaces it. Check the result:

```bash
ACR=$(out acrName)
az acr repository list "${SUB[@]}" --name "$ACR" -o tsv
```

The list shows `api`, `indexer`, `charts/api` and `charts/indexer`.

## M4: Local cluster

Needs `kind`, `kubectl` and `helm` on `PATH`, and Docker running.

### 1. Deploy the kind plugin

The stack `kind` (`infra/clusters/kind.bicep`) holds what only kind needs from Azure: the issuer storage account,
the ESO identity and its `AcrPull`, the `kind` federated credentials, and the key values of label `local`.

```bash
make kind-whatif
make kind-deploy
```

`kind-deploy` shows the what-if again and asks before it creates or updates the stack. `make kind-drop` deletes the
stack and everything in it. After a drop and a new deploy, publish the issuer documents again (step 2).

### 2. Publish the issuer

The kind cluster signs service-account tokens with a key pair that stays in `.local/` (ignored by git). Entra checks
those tokens against two public documents in the issuer storage account. Publish them before the cluster starts.

Add the issuer URL to `.lab.env` (no trailing slash), then load it again:

```bash
stackout() { az stack group show "${SUB[@]}" -g "$LAB_RESOURCE_GROUP" -n "$1" --query "outputs.$2.value" -o tsv; }
echo "LAB_ISSUER_URL=$(stackout kind issuerUrl)" >> .lab.env
set -a; source .lab.env; set +a
make local-issuer-publish
```

The target makes the key pair and the documents, uploads both files, and reads them back over HTTPS to compare.
Your account needs `Storage Blob Data Contributor` on the account, which Bicep grants. A 403 right after the deploy
usually means the role has not propagated yet: retry in a few minutes.

The key pair is the identity of the cluster. Keep `.local/oidc/sa.key`. If you delete it, publish the new documents
again and recreate the cluster.

### 3. Give Argo CD read access to the repository

Argo CD reads the GitHub repository over SSH with a read-only deploy key. The private half stays in
`.local/argocd-deploy-key`. Generate it with `ssh-keygen -t ed25519 -N "" -f .local/argocd-deploy-key`. Add
`.local/argocd-deploy-key.pub` in the repository under Settings, Deploy keys. Leave "Allow write access" off.

The `aks-dev` Applications under `gitops/` point at `git@github.com:giorgos-stefanakis/aks-lab.git`. The `local` ones use
`ssh://git@ssh.github.com:443/giorgos-stefanakis/aks-lab.git`, for networks that block port 22. Push `main` before
`make local-up`, because Argo syncs from `main`, not from your working tree.

### 4. Create the cluster

```bash
make local-up
```

`local-up` creates the cluster, installs Argo CD and applies the root app. It stops when the published issuer document
differs from `.local/oidc`, or when an existing cluster uses another issuer. In the second case run `make local-down`
first. `make local-down` deletes the cluster and keeps the key pair.

On an existing cluster, `local-up` upgrades Argo CD and re-applies the repository secrets from your working tree.
Run it again after a change to `gitops/clusters/local/argocd-values.yaml` or `scripts/argocd-bootstrap.sh`.

### 5. Check the image pull secret

The kind kubelet has no Azure identity. External Secrets Operator makes the `acr-pull` secret in `lab`, and the
workloads pull with it.

```bash
kubectl --context kind-aks-lab -n lab get externalsecret acr-pull
kubectl --context kind-aks-lab -n lab get pods
```

The ExternalSecret shows `SecretSynced`, and the `api` and `indexer` pods run.

## M5: Release from a tag

A `vX.Y.Z` tag on `main` runs the `release` job in `.github/workflows/apps.yml`. It publishes both images and both
charts at `X.Y.Z` and creates a GitHub release. Then it sets the chart `targetRevision` in
`gitops/clusters/local/apps/` and `gitops/clusters/aks-dev/apps/` to `X.Y.Z` and pushes that one commit to `main`.
Argo CD syncs it on each cluster. The chart's image tag
defaults to its `appVersion`, so that one line sets both the chart and the image. The job skips the commit when
`local` already runs the same or a newer version.

### 1. Deploy the GitHub federated credentials

Load `.lab.env` as in M2, then:

```bash
make infra-whatif
make infra-deploy
```

The what-if adds one federated credential to `id-lab-github`: `github-release`.

### 2. Create the environment and the variables

Create the environment `release` and allow only `v*` tags to deploy to it. Any job in that environment can sign in
as `id-lab-github`, so a branch must not reach it. Then set four repository variables. They are identifiers, not
secrets.

```bash
REPO=repos/giorgos-stefanakis/aks-lab
gh api -X PUT "$REPO/environments/release" --input - <<< \
  '{"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}'
gh api -X POST "$REPO/environments/release/deployment-branch-policies" -f name='v*' -f type=tag
gh api "$REPO/environments/release/deployment-branch-policies" --jq '.branch_policies[] | [.name, .type]'
gh variable set AZURE_CLIENT_ID --body "$(az deployment sub show "${SUB[@]}" -n main --query properties.outputs.identityClientIds.value.github -o tsv)"
gh variable set AZURE_TENANT_ID --body "$LAB_TENANT_ID"
gh variable set AZURE_SUBSCRIPTION_ID --body "$LAB_SUBSCRIPTION_ID"
gh variable set ACR_LOGIN_SERVER --body "$(out acrLoginServer)"
```

### 3. Release

```bash
git tag -a v0.2.0 -m "Release v0.2.0"
git push origin v0.2.0
```

The `release` job checks that the tag is `vX.Y.Z` and sits on `main`. Watch it with `gh run watch`, then pull the
deploy commit with `git pull --rebase`.

First release only: the `0.1.0` charts need `image.tag` in the values. Push `main` up to the commit before the one that
removes `image.tag`, then tag `v0.2.0`. After the job pins `0.2.0`, rebase that last commit onto the deploy commit and
push it. Pushing it earlier breaks kind, because `0.1.0` charts do not default to `appVersion`.

## M6: AKS

Needs `kubectl`, `helm` and `kubelogin` on `PATH` (`az aks install-cli` installs `kubectl` and `kubelogin`).
The cluster is the plugin stack `aks` (`infra/clusters/aks.bicep`). It reads the ACR and the identities that
`main.bicep` made.

### 1. Check the quota

Three `Standard_B2s_v2` nodes need 6 vCPU of regional quota and 6 of the `standardBsv2Family` quota in the region.

```bash
az vm list-usage "${SUB[@]}" --location "$LAB_LOCATION" -o json \
  | jq -r '.[] | select(.name.value == "cores" or .name.value == "standardBsv2Family") | [.name.value, .currentValue, .limit] | @tsv'
```

If the free quota is short, request more in the portal (Quotas, Compute), or set `LAB_AKS_NODE_COUNT=1` in `.lab.env`.
One node fits the lab: kind used 2.6 GiB with every component running.

### 2. Deploy and bootstrap

Load `.lab.env` as in M2. Push `main` first, because Argo syncs from `main`.

```bash
make aks-whatif
make aks-up
```

The what-if creates the cluster `aks-lab`, the public IP `pip-lab-gateway`, a federated credential named `aks` on
`id-lab-api`, `id-lab-indexer` and `id-lab-argocd`, `AcrPull` for the kubelet identity, `Network Contributor` on the
resource group for the cluster identity, `Azure Kubernetes Service RBAC Cluster Admin` for you, and the three key
values of label `aks-dev`.

`aks-up` shows the what-if again and asks before it creates or updates the stack. Then it writes the kubeconfig context `aks-lab`,
converts it to `kubelogin` with your az CLI sign-in, installs Argo CD and applies the root app for `aks-dev`. It
reuses the deploy key from M4. Run it again after a change to `gitops/clusters/aks-dev/argocd-values.yaml`.

### 3. Check

```bash
kubectl --context aks-lab -n argocd get applications
kubectl --context aks-lab -n lab get gateway lab
stackout aks gatewayFqdn
```

All five Applications are `Synced` and `Healthy`, and the Gateway address is the public IP. Until M7 the gateway
serves plain HTTP: `curl http://<fqdn>/config` shows label `aks-dev` and `secret: resolved`.

### 4. Drop

```bash
make aks-down
```

`aks-down` deletes the stack `aks` and everything it holds: the cluster, the public IP, its role assignments, the
`aks` federated credentials and the `aks-dev` key values. It asks first. The control plane and kind stay.

## Moving the live lab to plugins

Before the plugin layout, `main` held the kind resources and the key values of both labels. Moving them deletes and
recreates nothing, because the names stay the same:

1. `make infra-whatif`. Expect no Create and no Delete. The kind resources and the key values now show as `Ignore`:
   `main` no longer manages them, and incremental mode leaves them in place.
2. `make kind-whatif`. Expect no Create: the stack adopts the existing resources. Then `make kind-deploy`.
3. The `aks-dev` key values stay unmanaged until the first `make aks-up` adopts them.
