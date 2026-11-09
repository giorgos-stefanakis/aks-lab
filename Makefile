APPS := apps/api apps/indexer
CHARTS := api indexer
ENVS := local aks-dev
GATEWAY_CHART := gitops/platform/gateway
HELM ?= helm
VERSION := $(shell sed -n 's/^version: //p' charts/api/Chart.yaml)
ISSUER_URL = $(patsubst %/,%,$(LAB_ISSUER_URL))

-include .lab.env
export LAB_TENANT_ID LAB_SUBSCRIPTION_ID LAB_LOCATION LAB_RESOURCE_GROUP LAB_BUDGET_EMAIL LAB_OWNER_OBJECT_ID LAB_ISSUER_URL

DEPLOY_ARGS = --subscription $(LAB_SUBSCRIPTION_ID) --location $(LAB_LOCATION) --name main \
	--template-file infra/main.bicep --parameters infra/params/lab.bicepparam

.PHONY: help init lint test format infra-whatif infra-deploy publish local-issuer-publish local-up local-down \
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

publish: _check-env _lint-charts ## Build and push both images and both charts to ACR
	acr=$$(az deployment sub show --subscription $(LAB_SUBSCRIPTION_ID) -n main --query properties.outputs.acrLoginServer.value -o tsv) && \
	az acr login --subscription $(LAB_SUBSCRIPTION_ID) --name $${acr%%.*} && \
	for app in api indexer; do \
		$(MAKE) -C apps/$$app image IMAGE=$$acr/$$app:$(VERSION) && docker push $$acr/$$app:$(VERSION) || exit 1; \
	done && \
	mkdir -p dist && for chart in $(CHARTS); do \
		$(HELM) package charts/$$chart --destination dist && \
		$(HELM) push dist/$$chart-$(VERSION).tgz oci://$$acr/charts || exit 1; \
	done

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
