#!/usr/bin/env python3
"""Run the KIE/QIE test suite with a LOUD skip summary + a canonical-machine guard (remediation R3-3).

The audit found that skipUnless(DB-exists) guards make the suite vacuously green on any machine WITHOUT the
gitignored knowledge/question DBs — a silently-missing DB reads as a pass. This runner closes that:

  * runs the whole suite (fixtures-only tests always run; DB / PDF-input tests self-skip when absent);
  * prints a categorized skip summary (which suites skipped for a missing DB/input, and which for other reasons);
  * on the CANONICAL machine (env KIE_CANONICAL=1 — where the local estate SHOULD be complete) it FAILS
    (exit 1) if any test skipped for a missing DB/input, so a vacuous green can never slip through.

In CI (KIE_CANONICAL unset) the gitignored DBs are legitimately absent, so DB-skips are expected and allowed —
only real failures/errors fail the run. Usage:
    cd curriculum/scripts/intelligence
    ../../.venv/bin/python -m kie.tests.run_kie_suite          # CI/dev: skips allowed
    KIE_CANONICAL=1 ../../.venv/bin/python -m kie.tests.run_kie_suite   # dev: fail on any DB-skip
"""
from __future__ import annotations

import os
import sys
import unittest

# a skip is "DB/input-missing" (vacuous-green risk) when its reason names a gitignored store or input file.
_DB_SKIP_MARKERS = ("gitignored", "local only", "not present", "knowledge_index", "kie.db", "qie.db",
                    "qdi.db", "factory_corpus", "qpl_question_bank", "examdna", "db not", "database",
                    "frozen", "no pdf", "sample pdf", "fixture pdf")


def main() -> int:
    here = os.path.dirname(os.path.abspath(__file__))              # …/kie/tests
    top = os.path.abspath(os.path.join(here, "..", ".."))          # …/curriculum/scripts/intelligence
    if top not in sys.path:
        sys.path.insert(0, top)
    suite = unittest.TestLoader().discover(start_dir=here, top_level_dir=top)
    result = unittest.TextTestRunner(verbosity=1).run(suite)

    def _is_db(reason: str) -> bool:
        rl = (reason or "").lower()
        return any(m in rl for m in _DB_SKIP_MARKERS)

    db_skips = [(str(t), r) for (t, r) in result.skipped if _is_db(r)]
    other_skips = [(str(t), r) for (t, r) in result.skipped if not _is_db(r)]

    print("\n" + "=" * 74)
    print(f"KIE SUITE SUMMARY: ran={result.testsRun} failures={len(result.failures)} "
          f"errors={len(result.errors)} skipped={len(result.skipped)} "
          f"(db/input-missing={len(db_skips)}, other={len(other_skips)})")
    for t, r in db_skips:
        print(f"  [db/input-skip] {t} :: {r}")
    print("=" * 74)

    failed = bool(result.failures or result.errors)
    if os.environ.get("KIE_CANONICAL") == "1" and db_skips:
        print(f"\nCANONICAL MACHINE GUARD: {len(db_skips)} test(s) skipped for a MISSING DB/input — the local "
              f"estate is incomplete, so a green run would be VACUOUS. Failing loudly. (Unset KIE_CANONICAL "
              f"to run without the guard, e.g. in CI where the gitignored DBs are legitimately absent.)",
              file=sys.stderr)
        failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
