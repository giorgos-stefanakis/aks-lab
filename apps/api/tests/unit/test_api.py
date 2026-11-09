"""Unit tests for the api endpoints."""

from pathlib import Path

import httpx
import openai
from app.main import create_app
from app.settings import Settings, StubSource, load_settings
from azure.core.exceptions import ClientAuthenticationError
from fastapi.testclient import TestClient


def test_healthz(client):
    assert client.get("/healthz").json() == {"status": "ok"}


def test_readyz_after_startup(client):
    assert client.get("/readyz").status_code == 200


def test_readyz_before_startup():
    app = create_app(lambda: Settings(StubSource(), "local", 30))
    assert TestClient(app).get("/readyz").status_code == 503


def test_config_hides_secret_value(client):
    response = client.get("/config")
    body = response.json()
    assert body["label"] == "local"
    assert body["secret"] == "resolved"
    assert body["feature_flags"] == {"lab-banner": True}
    assert body["settings"]["message"] == "hi"
    assert "do-not-leak" not in response.text


def test_config_reports_unresolved_secret(client, source):
    del source["secret"]
    assert client.get("/config").json()["secret"] == "unresolved"


def test_config_follows_source_changes(client, source):
    source["message"] = "changed"
    assert client.get("/config").json()["settings"]["message"] == "changed"


def test_chat_uses_configured_deployment(client, fake_chat):
    response = client.post("/chat", json={"prompt": "ping"})
    assert response.json() == {"answer": "pong", "deployment": "model-1"}
    assert fake_chat.calls[0]["model"] == "model-1"


def test_chat_missing_setting(client, source):
    del source["openai:endpoint"]
    response = client.post("/chat", json={"prompt": "ping"})
    assert response.status_code == 503


def test_chat_upstream_error(client, fake_chat):
    fake_chat.error = openai.OpenAIError("boom")
    assert client.post("/chat", json={"prompt": "ping"}).status_code == 502


def test_chat_rejects_empty_prompt(client):
    assert client.post("/chat", json={"prompt": ""}).status_code == 422


async def test_index_forwards_to_indexer(monkeypatch, source):
    monkeypatch.setenv("INDEXER_URL", "http://indexer.test")

    def handler(request: httpx.Request) -> httpx.Response:
        assert str(request.url) == "http://indexer.test/api/index"
        return httpx.Response(200, json={"chunks": 3})

    real = httpx.AsyncClient
    monkeypatch.setattr(httpx, "AsyncClient", lambda **kw: real(transport=httpx.MockTransport(handler), **kw))
    app = create_app(lambda: Settings(source, "local", 30))
    async with app.router.lifespan_context(app):
        async with real(transport=httpx.ASGITransport(app=app), base_url="http://api.test") as api:
            response = await api.post("/index", json={"text": "abc"})
    assert response.json() == {"chunks": 3}


def test_index_without_indexer_url(client, monkeypatch):
    monkeypatch.delenv("INDEXER_URL", raising=False)
    assert client.post("/index", json={"text": "abc"}).status_code == 503


def test_stub_file_loads(monkeypatch):
    monkeypatch.setenv("LAB_CONFIG_STUB", str(Path(__file__).parents[2] / "stub" / "config.json"))
    settings = load_settings()
    assert settings.secret_resolved()
    assert settings.feature_flags() == {"lab-banner": True}


def test_config_hides_unlisted_keys(client, source):
    source["db:password"] = "from-key-vault"
    response = client.get("/config")
    assert "db:password" not in response.json()["settings"]
    assert "from-key-vault" not in response.text


def test_chat_auth_failure(client, fake_chat):
    fake_chat.error = ClientAuthenticationError("no credential")
    assert client.post("/chat", json={"prompt": "ping"}).status_code == 502


def test_chat_client_failure_on_creation(source):
    def factory(endpoint):
        raise ClientAuthenticationError("no credential")

    app = create_app(lambda: Settings(source, "local", 30), factory)
    with TestClient(app) as test_client:
        assert test_client.post("/chat", json={"prompt": "ping"}).status_code == 502


def test_chat_client_is_reused(source, fake_chat):
    created = []

    def factory(endpoint):
        created.append(endpoint)
        return fake_chat

    app = create_app(lambda: Settings(source, "local", 30), factory)
    with TestClient(app) as test_client:
        test_client.post("/chat", json={"prompt": "a"})
        test_client.post("/chat", json={"prompt": "b"})
    assert len(created) == 1


async def test_index_non_json_reply(monkeypatch, source):
    monkeypatch.setenv("INDEXER_URL", "http://indexer.test")
    real = httpx.AsyncClient
    transport = httpx.MockTransport(lambda request: httpx.Response(200, text="<html>proxy error</html>"))
    monkeypatch.setattr(httpx, "AsyncClient", lambda **kw: real(transport=transport, **kw))
    app = create_app(lambda: Settings(source, "local", 30))
    async with app.router.lifespan_context(app):
        async with real(transport=httpx.ASGITransport(app=app), base_url="http://api.test") as api:
            response = await api.post("/index", json={"text": "abc"})
    assert response.status_code == 502
