APPS := apps/api apps/indexer

.PHONY: init test lint format images

init test lint format:
	@for app in $(APPS); do $(MAKE) -C $$app $@ || exit 1; done

images:
	@for app in $(APPS); do $(MAKE) -C $$app image || exit 1; done
