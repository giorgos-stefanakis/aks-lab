# Shared targets. Each app sets IMAGE and defines `run` and `docker-run`.
.PHONY: init test lint format image

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
