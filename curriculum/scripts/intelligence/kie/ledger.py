"""Idempotent per-(doc, stage) checkpoint ledger — enables mid-phase recovery.

A stage reprocesses a doc only when its ledger row is absent/failed or the
input checksum changed (incremental update, KIE_ARCHITECTURE §9/§14).

APPEND-ONLY (R2-3, RI-10): on the current schema every re-run of a stage APPENDS a new attempt row
(PK includes `attempt`) rather than overwriting the prior outcome, so the failed→done / content-change
history is preserved. `stage_ledger_latest` (a view) exposes the most recent attempt so the readers below keep
their single-row semantics. These functions are SHAPE-ADAPTIVE: an older, historical store whose `stage_ledger`
still carries the legacy upsert shape (PK (doc_id, stage), no `attempt` column — e.g. the frozen kie.db copy)
is written with the original ON CONFLICT upsert and read from the base table, so nothing pre-existing is
rewritten and no freeze is breached. New/intake stores get the append-only shape from schema.sql.
"""
from __future__ import annotations

import sqlite3
from datetime import datetime, timezone
from typing import Optional, Tuple


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _is_append_only(conn: sqlite3.Connection) -> bool:
    """True iff stage_ledger carries the append-only shape (has an `attempt` column)."""
    try:
        return any(r[1] == "attempt" for r in conn.execute("PRAGMA table_info(stage_ledger)"))
    except sqlite3.Error:
        return False


def _latest_source(conn: sqlite3.Connection) -> str:
    """The relation readers query for the latest attempt per (doc, stage): the `_latest` view on the
    append-only shape, else the base table (which holds exactly one row per (doc, stage) on the legacy shape)."""
    try:
        if conn.execute("SELECT 1 FROM sqlite_master WHERE type='view' AND name='stage_ledger_latest'"
                        ).fetchone():
            return "stage_ledger_latest"
    except sqlite3.Error:
        pass
    return "stage_ledger"


def record(
    conn: sqlite3.Connection,
    doc_id: str,
    stage: str,
    status: str,
    input_sha256: Optional[str] = None,
    output_ref: Optional[str] = None,
    error: Optional[str] = None,
) -> None:
    if _is_append_only(conn):
        nxt = conn.execute("SELECT COALESCE(MAX(attempt), 0) + 1 FROM stage_ledger WHERE doc_id=? AND stage=?",
                           (doc_id, stage)).fetchone()[0]
        conn.execute(
            "INSERT INTO stage_ledger(doc_id, stage, status, input_sha256, output_ref, error, attempt, "
            "updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (doc_id, stage, status, input_sha256, output_ref, error, nxt, _now()),
        )
        return
    conn.execute(
        """INSERT INTO stage_ledger(doc_id, stage, status, input_sha256, output_ref, error, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?)
           ON CONFLICT(doc_id, stage) DO UPDATE SET
             status       = excluded.status,
             input_sha256 = excluded.input_sha256,
             output_ref   = excluded.output_ref,
             error        = excluded.error,
             updated_at   = excluded.updated_at""",
        (doc_id, stage, status, input_sha256, output_ref, error, _now()),
    )


def get(conn: sqlite3.Connection, doc_id: str, stage: str) -> Tuple[Optional[str], Optional[str]]:
    src = _latest_source(conn)
    row = conn.execute(
        f"SELECT status, input_sha256 FROM {src} WHERE doc_id = ? AND stage = ?",
        (doc_id, stage),
    ).fetchone()
    return (row["status"], row["input_sha256"]) if row else (None, None)


def needs_run(
    conn: sqlite3.Connection,
    doc_id: str,
    stage: str,
    input_sha256: Optional[str],
    force: bool = False,
) -> bool:
    if force:
        return True
    status, prev = get(conn, doc_id, stage)
    if status != "done":
        return True
    return prev != input_sha256


def counts(conn: sqlite3.Connection, stage: str) -> dict:
    src = _latest_source(conn)
    rows = conn.execute(
        f"SELECT status, COUNT(*) AS n FROM {src} WHERE stage = ? GROUP BY status",
        (stage,),
    ).fetchall()
    return {r["status"]: r["n"] for r in rows}
