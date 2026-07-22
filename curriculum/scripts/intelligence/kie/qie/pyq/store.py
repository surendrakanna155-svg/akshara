"""Opener for Program B's DERIVED store `pyq_corpus.db` — routed through the shared derived-store opener so it
inherits the R0-4 path guard, WAL, and mode=ro-by-default. NEVER the frozen kie.db / knowledge_index.db (those
have their own read-only openers). Local-only, deterministic-rebuildable; holds all Program B output so
examdna.db v1 stays byte-identical (OD-6)."""
from __future__ import annotations

import sqlite3
from pathlib import Path

from kie import config
from kie.qie import store_open as SO

SCHEMA_PATH = Path(__file__).resolve().parent / "schema.sql"
SCHEMA_VERSION = "pyq-b4"
PYQ_DB_PATH = config.KIE_HOME / "pyq_corpus.db"


def open_store(db_path=None, *, writable: bool = False) -> sqlite3.Connection:
    """read-only by default; `writable=True` creates/migrates the derived store (idempotent, additive schema)."""
    conn = SO.open_store(db_path or PYQ_DB_PATH, read_only=not writable)
    if writable:
        conn.executescript(SCHEMA_PATH.read_text())
        conn.execute("INSERT INTO pyq_meta(key, value) VALUES ('schema_version', ?) "
                     "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (SCHEMA_VERSION,))
        conn.commit()
    return conn
