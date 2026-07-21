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

import json
import sqlite3
from typing import Dict

from kie.qie.factory import corpus as CO
from kie.qie.factory import gates as G

REASON_NO_INDEPENDENT = ("awaiting_independent_evidence: qualitative lane has no non-model re-derivation "
                         "path; gates+judge alone cannot certify an answer")
REASON_STALE = ("stale_or_missing_evidence: no passing gate battery bound to the candidate's CURRENT content, "
                "or evidence was computed against different content (item_hash mismatch) — cannot certify")
REASON_NO_SOLUTION = ("awaiting_solution_stage: no passing solution_verified gate bound to the candidate's "
                      "CURRENT content — the solution stage (R2-2) has not certified a step solution")
REASON_NO_DISTRACTORS = ("awaiting_distractor_verification: no passing distractor_verified gate bound to the "
                         "candidate's CURRENT content — each wrong option's mis_relation is unproven (R2-2)")
REASON_PROVISIONAL_SAME_ACTOR = ("provisional_same_actor_review: the disposing judge is the same actor family "
                                 "as the generator; a cross-family (or human) reviewer is required before "
                                 "'certified' — this row is provisional and product-invisible (R2-1)")
REASON_NO_PROVENANCE = ("missing_row_provenance: on the production path a certified row must itself carry real "
                        "generation + judge provenance (model+version+prompt_sha256+actor), not ride a sibling's "
                        "run-level telemetry — RI-8 (R2-3)")
REASON_DUPLICATE_BANK = ("duplicate_of_certified: content already certified in this bank ({dup}) — bank-level "
                         "dedup refuses a second certification of the same question (R3-2, RI-9)")
REASON_CERTIFIED = "gates+sympy+solution+distractor+independent_judge"


def certify_run(conn: sqlite3.Connection, run_id: str, require_telemetry: bool = False) -> Dict[str, int]:
    """Promote only what the FULL evidence chain supports, BOUND TO THE CANDIDATE'S CURRENT CONTENT.

    The RI-3 conjunction, enforced here for the candidate's CURRENT item_hash (R1-1/2 + R2-1/2/4):
      * a gate battery ran and no FATAL and no QUARANTINE gate failed (gates re-derived, not trusted);
      * the latest independent_answer said 'agree', bound to this item_hash and not older than the candidate;
      * the latest judge verdict said 'accept', bound to this item_hash and not older than the candidate;
      * a passing `solution_verified` gate is bound to this item_hash (R2-2 — the mandatory solution stage);
      * a passing `distractor_verified` gate is bound to this item_hash (R2-2 — every wrong option proven);
      * the disposing judge is INDEPENDENT: `independent=1` AND a re-derived `judge_family != generator_family`
        (R2-1). A same-actor 'accept' certifies only as `certification_class='provisional'` — product-invisible.
    A promoted row is stamped `evidence_class='sympy_rederived'` and carries the EARNED depth + QIE-detected
    archetype (R2-4), never the generator's refuted claim. Evidence whose item_hash != the candidate's current
    item_hash (the replay case) can never certify. Never promotes on judge agreement alone.

    RUN-LEVEL PRECONDITION (R2-3, RI-8): when `require_telemetry` is set (the production path — see
    run_generation.certify), the whole run is refused fail-closed unless the generation AND judge model stages
    each left a real-provenance telemetry row (require_stage_telemetry). This composes ABOVE the per-candidate
    R2-1/2/4 preconditions as an AND-gate on the run — a certification without an accountable execution trail
    cannot be claimed. Low-level unit callers that construct fixtures in isolation leave it off (default False).
    """
    if require_telemetry:
        CO.require_stage_telemetry(conn, run_id, ("generation", "judge"))

    m = {"certified": 0, "provisional_same_actor": 0, "held_no_independent": 0, "held_no_solution": 0,
         "held_no_distractors": 0, "held_no_provenance": 0, "judge_rejected": 0, "judge_missing": 0,
         "stale_evidence": 0, "duplicate_of_certified": 0, "quarantined_prior": 0}

    # The factory-4 provenance columns are SELECTed only on the production path (require_telemetry), which always
    # runs on a factory-4 store; low-level unit fixtures may be an earlier schema without these columns.
    _gen_prov = (", c.generator_model, c.model_version AS gen_model_version, "
                 "c.prompt_sha256 AS gen_prompt_sha256, c.generator_actor, c.contract_version"
                 if require_telemetry else "")
    _judge_prov = (", jvl.judge_model AS judge_model, jvl.model_version AS judge_model_version, "
                   "jvl.prompt_sha256 AS judge_prompt_sha256, jvl.judge_actor AS judge_actor"
                   if require_telemetry else "")
    rows = conn.execute(f"""
        SELECT c.candidate_id, c.item_hash, c.stem_norm_hash, c.created_at, c.generator_family, c.structure,
               c.stem, c.answer_label, c.answer_value, c.options{_gen_prov},
          (SELECT COUNT(*) FROM gate_result g
             WHERE g.candidate_id=c.candidate_id AND g.item_hash=c.item_hash) AS gates_for_hash,
          (SELECT COUNT(*) FROM gate_result g
             WHERE g.candidate_id=c.candidate_id AND g.item_hash=c.item_hash
                   AND g.ok=0 AND g.severity=?) AS fatal_for_hash,
          (SELECT COUNT(*) FROM gate_result g
             WHERE g.candidate_id=c.candidate_id AND g.item_hash=c.item_hash
                   AND g.ok=0 AND g.severity=?) AS quarantine_for_hash,
          (SELECT COUNT(*) FROM gate_result g
             WHERE g.candidate_id=c.candidate_id AND g.item_hash=c.item_hash
                   AND g.gate='solution_verified' AND g.ok=1) AS solution_verified_for_hash,
          (SELECT COUNT(*) FROM gate_result g
             WHERE g.candidate_id=c.candidate_id AND g.item_hash=c.item_hash
                   AND g.gate='distractor_verified' AND g.ok=1) AS distractors_verified_for_hash,
          ial.verdict AS ind_verdict, ial.item_hash AS ind_hash, ial.checked_at AS ind_at,
          jvl.verdict AS judge_verdict, jvl.item_hash AS judge_hash, jvl.checked_at AS judge_at,
          jvl.independent AS judge_independent, jvl.judge_family AS judge_family{_judge_prov}
        FROM candidate c
        LEFT JOIN independent_answer_latest ial ON ial.candidate_id = c.candidate_id
        LEFT JOIN judge_verdict_latest      jvl ON jvl.candidate_id = c.candidate_id
        WHERE c.run_id = ? AND c.status = ?
    """, (G.FATAL, G.QUARANTINE, run_id, CO.CANDIDATE)).fetchall()

    for r in rows:
        cid = r["candidate_id"]
        jv = r["judge_verdict"]
        if jv is None:
            m["judge_missing"] += 1
            continue
        if jv != "accept":
            CO.set_status(conn, cid, CO.REJECTED, f"judge_{jv}")
            m["judge_rejected"] += 1
            continue

        ih, created = r["item_hash"], (r["created_at"] or "")
        # Certification independently RE-DERIVES the gate verdict for THIS content — it never trusts that an
        # upstream status flip already excluded a failure (defense-in-depth). A gate battery ran on this
        # item_hash; NO fatal AND NO quarantine gate failed; the judge verdict is for THIS content and not
        # stale. A recorded QUARANTINE failure (ungrounded relation, self-refuted depth) can therefore never
        # certify even if the candidate is somehow still in 'candidate' state.
        content_bound = (
            r["gates_for_hash"] > 0 and r["fatal_for_hash"] == 0 and r["quarantine_for_hash"] == 0
            and r["judge_hash"] == ih and (r["judge_at"] or "") >= created
        )
        if not content_bound:
            CO.set_status(conn, cid, CO.QUARANTINED, REASON_STALE)
            m["stale_evidence"] += 1
            continue

        # R2-3 (RI-8, adversarial-verifier fix): on the PRODUCTION path a certified row must ITSELF carry real
        # generation + judge provenance — not merely ride a sibling candidate's run-level telemetry row. Gated
        # to require_telemetry so low-level unit fixtures (built without a provenance bundle) stay green.
        if require_telemetry and not (
                CO.provenance_complete({"model": r["generator_model"], "model_version": r["gen_model_version"],
                                        "prompt_sha256": r["gen_prompt_sha256"], "actor": r["generator_actor"],
                                        "contract_version": r["contract_version"]})
                and CO.provenance_complete(
                    {"model": r["judge_model"], "model_version": r["judge_model_version"],
                     "prompt_sha256": r["judge_prompt_sha256"], "actor": r["judge_actor"]},
                    fields=CO._JUDGE_PROVENANCE_FIELDS)):
            CO.set_status(conn, cid, CO.QUARANTINED, REASON_NO_PROVENANCE)
            m["held_no_provenance"] += 1
            continue

        # R2-2: the mandatory solution stage — a passing solution_verified gate bound to this content.
        if not (r["solution_verified_for_hash"] > 0):
            CO.set_status(conn, cid, CO.QUARANTINED, REASON_NO_SOLUTION)
            m["held_no_solution"] += 1
            continue
        # R2-2: every wrong option's mis_relation proven by the deterministic distractor gate.
        if not (r["distractors_verified_for_hash"] > 0):
            CO.set_status(conn, cid, CO.QUARANTINED, REASON_NO_DISTRACTORS)
            m["held_no_distractors"] += 1
            continue

        # the mandatory link: an answer no independent system re-derived FROM THIS CONTENT is not certified
        ind_ok = (r["ind_verdict"] == "agree" and r["ind_hash"] == ih and (r["ind_at"] or "") >= created)
        if not ind_ok:
            CO.set_status(conn, cid, CO.QUARANTINED, REASON_NO_INDEPENDENT)
            m["held_no_independent"] += 1
            continue

        # R2-4: earn the reasoning depth by executing the DAG, and detect the archetype — stored so downstream
        # reads the honest values, never a refuted generator claim. Computed here regardless of promotion class.
        structure = json.loads(r["structure"] or "{}")
        rep = G.replay_steps(structure)
        earned_depth = rep.get("depth") if rep.get("ok") else None
        is_numeric = bool(structure.get("relation"))
        computed_archetype = G.qie_classify(r["stem"] or "", is_numeric=is_numeric, relation_verified=True)

        # R2-1: independence is COMPUTED (defense-in-depth) — the stored flag AND a re-derived cross-family
        # comparison must BOTH hold. A same-actor 'accept' can never satisfy 'certified'; it lands provisional.
        gen_fam = CO.actor_family(r["generator_family"] or "")
        jud_fam = CO.actor_family(r["judge_family"] or "")
        # FAIL-CLOSED (adversarial-verifier fix): an absent/unknown judge_family must NEVER read as cross-family.
        # actor_family(NULL)=='unknown', and 'unknown' != generator would otherwise certify a judge that declared
        # no family — the same-actor default lives in judge.ingest, but certify re-derives independently and must
        # not depend on it. A family is only 'known' when it is an explicit, non-sentinel string.
        known = jud_fam not in ("", "unknown") and gen_fam not in ("", "unknown")
        cross_family = bool(known and jud_fam != gen_fam)
        independent_judge = (r["judge_independent"] == 1) and cross_family
        if independent_judge:
            # R3-2 (RI-9) bank-level dedup — gates ONLY the PRODUCT-visible promotion (a provisional same-actor
            # row is product-invisible, so a duplicate there is harmless and must not be blocked). Defense-in-depth
            # beneath validate_run's dedup-at-gate seeding and the partial UNIQUE index: never promote a SECOND
            # product-visible certified row duplicating content already product-certified in THIS bank. A collision
            # QUARANTINEs THIS candidate gracefully (it is not wrong, just redundant) rather than aborting the run
            # at the UNIQUE index.
            dup = conn.execute(
                "SELECT candidate_id FROM candidate WHERE status=? AND certification_class=? AND candidate_id!=? "
                "AND (stem_norm_hash=? OR item_hash=?) LIMIT 1",
                (CO.CERTIFIED, CO.CERT_CERTIFIED, cid, r["stem_norm_hash"], ih)).fetchone()
            if dup is not None:
                CO.set_status(conn, cid, CO.QUARANTINED, REASON_DUPLICATE_BANK.format(dup=dup[0]))
                m["duplicate_of_certified"] += 1
                continue
            CO.mark_certified(conn, cid, CO.EVIDENCE_SYMPY, CO.CERT_CERTIFIED, REASON_CERTIFIED,
                              earned_depth=earned_depth, computed_archetype=computed_archetype)
            m["certified"] += 1
        else:
            CO.mark_certified(conn, cid, CO.EVIDENCE_SYMPY, CO.CERT_PROVISIONAL, REASON_PROVISIONAL_SAME_ACTOR,
                              earned_depth=earned_depth, computed_archetype=computed_archetype)
            m["provisional_same_actor"] += 1

    conn.commit()
    return m
