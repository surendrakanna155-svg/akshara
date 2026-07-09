"""Idempotent per-(doc, stage) checkpoint ledger — enables mid-phase recovery.

A stage reprocesses a doc only when its ledger row is absent/failed or the
input checksum changed (incremental update, KIE_ARCHITECTURE §9/§14).
"""
from __future__ import annotations

import sqlite3
from datetime import datetime, timezone
from typing import Optional, Tuple


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def record(
    conn: sqlite3.Connection,
    doc_id: str,
    stage: str,
    status: str,
    input_sha256: Optional[str] = None,
    output_ref: Optional[str] = None,
    error: Optional[str] = None,
) -> None:
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
    row = conn.execute(
        "SELECT status, input_sha256 FROM stage_ledger WHERE doc_id = ? AND stage = ?",
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
    rows = conn.execute(
        "SELECT status, COUNT(*) AS n FROM stage_ledger WHERE stage = ? GROUP BY status",
        (stage,),
    ).fetchall()
    return {r["status"]: r["n"] for r in rows}
