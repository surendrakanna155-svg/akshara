"""Remediation R2-3 — migrate a factory_corpus DB to the provenance/telemetry shape (schema factory-4).

WHAT IT DOES (in place, idempotent, PURELY ADDITIVE — see corpus.migrate_r2_3 / corpus.migrate_db):
  * ensures the factory-2 append-only + factory-3 R2 shapes first (runs the earlier migrators if needed),
  * adds candidate.{model_version, prompt_sha256, payload_sha256, generator_actor, contract_version},
  * adds judge_verdict.{model_version, prompt_sha256, payload_sha256, judge_actor},
  * adds gate_result.actor, independent_answer.actor, run_telemetry.actor,
  * bumps factory_meta.schema_version to 'factory-4'.

WHAT IT DOES NOT DO: it NEVER re-runs the certify promotion and never changes a row's lifecycle STATUS or its
provenance values. The certified COUNT is asserted UNCHANGED before/after (aborts otherwise). The new columns
are born NULL on legacy rows (honest null — NOTHING is backfilled/fabricated). Legacy certified rows were
already product-invisible under factory-3 (certification_class NULL); this migration only records their missing
provenance surface so the RI-8 placeholder scan can run post-re-certification. No row is promoted, demoted, or
flipped here, and no placeholder is stamped.

⚠ Path guard: refuses any DB outside KIE_HOME. Run against a COPY first to verify, then against the live DB at
integration time. Safe to run repeatedly.

Usage:
  python -m kie.qie.remediation.migrate_factory_r2_3                     # migrate the default factory DB
  python -m kie.qie.remediation.migrate_factory_r2_3 --db <path>         # migrate a specific DB (a copy)
  python -m kie.qie.remediation.migrate_factory_r2_3 --db <path> --check # report shape only, no changes
"""
from __future__ import annotations

import argparse
import sqlite3
import sys
from pathlib import Path

from kie import config
from kie.qie.factory import corpus as CO

_CAND_COLS = ("model_version", "prompt_sha256", "payload_sha256", "generator_actor", "contract_version")
_JUDGE_COLS = ("model_version", "prompt_sha256", "payload_sha256", "judge_actor")


def _shape(db_path: Path) -> dict:
    """Read-only inspection of the current schema shape + provenance coverage (no mutation)."""
    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    try:
        ver = None
        if CO._table_exists(conn, "factory_meta"):
            row = conn.execute("SELECT value FROM factory_meta WHERE key='schema_version'").fetchone()
            ver = row["value"] if row else None
        has_cand = CO._table_exists(conn, "candidate")
        cand_prov = has_cand and all(CO._has_col(conn, "candidate", c) for c in _CAND_COLS)
        judge_prov = CO._table_exists(conn, "judge_verdict") and \
            all(CO._has_col(conn, "judge_verdict", c) for c in _JUDGE_COLS)
        # how many certified rows already carry real generation provenance (0 expected pre-re-certification)
        certified_status = provenanced = None
        if has_cand:
            certified_status = conn.execute(
                "SELECT COUNT(*) FROM candidate WHERE status='certified'").fetchone()[0]
            if cand_prov:
                provenanced = conn.execute(
                    "SELECT COUNT(*) FROM candidate WHERE status='certified' "
                    "AND generator_actor IS NOT NULL AND prompt_sha256 IS NOT NULL").fetchone()[0]
        return {
            "schema_version": ver,
            "candidate_has_provenance": cand_prov,
            "judge_has_provenance": judge_prov,
            "gate_result_has_actor": CO._table_exists(conn, "gate_result")
                                     and CO._has_col(conn, "gate_result", "actor"),
            "independent_answer_has_actor": CO._table_exists(conn, "independent_answer")
                                            and CO._has_col(conn, "independent_answer", "actor"),
            "run_telemetry_has_actor": CO._table_exists(conn, "run_telemetry")
                                       and CO._has_col(conn, "run_telemetry", "actor"),
            "certified_status_rows": certified_status,
            "certified_with_provenance": provenanced,   # honest null until re-certification under R2-3
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
    result = CO.migrate_db(str(p))              # runs appendonly + r2 + r2_3, asserts cert count fixed
    result.update({"path": str(p), "shape_before": before, "shape_after": _shape(p)})
    return result


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--db", default=str(CO.CORPUS_DB_PATH),
                    help="factory DB to migrate (default: the live factory_corpus.db). Use a COPY to verify.")
    ap.add_argument("--check", action="store_true", help="report current schema shape only; make no changes")
    args = ap.parse_args(argv)

    db = Path(args.db)
    print(f"== R2-3 factory provenance/telemetry migration [{'CHECK' if args.check else 'APPLY'}] :: {db} ==")
    out = migrate(db, check=args.check)
    if args.check:
        print(f"   shape: {out['shape']}")
        return 0
    print(f"   changed={out['changed']} schema_version={out['schema_version']}")
    print(f"   status before: {out['before']}")
    print(f"   status after : {out['after']}")
    print(f"   certified(status) unchanged: {out['before'].get('certified', 0)} -> "
          f"{out['after'].get('certified', 0)}")
    print(f"   provenance columns present after: candidate={out['shape_after'].get('candidate_has_provenance')} "
          f"judge={out['shape_after'].get('judge_has_provenance')} "
          f"(legacy rows carry NULL provenance — honest null until re-certified under R2-3)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
