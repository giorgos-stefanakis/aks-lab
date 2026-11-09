FROM python:3.12.16-slim-bookworm AS build
ENV POETRY_VIRTUALENVS_IN_PROJECT=true POETRY_NO_INTERACTION=1 PIP_NO_CACHE_DIR=1
RUN pip install poetry==2.5.1
WORKDIR /srv
COPY pyproject.toml poetry.lock ./
RUN poetry install --only main --no-root

FROM python:3.12.16-slim-bookworm
RUN useradd --system --uid 10001 --no-create-home app
WORKDIR /srv
COPY --from=build /srv/.venv /srv/.venv
COPY app ./app
ENV PATH=/srv/.venv/bin:$PATH PYTHONUNBUFFERED=1
USER 10001
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
