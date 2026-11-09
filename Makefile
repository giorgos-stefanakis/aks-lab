APPS := apps/api apps/indexer
CHARTS := api indexer
ENVS := local aks-dev
# Images and charts share the chart version. Bump it in Chart.yaml and gitops/envs together.
VERSION := $(shell sed -n 's/^version: //p' charts/api/Chart.yaml)
HELM ?= helm

-include .lab.env
export LAB_TENANT_ID LAB_SUBSCRIPTION_ID LAB_LOCATION LAB_RESOURCE_GROUP LAB_BUDGET_EMAIL LAB_OWNER_OBJECT_ID

DEPLOY_ARGS = --subscription $(LAB_SUBSCRIPTION_ID) --location $(LAB_LOCATION) --name main \
	--template-file infra/main.bicep --parameters infra/params/lab.bicepparam

.PHONY: init test lint format images infra-lint infra-whatif infra-deploy check-lab-env chart-lint chart-template publish

init test lint format:
	@for app in $(APPS); do $(MAKE) -C $$app $@ || exit 1; done

images:
	@for app in $(APPS); do $(MAKE) -C $$app image || exit 1; done

check-lab-env:
	@for var in LAB_TENANT_ID LAB_SUBSCRIPTION_ID LAB_LOCATION LAB_RESOURCE_GROUP LAB_BUDGET_EMAIL LAB_OWNER_OBJECT_ID; do \
		test -n "$$(printenv $$var)" || { echo "Set $$var in .lab.env"; exit 1; }; \
	done

# Local only: no Azure call and no subscription. Placeholder values stand in for a missing .lab.env.
infra-lint:
	LAB_BUDGET_EMAIL=$${LAB_BUDGET_EMAIL:-lint@example.invalid} LAB_OWNER_OBJECT_ID=$${LAB_OWNER_OBJECT_ID:-00000000-0000-0000-0000-000000000000} \
		az bicep lint --file infra/main.bicep
	LAB_BUDGET_EMAIL=$${LAB_BUDGET_EMAIL:-lint@example.invalid} LAB_OWNER_OBJECT_ID=$${LAB_OWNER_OBJECT_ID:-00000000-0000-0000-0000-000000000000} \
		az bicep build-params --file infra/params/lab.bicepparam --stdout > /dev/null

# Subscription scope: the template creates the resource group too.
infra-whatif: check-lab-env
	az deployment sub what-if $(DEPLOY_ARGS)

infra-deploy: check-lab-env
	az deployment sub create $(DEPLOY_ARGS) --confirm-with-what-if

chart-lint:
	@for env in $(ENVS); do for chart in $(CHARTS); do \
		$(HELM) lint charts/$$chart -f gitops/envs/$$env/$$chart.yaml || exit 1; \
	done; done

chart-template:
	@for env in $(ENVS); do for chart in $(CHARTS); do \
		$(HELM) template $$chart charts/$$chart --namespace lab -f gitops/envs/$$env/$$chart.yaml > /dev/null || exit 1; \
	done; done; echo "rendered: $(ENVS)"

# Owner runs this. Images and charts share VERSION; CI replaces the manual tag in M5.
publish: check-lab-env chart-lint chart-template
	acr=$$(az deployment sub show --subscription $(LAB_SUBSCRIPTION_ID) -n main --query properties.outputs.acrLoginServer.value -o tsv) && \
	az acr login --subscription $(LAB_SUBSCRIPTION_ID) --name $${acr%%.*} && \
	for app in api indexer; do \
		$(MAKE) -C apps/$$app image IMAGE=$$acr/$$app:$(VERSION) && docker push $$acr/$$app:$(VERSION) || exit 1; \
	done && \
	mkdir -p dist && for chart in $(CHARTS); do \
		$(HELM) package charts/$$chart --destination dist && \
		$(HELM) push dist/$$chart-$(VERSION).tgz oci://$$acr/charts || exit 1; \
	done
