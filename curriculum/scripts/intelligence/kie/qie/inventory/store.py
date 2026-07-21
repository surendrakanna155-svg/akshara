"""Opener for the R4-1 unified_inventory.db manifest store (WRITABLE derived store under KIE_HOME).

Routed through the shared `store_open.open_store` so it inherits the R0-4 path guard, WAL, and the
mode=ro-by-DEFAULT fail-safe (a consumer that forgets `writable=True` cannot mutate the manifest). The manifest
is a REGISTRY, not a question surface — it holds provenance rows only.
"""
from __future__ import annotations

import sqlite3
from pathlib import Path

from kie import config
from kie.qie import store_open as SO

SCHEMA_PATH = Path(__file__).resolve().parent / "schema.sql"
SCHEMA_VERSION = "unified-1"
UNIFIED_DB_PATH = config.KIE_HOME / "unified_inventory.db"

# The manifest's role marker — it is an INVENTORY/registry, never a product question bank.
ROLE = "unified_inventory"
PRODUCT_VISIBLE = "0"


def open_store(db_path=None, *, writable: bool = False) -> sqlite3.Connection:
    """Open the manifest store. read-only by default; `writable=True` creates/migrates it."""
    path = db_path or UNIFIED_DB_PATH
    conn = SO.open_store(path, read_only=not writable)
    if writable:
        conn.executescript(SCHEMA_PATH.read_text())
        _ensure_columns(conn)                                        # additive migration (CREATE IF NOT EXISTS
                                                                     # can't add a column to an existing table)
        conn.execute("INSERT INTO unified_meta(key, value) VALUES ('schema_version', ?) "
                     "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (SCHEMA_VERSION,))
        conn.execute("INSERT INTO unified_meta(key, value) VALUES ('role', ?) "
                     "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (ROLE,))
        conn.execute("INSERT INTO unified_meta(key, value) VALUES ('product_visible', ?) "
                     "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (PRODUCT_VISIBLE,))
        conn.commit()
    return conn


def _ensure_columns(conn: sqlite3.Connection) -> None:
    """Additively bring an EXISTING unified_inventory table up to the current schema. The manifest is a
    rebuilt-from-scratch derived store, but its file persists across builds, so a newly-added column must be
    ALTER-ed in (schema.sql's CREATE TABLE IF NOT EXISTS is a no-op once the table exists)."""
    have = {r[1] for r in conn.execute("PRAGMA table_info(unified_inventory)")}
    for col, decl in (("compose_concept", "TEXT"),):
        if col not in have:
            conn.execute(f"ALTER TABLE unified_inventory ADD COLUMN {col} {decl}")


def store_role(conn: sqlite3.Connection) -> str:
    r = conn.execute("SELECT value FROM unified_meta WHERE key='role'").fetchone()
    return r[0] if r else None
