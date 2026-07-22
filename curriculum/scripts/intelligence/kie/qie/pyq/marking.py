"""Program B · B4 (part 2) — marking-scheme extraction (OD-6).

For each exam+question-type, establish a marking scheme, labelled honestly by provenance:
  * `parsed_from_paper` — the eligible papers themselves consistently STATE it (e.g. NEET's "+4 / −1").
  * `published`         — a STABLE, well-known official scheme fills a gap the papers don't state (used only for
                          schemes that are genuinely stable across years; NEVER for a variable one).
  * `honest_null`       — variable / unknown (JEE Advanced's section-dependent partial marking, JEE Main's
                          numerical negative-marking that changed by year) → marks NULL, never fabricated.

Read-only over the frozen kie.db (head text of each eligible doc) + the derived B1 store. Deterministic.
"""
from __future__ import annotations

import json
import re
from typing import Dict, List, Tuple

from kie.qie.pyq import source_class as SC
from kie.qie.pyq import store as ST

# CONTEXT-AWARE scheme detection: a real marking statement ties the number to MARKS + a marking verb — so a
# stray physics quantity ("+4 μC charge", "oxidation state +4 to −1") does NOT count as scheme evidence. (The
# earlier bare-token detector false-fired 26/52 on JEE Advanced, whose scheme is NOT +4/−1 — a provenance lie.)
_CORRECT4_RE = re.compile(r"(?i)(?:\+?\s*4\s*marks?\s*(?:for|will|shall|is|are|be|awarded|to|:)|"
                          r"four\s*marks?\s*(?:for|will|shall|awarded|to|:)|"
                          r"(?:correct\s+(?:answer|response|option)[^.]{0,30}(?:\+?\s*4\s*marks?|four\s*marks?)))")
_NEG1_RE = re.compile(r"(?i)(?:[-–−]\s*1\s*mark|1\s*mark\s*(?:will|shall|would)?\s*(?:be\s*)?deduct|"
                      r"minus\s*one\s*mark|negative\s*mark(?:ing)?[^.]{0,20}[-–−]?\s*1|"
                      r"(?:incorrect|wrong)\s+(?:answer|response|option)[^.]{0,30}[-–−]\s*1\s*mark)")

# STABLE published official schemes — asserted ONLY where the scheme is well-known and year-stable.
# (exam, question_type) -> (marks_correct, marks_incorrect, partial_rule, note)
_PUBLISHED = {
    ("NEET", "mcq"): (4, -1, "none", "NEET single-correct MCQ, stable +4/−1"),
    ("JEE_MAIN", "mcq"): (4, -1, "none", "JEE Main single-correct MCQ, stable +4/−1"),
}
# question types for which the scheme is genuinely variable / unknown → honest-null (never fabricated).
_HONEST_NULL = {
    ("JEE_MAIN", "numerical"): "JEE Main numerical negative-marking changed by year (none → −1 in 2023) — honest-null",
    ("JEE_ADVANCED", "any"): "JEE Advanced marking is section- and year-dependent (partial, +4/−2, +3/−1, …) — honest-null",
}
_PARSE_MIN_DOCS = 5   # a parsed_from_paper scheme needs at least this many eligible papers stating it consistently


def parse_doc_scheme(text: str) -> Tuple[bool, bool]:
    """(states_plus4, states_minus1) for one paper's head text. Conservative — both must be explicit."""
    return bool(_CORRECT4_RE.search(text or "")), bool(_NEG1_RE.search(text or ""))


def build(pyq_db_path=None) -> Dict[str, object]:
    """Establish the marking_scheme table. READ-ONLY over kie.db; writes only the derived store."""
    store = ST.open_store(pyq_db_path, writable=True)
    try:
        eligible = list(store.execute(
            "SELECT doc_id, exam_resolved FROM pyq_source_class WHERE eligible_for_dna=1"))
    finally:
        store.close()

    kie = SC._open_kie_ro()
    ev: Dict[str, Dict[str, int]] = {}
    try:
        for doc_id, exam in eligible:
            head = " ".join((r[0] or "") for r in kie.execute(
                "SELECT text FROM chunks WHERE doc_id=? ORDER BY ordinal LIMIT 40", (doc_id,)))
            p4, n1 = parse_doc_scheme(head)
            e = ev.setdefault(exam, {"docs": 0, "plus4": 0, "minus1": 0, "both": 0})
            e["docs"] += 1
            e["plus4"] += p4
            e["minus1"] += n1
            e["both"] += (p4 and n1)
    finally:
        kie.close()

    rows: List[tuple] = []
    for exam in ("NEET", "JEE_MAIN", "JEE_ADVANCED"):
        e = ev.get(exam, {"docs": 0, "both": 0})
        # 1) MCQ: prefer parsed-from-paper when the papers consistently state +4/−1; else stable published; else null
        if (exam, "mcq") in _PUBLISHED:
            mc, mi, pr, note = _PUBLISHED[(exam, "mcq")]
            if e["both"] >= _PARSE_MIN_DOCS:
                # parsed evidence uses the published mc/mi values (context-aware detection confirms them, it does
                # not read arbitrary numbers) — labelled parsed_from_paper only because ≥N papers genuinely state it
                rows.append((exam, "mcq", mc, mi, pr, "parsed_from_paper", None, e["both"],
                             f"{e['both']}/{e['docs']} papers state a {mc:+d}/{mi:+d} scheme in a marking context"))
            else:
                rows.append((exam, "mcq", mc, mi, pr, "published", None, None, note))
        # 2) explicitly-honest-null schemes (variable/unknown) — recorded with NULL marks, never fabricated
    for (exam, qtype), note in _HONEST_NULL.items():
        rows.append((exam, qtype, None, None, None, "honest_null", None, None, note))

    conn = ST.open_store(pyq_db_path, writable=True)
    try:
        conn.execute("DELETE FROM marking_scheme")
        conn.executemany("INSERT INTO marking_scheme (exam, question_type, marks_correct, marks_incorrect, "
                         "partial_rule, provenance_class, source_doc_id, n_docs_evidence, note) "
                         "VALUES (?,?,?,?,?,?,?,?,?)", rows)
        conn.commit()
    finally:
        conn.close()
    return {"schemes": len(rows), "evidence": {k: {"both_plus4_minus1": v["both"], "docs": v["docs"]}
                                               for k, v in sorted(ev.items())},
            "by_provenance": _by_prov(rows)}


def _by_prov(rows) -> Dict[str, int]:
    out: Dict[str, int] = {}
    for r in rows:
        out[r[5]] = out.get(r[5], 0) + 1
    return dict(sorted(out.items()))


if __name__ == "__main__":
    print(json.dumps(build(), indent=2))
