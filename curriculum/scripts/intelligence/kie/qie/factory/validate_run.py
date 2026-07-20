"""Stage 2 — deterministic gates + INDEPENDENT answer validation over the candidate corpus.

Order matters and is deliberate:
  1. controls          — prove the battery can still fail known-bad items (abort the run if not)
  2. deterministic     — the gate battery, cheapest and most decisive first
  3. independent solve — sympy re-derives the answer from the DECLARED structure, never from the prose,
                         never from the generator's stated answer

A disagreement between the generator and the solver is a CERTIFICATION EVENT, not a repair job: the item is
quarantined. We never rewrite the key to whatever the solver said — the solver could be right and the item
still ambiguous, and silently adopting its answer would destroy the evidence that they disagreed.
"""
from __future__ import annotations

import json
import sqlite3
import time
from typing import Dict, List

from kie.qie.factory import controls as C, corpus as CO, gates as G


def _spec_of(conn, spec_id: str) -> dict:
    r = conn.execute("SELECT * FROM generation_spec WHERE spec_id=?", (spec_id,)).fetchone()
    return dict(r) if r else {}


def run(conn: sqlite3.Connection, qconn: sqlite3.Connection, run_id: str) -> dict:
    t0 = time.time()
    certified_relations = G.load_certified_relations(qconn)

    # ── 1. controls first, both directions ──
    # a battery that cannot fail a known-bad item cannot certify a good one; and a comparator that misreads
    # correct notation would manufacture disagreements. Both are run before a single candidate is judged.
    C.check_controls({"spec": C._spec(), "seen_norm": {}, "corpus": [],
                      "certified_relations": certified_relations})
    C.check_notation_controls()
    C.check_magnitude_controls()

    rows = conn.execute(
        "SELECT * FROM candidate WHERE run_id=? AND status=? ORDER BY candidate_id", (run_id, CO.CANDIDATE)
    ).fetchall()

    metrics = {"examined": len(rows), "rejected": 0, "quarantined": 0, "survived_gates": 0,
               "gate_fail_counts": {}, "independent": {}}
    seen_norm: Dict[str, str] = {}
    # near-duplicate scan is scoped per (class, subject) — a Class-6 maths item and a Class-12 physics item
    # sharing tokens is not a duplicate, and an unscoped O(n^2) scan would drown in false positives.
    corpus_by_cell: Dict[tuple, List[tuple]] = {}

    for r in rows:
        spec = _spec_of(conn, r["spec_id"])
        cell = (spec.get("class_level"), spec.get("subject"))
        cand = {
            "stem": r["stem"], "options": json.loads(r["options"] or "{}"),
            "answer_label": r["answer_label"], "answer_value": r["answer_value"],
            "claimed": json.loads(r["claimed"] or "{}"),
            "structure": json.loads(r["structure"] or "{}"),
            "solution": json.loads(r["solution"] or "{}"),
            "visual_spec": json.loads(r["visual_spec"]) if r["visual_spec"] else None,
        }
        ctx = {"spec": spec, "seen_norm": seen_norm, "corpus": corpus_by_cell.get(cell, []),
               "certified_relations": certified_relations}

        gr = G.run_gates(cand, ctx)
        CO.record_gates(conn, r["candidate_id"], gr)
        for g in gr:
            if not g["ok"]:
                metrics["gate_fail_counts"][g["gate"]] = metrics["gate_fail_counts"].get(g["gate"], 0) + 1

        status, reason = G.verdict(gr)

        # ── 3. independent answer validation (only where a structure was declared) ──
        ind = G.independent_solve(cand["structure"])
        if ind["verdict"] == "not_applicable":
            v, method, solver_ans, detail = "not_applicable", "none_available", None, ind["reason"]
        elif ind["verdict"] == "solved":
            agree, why = G.answers_agree(ind["solver_answer"], cand["answer_value"])
            v, method, solver_ans, detail = ("agree" if agree else "disagree"), "sympy_relation_solve", \
                ind["solver_answer"], why
        else:
            v, method, solver_ans, detail = ind["verdict"], "sympy_relation_solve", \
                ind.get("solver_answer"), ind["reason"]
        CO.record_independent(conn, r["candidate_id"], method, solver_ans, cand["answer_value"], v, detail)
        metrics["independent"][v] = metrics["independent"].get(v, 0) + 1

        # a generator whose own declared relation refutes its own key is not a quarantine case — it is wrong
        if v == "disagree":
            status, reason = CO.REJECTED, f"independent_solve DISAGREE: {detail}"
        elif v in ("ambiguous", "no_valid_answer"):
            status = CO.QUARANTINED if status != CO.REJECTED else status
            reason = f"independent_solve {v}: {detail}" if status == CO.QUARANTINED else reason
        elif v == "solver_failed" and status == CO.CANDIDATE:
            status, reason = CO.QUARANTINED, f"independent_solve unusable: {detail}"

        if status == CO.REJECTED:
            metrics["rejected"] += 1
        elif status == CO.QUARANTINED:
            metrics["quarantined"] += 1
        else:
            metrics["survived_gates"] += 1
            seen_norm[r["stem_norm_hash"]] = r["candidate_id"]
            corpus_by_cell.setdefault(cell, []).append((r["candidate_id"], r["stem"]))

        if status != CO.CANDIDATE:
            CO.set_status(conn, r["candidate_id"], status, reason)
    conn.commit()

    metrics["wall_seconds"] = round(time.time() - t0, 2)
    metrics["gate_fail_counts"] = dict(sorted(metrics["gate_fail_counts"].items(), key=lambda kv: -kv[1]))
    CO.telemetry(conn, run_id, "gates", "deterministic", items=len(rows),
                 wall_seconds=metrics["wall_seconds"], note="sympy + frozen QIE gates; no model calls")
    return metrics
