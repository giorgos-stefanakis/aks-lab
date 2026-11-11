"""Unit tests for the api endpoints."""

import base64
import json
from pathlib import Path
from types import SimpleNamespace

import httpx
import openai
from app.main import azure_graph_credential, create_app
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


def make_token(claims: dict) -> str:
    def part(data: dict) -> str:
        return base64.urlsafe_b64encode(json.dumps(data).encode()).decode().rstrip("=")

    return f"{part({'alg': 'none'})}.{part(claims)}.sig"


class FakeCredential:
    """Stands in for a TokenCredential."""

    def __init__(self, token: str = "", error: Exception | None = None) -> None:
        self.token = token
        self.error = error
        self.scopes: list[str] = []

    def get_token(self, *scopes: str, **kwargs):
        self.scopes.extend(scopes)
        if self.error:
            raise self.error
        return SimpleNamespace(token=self.token, expires_on=0)


def graph_client(source, credential, handler, kind="workload_identity"):
    app = create_app(
        lambda: Settings(source, "local", 30),
        graph_credential_factory=lambda: (kind, credential),
        graph_transport=httpx.MockTransport(handler),
    )
    return TestClient(app)


def test_graph_reports_client_id_without_leaking(source):
    token = make_token({"appid": "app-1", "tid": "tenant-1"})
    seen = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return httpx.Response(200, json={"value": [{"displayName": "secret-org"}]})

    credential = FakeCredential(token)
    with graph_client(source, credential, handler) as client:
        response = client.get("/graph")
    assert response.json() == {"credential": "workload_identity", "client_id": "app-1", "graph": "ok"}
    assert credential.scopes == ["https://graph.microsoft.com/.default"]
    assert str(seen[0].url) == "https://graph.microsoft.com/v1.0/organization"
    assert seen[0].headers["Authorization"] == f"Bearer {token}"
    assert token not in response.text
    assert "secret-org" not in response.text


def test_graph_falls_back_to_azp_claim(source):
    handler = lambda request: httpx.Response(200, json={})  # noqa: E731
    with graph_client(source, FakeCredential(make_token({"azp": "app-2"})), handler, kind="default") as client:
        assert client.get("/graph").json()["client_id"] == "app-2"


def test_graph_http_error_returns_502(source):
    handler = lambda request: httpx.Response(403, json={"error": {"message": "tenant-detail"}})  # noqa: E731
    with graph_client(source, FakeCredential(make_token({"appid": "a"})), handler) as client:
        response = client.get("/graph")
    assert response.status_code == 502
    assert response.json()["detail"] == "Graph call failed: HTTPStatusError"
    assert "tenant-detail" not in response.text


def test_graph_credential_error_returns_502(source):
    handler = lambda request: httpx.Response(200, json={})  # noqa: E731
    with graph_client(source, FakeCredential(error=ClientAuthenticationError("no token")), handler) as client:
        response = client.get("/graph")
    assert response.status_code == 502
    assert response.json()["detail"] == "Graph call failed: ClientAuthenticationError"


def test_graph_credential_factory_runs_once(source):
    calls = []
    handler = lambda request: httpx.Response(200, json={})  # noqa: E731

    def factory():
        calls.append(1)
        return "default", FakeCredential(make_token({"appid": "a"}))

    app = create_app(lambda: Settings(source, "local", 30), graph_credential_factory=factory, graph_transport=httpx.MockTransport(handler))
    with TestClient(app) as client:
        client.get("/graph")
        client.get("/graph")
    assert len(calls) == 1


def test_graph_credential_default_without_client_id(monkeypatch):
    monkeypatch.delenv("GRAPH_CLIENT_ID", raising=False)
    kind, credential = azure_graph_credential()
    assert kind == "default"
    assert type(credential).__name__ == "DefaultAzureCredential"


def test_graph_credential_workload_identity_with_client_id(monkeypatch, tmp_path):
    token_file = tmp_path / "token"
    token_file.write_text("x")
    monkeypatch.setenv("GRAPH_CLIENT_ID", "11111111-1111-1111-1111-111111111111")
    monkeypatch.setenv("AZURE_TENANT_ID", "22222222-2222-2222-2222-222222222222")
    monkeypatch.setenv("AZURE_FEDERATED_TOKEN_FILE", str(token_file))
    kind, credential = azure_graph_credential()
    assert kind == "workload_identity"
    assert type(credential).__name__ == "WorkloadIdentityCredential"
