"""Stage 3b — the separate AI judge.

INDEPENDENCE, STATED HONESTLY (the owner asked for this explicitly, so it is enforced here rather than
promised in a report):

  * The judge is BLIND to the generator's reasoning, its declared structure, its step DAG, its solution and
    its distractor rationales. It sees only what a student sees — stem, options — plus the spec's claims that
    it is being asked to test. Showing it the generator's derivation would let it grade the argument instead
    of the question, and it would agree with fluent-but-wrong work.
  * The judge is the SAME MODEL FAMILY as the generator. That is a real limitation and it is recorded on every
    verdict as `independent=0`. Same-family self-review is NOT full independence and this module never claims
    it is. It is a semantic reviewer, not a proof.
  * Therefore the judge can REJECT but it can never CERTIFY on its own. Certification additionally requires a
    non-model re-derivation (sympy). See certify.py — that ordering is the whole point of the architecture.

Worksheet-in / verdicts-out, mirroring kie.qie.convert.examiner.
"""
from __future__ import annotations

import json
import sqlite3
from typing import Dict, List

from kie.qie.factory import corpus as CO

JUDGE_BRIEF = """\
You are an INDEPENDENT EXAMINER reviewing question candidates for a school/JEE/NEET question bank. You did not
write these questions and you cannot see how they were made. Judge only what is in front of you.

You are given the question, its options, the proposed key, and the CLAIMS made about it. Test the claims.
Do NOT assume a claim is true because it is stated. Your default on genuine uncertainty is to QUARANTINE, not
to accept — an accepted bad item reaches students, a quarantined good item merely waits for review.

Solve each question yourself, from scratch, before looking at the proposed key.

For each item, answer:
- well_posed         : is it unambiguous and answerable exactly as written? (missing data, undefined terms,
                       "as shown" with no figure, two readings of the sentence -> false)
- curriculum_ok      : is EVERY concept and technique needed to solve it within the stated class and subject?
                       (a Class-8 item needing Class-11 method -> false; a "Chemistry" item that is actually
                       maths or physics -> false)
- answer_correct     : did YOUR independent solution reach the proposed key?
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
{"candidate_id":"...","verdict":"accept|reject|quarantine","well_posed":true,"curriculum_ok":true,
 "answer_correct":true,"unique_answer":true,"concepts_real":true,"composition_real":true,
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
    """Strictly what a student sees + the claims under test. NEVER the structure, DAG, solution or rationale."""
    out = []
    for it in items:
        opts = json.loads(it["options"] or "{}")
        claimed = json.loads(it["claimed"] or "{}")
        out.append({
            "candidate_id": it["candidate_id"],
            "class": it["class_level"], "subject": it["subject"],
            "stem": it["stem"], "options": opts,
            "proposed_key": it["answer_label"],
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


def write_worksheet(items: List[dict], path: str) -> int:
    with open(path, "w") as f:
        f.write(JUDGE_BRIEF)
        for w in worksheet(items):
            f.write(json.dumps(w, ensure_ascii=False) + "\n")
        f.write(f"\nReturn ONLY the JSON array of {len(items)} verdict objects.\n")
    return len(items)


def ingest(conn: sqlite3.Connection, run_id: str, payload: List[dict], judge_model: str,
           independent: bool = False) -> Dict[str, int]:
    m = {"in": 0, "accept": 0, "reject": 0, "quarantine": 0, "unmatched": 0}
    for v in payload:
        cid = v.get("candidate_id")
        row = conn.execute("SELECT candidate_id FROM candidate WHERE candidate_id=? AND run_id=?",
                           (cid, run_id)).fetchone()
        if not row:
            m["unmatched"] += 1
            continue
        verdict = v.get("verdict") or "quarantine"
        CO.record_judge(conn, cid, judge_model, independent, v)
        m["in"] += 1
        m[verdict] = m.get(verdict, 0) + 1
    conn.commit()
    return m
