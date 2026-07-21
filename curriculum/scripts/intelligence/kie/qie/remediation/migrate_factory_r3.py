"""Remediation R3-1/R3-2 — migrate a factory store to the store-role + bank-dedup shape (schema factory-5).

WHAT IT DOES (in place, idempotent — see corpus.migrate_r3 / corpus.migrate_db):
  * ensures the factory-2/3/4 shapes first (runs the earlier migrators if needed),
  * ADDITIVE SCHEMA (both roles): the bank-level partial UNIQUE indexes over PRODUCT-visible certified
    item_hash / stem_norm_hash — the RI-9 backstop that no two product rows in a store share content
    (created only after a fail-closed no-existing-dupe check),
  * ROLE STAMP: factory_meta.role = 'production_bank' | 'trial_corpus' (R3-1, RI-6),
  * TRIAL ONLY (--role trial_corpus): demotes every certified row's certification_class to 'trial_certified'
    (product-INVISIBLE forever) AND closes the forever-'candidate' rows to the terminal 'expired_unjudged'
    status (a status_audit row preserves prior state — reject_reason history is never overwritten),
  * bumps factory_meta.schema_version to 'factory-5'.

WHAT IT DOES NOT DO: it NEVER re-runs the certify promotion. The certified STATUS count is asserted UNCHANGED
before/after (aborts otherwise) — the trial demotion changes product-VISIBILITY (certification_class), not the
certified STATUS count; the run-closure moves 'candidate' rows to 'expired_unjudged' and never touches certified
rows. No row is promoted, and no placeholder is stamped.

DEFAULT ROLE BY PATH: qpl_question_bank.db -> production_bank; factory_corpus.db -> trial_corpus (+ demotion).
Override with --role / --no-demote-trial.

⚠ Path guard: refuses any DB outside KIE_HOME. NO-LIVE-MUTATION discipline: run --check first, then run --apply
against a COPY to verify counts, and only then (owner decision) against the live store. Safe to run repeatedly.

Usage:
  python -m kie.qie.remediation.migrate_factory_r3 --check                         # shape only, no changes
  python -m kie.qie.remediation.migrate_factory_r3 --db <copy_of_bank.db> --apply  # production bank (copy)
  python -m kie.qie.remediation.migrate_factory_r3 --db <copy_of_trial.db> --apply # trial (copy): demote+close
  python -m kie.qie.remediation.migrate_factory_r3 --db <path> --role production_bank --apply
"""
from __future__ import annotations

import argparse
import sqlite3
import sys
from pathlib import Path

from kie import config
from kie.qie.factory import corpus as CO


def _default_role(db_path: Path) -> str:
    """Infer the store's role from its filename: the one authoritative bank vs the discredited trial corpus."""
    name = Path(db_path).name
    if name == CO.PRODUCTION_BANK_DB_PATH.name:
        return CO.ROLE_PRODUCTION
    if name == CO.CORPUS_DB_PATH.name:
        return CO.ROLE_TRIAL
    return CO.ROLE_PRODUCTION      # unknown store: default to the guarded production role (opt into trial)


def _shape(db_path: Path) -> dict:
    """Read-only inspection of role + version + product-visibility + dedup-index presence (no mutation)."""
    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    try:
        ver = role = None
        if CO._table_exists(conn, "factory_meta"):
            vr = conn.execute("SELECT value FROM factory_meta WHERE key='schema_version'").fetchone()
            ver = vr["value"] if vr else None
            role = CO.store_role(conn)
        has_cand = CO._table_exists(conn, "candidate")
        idx = {r["name"] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='index'")}
        product_visible = certified_status = trial_certified = expired = None
        if has_cand:
            certified_status = conn.execute(
                "SELECT COUNT(*) FROM candidate WHERE status='certified'").fetchone()[0]
            if CO._has_col(conn, "candidate", "certification_class"):
                product_visible = conn.execute(
                    "SELECT COUNT(*) FROM candidate WHERE status='certified' AND certification_class='certified'"
                ).fetchone()[0]
                trial_certified = conn.execute(
                    "SELECT COUNT(*) FROM candidate WHERE status='certified' "
                    "AND certification_class='trial_certified'").fetchone()[0]
            expired = conn.execute(
                "SELECT COUNT(*) FROM candidate WHERE status='expired_unjudged'").fetchone()[0]
        return {
            "schema_version": ver,
            "role": role,
            "has_dedup_indexes": {"ux_cert_item_hash", "ux_cert_norm_hash"} <= idx,
            "certified_status_rows": certified_status,    # status='certified' (may include trial/provisional)
            "product_visible_rows": product_visible,      # status+certification_class='certified' (product bank)
            "trial_certified_rows": trial_certified,
            "expired_unjudged_rows": expired,
            "status_counts": CO._status_counts(conn),
        }
    finally:
        conn.close()


def migrate(db_path, role: str = None, demote_trial: bool = None, check: bool = False) -> dict:
    p = config.assert_under_kie_home(db_path)
    if not p.exists():
        raise FileNotFoundError(f"factory DB not present: {p}")
    if role is None:
        role = _default_role(p)
    if demote_trial is None:
        demote_trial = (role == CO.ROLE_TRIAL)
    if check:
        return {"check": True, "path": str(p), "role_to_stamp": role, "demote_trial": demote_trial,
                "shape": _shape(p)}
    before = _shape(p)
    result = CO.migrate_db(str(p), role=role, demote_trial=demote_trial)   # asserts certified STATUS count fixed
    result.update({"path": str(p), "role_stamped": role, "demote_trial": demote_trial,
                   "shape_before": before, "shape_after": _shape(p)})
    return result


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--db", default=str(CO.PRODUCTION_BANK_DB_PATH),
                    help="factory DB to migrate (default: the live production bank). Use a COPY to verify.")
    ap.add_argument("--role", choices=[CO.ROLE_PRODUCTION, CO.ROLE_TRIAL], default=None,
                    help="role to stamp (default: inferred from the filename)")
    ap.add_argument("--demote-trial", dest="demote_trial", action="store_true", default=None,
                    help="force the trial demotion + run-closure (default: on iff role=trial_corpus)")
    ap.add_argument("--no-demote-trial", dest="demote_trial", action="store_false",
                    help="skip the trial demotion + run-closure")
    ap.add_argument("--apply", action="store_true", help="perform the migration (default is --check)")
    ap.add_argument("--check", action="store_true", help="report current shape only; make no changes")
    args = ap.parse_args(argv)

    db = Path(args.db)
    do_check = args.check or not args.apply
    print(f"== R3-1/R3-2 factory store-role + bank-dedup migration [{'CHECK' if do_check else 'APPLY'}] :: {db} ==")
    out = migrate(db, role=args.role, demote_trial=args.demote_trial, check=do_check)
    if do_check:
        print(f"   role_to_stamp={out['role_to_stamp']} demote_trial={out['demote_trial']}")
        print(f"   shape: {out['shape']}")
        return 0
    print(f"   changed={out['changed']} schema_version={out['schema_version']} role={out['role']}")
    print(f"   status before: {out['before']}")
    print(f"   status after : {out['after']}")
    print(f"   certified(status) unchanged: {out['before'].get('certified', 0)} -> "
          f"{out['after'].get('certified', 0)}")
    print(f"   product-visible after: {out['shape_after'].get('product_visible_rows')}  "
          f"trial_certified: {out['shape_after'].get('trial_certified_rows')}  "
          f"expired_unjudged: {out['shape_after'].get('expired_unjudged_rows')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
