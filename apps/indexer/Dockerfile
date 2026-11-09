# Functions host 4, Python 3.12. Pinned by digest because the versioned tags stopped in 2024; see docs/LOG.md.
FROM mcr.microsoft.com/azure-functions/python@sha256:51c4f339c34a9966c8de8ba2475000c31a5668ba390cc43a868bd5b478520922
ENV AzureWebJobsScriptRoot=/home/site/wwwroot AzureFunctionsJobHost__Logging__Console__IsEnabled=true \
    PIP_NO_CACHE_DIR=1 POETRY_VIRTUALENVS_CREATE=false POETRY_NO_INTERACTION=1
WORKDIR /home/site/wwwroot
COPY pyproject.toml poetry.lock ./
RUN python -m pip install poetry==2.5.1 && python -m poetry install --only main --no-root && python -m pip uninstall -y poetry
COPY host.json function_app.py ./
COPY indexer ./indexer
USER 10001
