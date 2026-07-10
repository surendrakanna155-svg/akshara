"""Apply the Intake Center's additive control-table schema onto a KIE store.

Kept OUT of kie.store.migrate so the frozen core schema (Phases 1-7) is never
touched. Callers open the store the normal way (`store.open_store`) then call
`apply_intake_schema(conn)` once — it is idempotent (CREATE TABLE IF NOT EXISTS).
"""
from __future__ import annotations

import sqlite3
from datetime import datetime, timezone
from pathlib import Path

INTAKE_SCHEMA_PATH = Path(__file__).resolve().parent / "schema.sql"

INTAKE_TABLES = ("intake_batches", "intake_items", "document_versions", "watch_state")


def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def apply_intake_schema(conn: sqlite3.Connection) -> None:
    """Create the intake control tables if absent. Idempotent; commits."""
    conn.executescript(INTAKE_SCHEMA_PATH.read_text())
    conn.commit()


def has_intake_schema(conn: sqlite3.Connection) -> bool:
    rows = {
        r[0]
        for r in conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name IN "
            "('intake_batches','intake_items','document_versions','watch_state')"
        ).fetchall()
    }
    return rows == set(INTAKE_TABLES)
