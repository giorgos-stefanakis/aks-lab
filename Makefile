APPS := apps/api apps/indexer
CHARTS := api indexer
ENVS := local aks-dev
GATEWAY_CHART := gitops/components/gateway
HELM ?= helm
ISSUER_URL = $(patsubst %/,%,$(LAB_ISSUER_URL))

-include .lab.env
export LAB_TENANT_ID LAB_SUBSCRIPTION_ID LAB_LOCATION LAB_RESOURCE_GROUP LAB_BUDGET_EMAIL LAB_OWNER_OBJECT_ID LAB_ISSUER_URL LAB_AKS_ISSUER_URL LAB_API_APP_SP_ID LAB_AKS_NODE_COUNT

DEPLOY_ARGS = --subscription $(LAB_SUBSCRIPTION_ID) --location $(LAB_LOCATION) --name main \
	--template-file infra/main.bicep --parameters infra/params/lab.bicepparam
RG_ARGS = --subscription $(LAB_SUBSCRIPTION_ID) --resource-group $(LAB_RESOURCE_GROUP)
KIND_ARGS = $(RG_ARGS) --name kind --template-file infra/clusters/kind.bicep --parameters infra/params/kind.bicepparam
AKS_ARGS = $(RG_ARGS) --name aks --template-file infra/clusters/aks.bicep --parameters infra/params/aks.bicepparam

.PHONY: help init lint test format infra-whatif infra-deploy publish \
	kind-whatif kind-deploy kind-drop local-issuer-publish local-up local-down aks-whatif aks-up aks-down \
	_check-env _lint-apps _lint-charts _lint-infra

help: ## Show this list
	@awk 'BEGIN { FS = ":.*## " } /^##@/ { printf "\n%s\n", substr($$0, 5) } /^[a-z-]+:.*## / { printf "  %-22s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

##@ Develop
init: ## Install the dependencies of both apps
	@for app in $(APPS); do $(MAKE) -C $$app init || exit 1; done

lint: _lint-apps _lint-charts _lint-infra ## Lint the apps, lint and render every chart for both environments, lint the Bicep

test: ## Run the unit tests of both apps
	@for app in $(APPS); do $(MAKE) -C $$app test || exit 1; done

format: ## Format the Python code
	@for app in $(APPS); do $(MAKE) -C $$app format || exit 1; done

##@ Azure (the owner runs these)
infra-whatif: _check-env ## Preview the Bicep deployment. Changes nothing.
	az deployment sub what-if $(DEPLOY_ARGS)

infra-deploy: _check-env ## Deploy the Bicep after a what-if and a confirmation
	az deployment sub create $(DEPLOY_ARGS) --confirm-with-what-if

publish: ## Push both images and both charts to ACR at VERSION. The release job runs it; a pushed version is never reused.
	@test -n "$(VERSION)" || { echo "Set VERSION, e.g. make publish VERSION=0.2.0"; exit 1; }
	@test -n "$(LAB_SUBSCRIPTION_ID)" || { echo "Set LAB_SUBSCRIPTION_ID"; exit 1; }
	acr="$(ACR)" && { [ -n "$$acr" ] || acr=$$(az deployment sub show --subscription $(LAB_SUBSCRIPTION_ID) -n main --query properties.outputs.acrLoginServer.value -o tsv); } && \
	az acr login --subscription $(LAB_SUBSCRIPTION_ID) --name $${acr%%.*} --expose-token --output tsv --query accessToken \
		| docker login $$acr --username 00000000-0000-0000-0000-000000000000 --password-stdin && \
	for app in api indexer; do \
		$(MAKE) -C apps/$$app image IMAGE=$$acr/$$app:$(VERSION) && docker push $$acr/$$app:$(VERSION) || exit 1; \
	done && \
	mkdir -p dist && for chart in $(CHARTS); do \
		$(HELM) package charts/$$chart --version $(VERSION) --app-version $(VERSION) --destination dist && \
		$(HELM) push dist/$$chart-$(VERSION).tgz oci://$$acr/charts || exit 1; \
	done

##@ AKS plugin (the owner runs these; never run two plugin deploys at once)
aks-whatif: _check-env ## Preview the aks stack. Changes nothing.
	az deployment group what-if $(AKS_ARGS)

# A stack has no what-if of its own, so the deploy targets show a deployment what-if of the same template first.
aks-up: aks-whatif ## Deploy the aks stack after a what-if and a confirmation, fetch credentials, install Argo CD
	@read -r -p "Deploy the aks stack? [y/N] " answer && [ "$$answer" = y ]
	az stack group create $(AKS_ARGS) --action-on-unmanage deleteResources --deny-settings-mode none --yes
	scripts/aks-up.sh

aks-down: _check-env ## Delete the aks stack: the cluster, its IP, its roles, credentials and aks-dev key values
	az stack group delete $(RG_ARGS) --name aks --action-on-unmanage deleteResources
	-kubectl config delete-context aks-lab
	-kubectl config delete-cluster aks-lab
	-kubectl config delete-user clusterUser_$(LAB_RESOURCE_GROUP)_aks-lab

##@ Kind plugin: the Azure side of the local cluster (the owner runs these)
kind-whatif: _check-env ## Preview the kind stack. Changes nothing.
	az deployment group what-if $(KIND_ARGS)

kind-deploy: kind-whatif ## Deploy the kind stack after a what-if and a confirmation
	@read -r -p "Deploy the kind stack? [y/N] " answer && [ "$$answer" = y ]
	az stack group create $(KIND_ARGS) --action-on-unmanage deleteResources --deny-settings-mode none --yes

kind-drop: _check-env ## Delete the kind stack: issuer storage, ESO identity, kind credentials and local key values
	az stack group delete $(RG_ARGS) --name kind --action-on-unmanage deleteResources

##@ Local cluster (kind)
local-issuer-publish: _check-env ## Make the cluster signing key and upload its public OIDC documents (once)
	scripts/kind-issuer.sh
	for f in .well-known/openid-configuration openid/v1/jwks; do \
		az storage blob upload --subscription $(LAB_SUBSCRIPTION_ID) --account-name $$(echo $(ISSUER_URL) | sed 's|https://\([^.]*\)\..*|\1|') \
			--auth-mode login --container-name oidc --name $$f --file .local/oidc/$$f \
			--content-type application/json --overwrite --only-show-errors --output none || exit 1; \
		curl -fsS $(ISSUER_URL)/$$f | cmp - .local/oidc/$$f || { echo "$$f differs after upload"; exit 1; }; \
	done
	@echo "Issuer published at $(ISSUER_URL)"

local-up: ## Create the kind cluster, install Argo CD and apply the root app
	scripts/local-up.sh

local-down: ## Delete the kind cluster. Keeps the signing key.
	scripts/local-down.sh

_check-env:
	@for var in LAB_TENANT_ID LAB_SUBSCRIPTION_ID LAB_LOCATION LAB_RESOURCE_GROUP LAB_BUDGET_EMAIL LAB_OWNER_OBJECT_ID; do \
		test -n "$$(printenv $$var)" || { echo "Set $$var in .lab.env"; exit 1; }; \
	done

_lint-apps:
	@for app in $(APPS); do $(MAKE) -C $$app lint || exit 1; done

_lint-charts:
	@for env in $(ENVS); do \
		for chart in $(CHARTS); do \
			$(HELM) lint charts/$$chart -f gitops/envs/$$env/$$chart.yaml || exit 1; \
			$(HELM) template $$chart charts/$$chart --namespace lab -f gitops/envs/$$env/$$chart.yaml > /dev/null || exit 1; \
		done; \
		$(HELM) lint $(GATEWAY_CHART) -f gitops/envs/$$env/gateway.yaml || exit 1; \
		$(HELM) template gateway $(GATEWAY_CHART) --namespace lab -f gitops/envs/$$env/gateway.yaml > /dev/null || exit 1; \
	done

_lint-infra:
	LAB_BUDGET_EMAIL=$${LAB_BUDGET_EMAIL:-lint@example.invalid} LAB_OWNER_OBJECT_ID=$${LAB_OWNER_OBJECT_ID:-00000000-0000-0000-0000-000000000000} \
		az bicep lint --file infra/main.bicep
	LAB_BUDGET_EMAIL=$${LAB_BUDGET_EMAIL:-lint@example.invalid} LAB_OWNER_OBJECT_ID=$${LAB_OWNER_OBJECT_ID:-00000000-0000-0000-0000-000000000000} \
		az bicep build-params --file infra/params/lab.bicepparam --stdout > /dev/null
	LAB_ISSUER_URL=$${LAB_ISSUER_URL:-https://lint.example.invalid/oidc} \
		az bicep lint --file infra/app-registration.bicep
	LAB_ISSUER_URL=$${LAB_ISSUER_URL:-https://lint.example.invalid/oidc} \
		az bicep build-params --file infra/params/app-registration.bicepparam --stdout > /dev/null
	@for c in kind aks; do \
		az bicep lint --file infra/clusters/$$c.bicep && \
		LAB_OWNER_OBJECT_ID=$${LAB_OWNER_OBJECT_ID:-00000000-0000-0000-0000-000000000000} \
			az bicep build-params --file infra/params/$$c.bicepparam --stdout > /dev/null || exit 1; \
	done
