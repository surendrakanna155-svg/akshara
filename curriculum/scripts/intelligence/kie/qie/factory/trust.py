"""Deterministic SUBJECT-TRUST classifier for planning concepts.

THE DEFECT THIS MEASURES (verified, reproducible):
`concepts.subject_domain` is inherited per-DOCUMENT from `source_documents.subject`, and `typical_grade_low`
is `source_documents.class_label` verbatim (0 exceptions across the corpus). For single-subject books that is
fine. For NCERT Classes 6-10 it is structurally invalid, because that material is ONE INTEGRATED SCIENCE book
per class — so the pipeline had to force an integrated book into a single subject tag, and it did so
arbitrarily. Proof from the corpus: the SAME `*sc1dd` series is tagged

    Class 7 gesc1dd -> Biology | Class 8 hesc1dd -> Physics | Class 9 iesc1dd -> Biology | Class 10 jesc1dd -> Chemistry

Four classes of one integrated series, four different subjects. And `Class8_hegp1dd` (Ganita Prakash — a
MATHS book) is tagged **Chemistry**, which is why "Class 8 Chemistry" in this DB is 55 concepts named
`CHE_SQUARE_NUMBERS`, `CHE_CUBIC_NUMBERS`, `CHE_RECTANGLES_AND_SQUARES`. Its sibling `hegp2dd` is tagged
Mathematics — same series, same class, different tag.

WHY A CLASSIFIER AND NOT A FIX:
The NCERT filename code is a deterministic, documented convention, so the *book's* true subject is recoverable
from `rel_path` with no model call and no guessing. That recovers MATH and the single-subject 11/12 books. It
does NOT recover the integrated books — no filename can tell you whether a given concept inside an integrated
Science book is physics or biology; that needs per-CHUNK re-derivation, which is data work, not tagging.

So this module reports TRUST, and the planner refuses to plan on `unreliable`. It does not silently rewrite
kie.db — the certified store stays untouched.

NCERT code convention (class prefix + subject code + volume):
  class:   fe=6  ge=7  he=8  ie=9  je=10  le=11  ke=12
  subject: gp=Ganita Prakash (MATHS)  mh=Mathematics  bo=Biology  ph=Physics  ch=Chemistry
           sc=Science (INTEGRATED)    cu=Curiosity (INTEGRATED science)
"""
from __future__ import annotations

import re
import sqlite3
from typing import Dict, Optional, Tuple

RELIABLE = "reliable"
UNRELIABLE = "unreliable"

_NCERT = re.compile(r"NCERT_Class(\d+)_([a-z]{2})([a-z]{2})(\d)dd", re.I)

_SUBJECT_CODE = {
    "gp": "Mathematics",   # Ganita Prakash — the new NCERT maths series
    "mh": "Mathematics",
    "bo": "Biology",
    "ph": "Physics",
    "ch": "Chemistry",
}
_INTEGRATED_CODE = {"sc", "cu"}   # Science / Curiosity — integrated, subject NOT recoverable from the filename


def classify_document(rel_path: str, class_label: str, subject_tag: str) -> Tuple[str, Optional[str], str]:
    """-> (trust, true_subject_or_None, reason)"""
    p = rel_path or ""

    m = _NCERT.search(p)
    if m:
        code = m.group(3).lower()
        if code in _SUBJECT_CODE:
            true_subj = _SUBJECT_CODE[code]
            if true_subj != subject_tag:
                return RELIABLE, true_subj, (
                    f"NCERT code {code!r} => {true_subj}; stored tag {subject_tag!r} is WRONG (corrected)")
            return RELIABLE, true_subj, f"NCERT code {code!r} => {true_subj} (tag agrees)"
        if code in _INTEGRATED_CODE:
            return UNRELIABLE, None, (
                f"NCERT code {code!r} = INTEGRATED science book; per-document subject tag "
                f"({subject_tag!r}) is arbitrary — same series is tagged 4 different subjects across classes")
        return UNRELIABLE, None, f"unrecognised NCERT subject code {code!r}"

    low = p.lower()
    if "physical_science" in low:
        return UNRELIABLE, None, "TS Physical Science = integrated Physics+Chemistry; single tag is arbitrary"
    if "biological_science" in low:
        return RELIABLE, "Biology", "TS Biological Science = single-subject"
    if not (class_label or "").strip():
        return UNRELIABLE, None, (
            "no class_label => exam paper (NEET/JEE are multi-subject); one doc tag cannot describe it")
    return UNRELIABLE, None, f"unclassified source ({p[:60]!r})"


def build_doc_trust(kconn: sqlite3.Connection) -> Dict[str, dict]:
    """doc_id -> {trust, true_subject, reason, class_label}"""
    out: Dict[str, dict] = {}
    for r in kconn.execute("SELECT doc_id, rel_path, class_label, subject FROM source_documents"):
        trust, subj, reason = classify_document(r["rel_path"], r["class_label"], r["subject"])
        out[r["doc_id"]] = {"trust": trust, "true_subject": subj, "reason": reason,
                            "class_label": r["class_label"], "rel_path": r["rel_path"],
                            "stored_subject": r["subject"]}
    return out


def annotate_concepts(kconn: sqlite3.Connection) -> Dict[str, dict]:
    """concept_code -> trust record. Adds `planning_subject` = the corrected subject where recoverable."""
    docs = build_doc_trust(kconn)
    out: Dict[str, dict] = {}
    rows = kconn.execute("""
        SELECT concept_code, title, subject_domain, typical_grade_low, typical_grade_high,
               json_extract(evidence, '$.doc') AS doc
        FROM concepts WHERE status='active'
    """).fetchall()
    for r in rows:
        d = docs.get(r["doc"] or "")
        if not d:
            out[r["concept_code"]] = {"trust": UNRELIABLE, "planning_subject": None,
                                      "reason": "concept has no traceable source document"}
            continue
        out[r["concept_code"]] = {
            "trust": d["trust"],
            "planning_subject": d["true_subject"] or r["subject_domain"],
            "stored_subject": r["subject_domain"],
            "subject_corrected": bool(d["true_subject"] and d["true_subject"] != r["subject_domain"]),
            "reason": d["reason"],
            "grade": r["typical_grade_low"],
            "grade_meaning": "source_documents.class_label verbatim — 'mentioned in this book', NOT 'taught in "
                             "this class'. A Class-12 Physics chapter that mentions Gay-Lussac's law (Class-11 "
                             "Chemistry) produces a grade-12 tag.",
            "rel_path": d["rel_path"],
        }
    return out


def summary(ann: Dict[str, dict]) -> dict:
    tot = len(ann)
    rel = sum(1 for v in ann.values() if v["trust"] == RELIABLE)
    corr = sum(1 for v in ann.values() if v.get("subject_corrected"))
    by_reason: Dict[str, int] = {}
    for v in ann.values():
        if v["trust"] == UNRELIABLE:
            k = v["reason"].split(";")[0][:60]
            by_reason[k] = by_reason.get(k, 0) + 1
    return {"active_concepts": tot, "reliable": rel, "unreliable": tot - rel,
            "reliable_pct": round(100 * rel / max(1, tot), 1),
            "subject_tag_corrected_by_filename": corr,
            "unreliable_reasons": dict(sorted(by_reason.items(), key=lambda kv: -kv[1]))}
