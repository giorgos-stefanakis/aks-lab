APPS := apps/api apps/indexer

-include .lab.env
export LAB_TENANT_ID LAB_SUBSCRIPTION_ID LAB_LOCATION LAB_RESOURCE_GROUP LAB_BUDGET_EMAIL LAB_OWNER_OBJECT_ID

DEPLOY_ARGS = --subscription $(LAB_SUBSCRIPTION_ID) --location $(LAB_LOCATION) --name main \
	--template-file infra/main.bicep --parameters infra/params/lab.bicepparam

.PHONY: init test lint format images infra-lint infra-whatif infra-deploy check-lab-env

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
