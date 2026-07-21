"""Remediation R1-2 — migrate a factory_corpus DB to the append-only, content-bound shape (schema factory-2).

WHAT IT DOES (in place, idempotent, gated on schema shape — see corpus.migrate_appendonly / corpus.migrate_db):
  * adds `candidate.relation_waiver` (owner override for R1-1 blocking grounding),
  * rebuilds gate_result / independent_answer / judge_verdict as APPEND-ONLY tables
    (id AUTOINCREMENT + item_hash), backfilling item_hash from each candidate's CURRENT item_hash,
  * adds UNIQUE(run_id, spec_id), the _latest views, and the new indexes,
  * bumps factory_meta.schema_version to 'factory-2'.

WHAT IT DOES NOT DO: it NEVER re-runs the certify promotion. No row is promoted or demoted; the certified count
is asserted UNCHANGED before/after (aborts otherwise). candidate_id is left untouched, so all evidence linkage
and the 22 owner-gated certified rows are preserved exactly.

⚠ Path guard: refuses any DB outside KIE_HOME. Run against a COPY first to verify, then against the live DB at
integration time. Safe to run repeatedly.

Usage:
  python -m kie.qie.remediation.migrate_factory_appendonly                     # migrate the default factory DB
  python -m kie.qie.remediation.migrate_factory_appendonly --db <path>         # migrate a specific DB (a copy)
  python -m kie.qie.remediation.migrate_factory_appendonly --db <path> --check # report shape only, no changes
"""
from __future__ import annotations

import argparse
import sqlite3
import sys
from pathlib import Path

from kie import config
from kie.qie.factory import corpus as CO


def _shape(db_path: Path) -> dict:
    """Read-only inspection of the current schema shape (no mutation)."""
    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    try:
        ver = None
        if CO._table_exists(conn, "factory_meta"):
            row = conn.execute("SELECT value FROM factory_meta WHERE key='schema_version'").fetchone()
            ver = row["value"] if row else None
        return {
            "schema_version": ver,
            "candidate_has_relation_waiver": CO._table_exists(conn, "candidate")
                                             and CO._has_col(conn, "candidate", "relation_waiver"),
            "gate_result_append_only": CO._table_exists(conn, "gate_result")
                                       and CO._has_col(conn, "gate_result", "item_hash"),
            "status_counts": CO._status_counts(conn),
        }
    finally:
        conn.close()


def migrate(db_path, check: bool = False) -> dict:
    p = config.assert_under_kie_home(db_path)
    if not p.exists():
        raise FileNotFoundError(f"factory DB not present: {p}")
    if check:
        return {"check": True, "path": str(p), "shape": _shape(p)}
    before = _shape(p)
    result = CO.migrate_db(str(p))
    result.update({"path": str(p), "shape_before": before, "shape_after": _shape(p)})
    return result


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--db", default=str(CO.CORPUS_DB_PATH),
                    help="factory DB to migrate (default: the live factory_corpus.db). Use a COPY to verify.")
    ap.add_argument("--check", action="store_true", help="report current schema shape only; make no changes")
    args = ap.parse_args(argv)

    db = Path(args.db)
    print(f"== R1-2 factory append-only migration [{'CHECK' if args.check else 'APPLY'}] :: {db} ==")
    out = migrate(db, check=args.check)
    if args.check:
        print(f"   shape: {out['shape']}")
        return 0
    print(f"   changed={out['changed']} schema_version={out['schema_version']}")
    print(f"   status before: {out['before']}")
    print(f"   status after : {out['after']}")
    print(f"   certified unchanged: {out['before'].get('certified', 0)} -> {out['after'].get('certified', 0)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
