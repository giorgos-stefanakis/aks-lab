"""Configuration for the indexer: Azure App Configuration, or a JSON stub file for offline runs."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

from azure.appconfiguration.provider import SettingSelector, load
from azure.identity import DefaultAzureCredential

KEY_PREFIX = "lab:"
SENTINEL_KEY = "sentinel"
DEFAULT_REFRESH_SECONDS = 30


class ConfigError(ValueError):
    """The chunking settings are missing, not numeric or out of range."""


class StubSource(dict):
    """Static config read from a JSON file."""

    def refresh(self) -> None:
        """Do nothing. A stub never changes."""


class Settings:
    """Chunking settings. Refreshes on access, throttled by the provider."""

    def __init__(self, source: Any) -> None:
        """Wrap a config source.

        Args:
            source: Mapping of trimmed keys to values, with a `refresh` method.
        """
        self._source = source

    def chunking(self) -> tuple[int, int]:
        """Return the current chunk size and overlap.

        Raises:
            ConfigError: If a value is not an integer or the pair is out of range.
        """
        self._source.refresh()
        try:
            size = int(self._source.get("indexer:chunk_size", 200))
            overlap = int(self._source.get("indexer:chunk_overlap", 20))
        except ValueError as error:
            raise ConfigError("chunk settings must be integers") from error
        if size <= 0 or not 0 <= overlap < size:
            raise ConfigError("chunk_size must be positive and chunk_overlap in [0, chunk_size)")
        return size, overlap


def load_settings() -> Settings:
    """Build settings from the environment.

    `LAB_CONFIG_STUB` names a JSON file and skips Azure. Otherwise `AZURE_APPCONFIG_ENDPOINT` is required.
    """
    stub = os.environ.get("LAB_CONFIG_STUB")
    if stub:
        return Settings(StubSource(json.loads(Path(stub).read_text())))

    label = os.environ.get("LAB_LABEL", "local")
    return Settings(
        load(
            endpoint=os.environ["AZURE_APPCONFIG_ENDPOINT"],
            credential=DefaultAzureCredential(),
            selects=[SettingSelector(key_filter=f"{KEY_PREFIX}*", label_filter=label)],
            trim_prefixes=[KEY_PREFIX],
            refresh_on=[(f"{KEY_PREFIX}{SENTINEL_KEY}", label)],
            refresh_interval=int(os.environ.get("LAB_REFRESH_SECONDS", DEFAULT_REFRESH_SECONDS)),
        )
    )
