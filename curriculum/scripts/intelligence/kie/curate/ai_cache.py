"""Knowledge Layer — persistent AI spec-hash cache (Phase 5).

The engine's ai_fill(specs, provider, cache) caches authored questions in a dict keyed by the
spec-hash, so identical specs never re-call the provider WITHIN a run. This module makes that
cache PERSISTENT (JSON on disk), so identical specs never re-call the provider ACROSS runs
either — minimising API calls to (at most) one per distinct specification, ever.

It is a plain MutableMapping (the exact interface ai_fill needs: `key in cache`, `cache[key]`,
`cache[key] = value`); every write is flushed to disk. Deterministic + stdlib-only. Nothing is
cached unless the engine actually authored something, so an empty cache means zero AI was used.
"""
from __future__ import annotations

import json
from collections.abc import MutableMapping
from pathlib import Path
from typing import Optional

from kie import config


class PersistentSpecCache(MutableMapping):
    """A dict keyed by spec-hash, transparently persisted to a JSON file."""

    def __init__(self, path: Optional[Path] = None):
        self.path = Path(path) if path else (config.KIE_HOME / "ai_cache" / "spec_cache.json")
        self._data: dict = {}
        if self.path.exists():
            try:
                self._data = json.loads(self.path.read_text())
            except (ValueError, OSError):
                self._data = {}

    def _flush(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_suffix(".tmp")
        tmp.write_text(json.dumps(self._data, sort_keys=True, indent=0))
        tmp.replace(self.path)                          # atomic on POSIX

    def __getitem__(self, key):
        return self._data[key]

    def __setitem__(self, key, value):
        self._data[key] = value
        self._flush()

    def __delitem__(self, key):
        del self._data[key]
        self._flush()

    def __iter__(self):
        return iter(self._data)

    def __len__(self):
        return len(self._data)

    def __contains__(self, key):                        # explicit: ai_fill checks `key in cache`
        return key in self._data
