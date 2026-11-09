"""Shared fixtures."""

from types import SimpleNamespace

import pytest
from app.main import create_app
from app.settings import Settings, StubSource
from fastapi.testclient import TestClient

CONFIG = {
    "openai:endpoint": "https://example.invalid",
    "openai:deployment": "model-1",
    "message": "hi",
    "secret": "do-not-leak",
    "feature_management": {"feature_flags": [{"id": "lab-banner", "enabled": True}]},
}


class FakeChat:
    """Stands in for AzureOpenAI."""

    def __init__(self, error: Exception | None = None) -> None:
        self.error = error
        self.calls: list[dict] = []
        self.chat = SimpleNamespace(completions=SimpleNamespace(create=self.create))

    def create(self, **kwargs):
        self.calls.append(kwargs)
        if self.error:
            raise self.error
        return SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content="pong"))])


@pytest.fixture
def source() -> StubSource:
    return StubSource(CONFIG)


@pytest.fixture
def fake_chat() -> FakeChat:
    return FakeChat()


@pytest.fixture
def client(source, fake_chat):
    app = create_app(lambda: Settings(source, "local", 30), lambda endpoint: fake_chat)
    with TestClient(app) as test_client:
        yield test_client
