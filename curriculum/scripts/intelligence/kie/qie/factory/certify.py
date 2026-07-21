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
from kie.qie.factory import gates as G

REASON_NO_INDEPENDENT = ("awaiting_independent_evidence: qualitative lane has no non-model re-derivation "
                         "path; gates+judge alone cannot certify an answer")
REASON_STALE = ("stale_or_missing_evidence: no passing gate battery bound to the candidate's CURRENT content, "
                "or evidence was computed against different content (item_hash mismatch) — cannot certify")


def certify_run(conn: sqlite3.Connection, run_id: str) -> Dict[str, int]:
    """Promote only what the full evidence chain supports, BOUND TO THE CANDIDATE'S CURRENT CONTENT (R1-2).

    An item may certify only when, for its CURRENT item_hash:
      * a gate battery ran and no FATAL gate failed (gates are actually consulted now — not just labelled);
      * the latest independent_answer said 'agree', was computed against this item_hash, and is not older than
        the candidate;
      * the latest judge verdict said 'accept', was computed against this item_hash, and is not older than the
        candidate.
    Evidence whose item_hash != the candidate's current item_hash (the replay case) can NEVER certify — it
    falls into `stale_evidence` and the row is quarantined. Never promotes on judge agreement alone.
    """
    m = {"certified": 0, "held_no_independent": 0, "judge_rejected": 0, "judge_missing": 0,
         "stale_evidence": 0, "quarantined_prior": 0}

    rows = conn.execute("""
        SELECT c.candidate_id, c.item_hash, c.created_at,
          (SELECT COUNT(*) FROM gate_result g
             WHERE g.candidate_id=c.candidate_id AND g.item_hash=c.item_hash) AS gates_for_hash,
          (SELECT COUNT(*) FROM gate_result g
             WHERE g.candidate_id=c.candidate_id AND g.item_hash=c.item_hash
                   AND g.ok=0 AND g.severity=?) AS fatal_for_hash,
          (SELECT COUNT(*) FROM gate_result g
             WHERE g.candidate_id=c.candidate_id AND g.item_hash=c.item_hash
                   AND g.ok=0 AND g.severity=?) AS quarantine_for_hash,
          ial.verdict AS ind_verdict, ial.item_hash AS ind_hash, ial.checked_at AS ind_at,
          jvl.verdict AS judge_verdict, jvl.item_hash AS judge_hash, jvl.checked_at AS judge_at
        FROM candidate c
        LEFT JOIN independent_answer_latest ial ON ial.candidate_id = c.candidate_id
        LEFT JOIN judge_verdict_latest      jvl ON jvl.candidate_id = c.candidate_id
        WHERE c.run_id = ? AND c.status = ?
    """, (G.FATAL, G.QUARANTINE, run_id, CO.CANDIDATE)).fetchall()

    for r in rows:
        jv = r["judge_verdict"]
        if jv is None:
            m["judge_missing"] += 1
            continue
        if jv != "accept":
            CO.set_status(conn, r["candidate_id"], CO.REJECTED, f"judge_{jv}")
            m["judge_rejected"] += 1
            continue

        ih, created = r["item_hash"], (r["created_at"] or "")
        # Certification independently RE-DERIVES the gate verdict for THIS content — it never trusts that an
        # upstream status flip already excluded a failure (defense-in-depth, R1-1 hardening). A gate battery
        # ran on this item_hash; NO fatal AND NO quarantine gate failed; the judge verdict is for THIS content
        # and not stale. A recorded QUARANTINE failure (e.g. an ungrounded relation) can therefore never
        # certify even if the candidate is somehow still in 'candidate' state.
        content_bound = (
            r["gates_for_hash"] > 0 and r["fatal_for_hash"] == 0 and r["quarantine_for_hash"] == 0
            and r["judge_hash"] == ih and (r["judge_at"] or "") >= created
        )
        if not content_bound:
            CO.set_status(conn, r["candidate_id"], CO.QUARANTINED, REASON_STALE)
            m["stale_evidence"] += 1
            continue

        # the mandatory link: an answer no independent system re-derived FROM THIS CONTENT is not certified
        ind_ok = (r["ind_verdict"] == "agree" and r["ind_hash"] == ih and (r["ind_at"] or "") >= created)
        if ind_ok:
            CO.set_status(conn, r["candidate_id"], CO.CERTIFIED, "gates+sympy+judge")
            m["certified"] += 1
        else:
            CO.set_status(conn, r["candidate_id"], CO.QUARANTINED, REASON_NO_INDEPENDENT)
            m["held_no_independent"] += 1

    conn.commit()
    return m
