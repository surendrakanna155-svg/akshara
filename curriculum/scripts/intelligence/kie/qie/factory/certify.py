"""Stage 4 — the certification decision.

THE RULE, taken straight from the owner's own architecture:

    CANDIDATE -> DETERMINISTIC GATES -> INDEPENDENT ANSWER VALIDATION -> SEPARATE AI JUDGE -> CERTIFIED KEY

`INDEPENDENT ANSWER VALIDATION` is a mandatory link in that chain, not an optional enrichment. So an item may
only be CERTIFIED when its answer was re-derived by something that is not the generator and not a language
model at all. In this repo that means sympy, and sympy can only re-derive an item that declared a structure.

The consequence is uncomfortable and is the trial's central finding, so it is stated in code rather than buried
in a report:

  * STRUCTURED_NUMERIC items CAN be certified — a computer-algebra system independently reproduces the key.
  * QUALITATIVE items CANNOT be certified by this architecture. There is no independent re-derivation
    available for "which hormone regulates X". Gates check FORM; the judge is a language model of the same
    family as the generator. Certifying on those two alone would mean certifying a model's opinion of its own
    output — precisely the self-confirmation the owner ruled out.

Qualitative items that pass every available check are therefore parked as `quarantined` with the reason
`awaiting_independent_evidence`. That is not a defect in the item and not a failure of the generator. It is the
architecture telling the truth about what it can and cannot prove — and it is why the existing OCR/extraction
lane, which grounds every qualitative fact in an owned source document, remains the only path that can
certify them.
"""
from __future__ import annotations

import sqlite3
from typing import Dict

from kie.qie.factory import corpus as CO

REASON_NO_INDEPENDENT = ("awaiting_independent_evidence: qualitative lane has no non-model re-derivation "
                         "path; gates+judge alone cannot certify an answer")


def certify_run(conn: sqlite3.Connection, run_id: str) -> Dict[str, int]:
    """Promote only what the full evidence chain supports. Never promotes on judge agreement alone."""
    m = {"certified": 0, "held_no_independent": 0, "judge_rejected": 0, "judge_missing": 0,
         "quarantined_prior": 0}

    rows = conn.execute("""
        SELECT c.candidate_id, c.status, s.lane,
               i.verdict AS ind_verdict, j.verdict AS judge_verdict
        FROM candidate c
        JOIN generation_spec s ON s.spec_id = c.spec_id
        LEFT JOIN independent_answer i ON i.candidate_id = c.candidate_id
        LEFT JOIN judge_verdict j ON j.candidate_id = c.candidate_id
        WHERE c.run_id = ? AND c.status = ?
    """, (run_id, CO.CANDIDATE)).fetchall()

    for r in rows:
        if r["judge_verdict"] is None:
            m["judge_missing"] += 1
            continue
        if r["judge_verdict"] != "accept":
            CO.set_status(conn, r["candidate_id"], CO.REJECTED, f"judge_{r['judge_verdict']}")
            m["judge_rejected"] += 1
            continue

        # the mandatory link: an answer no independent system re-derived is not a certified answer
        if r["ind_verdict"] == "agree":
            CO.set_status(conn, r["candidate_id"], CO.CERTIFIED, "gates+sympy+judge")
            m["certified"] += 1
        else:
            CO.set_status(conn, r["candidate_id"], CO.QUARANTINED, REASON_NO_INDEPENDENT)
            m["held_no_independent"] += 1

    conn.commit()
    return m
