"""Openers for the OCR Recovery Lane.

Two clean, separate doors, matching the freeze boundary:
  * `open_store()`  — the WRITABLE DERIVED store `ocr_recovery.db`, routed through the shared derived-store
    opener (kie.qie.store_open) so it inherits the R0-4 path guard, WAL, and mode=ro-by-default.
  * `open_kie_ro()` — the FROZEN kie.db substrate, opened read-only with a raw `mode=ro` URI. Deliberately
    NOT routed through store_open (per that module's own scope note: the frozen substrate has its own
    read-only door). This lane never has any other way to touch kie.db, and never opens it writable.
"""
from __future__ import annotations

import sqlite3
from pathlib import Path

from kie import config
from kie.qie import store_open as SO

SCHEMA_PATH = Path(__file__).resolve().parent / "schema.sql"
SCHEMA_VERSION = "ocr-recovery-1"
OCR_RECOVERY_DB_PATH = config.KIE_HOME / "ocr_recovery.db"


def open_store(db_path=None, *, writable: bool = False) -> sqlite3.Connection:
    """read-only by default; `writable=True` creates/migrates the derived store (idempotent, additive schema)."""
    conn = SO.open_store(db_path or OCR_RECOVERY_DB_PATH, read_only=not writable)
    if writable:
        conn.executescript(SCHEMA_PATH.read_text())
        conn.execute(
            "INSERT INTO recovery_meta(key, value) VALUES ('schema_version', ?) "
            "ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            (SCHEMA_VERSION,),
        )
        conn.commit()
    return conn


def open_kie_ro(db_path=None) -> sqlite3.Connection:
    """Open the FROZEN kie.db strictly read-only (`file:…?mode=ro`). NEVER writable — this is the substrate the
    lane reads and must leave byte-identical. Raises OperationalError if the (gitignored, local) DB is absent,
    which is the honest outcome."""
    path = Path(db_path) if db_path else config.DB_PATH
    conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    return conn
