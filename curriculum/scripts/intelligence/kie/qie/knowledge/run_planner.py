"""STAGE 2 driver — run the CERTIFIED-ONLY question planner against the FROZEN v1.4 knowledge index.

This is the single sanctioned entry to question planning. It reads ONLY the independently-audited
certified knowledge index (`ki_concept.status='certified'`) and the certified design intelligence
(`qdi_pattern.status='certified'`), both strictly READ-ONLY. The old kie.db planning path
(`factory/manifest.py` + `factory/trust.py`) has been RETIRED — nothing here ever touches
`kie.db.concepts`, and the foundation is opened `mode=ro` so planning can never mutate it.

Determinism note (Phase 1 state): the spec CONTENT is still seed-sampled inside `plan_specs.build_specs`.
Phase 3 replaces that RNG with a deterministic, Exam-DNA-driven allocator. This driver's contract —
same frozen index + same args -> same issued specs — is stable across that change.
"""
from __future__ import annotations

import sqlite3
from typing import Dict, List, Optional

from kie import config
from kie.qie.knowledge import plan_specs as PS
from kie.qie.knowledge import planner as P
from kie.qie.knowledge import qdi as QDI

INDEX_DB_PATH = config.KIE_HOME / "knowledge_index.db"

# subjects exactly as they appear in the certified index's curriculum-source `subject` column
CERTIFIED_SUBJECTS = ("Mathematics", "Science", "Physics", "Chemistry", "Biology")


def open_frozen_index(path=None) -> sqlite3.Connection:
    """Open the immutable v1.4 foundation READ-ONLY. Planning must never write to the foundation."""
    p = str(path or INDEX_DB_PATH)
    conn = sqlite3.connect(f"file:{p}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    return conn


def _certified_patterns(conn: sqlite3.Connection, subject: str) -> List[dict]:
    """Certified design intelligence for this subject (0 today; QDI certification is Phase 4)."""
    try:
        return QDI.certified_patterns(conn, subject)
    except sqlite3.OperationalError:
        return []  # a stripped index without qdi_* tables — plan on the curriculum boundary alone


def plan(subject: str, run_id: str, classes: Optional[List[int]] = None, n: int = 120,
         seed: int = 20260716, index_path=None) -> Dict[str, object]:
    """certified_universe -> dedupe -> certified design patterns -> gate-validated specs."""
    conn = open_frozen_index(index_path)
    try:
        universe = P.certified_universe(conn, subject, classes)
        universe, _dups = P.dedupe_universe(universe)
        patterns = _certified_patterns(conn, subject)
    finally:
        conn.close()
    return PS.build_specs(universe, patterns, run_id, n=n, seed=seed, subject=subject)


def _main() -> int:
    import argparse

    ap = argparse.ArgumentParser(description="Run the certified-only question planner on frozen v1.4.")
    ap.add_argument("subject", nargs="?", default=None, help="one of %s" % ", ".join(CERTIFIED_SUBJECTS))
    ap.add_argument("--classes", type=int, nargs="*", default=None)
    ap.add_argument("--n", type=int, default=60)
    ap.add_argument("--seed", type=int, default=20260716)
    ap.add_argument("--run-id", default="plan_dev")
    args = ap.parse_args()

    subjects = [args.subject] if args.subject else list(CERTIFIED_SUBJECTS)
    for s in subjects:
        out = plan(s, args.run_id, classes=args.classes, n=args.n, seed=args.seed)
        issued, refused = out.get("issued", []), out.get("refused", [])
        note = f"  ({out['note']})" if out.get("note") else ""
        print(f"{s:12s} planned={out.get('planned', 0):4d}  issued={len(issued):4d}  "
              f"refused={len(refused):4d}{note}")
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
