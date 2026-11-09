"""Point the indexer at a stub config before the function app imports."""

import os

os.environ["LAB_CONFIG_STUB"] = os.path.join(os.path.dirname(__file__), "..", "..", "stub", "config.json")
