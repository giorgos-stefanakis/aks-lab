IMAGE ?= aks-lab-indexer:dev

include ../common.mk

.PHONY: run docker-run

run:
	LAB_CONFIG_STUB=stub/config.json poetry run func start --port 7071

docker-run: image
	docker run --rm -p 8080:80 -v $(CURDIR)/stub:/stub:ro -e LAB_CONFIG_STUB=/stub/config.json $(IMAGE)
