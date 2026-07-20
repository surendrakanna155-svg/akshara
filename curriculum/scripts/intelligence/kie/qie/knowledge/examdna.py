"""Exam DNA (v1) — certified per-exam PLANNING distributions for JEE Main / JEE Advanced / NEET.

The planner fuses the frozen curriculum (WHAT may be asked) with Exam DNA (HOW an exam distributes its
questions). Exam DNA lives in a SEPARATE store (examdna.db); the frozen knowledge_index.db is immutable and
is only READ here (chapter lists + certified concept counts) to compute evidence-proportional weights.

HONESTY (standing law: wrong knowledge is worse than missing knowledge). Every row is labelled with an honest
`provenance_class`:
  * published            — real published exam structure (subject weightage; mirrors qpgen/blueprints.py)
  * evidence_proportional — COMPUTED from the frozen index (chapter weight = certified concept share);
                            reproducible, honest, and explicitly NOT PYQ-measured
  * derived_from_profiles — archetype mix derived from the curated profiles.py allow-lists
  * curated_prior         — an authored planning prior from documented exam CHARACTER (difficulty / depth);
                            a defensible estimate, explicitly NOT a measured statistic
`status='curated'` means the row passed the structural + provenance-honesty gates. `status='certified'` is
reserved for the mining phase (Decision 2 "then mine"), which replaces the curated_prior dimensions with
mined, independently-audited evidence and bumps the version. No estimate is ever relabelled as a measurement.
"""
from __future__ import annotations

import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List

from kie import config
from kie.qie import profiles as PR

SCHEMA_PATH = Path(__file__).resolve().parent / "examdna_schema.sql"
EXAMDNA_DB_PATH = config.KIE_HOME / "examdna.db"
INDEX_DB_PATH = config.KIE_HOME / "knowledge_index.db"
VERSION = "v1"

EXAMS = ("JEE_MAIN", "JEE_ADVANCED", "NEET")
EXAM_CLASSES = (11, 12)
EXAM_SUBJECTS: Dict[str, tuple] = {
    "NEET": ("Physics", "Chemistry", "Biology"),
    "JEE_MAIN": ("Physics", "Chemistry", "Mathematics"),
    "JEE_ADVANCED": ("Physics", "Chemistry", "Mathematics"),
}

# published exam structure (subject weightage). NEET matches qpgen/blueprints.py exactly (25/25/50); JEE uses
# exact thirds — faithful to the real equal-25-questions-per-subject structure (blueprints.py rounds to 33/33/34).
EXAM_SUBJECT_WEIGHT: Dict[str, Dict[str, float]] = {
    "NEET": {"Physics": 0.25, "Chemistry": 0.25, "Biology": 0.50},
    "JEE_MAIN": {"Physics": 1 / 3, "Chemistry": 1 / 3, "Mathematics": 1 / 3},
    "JEE_ADVANCED": {"Physics": 1 / 3, "Chemistry": 1 / 3, "Mathematics": 1 / 3},
}

# curated PRIOR from documented exam CHARACTER — NOT a measured statistic (mining replaces these in v2).
# NEET: NCERT-anchored, conceptual/recall-dominant, few very-hard items. JEE Main: balanced. JEE Advanced:
# hard/multi-concept dominant.
EXAM_DIFFICULTY_DIST: Dict[str, Dict[str, float]] = {
    "NEET": {"easy": 0.30, "moderate": 0.55, "hard": 0.15},
    "JEE_MAIN": {"easy": 0.20, "moderate": 0.50, "hard": 0.30},
    "JEE_ADVANCED": {"easy": 0.05, "moderate": 0.35, "hard": 0.60},
}
EXAM_DEPTH_DIST: Dict[str, Dict[str, float]] = {
    "NEET": {"1": 0.30, "2": 0.35, "3": 0.25, "4": 0.08, "5": 0.02},
    "JEE_MAIN": {"1": 0.15, "2": 0.30, "3": 0.30, "4": 0.18, "5": 0.07},
    "JEE_ADVANCED": {"1": 0.05, "2": 0.15, "3": 0.30, "4": 0.30, "5": 0.20},
}


class ExamDnaError(Exception):
    """A structurally invalid or dishonestly-provenanced Exam DNA record."""


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _normalize(d: Dict[str, float]) -> Dict[str, float]:
    tot = sum(d.values())
    if tot <= 0:
        raise ExamDnaError(f"distribution has non-positive total {tot}")
    return {k: v / tot for k, v in d.items()}


def validate_distribution(d: Dict[str, float], tol: float = 1e-6) -> None:
    """A probability distribution must be non-empty, non-negative, and sum to 1."""
    if not d:
        raise ExamDnaError("empty distribution")
    for k, v in d.items():
        if v < 0:
            raise ExamDnaError(f"negative probability {v} for bucket {k!r}")
    s = sum(d.values())
    if abs(s - 1.0) > tol:
        raise ExamDnaError(f"distribution sums to {s}, not 1.0")


def validate_exam_scope(exam: str, subject: str) -> None:
    """A weight row must name a known exam and a subject that exam actually assesses."""
    if exam not in EXAMS:
        raise ExamDnaError(f"unknown exam {exam!r}")
    if subject not in EXAM_SUBJECTS[exam]:
        raise ExamDnaError(f"subject {subject!r} is not assessed by exam {exam!r}")


def validate_chapter_ref(valid_ids: set, chapter_id: str) -> None:
    """A chapter weight must reference a real certified chapter of the frozen index."""
    if chapter_id not in valid_ids:
        raise ExamDnaError(f"chapter {chapter_id!r} is not a certified chapter in the frozen index")


def archetype_distribution(exam: str) -> Dict[str, float]:
    """Derived from the curated profiles.py allow-list: uniform over valid archetypes, 2x weight on core."""
    prof = PR.PROFILES.get(exam)
    if prof is None:
        raise ExamDnaError(f"no assessment profile for exam {exam!r}")
    raw = {a: (2.0 if a in prof.core_archetypes else 1.0) for a in prof.valid_archetypes}
    return _normalize(raw)


def chapter_weights(index_conn: sqlite3.Connection, subject: str, classes=EXAM_CLASSES) -> List[dict]:
    """Evidence-proportional chapter weight = the chapter's certified-concept share within the subject."""
    q = ("SELECT ch.chapter_id, ch.title, COUNT(*) AS n "
         "FROM ki_concept co JOIN ki_chapter ch ON ch.chapter_id = co.chapter_id "
         "WHERE co.subject=? AND co.status='certified' AND ch.status='accepted' "
         "AND co.taught_at_class IN (%s) GROUP BY ch.chapter_id" % ",".join("?" * len(classes)))
    rows = index_conn.execute(q, [subject, *classes]).fetchall()
    total = sum(r["n"] for r in rows)
    if total == 0:
        return []
    return [{"chapter_id": r["chapter_id"], "title": r["title"], "weight": r["n"] / total, "n": r["n"]}
            for r in rows]


def valid_chapter_ids(index_conn: sqlite3.Connection, subject: str, classes=EXAM_CLASSES) -> set:
    q = ("SELECT DISTINCT ch.chapter_id FROM ki_chapter ch WHERE ch.subject=? AND ch.status='accepted' "
         "AND ch.taught_at_class IN (%s)" % ",".join("?" * len(classes)))
    return {r[0] for r in index_conn.execute(q, [subject, *classes])}


def open_examdna(path=None) -> sqlite3.Connection:
    p = path or EXAMDNA_DB_PATH
    if str(p) != ":memory:":
        Path(p).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(p))
    conn.row_factory = sqlite3.Row
    conn.executescript(SCHEMA_PATH.read_text())
    return conn


def open_frozen_index(path=None) -> sqlite3.Connection:
    p = str(path or INDEX_DB_PATH)
    conn = sqlite3.connect(f"file:{p}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    return conn


def open_examdna_ro(path=None) -> sqlite3.Connection:
    """READ-ONLY open for consumers (e.g. the planner). Fails loudly if Exam DNA has not been built —
    which is the honest outcome: the planner must not silently plan against an absent Exam DNA."""
    p = str(path or EXAMDNA_DB_PATH)
    conn = sqlite3.connect(f"file:{p}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    return conn


def build(index_conn: sqlite3.Connection, out_conn: sqlite3.Connection, version: str = VERSION) -> Dict[str, int]:
    """Materialize curated Exam DNA v1 for all three exams. Validates every distribution before writing."""
    now = _now()
    wrows: List[tuple] = []
    drows: List[tuple] = []
    for exam in EXAMS:
        # subject weightage (published)
        sw = EXAM_SUBJECT_WEIGHT[exam]
        validate_distribution(sw)
        for subject, w in sw.items():
            wrows.append((exam, subject, "subject", "", subject, w,
                          "published exam structure (qpgen/blueprints.py subject weightage)",
                          "published", version, "curated", now))
        # chapter weightage (evidence-proportional, per subject)
        for subject in EXAM_SUBJECTS[exam]:
            cw = chapter_weights(index_conn, subject)
            if cw:
                validate_distribution({c["chapter_id"]: c["weight"] for c in cw})
            for c in cw:
                wrows.append((exam, subject, "chapter", c["chapter_id"], c["title"], c["weight"],
                              f"evidence_proportional: {c['n']} certified concepts / subject total (cls 11-12); "
                              f"NOT PYQ-measured", "evidence_proportional", version, "curated", now))
        # distributions (per-exam, subject='' = exam-wide)
        for dim, table in (("difficulty", EXAM_DIFFICULTY_DIST), ("depth", EXAM_DEPTH_DIST)):
            dist = _normalize(table[exam])
            validate_distribution(dist)
            pc = "curated_prior"
            basis = f"curated_prior: documented exam {dim} character; NOT measured (mining replaces in v2)"
            for bucket, p in dist.items():
                drows.append((exam, "", dim, bucket, p, basis, pc, version, "curated", now))
        arch = archetype_distribution(exam)
        validate_distribution(arch)
        for bucket, p in arch.items():
            drows.append((exam, "", "archetype", bucket, p,
                          "derived_from_profiles: uniform over valid archetypes, 2x on core",
                          "derived_from_profiles", version, "curated", now))

    out_conn.executemany(
        "INSERT OR REPLACE INTO exam_weight (exam,subject,scope_type,scope_id,scope_label,weight,basis,"
        "provenance_class,version,status,created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)", wrows)
    out_conn.executemany(
        "INSERT OR REPLACE INTO exam_distribution (exam,subject,dimension,bucket,probability,basis,"
        "provenance_class,version,status,created_at) VALUES (?,?,?,?,?,?,?,?,?,?)", drows)
    out_conn.execute("INSERT OR REPLACE INTO examdna_meta(key,value) VALUES ('version',?)", (version,))
    out_conn.execute("INSERT OR REPLACE INTO examdna_meta(key,value) VALUES ('built_at',?)", (now,))
    out_conn.commit()
    return {"weights": len(wrows), "distributions": len(drows)}


# ── readers (consumed by the Phase 3 deterministic allocator) ─────────────────────────────────────────
# Readers carry an explicit ORDER BY so the dict insertion order (hence any downstream summation order) is a
# total, physical-row-order-independent function of the data — determinism holds under any re-import.
def subject_weights(conn: sqlite3.Connection, exam: str) -> Dict[str, float]:
    return {r["subject"]: r["weight"] for r in conn.execute(
        "SELECT subject, weight FROM exam_weight WHERE exam=? AND scope_type='subject' ORDER BY subject",
        (exam,))}


def chapter_weight_map(conn: sqlite3.Connection, exam: str, subject: str) -> Dict[str, float]:
    return {r["scope_id"]: r["weight"] for r in conn.execute(
        "SELECT scope_id, weight FROM exam_weight WHERE exam=? AND subject=? AND scope_type='chapter' "
        "ORDER BY scope_id", (exam, subject))}


def distribution(conn: sqlite3.Connection, exam: str, dimension: str, subject: str = "") -> Dict[str, float]:
    return {r["bucket"]: r["probability"] for r in conn.execute(
        "SELECT bucket, probability FROM exam_distribution WHERE exam=? AND subject=? AND dimension=? "
        "ORDER BY bucket", (exam, subject, dimension))}


def _main() -> int:
    idx = open_frozen_index()
    out = open_examdna()
    try:
        m = build(idx, out)
        print(f"Exam DNA {VERSION} built: {m['weights']} weight rows, {m['distributions']} distribution rows")
        for exam in EXAMS:
            sw = subject_weights(out, exam)
            print(f"  {exam:13s} subjects={sw}")
    finally:
        idx.close()
        out.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
