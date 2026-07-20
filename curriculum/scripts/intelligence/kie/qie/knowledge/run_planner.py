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
from kie.qie.knowledge import allocate as AL
from kie.qie.knowledge import blueprint as BP
from kie.qie.knowledge import examdna as ED
from kie.qie.knowledge import plan_specs as PS
from kie.qie.knowledge import planner as P
from kie.qie.knowledge import qdi as QDI
from kie.qie.knowledge import qdi_link as QL

INDEX_DB_PATH = config.KIE_HOME / "knowledge_index.db"
EXAM_CLASSES = (11, 12)

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


def _foundation_version(conn) -> str:
    try:
        r = conn.execute("SELECT value FROM ki_meta WHERE key='frozen_version'").fetchone()
        return r[0] if r else "unknown"
    except sqlite3.OperationalError:
        return "unknown"


def plan_blueprints(exam: str, total: int, index_path=None, examdna_path=None) -> dict:
    """Deterministically plan `total` QuestionBlueprints for one exam from frozen v1.4 + Exam DNA.

    NO RNG, NO clock: the same (frozen index, Exam DNA, exam, total) always yields the identical set of
    blueprints (by fingerprint). Every blueprint is gate-validated (`planner.check_plan`); a blueprint that
    cannot be defended is refused, never fabricated.
    """
    if exam not in ED.EXAMS:
        raise ValueError(f"unknown exam {exam!r} (expected one of {ED.EXAMS})")
    conn = open_frozen_index(index_path)
    edb = ED.open_examdna(examdna_path)
    try:
        fver = _foundation_version(conn)
        ever = (edb.execute("SELECT value FROM examdna_meta WHERE key='version'").fetchone() or ["v1"])[0]
        subj_w = ED.subject_weights(edb, exam)
        concepts_by_chapter: dict = {}
        chapter_weights: dict = {}
        universe_all = []
        cert_patterns = []
        for subject in ED.EXAM_SUBJECTS[exam]:
            uni = P.certified_universe(conn, subject, list(EXAM_CLASSES))
            uni, _ = P.dedupe_universe(uni)
            universe_all.extend(uni)
            for c in uni:
                concepts_by_chapter.setdefault(c["chapter_id"], []).append(c)
            chapter_weights[subject] = ED.chapter_weight_map(edb, exam, subject)
            cert_patterns.extend(QDI.certified_patterns(conn, subject))  # 0 today; QDI mining = owner-gated
        for cid in concepts_by_chapter:
            concepts_by_chapter[cid].sort(key=lambda c: c["concept_id"])
        diff_dist = ED.distribution(edb, exam, "difficulty")
        arch_dist = ED.distribution(edb, exam, "archetype")
        slots = AL.allocate_slots(exam, total, subj_w, chapter_weights, concepts_by_chapter,
                                  diff_dist, arch_dist)
    finally:
        conn.close()
        edb.close()

    pat_idx = QL.index_by_key(cert_patterns)
    by_id = {c["concept_id"]: c for c in universe_all}
    issued, refused, seen_fp = [], [], set()
    for s in slots:
        n_in_chapter = len(concepts_by_chapter.get(s["chapter_id"]) or []) or 1
        cw = chapter_weights[s["subject"]].get(s["chapter_id"], 0.0)
        bp = BP.build_blueprint(s, f"plan_{exam}", cw, 1.0 / n_in_chapter, fver, ever)
        bp = QL.attach_pattern(bp, pat_idx)   # enrich with certified design DNA when available (honest null otherwise)
        v = P.check_plan(bp, by_id)
        if v:
            refused.append({"blueprint_id": bp["blueprint_id"], "violations": v})
        else:
            issued.append(bp)
            seen_fp.add(bp["blueprint_fingerprint"])
    realized = {}
    for b in issued:
        realized[b["difficulty"]] = realized.get(b["difficulty"], 0) + 1
    shortfall = sum(1 for b in issued if b["difficulty"] != b["target_difficulty"])
    return {"exam": exam, "planned": len(slots), "issued": issued, "refused": refused,
            "distinct_fingerprints": len(seen_fp), "realized_difficulty": realized,
            "difficulty_shortfall": shortfall, "foundation_version": fver, "examdna_version": ever}


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
