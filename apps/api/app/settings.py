"""Configuration source for the api: Azure App Configuration, or a JSON stub file for offline runs."""

from __future__ import annotations

import json
import os
from collections.abc import Mapping
from pathlib import Path
from typing import Any, Protocol

from azure.appconfiguration.provider import SettingSelector, load
from azure.identity import DefaultAzureCredential

KEY_PREFIX = "lab:"
SECRET_KEY = "secret"
SENTINEL_KEY = "sentinel"
# Allow-list: a resolved Key Vault value looks like any other value, so unknown keys stay hidden.
PUBLIC_KEYS = ("openai:endpoint", "openai:deployment", "message", SENTINEL_KEY)
DEFAULT_REFRESH_SECONDS = 30


class ConfigSource(Protocol):
    """Mapping of trimmed keys to values, with a refresh hook."""

    def __getitem__(self, key: str, /) -> Any: ...  # noqa: D105
    def get(self, key: str, default: Any = None, /) -> Any: ...  # noqa: D102
    def keys(self) -> Any: ...  # noqa: D102
    def refresh(self) -> None: ...  # noqa: D102


class StubSource(dict):
    """Static config read from a JSON file. Same shape as the App Configuration provider output."""

    def refresh(self) -> None:
        """Do nothing. A stub never changes."""


class Settings:
    """Read-only view over the config source. Refreshes on access, throttled by the provider."""

    def __init__(self, source: ConfigSource, label: str, refresh_seconds: int) -> None:
        """Wrap a config source.

        Args:
            source: Loaded configuration.
            label: App Configuration label that selected the values.
            refresh_seconds: Minimum seconds between sentinel checks.
        """
        self._source = source
        self.label = label
        self.refresh_seconds = refresh_seconds

    def refresh(self) -> None:
        """Check the sentinel key and reload when it changed."""
        self._source.refresh()

    def get(self, key: str, default: str | None = None) -> str | None:
        """Return one setting by trimmed key."""
        value = self._source.get(key, default)
        return None if value is None else str(value)

    def require(self, key: str) -> str:
        """Return one setting or raise KeyError when it is missing or empty."""
        value = self.get(key)
        if not value:
            raise KeyError(key)
        return value

    def public(self) -> dict[str, str]:
        """Return the settings on the public allow-list."""
        return {k: str(self._source[k]) for k in PUBLIC_KEYS if k in self._source.keys()}  # noqa: SIM118

    def feature_flags(self) -> dict[str, bool]:
        """Return the state of every feature flag."""
        management: Mapping[str, Any] = self._source.get("feature_management") or {}
        return {flag["id"]: bool(flag.get("enabled", False)) for flag in management.get("feature_flags", [])}

    def secret_resolved(self) -> bool:
        """Report whether the Key Vault reference resolved. Never exposes the value."""
        return bool(self._source.get(SECRET_KEY))


def load_settings() -> Settings:
    """Build settings from the environment.

    `LAB_CONFIG_STUB` names a JSON file and skips Azure. Otherwise `AZURE_APPCONFIG_ENDPOINT` and `LAB_LABEL` are required.
    """
    label = os.environ.get("LAB_LABEL", "local")
    refresh_seconds = int(os.environ.get("LAB_REFRESH_SECONDS", DEFAULT_REFRESH_SECONDS))
    stub = os.environ.get("LAB_CONFIG_STUB")
    if stub:
        return Settings(StubSource(json.loads(Path(stub).read_text())), label, refresh_seconds)

    credential = DefaultAzureCredential()
    source = load(
        endpoint=os.environ["AZURE_APPCONFIG_ENDPOINT"],
        credential=credential,
        selects=[SettingSelector(key_filter=f"{KEY_PREFIX}*", label_filter=label)],
        trim_prefixes=[KEY_PREFIX],
        keyvault_credential=credential,
        refresh_on=[(f"{KEY_PREFIX}{SENTINEL_KEY}", label)],
        refresh_interval=refresh_seconds,
        feature_flag_enabled=True,
        feature_flag_selectors=[SettingSelector(key_filter="*", label_filter=label)],
        feature_flag_refresh_enabled=True,
    )
    return Settings(source, label, refresh_seconds)
