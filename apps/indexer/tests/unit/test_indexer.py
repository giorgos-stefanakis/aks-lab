"""Unit tests for chunking and the HTTP triggers."""

import json

import azure.functions as func
import function_app
import pytest
from indexer import settings as settings_module
from indexer.chunking import split_text
from indexer.settings import Settings, StubSource


def call(fn, body: bytes | None = None, method: str = "POST") -> func.HttpResponse:
    req = func.HttpRequest(method=method, url="/api/x", body=body or b"")
    return fn.build().get_user_function()(req)


def test_split_without_overlap():
    assert split_text("abcdef", 3, 0) == ["abc", "def"]


def test_split_with_overlap():
    assert split_text("abcdef", 4, 2) == ["abcd", "cdef"]


def test_split_last_chunk_not_contained_in_previous():
    assert split_text("abcdef", 4, 2) == ["abcd", "cdef"]
    assert split_text("abcde", 4, 2) == ["abcd", "cde"]
    assert split_text("abcd", 4, 2) == ["abcd"]


def test_split_empty_text():
    assert split_text("", 3, 0) == []


@pytest.mark.parametrize(("size", "overlap"), [(0, 0), (3, 3), (3, -1)])
def test_split_rejects_bad_sizes(size, overlap):
    with pytest.raises(ValueError):
        split_text("abc", size, overlap)


def test_index_counts_chunks(monkeypatch):
    monkeypatch.setattr(function_app, "settings", Settings(StubSource({"indexer:chunk_size": "5", "indexer:chunk_overlap": "0"})))
    response = call(function_app.index, json.dumps({"text": "x" * 12}).encode())
    assert response.status_code == 200
    assert json.loads(response.get_body())["chunks"] == 3


def test_index_uses_default_stub_config():
    response = call(function_app.index, json.dumps({"text": "x" * 500}).encode())
    assert json.loads(response.get_body())["chunk_size"] == 200


@pytest.mark.parametrize("body", [b"", b"not json", b'{"text": ""}', b'{"other": 1}', b"[1]", b'"x"', b"5", b"null"])
def test_index_rejects_bad_body(body):
    assert call(function_app.index, body).status_code == 400


def test_health():
    response = call(function_app.health, method="GET")
    assert response.status_code == 200


@pytest.mark.parametrize(
    "config",
    [
        {"indexer:chunk_size": "200", "indexer:chunk_overlap": "200"},
        {"indexer:chunk_size": "abc"},
        {"indexer:chunk_size": "0"},
        {"indexer:chunk_overlap": "-1"},
    ],
)
def test_index_invalid_config_returns_503(monkeypatch, config):
    monkeypatch.setattr(function_app, "settings", Settings(StubSource(config)))
    response = call(function_app.index, json.dumps({"text": "abc"}).encode())
    assert response.status_code == 503


def test_azure_load_selects_only_indexer_keys(monkeypatch):
    captured = {}
    monkeypatch.delenv("LAB_CONFIG_STUB")
    monkeypatch.setenv("AZURE_APPCONFIG_ENDPOINT", "https://example.invalid")
    monkeypatch.setenv("LAB_LABEL", "aks-dev")
    monkeypatch.setattr(settings_module, "DefaultAzureCredential", lambda: object())
    monkeypatch.setattr(settings_module, "load", lambda **kwargs: captured.update(kwargs) or StubSource())
    settings_module.load_settings()
    (selector,) = captured["selects"]
    assert (selector.key_filter, selector.label_filter) == ("lab:indexer:*", "aks-dev")
    assert captured["refresh_on"] == [("lab:sentinel", "aks-dev")]
