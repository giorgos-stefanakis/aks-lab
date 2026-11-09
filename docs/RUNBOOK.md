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

The template runs at subscription scope. It creates the resource group and everything in it.

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

The list shows the seeded keys and the three that Bicep created.

## M3: Publish images and charts

Needs M2 deployed and Docker running. Load `.lab.env` as in M2.

```bash
make lint
make publish
```

`publish` builds both images, signs in to ACR with your Azure login, pushes `api` and `indexer` at `0.1.0`, and
pushes the two charts to `oci://<acr>/charts`. Check the result:

```bash
ACR=$(out acrName)
az acr repository list "${SUB[@]}" --name "$ACR" -o tsv
```

The list shows `api`, `indexer`, `charts/api` and `charts/indexer`.

## M4: Local cluster

Needs `kind`, `kubectl` and `helm` on `PATH`, and Docker running.

### 1. Publish the issuer

The kind cluster signs service-account tokens with a key pair that stays in `.local/` (ignored by git). Entra checks
those tokens against two public documents in the issuer storage account. Publish them before the cluster starts.

Add the issuer URL to `.lab.env` (no trailing slash), then load it again:

```bash
echo "LAB_ISSUER_URL=$(out localIssuerUrl)" >> .lab.env
set -a; source .lab.env; set +a
make local-issuer-publish
```

The target makes the key pair and the documents, uploads both files, and reads them back over HTTPS to compare.
Your account needs `Storage Blob Data Contributor` on the account, which Bicep grants. A 403 right after the deploy
usually means the role has not propagated yet: retry in a few minutes.

The key pair is the identity of the cluster. Keep `.local/oidc/sa.key`. If you delete it, publish the new documents
again and recreate the cluster.

### 2. Give Argo CD read access to the repository

Argo CD reads the GitHub repository over SSH with a read-only deploy key. The private half stays in
`.local/argocd-deploy-key`. Generate it with `ssh-keygen -t ed25519 -N "" -f .local/argocd-deploy-key`. Add
`.local/argocd-deploy-key.pub` in the repository under Settings, Deploy keys. Leave "Allow write access" off.

The Applications under `gitops/` point at `git@github.com:giorgos-stefanakis/aks-lab.git`. Push `main` before
`make local-up`, because Argo syncs from `main`, not from your working tree.

### 3. Create the cluster

```bash
make local-up
```

`local-up` creates the cluster, installs Argo CD and applies the root app. It stops when the published issuer document
differs from `.local/oidc`, or when an existing cluster uses another issuer. In the second case run `make local-down`
first. `make local-down` deletes the cluster and keeps the key pair.
