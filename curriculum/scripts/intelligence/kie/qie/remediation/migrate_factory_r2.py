"""Remediation R2 — migrate a factory_corpus DB to the certification-hardening shape (schema factory-3).

WHAT IT DOES (in place, idempotent, PURELY ADDITIVE — see corpus.migrate_r2 / corpus.migrate_db):
  * ensures the factory-2 append-only shape first (runs corpus.migrate_appendonly if needed),
  * adds candidate.{generator_family, evidence_class, certification_class, earned_depth, computed_archetype},
  * adds judge_verdict.judge_family,
  * backfills candidate.generator_family from the recorded generator_model (so a future cross-family judge has
    an actor family to be compared against),
  * bumps factory_meta.schema_version to 'factory-3'.

WHAT IT DOES NOT DO: it NEVER re-runs the certify promotion and never changes a row's lifecycle STATUS. The
certified COUNT is asserted UNCHANGED before/after (aborts otherwise). Because the new evidence_class /
certification_class columns are born NULL, every legacy status='certified' row immediately falls OUT of
product_inventory (which now requires certification_class='certified') until it is re-certified under the R2
gates — the intended R0-2 quarantine-by-construction. No row is promoted, demoted, or flipped here.

⚠ Path guard: refuses any DB outside KIE_HOME. Run against a COPY first to verify, then against the live DB at
integration time. Safe to run repeatedly.

Usage:
  python -m kie.qie.remediation.migrate_factory_r2                     # migrate the default factory DB
  python -m kie.qie.remediation.migrate_factory_r2 --db <path>         # migrate a specific DB (a copy)
  python -m kie.qie.remediation.migrate_factory_r2 --db <path> --check # report shape only, no changes
"""
from __future__ import annotations

import argparse
import sqlite3
import sys
from pathlib import Path

from kie import config
from kie.qie.factory import corpus as CO


def _shape(db_path: Path) -> dict:
    """Read-only inspection of the current schema shape + product-visibility counts (no mutation)."""
    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    try:
        ver = None
        if CO._table_exists(conn, "factory_meta"):
            row = conn.execute("SELECT value FROM factory_meta WHERE key='schema_version'").fetchone()
            ver = row["value"] if row else None
        has_cand = CO._table_exists(conn, "candidate")
        product_visible = None
        certified_status = None
        if has_cand and CO._has_col(conn, "candidate", "certification_class"):
            product_visible = conn.execute(
                "SELECT COUNT(*) FROM candidate WHERE status='certified' AND certification_class='certified'"
            ).fetchone()[0]
        if has_cand:
            certified_status = conn.execute(
                "SELECT COUNT(*) FROM candidate WHERE status='certified'").fetchone()[0]
        return {
            "schema_version": ver,
            "candidate_has_generator_family": has_cand and CO._has_col(conn, "candidate", "generator_family"),
            "candidate_has_evidence_class": has_cand and CO._has_col(conn, "candidate", "evidence_class"),
            "candidate_has_certification_class": has_cand
                                                 and CO._has_col(conn, "candidate", "certification_class"),
            "candidate_has_earned_depth": has_cand and CO._has_col(conn, "candidate", "earned_depth"),
            "judge_has_judge_family": CO._table_exists(conn, "judge_verdict")
                                      and CO._has_col(conn, "judge_verdict", "judge_family"),
            "certified_status_rows": certified_status,       # status='certified' (may include legacy/provisional)
            "product_visible_rows": product_visible,          # status+certification_class='certified' (R2 gate)
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
    result = CO.migrate_db(str(p))              # runs migrate_appendonly + migrate_r2, asserts cert count fixed
    result.update({"path": str(p), "shape_before": before, "shape_after": _shape(p)})
    return result


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--db", default=str(CO.CORPUS_DB_PATH),
                    help="factory DB to migrate (default: the live factory_corpus.db). Use a COPY to verify.")
    ap.add_argument("--check", action="store_true", help="report current schema shape only; make no changes")
    args = ap.parse_args(argv)

    db = Path(args.db)
    print(f"== R2 factory certification-hardening migration [{'CHECK' if args.check else 'APPLY'}] :: {db} ==")
    out = migrate(db, check=args.check)
    if args.check:
        print(f"   shape: {out['shape']}")
        return 0
    print(f"   changed={out['changed']} schema_version={out['schema_version']}")
    print(f"   status before: {out['before']}")
    print(f"   status after : {out['after']}")
    print(f"   certified(status) unchanged: {out['before'].get('certified', 0)} -> "
          f"{out['after'].get('certified', 0)}")
    print(f"   product-visible after: {out['shape_after'].get('product_visible_rows')} "
          f"(legacy certified rows are invisible until re-certified under the R2 gates)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
