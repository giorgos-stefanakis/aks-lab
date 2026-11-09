IMAGE ?= aks-lab-api:dev

.PHONY: init test lint format image run docker-run

init:
	poetry install

test:
	poetry run pytest

lint:
	poetry run ruff check .
	poetry run ruff format --check .

format:
	poetry run ruff check --fix .
	poetry run ruff format .

image:
	docker build -t $(IMAGE) .

run:
	LAB_CONFIG_STUB=stub/config.json poetry run uvicorn app.main:app --reload --port 8000

docker-run: image
	docker run --rm -p 8000:8000 -v $(CURDIR)/stub:/stub:ro -e LAB_CONFIG_STUB=/stub/config.json $(IMAGE)
