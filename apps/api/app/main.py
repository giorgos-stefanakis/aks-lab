"""FastAPI application of the lab."""

from __future__ import annotations

import os
from collections.abc import AsyncIterator, Callable
from contextlib import asynccontextmanager
from typing import Any

import httpx
from azure.core.exceptions import AzureError
from fastapi import Depends, FastAPI, HTTPException, Request
from openai import AzureOpenAI, OpenAIError
from pydantic import BaseModel, Field

from app.settings import Settings, load_settings

OPENAI_SCOPE = "https://cognitiveservices.azure.com/.default"
OPENAI_API_VERSION = "2024-10-21"
INDEXER_TIMEOUT_SECONDS = 10.0

ChatClientFactory = Callable[[str], AzureOpenAI]


class ChatRequest(BaseModel):
    """Body of `POST /chat`."""

    prompt: str = Field(min_length=1)


class IndexRequest(BaseModel):
    """Body of `POST /index`."""

    text: str = Field(min_length=1)


def azure_chat_client(endpoint: str) -> AzureOpenAI:
    """Create an Azure OpenAI client that authenticates with Entra."""
    from azure.identity import DefaultAzureCredential, get_bearer_token_provider

    token_provider = get_bearer_token_provider(DefaultAzureCredential(), OPENAI_SCOPE)
    return AzureOpenAI(azure_endpoint=endpoint, azure_ad_token_provider=token_provider, api_version=OPENAI_API_VERSION)


def create_app(
    settings_loader: Callable[[], Settings] = load_settings,
    chat_client_factory: ChatClientFactory = azure_chat_client,
) -> FastAPI:
    """Build the app. Both arguments exist so tests can replace Azure."""

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        app.state.settings = settings_loader()
        async with httpx.AsyncClient(timeout=INDEXER_TIMEOUT_SECONDS) as indexer_client:
            app.state.indexer_client = indexer_client
            yield

    app = FastAPI(title="aks-lab api", lifespan=lifespan)
    chat_clients: dict[str, AzureOpenAI] = {}

    def get_settings(request: Request) -> Settings:
        settings: Settings = request.app.state.settings
        settings.refresh()
        return settings

    @app.get("/healthz")
    def healthz() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/readyz")
    def readyz(request: Request) -> dict[str, str]:
        if getattr(request.app.state, "settings", None) is None:
            raise HTTPException(status_code=503, detail="configuration not loaded")
        return {"status": "ready"}

    @app.get("/config")
    def config(settings: Settings = Depends(get_settings)) -> dict[str, Any]:
        return {
            "label": settings.label,
            "refresh_seconds": settings.refresh_seconds,
            "settings": settings.public(),
            "feature_flags": settings.feature_flags(),
            "secret": "resolved" if settings.secret_resolved() else "unresolved",
        }

    @app.post("/chat")
    def chat(body: ChatRequest, settings: Settings = Depends(get_settings)) -> dict[str, str]:
        try:
            endpoint = settings.require("openai:endpoint")
            deployment = settings.require("openai:deployment")
        except KeyError as error:
            raise HTTPException(status_code=503, detail=f"missing setting {error.args[0]}") from error
        try:
            client = chat_clients.get(endpoint) or chat_clients.setdefault(endpoint, chat_client_factory(endpoint))
            result = client.chat.completions.create(
                model=deployment,
                messages=[{"role": "user", "content": body.prompt}],
            )
        except (OpenAIError, AzureError) as error:
            raise HTTPException(status_code=502, detail=f"Azure OpenAI call failed: {type(error).__name__}") from error
        return {"answer": result.choices[0].message.content or "", "deployment": deployment}

    @app.post("/index")
    async def index(body: IndexRequest, request: Request) -> Any:
        url = os.environ.get("INDEXER_URL")
        if not url:
            raise HTTPException(status_code=503, detail="INDEXER_URL is not set")
        try:
            response = await request.app.state.indexer_client.post(f"{url.rstrip('/')}/api/index", json={"text": body.text})
            response.raise_for_status()
            return response.json()
        except (httpx.HTTPError, ValueError) as error:
            raise HTTPException(status_code=502, detail=f"indexer call failed: {type(error).__name__}") from error

    return app


app = create_app()
