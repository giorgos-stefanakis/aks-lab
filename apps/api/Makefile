IMAGE ?= aks-lab-api:dev

include ../common.mk

.PHONY: run docker-run

run:
	LAB_CONFIG_STUB=stub/config.json poetry run uvicorn app.main:app --reload --port 8000

docker-run: image
	docker run --rm -p 8000:8000 -v $(CURDIR)/stub:/stub:ro -e LAB_CONFIG_STUB=/stub/config.json $(IMAGE)
