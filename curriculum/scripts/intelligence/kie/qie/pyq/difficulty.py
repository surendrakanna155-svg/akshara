"""Program B · B4 (part 1) — structural difficulty (OD-3).

OD-3: implement STRUCTURAL difficulty only; do NOT claim measured student difficulty. This computes a
deterministic complexity PROXY from a question's own structure — its type and its length — and labels it
`difficulty_basis='structural_proxy'`. It is explicitly NOT a measured p-value; measured difficulty stays
honest-null until the ERP response spine carries pilot data (roadmap R5-5). B5 surfaces this as a labelled
STRUCTURAL distribution, never as "measured".

Deliberately coarse and honest: it keys only on `question_type` (assertion-reason / match / numerical are
structurally heavier than a plain MCQ) and `span_len` (a longer question is a proxy for more reading / more
steps). It does not pretend to know how hard a student found the question.
"""
from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Dict, Tuple

from kie.qie.pyq import store as ST

# structural weight by type: multi-statement / cross-matching / compute-an-answer forms are heavier than a
# straight single-best-option MCQ.
_TYPE_WEIGHT = {"assertion_reason": 2, "match": 2, "numerical": 1, "mcq": 0, "short_answer": 0, "unknown": 0}


def structural_difficulty(question_type: str, span_len: int) -> Tuple[str, int]:
    """(label, complexity_score) — a STRUCTURAL proxy from (type, length). Deterministic. Never 'measured'."""
    score = _TYPE_WEIGHT.get(question_type, 0)
    score += 2 if span_len > 900 else (1 if span_len > 400 else 0)   # length as a reading/steps proxy
    label = "hard" if score >= 3 else ("moderate" if score >= 2 else "easy")
    return label, score


def build(pyq_db_path=None) -> Dict[str, object]:
    """Attribute a structural difficulty to every pyq_item. Idempotent. Reads + writes only the derived store."""
    conn = ST.open_store(pyq_db_path, writable=True)
    try:
        rows = conn.execute("SELECT item_id, question_type, span_len FROM pyq_item").fetchall()
        out = []
        for item_id, qtype, span_len in rows:
            label, score = structural_difficulty(qtype, span_len or 0)
            out.append((item_id, label, "structural_proxy", score,
                        json.dumps({"type": qtype, "span_len": span_len}, sort_keys=True)))
        conn.execute("DELETE FROM pyq_item_difficulty")
        conn.executemany("INSERT INTO pyq_item_difficulty (item_id, difficulty_label, difficulty_basis, "
                         "complexity_score, signals) VALUES (?,?,?,?,?)", out)
        stats = _tally(out)
        conn.execute("INSERT INTO pyq_meta(key,value) VALUES ('b4_difficulty_built_at',?) "
                     "ON CONFLICT(key) DO UPDATE SET value=excluded.value",
                     (datetime.now(timezone.utc).isoformat(),))
        conn.commit()
    finally:
        conn.close()
    return {"items": len(out), "stats": stats}


def _tally(out) -> Dict[str, object]:
    by_label: Dict[str, int] = {}
    for _, label, _basis, _score, _sig in out:
        by_label[label] = by_label.get(label, 0) + 1
    return {"by_label": dict(sorted(by_label.items())),
            "basis": "structural_proxy (NOT measured; measured difficulty honest-null pending pilot data)"}


if __name__ == "__main__":
    print(json.dumps(build(), indent=2))
