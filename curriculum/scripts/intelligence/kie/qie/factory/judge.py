"""Stage 3b — the separate AI judge.

INDEPENDENCE, STATED HONESTLY (the owner asked for this explicitly, so it is ENFORCED IN THE DATA FLOW rather
than promised in a report — R2-1):

  * The judge is BLIND to the generator's reasoning, its declared structure, its step DAG, its solution and
    its distractor rationales — AND NOW BLIND TO THE PROPOSED KEY. It sees only what a student sees (stem,
    options) plus the claims under test, and must produce its OWN `chosen_label`. Whether that matches the
    bank's key is COMPUTED afterwards from the label it chose, never handed to it — so "the judge reached the
    key" can no longer be self-reported. (Old leak: judge.py:92 shipped `proposed_key` on the worksheet.)
  * Independence is COMPUTED, not asserted. `record_judge` stores the judge's actor family; certification
    re-derives `independent = judge_family != generator_family`. A same-actor review (today's code default,
    where generator and judge are the same orchestrator) yields `independent=0` and can only ever produce a
    PROVISIONAL, product-invisible row — never 'certified'. A genuinely different family (or a human) must
    dispose the verdict for full certification.
  * Seeded known-bad control items are injected into the judge worksheet (judge_control_items); on ingest the
    judge's dispositions are checked and the pass ABORTS (JudgeControlBreach) if it accepted a planted bad
    item — the controls-before-batch discipline extended to the AI judge.
  * Therefore the judge can REJECT but it can never CERTIFY on its own. Certification additionally requires a
    non-model re-derivation (sympy). See certify.py — that ordering is the whole point of the architecture.

Worksheet-in / verdicts-out, mirroring kie.qie.convert.examiner.
"""
from __future__ import annotations

import json
import sqlite3
from typing import Dict, List

from kie.qie.factory import corpus as CO


class JudgeControlBreach(Exception):
    """The judge accepted (or skipped) a planted known-bad item. The JUDGE — not the item — is the problem, so
    the whole judge pass is aborted: verdicts from a reviewer that cannot fail a known-bad item are not
    evidence, exactly as controls.ControlBreach treats the deterministic battery."""

JUDGE_BRIEF = """\
You are an INDEPENDENT EXAMINER reviewing question candidates for a school/JEE/NEET question bank. You did not
write these questions and you cannot see how they were made. Judge only what is in front of you.

You are given the question, its options, and the CLAIMS made about it. You are DELIBERATELY NOT given the
proposed answer key. SOLVE EACH QUESTION YOURSELF, FROM SCRATCH, and report the option YOU choose in
`chosen_label`. Whether your answer matches the bank's key is computed afterwards, from your `chosen_label` — so
there is nothing to agree with here, only your own worked answer. Test every claim; do NOT assume a claim is
true because it is stated. Your default on genuine uncertainty is to QUARANTINE, not to accept — an accepted
bad item reaches students, a quarantined good item merely waits for review.

For each item, answer:
- chosen_label       : the option label YOUR OWN independent solution selects (a|b|c|d). REQUIRED.
- well_posed         : is it unambiguous and answerable exactly as written? (missing data, undefined terms,
                       "as shown" with no figure, two readings of the sentence -> false)
- curriculum_ok      : is EVERY concept and technique needed to solve it within the stated class and subject?
                       (a Class-8 item needing Class-11 method -> false; a "Chemistry" item that is actually
                       maths or physics -> false)
- unique_answer      : is exactly ONE option defensible? (two correct options, or none -> false)
- concepts_real      : are the CLAIMED concepts genuinely REQUIRED to solve it, or just name-dropped?
- composition_real   : if composition is "multi", are 2+ concepts genuinely required? Two topic words in the
                       sentence is NOT composition. If "single", set true.
- difficulty_plausible : is the claimed difficulty believable for that class? (ugly arithmetic is NOT hard;
                       a subtle trap at low depth CAN be hard)
- distractors_plausible : does each wrong option correspond to a real, nameable student mistake? (random or
                       absurd numbers -> false)
- visual_judgement   : "ok" (no visual needed and none implied) | "missing" (the item cannot be answered
                       without a figure it does not have) | "unnecessary" (it references a figure it does not
                       need)

verdict: "accept" only if the item is genuinely fit for a student. "reject" if it is broken.
         "quarantine" if it needs a human decision.

OUTPUT — JSON array, candidate_id copied EXACTLY, no prose outside the JSON:
{"candidate_id":"...","verdict":"accept|reject|quarantine","chosen_label":"b","well_posed":true,
 "curriculum_ok":true,"unique_answer":true,"concepts_real":true,"composition_real":true,
 "difficulty_plausible":true,"distractors_plausible":true,"visual_judgement":"ok",
 "reasons":"<one short sentence; REQUIRED whenever any field is false>"}

## ITEMS
"""


def to_judge(conn: sqlite3.Connection, run_id: str, limit: int = None) -> List[dict]:
    q = """
        SELECT c.candidate_id, c.stem, c.options, c.answer_label, c.claimed, c.visual_spec,
               s.class_level, s.subject, s.archetype, s.intended_depth, s.intended_difficulty,
               s.composition, s.visual_required
        FROM candidate c JOIN generation_spec s ON s.spec_id = c.spec_id
        WHERE c.run_id = ? AND c.status = 'candidate'
        ORDER BY c.candidate_id
    """
    if limit:
        q += f" LIMIT {int(limit)}"
    return [dict(r) for r in conn.execute(q, (run_id,))]


def worksheet(items: List[dict]) -> List[dict]:
    """Strictly what a student sees + the claims under test. NEVER the structure, DAG, solution, rationale — and
    NEVER the proposed key (R2-1): the judge must produce its own `chosen_label`, which is compared afterwards."""
    out = []
    for it in items:
        opts = json.loads(it["options"] or "{}")
        claimed = json.loads(it["claimed"] or "{}")
        out.append({
            "candidate_id": it["candidate_id"],
            "class": it["class_level"], "subject": it["subject"],
            "stem": it["stem"], "options": opts,
            "claims": {
                "concepts": claimed.get("concepts"),
                "archetype": it["archetype"],
                "depth": it["intended_depth"],
                "difficulty": it["intended_difficulty"],
                "composition": it["composition"],
                "visual_required": bool(it["visual_required"]),
                "has_visual_spec": bool(it["visual_spec"]),
            },
        })
    return out


# ── seeded known-bad judge controls (R2-1) — the controls-before-batch discipline, extended to the AI judge ──
# Each is broken in a way a competent BLIND solver (stem+options only, no key) must catch, so the expected
# disposition is anything but 'accept'. If the judge accepts one, its verdicts are not evidence — abort.
_JUDGE_CONTROL_PREFIX = "JUDGE_CTRL_"


def judge_control_items() -> List[dict]:
    """Planted worksheet rows to inject into every judge pass. Each carries `expected_not` (the disposition it
    must NOT return) and a `flaw` note (for the breach message). These are NOT real candidates and are stripped
    from the DB write in `ingest`."""
    base_claims = {"concepts": ["placeholder"], "archetype": "single_step_numerical", "depth": 1,
                   "difficulty": "easy", "composition": "single", "visual_required": False,
                   "has_visual_spec": False}
    return [
        {"candidate_id": _JUDGE_CONTROL_PREFIX + "unanswerable", "class": 9, "subject": "Physics",
         "stem": "A car accelerates uniformly from rest. What is its speed?",   # no time/accel given
         "options": {"a": "5 m/s", "b": "10 m/s", "c": "20 m/s", "d": "40 m/s"},
         "claims": base_claims, "expected_not": "accept", "flaw": "unanswerable: no data to determine a speed"},
        {"candidate_id": _JUDGE_CONTROL_PREFIX + "two_correct", "class": 8, "subject": "Mathematics",
         "stem": "Which of the following equals one half?",
         "options": {"a": "0.5", "b": "1/2", "c": "3", "d": "7"},   # a and b are both correct
         "claims": base_claims, "expected_not": "accept", "flaw": "two correct options (0.5 and 1/2)"},
        {"candidate_id": _JUDGE_CONTROL_PREFIX + "none_correct", "class": 9, "subject": "Physics",
         "stem": "A body of mass 2 kg accelerates at 3 m/s^2. What net force acts on it? (F = m a)",
         "options": {"a": "1 N", "b": "2 N", "c": "3 N", "d": "5 N"},   # correct is 6 N — not present
         "claims": base_claims, "expected_not": "accept", "flaw": "no correct option present (F = 6 N)"},
    ]


def check_judge_controls(control_verdicts: Dict[str, dict]) -> dict:
    """Verify the judge caught every planted bad item. Raises JudgeControlBreach if any expected control is
    missing from the verdicts or was 'accept'ed. Returns a summary when all controls held."""
    results = []
    for ctrl in judge_control_items():
        cid = ctrl["candidate_id"]
        v = control_verdicts.get(cid)
        if v is None:
            raise JudgeControlBreach(f"judge control {cid!r} ({ctrl['flaw']}) was not disposed — the judge "
                                     f"skipped a planted bad item; the pass is not trustworthy")
        got = v.get("verdict") or "quarantine"
        if got == ctrl["expected_not"]:
            raise JudgeControlBreach(f"judge control {cid!r} was {got!r} but is broken: {ctrl['flaw']}. A judge "
                                     f"that accepts a known-bad item cannot certify a good one — aborting.")
        results.append({"control": cid, "verdict": got, "ok": True})
    return {"judge_controls": len(results), "all_caught": True, "results": results}


def worksheet_with_controls(items: List[dict]) -> List[dict]:
    """The judge worksheet with the seeded known-bad controls appended (R2-1). Use this everywhere a real judge
    pass is issued; ingest then enforces the controls were caught."""
    ctrls = [{k: c[k] for k in ("candidate_id", "class", "subject", "stem", "options", "claims")}
             for c in judge_control_items()]
    return worksheet(items) + ctrls


def write_worksheet(items: List[dict], path: str, with_controls: bool = True) -> int:
    rows = worksheet_with_controls(items) if with_controls else worksheet(items)
    with open(path, "w") as f:
        f.write(JUDGE_BRIEF)
        for w in rows:
            f.write(json.dumps(w, ensure_ascii=False) + "\n")
        f.write(f"\nReturn ONLY the JSON array of {len(rows)} verdict objects.\n")
    return len(rows)


def ingest(conn: sqlite3.Connection, run_id: str, payload: List[dict], judge_model: str,
           judge_family: str = None, independent: bool = None) -> Dict[str, int]:
    """Record judge verdicts. Independence is COMPUTED, never taken from the caller (R2-1):

      * If any planted control verdicts are present, they are checked (JudgeControlBreach on a miss) and then
        stripped — controls are not real candidates.
      * For each real verdict, the disposing reviewer's actor family is resolved (explicit `judge_family`, else
        the candidate's OWN generator_family — the fail-closed same-actor default), and
        `independent = (judge_family != generator_family)` is computed and stored.
      * `answer_correct` is COMPUTED from the judge's own `chosen_label` vs the item's real key (which the judge
        never saw), never self-reported.

    The legacy `independent` parameter is accepted for call-site compatibility (run_generation) but IGNORED —
    a caller can no longer assert its own independence.
    """
    control_ids = {c["candidate_id"] for c in judge_control_items()}
    control_verdicts = {v.get("candidate_id"): v for v in payload if v.get("candidate_id") in control_ids}
    if control_verdicts:                       # controls were injected into this pass — enforce them
        check_judge_controls(control_verdicts)

    m = {"in": 0, "accept": 0, "reject": 0, "quarantine": 0, "unmatched": 0,
         "independent": 0, "same_actor": 0}
    for v in payload:
        cid = v.get("candidate_id")
        if cid in control_ids:
            continue                           # planted control — verified above, never written to the DB
        row = conn.execute(
            "SELECT candidate_id, generator_family, answer_label FROM candidate WHERE candidate_id=? AND run_id=?",
            (cid, run_id)).fetchone()
        if not row:
            m["unmatched"] += 1
            continue
        gen_family = CO.actor_family(row["generator_family"] or "")
        eff_judge_family = CO.actor_family(judge_family) if judge_family else gen_family
        computed_independent = bool(eff_judge_family and gen_family and eff_judge_family != gen_family)
        # blind-answer (R2-1): the judge's own chosen_label decides answer_correct — not a self-report
        chosen = v.get("chosen_label")
        vv = dict(v)
        vv["answer_correct"] = bool(chosen is not None and chosen == row["answer_label"])
        verdict = v.get("verdict") or "quarantine"
        CO.record_judge(conn, cid, judge_model, computed_independent, vv, judge_family=eff_judge_family)
        m["in"] += 1
        m[verdict] = m.get(verdict, 0) + 1
        m["independent" if computed_independent else "same_actor"] += 1
    conn.commit()
    return m
