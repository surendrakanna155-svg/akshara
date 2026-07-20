"""Stage 3 — solution construction for SURVIVORS ONLY, then deterministic solution verification.

Ordering is an economic decision, not a stylistic one. ~20% of candidates die at a gate battery that costs
5.8 seconds and zero tokens for 414 items. Asking Opus to write a careful step-by-step solution before that
filter runs would spend the most expensive tokens in the pipeline on items already destined for rejection.
So: gates first (free), then solutions (expensive), for survivors only.

The lifecycle rule from the owner's architecture is preserved exactly:

    ... -> INDEPENDENT ANSWER VALIDATION -> LOCK CERTIFIED KEY -> CONSTRUCT SOLUTION -> VERIFY SOLUTION

The key is LOCKED before the solution is written. The solution author is told the key and must derive it — it
may not choose a different answer, and if its final line disagrees with the locked key, the item fails. That
ordering is what stops a solution from silently "fixing" a wrong question into a different one.

Worksheet-in / verdicts-out, mirroring kie.qie.convert.examiner — the repo's established Tier-2/3 boundary.
"""
from __future__ import annotations

import json
import sqlite3
from typing import Dict, List

from kie.qie.factory import corpus as CO, gates as G

SOLUTION_BRIEF = """\
You are constructing CERTIFIED STUDENT SOLUTIONS for questions that have already passed independent
verification. The correct answer is LOCKED. Your job is to explain how to reach it — not to re-decide it.

RULES
- The `locked_answer` is final. Derive it. If you believe it is wrong, do NOT silently write a different
  answer: set "dispute": true with a reason. That is a certification event and is respected.
- Steps must be genuinely student-readable at the stated class level. No hand-waving, no skipped algebra.
- `final` MUST equal the locked answer. It is machine-compared.
- For each WRONG option, name the specific misconception or slip that produces it. If you cannot identify a
  real mistake that yields that option, say so honestly with "distractor_uncertifiable": ["c"] rather than
  inventing a plausible-sounding rationale. A fabricated rationale is worse than an admitted gap.
- Do not exceed the class level in your explanation either.

OUTPUT — JSON array, one object per item, candidate_id copied EXACTLY, no prose outside the JSON:
{
  "candidate_id": "<copied exactly>",
  "dispute": false,
  "solution": {
    "steps": ["Step 1 — Identify ...", "Step 2 — Apply ...", "Step 3 — Compute ...", "Step 4 — Conclude ..."],
    "final": "<must equal the locked answer>"
  },
  "distractor_rationale": {"a": "obtained by using m/F instead of F/m", "c": "...", "d": "..."},
  "distractor_uncertifiable": [],
  "common_mistake": "<the single most likely error a student makes on this item>"
}

## ITEMS
"""


def survivors_for_solution(conn: sqlite3.Connection, run_id: str, only_certifiable: bool = True) -> List[dict]:
    """Items worth paying for. `only_certifiable=True` restricts to those that CAN reach certification —
    i.e. an independent solver already agreed. Writing solutions for items that can never be certified
    (the qualitative lane) buys evidence we cannot use."""
    q = """
        SELECT c.candidate_id, c.stem, c.options, c.answer_label, c.answer_value, c.claimed, c.structure,
               s.class_level, s.subject, s.lane, i.verdict AS ind
        FROM candidate c
        JOIN generation_spec s ON s.spec_id = c.spec_id
        LEFT JOIN independent_answer i ON i.candidate_id = c.candidate_id
        WHERE c.run_id = ? AND c.status = 'candidate'
    """
    if only_certifiable:
        q += " AND i.verdict = 'agree'"
    return [dict(r) for r in conn.execute(q, (run_id,))]


def worksheet(items: List[dict]) -> List[dict]:
    out = []
    for it in items:
        opts = json.loads(it["options"] or "{}")
        out.append({
            "candidate_id": it["candidate_id"],
            "class": it["class_level"], "subject": it["subject"],
            "stem": it["stem"], "options": opts,
            "locked_answer_label": it["answer_label"],
            "locked_answer": opts.get(it["answer_label"]),
        })
    return out


def write_worksheet(items: List[dict], path: str) -> int:
    with open(path, "w") as f:
        f.write(SOLUTION_BRIEF)
        for w in worksheet(items):
            f.write(json.dumps(w, ensure_ascii=False) + "\n")
        f.write(f"\nReturn ONLY the JSON array of {len(items)} objects.\n")
    return len(items)


def ingest(conn: sqlite3.Connection, run_id: str, payload: List[dict]) -> Dict[str, int]:
    """Attach solutions, then VERIFY them deterministically against the locked key."""
    m = {"in": 0, "disputed": 0, "verified": 0, "failed_verification": 0, "unmatched": 0}
    for p in payload:
        cid = p.get("candidate_id")
        row = conn.execute(
            "SELECT candidate_id, options, answer_label FROM candidate WHERE candidate_id=? AND run_id=?",
            (cid, run_id)).fetchone()
        if not row:
            m["unmatched"] += 1
            continue
        m["in"] += 1
        if p.get("dispute"):
            CO.set_status(conn, cid, CO.QUARANTINED,
                          f"solution_author_disputes_key: {str(p.get('reason') or '')[:200]}")
            m["disputed"] += 1
            continue

        sol = p.get("solution") or {}
        conn.execute(
            "UPDATE candidate SET solution=?, distractor_rationale=? WHERE candidate_id=?",
            (json.dumps(sol), json.dumps(p.get("distractor_rationale") or {}), cid))

        # deterministic solution verification: the solution must terminate on the LOCKED key
        opts = json.loads(row["options"] or "{}")
        keyed = opts.get(row["answer_label"])
        final = sol.get("final")
        fn, kn = G._num(final), G._num(keyed)
        if fn is not None and kn is not None:
            ok = abs(fn - kn) <= max(1e-9, 0.02 * abs(kn))
        else:
            a, b = str(final or "").strip().lower(), str(keyed or "").strip().lower()
            ok = bool(a) and bool(b) and (a in b or b in a)
        ok = ok and bool(sol.get("steps"))

        conn.execute(
            "INSERT OR REPLACE INTO gate_result (candidate_id, gate, ok, severity, detail, checked_at) "
            "VALUES (?,?,?,?,?,datetime('now'))",
            (cid, "solution_verified", int(ok), G.FATAL,
             f"solution_final={final!r} locked_key={keyed!r} steps={len(sol.get('steps') or [])}"))
        if ok:
            m["verified"] += 1
        else:
            CO.set_status(conn, cid, CO.REJECTED,
                          f"solution_verification_failed: final={final!r} vs locked_key={keyed!r}")
            m["failed_verification"] += 1
    conn.commit()
    return m
