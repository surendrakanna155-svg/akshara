"""Crash-safe atomic file I/O for the staging lane.

Every state mutation is written to a temp file in the SAME directory, fsync'd, then
os.replace()'d over the target — an atomic rename on POSIX. A crash, terminal close,
model-session end, or power loss can therefore leave either the old complete file or the
new complete file, never a truncated one. This is what makes --resume safe: a per-doc
record either exists in full or does not exist at all.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any, Iterable, Iterator


def write_json_atomic(path: Path, obj: Any) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    data = json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(data)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)          # atomic


def read_json(path: Path, default: Any = None) -> Any:
    path = Path(path)
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


class JsonlWriter:
    """Streaming JSONL writer that builds a manifest atomically.

    Writes rows to `<path>.tmp` as they stream in, then os.replace() over the final path
    on close(). If the process dies mid-rebuild, the previous complete manifest survives.
    Use as a context manager.
    """

    def __init__(self, path: Path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.tmp = self.path.with_suffix(self.path.suffix + ".tmp")
        self._fh = None
        self.count = 0

    def __enter__(self) -> "JsonlWriter":
        self._fh = open(self.tmp, "w", encoding="utf-8")
        return self

    def write(self, row: Any) -> None:
        self._fh.write(json.dumps(row, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
        self._fh.write("\n")
        self.count += 1

    def __exit__(self, exc_type, exc, tb) -> None:
        self._fh.flush()
        os.fsync(self._fh.fileno())
        self._fh.close()
        if exc_type is None:
            os.replace(self.tmp, self.path)
        else:                      # leave prior manifest intact on failure
            try:
                os.remove(self.tmp)
            except OSError:
                pass


def read_jsonl(path: Path) -> Iterator[dict]:
    path = Path(path)
    if not path.exists():
        return
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                yield json.loads(line)
