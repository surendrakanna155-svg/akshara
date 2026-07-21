"""Remediation R3-6 — run-scoped excision / recall of a bad batch from a factory store.

WHY THIS EXISTS (pairs with R1-3's no-fix-forward rule): the standing law is that a defect discovered in a
CERTIFIED artifact is never patched in place and never silently re-derived — the affected batch is RECALLED
(excised) and must re-earn certification through the gates. There was no batch-excision routine, and raw status
flips overwrote reject_reason history. This module provides the recall.

DESIGN (the project's money-integrity race pattern + honest-audit discipline):
  * GUARDED transitions: `UPDATE candidate SET status='excised' WHERE candidate_id=? AND status=<expected>`,
    asserting rowcount == 1 per row; ANY deviation ABORTS the whole transaction (nothing committed).
  * PRIOR STATE PRESERVED, HISTORY NOT OVERWRITTEN: the transition changes ONLY `status`; a `status_audit` row
    records (from_status -> 'excised', reason, at). `reject_reason` is left EXACTLY as it was — the recall never
    destroys the evidence of why a row reached its prior state.
  * 'excised' is TERMINAL: an excised row is not 'certified', so product_inventory / certified_bank never see
    it, it leaves the partial UNIQUE dedup index, and no later gate/certify pass can pick it up. Re-entry is by
    a FRESH run through the full evidence chain — never by un-excising.
  * DRY-RUN BY DEFAULT: prints exactly what it would do. `--apply` performs the flip.
  * Path guard (R0-4): refuses any store outside KIE_HOME. NO-LIVE-MUTATION discipline — test on a COPY first.

RECALL PROCEDURE (documented, pairs with R1-3):
  1. Identify the bad batch by run_id (and optionally the exact statuses to recall — default: 'certified').
  2. Dry-run: `python -m kie.qie.remediation.excise_run --db <store> --run <run_id>` — read the plan.
  3. Back up the store off-machine (R0-1), then `--apply` (owner decision for a production bank).
  4. The excised rows leave product inventory immediately; status_audit holds the recall trail; reject_reason
     history is intact. Re-certification, if warranted, happens in a NEW run — fix-forward is prohibited.

Usage:
  python -m kie.qie.remediation.excise_run --db <store> --run <run_id>                    # dry run (default)
  python -m kie.qie.remediation.excise_run --db <store> --run <run_id> --status certified quarantined
  python -m kie.qie.remediation.excise_run --db <store> --run <run_id> --reason "recall-2026-..." --apply
"""
from __future__ import annotations

import argparse
import sqlite3
import sys
from pathlib import Path
from typing import List

from kie import config
from kie.qie.factory import corpus as CO

EXCISED = "excised"                 # terminal recall state; never product-visible, never re-picked-up


def plan(conn: sqlite3.Connection, run_id: str, statuses) -> List[tuple]:
    """The rows a recall WOULD excise: (candidate_id, current_status) for this run in the target statuses."""
    qs = ",".join("?" * len(statuses))
    return [(r["candidate_id"], r["status"]) for r in conn.execute(
        f"SELECT candidate_id, status FROM candidate WHERE run_id=? AND status IN ({qs}) ORDER BY candidate_id",
        (run_id, *statuses))]


def excise_run(db_path, run_id: str, reason: str, statuses=(CO.CERTIFIED,), apply: bool = False) -> dict:
    """Run-scoped excision. Guarded, audited, idempotent-safe (a re-run finds nothing in `statuses`).

    Returns a summary. `apply=False` (default) is a dry run that mutates nothing. `reason` is REQUIRED on apply
    — a recall must say why. `statuses` are the states eligible for recall (default: certified only)."""
    p = config.assert_under_kie_home(db_path)
    if not p.exists():
        raise FileNotFoundError(f"factory DB not present: {p}")
    if apply and not (reason or "").strip():
        raise ValueError("a recall requires a --reason (it is written to status_audit)")
    conn = sqlite3.connect(str(p))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys=ON")
    try:
        rows = plan(conn, run_id, tuple(statuses))
        out = {"db": p.name, "run_id": run_id, "statuses": list(statuses), "eligible": len(rows),
               "excised": 0, "apply": apply, "plan": rows}
        if not rows or not apply:
            return out
        conn.executescript(CO.STATUS_AUDIT_DDL)
        for cid, cur_status in rows:
            c = conn.execute("UPDATE candidate SET status=? WHERE candidate_id=? AND status=?",
                             (EXCISED, cid, cur_status))
            if c.rowcount != 1:
                conn.rollback()
                raise CO.CorpusIntegrityError(
                    f"guarded excision failed for {cid}: rowcount={c.rowcount} (expected 1) — aborting, "
                    f"nothing committed")
            conn.execute("INSERT INTO status_audit(entity_table, entity_id, from_status, to_status, reason) "
                         "VALUES('candidate',?,?,?,?)", (cid, cur_status, EXCISED, reason))
        # post-condition: none of the targeted rows remain in their prior statuses for this run
        remaining = conn.execute(
            f"SELECT COUNT(*) FROM candidate WHERE run_id=? AND status IN ({','.join('?'*len(statuses))})",
            (run_id, *statuses)).fetchone()[0]
        if remaining != 0:
            conn.rollback()
            raise CO.CorpusIntegrityError(f"post-check failed: {remaining} target rows remain after excision")
        conn.commit()
        out["excised"] = len(rows)
        return out
    finally:
        conn.close()


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--db", required=True, help="factory store to recall from (a COPY unless owner-approved)")
    ap.add_argument("--run", required=True, help="run_id to excise")
    ap.add_argument("--status", nargs="+", default=[CO.CERTIFIED],
                    help="statuses eligible for recall (default: certified)")
    ap.add_argument("--reason", default="", help="recall reason (required with --apply; written to status_audit)")
    ap.add_argument("--apply", action="store_true", help="perform the excision (default is a dry run)")
    args = ap.parse_args(argv)

    mode = "APPLY" if args.apply else "DRY RUN"
    print(f"== R3-6 run-scoped excision [{mode}] :: {Path(args.db).name} run={args.run} ==")
    out = excise_run(args.db, args.run, args.reason, statuses=tuple(args.status), apply=args.apply)
    for cid, st in out["plan"]:
        print(f"      {'excised' if args.apply else 'would excise'} {cid} (was {st})")
    print(f"== {'excised' if args.apply else 'would excise'} {out['excised'] if args.apply else out['eligible']} "
          f"row(s) from run {args.run} ==")
    if not args.apply:
        print("   (dry run — no changes. Re-run with --reason ... --apply after a backup + owner approval.)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
