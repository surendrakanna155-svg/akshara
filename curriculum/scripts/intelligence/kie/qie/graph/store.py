"""Opener for the R5 derived graph store (graph_edges.db) — routed through the shared derived-store opener so
it inherits the R0-4 path guard, WAL, and mode=ro-by-default. NEVER the frozen index (that has its own opener)."""
from __future__ import annotations

import sqlite3
from pathlib import Path

from kie import config
from kie.qie import store_open as SO

SCHEMA_PATH = Path(__file__).resolve().parent / "schema.sql"
SCHEMA_VERSION = "graph-1"
GRAPH_DB_PATH = config.KIE_HOME / "graph_edges.db"


def open_store(db_path=None, *, writable: bool = False) -> sqlite3.Connection:
    """read-only by default; `writable=True` creates/migrates the derived graph store."""
    conn = SO.open_store(db_path or GRAPH_DB_PATH, read_only=not writable)
    if writable:
        conn.executescript(SCHEMA_PATH.read_text())
        conn.execute("INSERT INTO prereq_meta(key, value) VALUES ('schema_version', ?) "
                     "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (SCHEMA_VERSION,))
        conn.commit()
    return conn
