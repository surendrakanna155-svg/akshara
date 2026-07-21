"""Remediation R0-2 — quarantine the audit-flagged certified estate.

Flips the 22 factory-lane "certified" questions (qpl_question_bank.db) and the 7
"certified" QDI patterns (qdi.db) from `certified → quarantined`, because the audit
proved they were promoted by bypassable guards (self-consistency, not truth), with the
solution stage skipped, and — for the QDI patterns — on false provenance.

Design (from the roadmap + the project's money-integrity race pattern):
  * GUARDED transitions: `UPDATE ... SET status='quarantined' WHERE id=? AND status='certified'`,
    asserting rowcount == 1 per row; ANY deviation aborts the whole transaction.
  * PRIOR STATE PRESERVED: writes a `status_audit` row per flip (from_status, to_status,
    reason, at) — it NEVER overwrites `reject_reason` history.
  * IDEMPOTENT-safe: re-running finds 0 certified rows and reports "nothing to do".
  * DRY-RUN BY DEFAULT: prints exactly what it would do. `--apply` performs the flip.

⚠ EXECUTION IS AN OWNER DECISION. The roadmap tags R0-2 "(OWNER decision to execute)".
This module is prepared and dry-run-verified but must NOT be `--apply`-ed without the
owner's go-ahead. Re-certification happens automatically when the R1/R2 gates re-run
these items after Phase R1 lands.

Usage:
  python -m kie.qie.remediation.quarantine_audited_estate            # dry run (default)
  python -m kie.qie.remediation.quarantine_audited_estate --apply    # OWNER-approved flip
"""
from __future__ import annotations

import argparse
import sqlite3
import sys
from pathlib import Path

from kie import config

REASON = "audit-2026-07-21"

# (db filename, table, id column, human label)
TARGETS = [
    ("qpl_question_bank.db", "candidate", "candidate_id", "factory question"),
    ("qdi.db", "qdi_pattern", "pattern_id", "QDI pattern"),
]

STATUS_AUDIT_DDL = """
CREATE TABLE IF NOT EXISTS status_audit (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_table TEXT NOT NULL,
  entity_id    TEXT NOT NULL,
  from_status  TEXT NOT NULL,
  to_status    TEXT NOT NULL,
  reason       TEXT NOT NULL,
  at           TEXT NOT NULL DEFAULT (datetime('now'))
);
"""


def _rows_to_flip(conn: sqlite3.Connection, table: str, idcol: str):
    return [r[0] for r in conn.execute(
        f"SELECT {idcol} FROM {table} WHERE status='certified' ORDER BY {idcol}"
    ).fetchall()]


def process(db_path: Path, table: str, idcol: str, label: str, apply: bool) -> int:
    if not db_path.exists():
        print(f"  [skip] {db_path.name}: not present")
        return 0
    # path guard (R0-4): never touch a store outside KIE_HOME
    config.assert_under_kie_home(db_path)
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys=ON;")
    try:
        ids = _rows_to_flip(conn, table, idcol)
        print(f"  {db_path.name}::{table} — {len(ids)} certified {label}(s) to quarantine")
        if not ids:
            return 0
        if not apply:
            for i in ids:
                print(f"      would quarantine {i}")
            return len(ids)

        conn.execute(STATUS_AUDIT_DDL)
        flipped = 0
        for i in ids:
            cur = conn.execute(
                f"UPDATE {table} SET status='quarantined' "
                f"WHERE {idcol}=? AND status='certified'",
                (i,),
            )
            if cur.rowcount != 1:
                conn.rollback()
                raise RuntimeError(
                    f"guarded transition failed for {i}: rowcount={cur.rowcount} "
                    f"(expected 1) — aborting, no changes committed"
                )
            conn.execute(
                "INSERT INTO status_audit(entity_table, entity_id, from_status, "
                "to_status, reason) VALUES (?,?,?,?,?)",
                (table, i, "certified", "quarantined", REASON),
            )
            flipped += 1
        # post-condition: zero certified rows remain
        remaining = conn.execute(
            f"SELECT COUNT(*) FROM {table} WHERE status='certified'"
        ).fetchone()[0]
        if remaining != 0:
            conn.rollback()
            raise RuntimeError(f"post-check failed: {remaining} certified rows remain")
        conn.commit()
        print(f"      quarantined {flipped}; certified now 0; audit rows written")
        return flipped
    finally:
        conn.close()


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--apply", action="store_true",
                    help="OWNER-approved: perform the flip (default is dry run)")
    args = ap.parse_args(argv)

    mode = "APPLY" if args.apply else "DRY RUN"
    print(f"== R0-2 quarantine audited estate [{mode}] ==")
    if not args.apply:
        print("   (dry run — no changes. Re-run with --apply ONLY after owner approval.)")
    total = 0
    for fname, table, idcol, label in TARGETS:
        total += process(config.KIE_HOME / fname, table, idcol, label, args.apply)
    print(f"== {'quarantined' if args.apply else 'would quarantine'} {total} artifact(s) ==")
    return 0


if __name__ == "__main__":
    sys.exit(main())
