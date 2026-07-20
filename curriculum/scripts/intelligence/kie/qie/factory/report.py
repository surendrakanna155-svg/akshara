"""Trial metrics — measured from the corpus, never estimated.

Every number here is a query against what actually happened. Where a metric the owner asked for cannot be
measured (provider token telemetry is not exposed to this harness; SVG rendering does not exist), the report
says so explicitly rather than substituting a plausible-looking figure. An unmeasurable metric reported as a
number is worse than an admitted gap.
"""
from __future__ import annotations

import json
import sqlite3
from typing import Dict, List


def _d(conn, sql, params=()) -> Dict[str, int]:
    return {str(r[0]): r[1] for r in conn.execute(sql, params)}


def build(conn: sqlite3.Connection, run_id: str) -> dict:
    R: dict = {"run_id": run_id}

    R["planned_specs"] = conn.execute(
        "SELECT COUNT(*) FROM generation_spec WHERE run_id=?", (run_id,)).fetchone()[0]
    R["candidates_returned"] = conn.execute(
        "SELECT COUNT(*) FROM candidate WHERE run_id=?", (run_id,)).fetchone()[0]
    R["generator_refusals"] = conn.execute(
        "SELECT COUNT(*) FROM candidate WHERE run_id=? AND reject_reason LIKE 'generator_refused%'",
        (run_id,)).fetchone()[0]
    R["never_returned"] = R["planned_specs"] - R["candidates_returned"]

    R["by_status"] = _d(conn, "SELECT status, COUNT(*) FROM candidate WHERE run_id=? GROUP BY 1", (run_id,))
    R["by_generator_model"] = _d(
        conn, "SELECT generator_model, COUNT(*) FROM candidate WHERE run_id=? GROUP BY 1", (run_id,))

    # ── distribution of what was actually produced (joined to the plan) ──
    J = ("FROM candidate c JOIN generation_spec s ON s.spec_id=c.spec_id WHERE c.run_id=?")
    for name, col in (("by_class", "s.class_level"), ("by_subject", "s.subject"), ("by_lane", "s.lane"),
                      ("by_archetype", "s.archetype"), ("by_depth", "s.intended_depth"),
                      ("by_difficulty", "s.intended_difficulty"), ("by_composition", "s.composition"),
                      ("by_arm", "json_extract(s.planner_evidence,'$.arm')")):
        R[name] = _d(conn, f"SELECT {col}, COUNT(*) {J} GROUP BY 1", (run_id,))

    R["distinct_concepts_covered"] = conn.execute(
        f"SELECT COUNT(DISTINCT s.concept_code) {J}", (run_id,)).fetchone()[0]
    R["visual_required_planned"] = conn.execute(
        f"SELECT COUNT(*) {J} AND s.visual_required=1", (run_id,)).fetchone()[0]
    R["visual_spec_emitted"] = conn.execute(
        "SELECT COUNT(*) FROM candidate WHERE run_id=? AND visual_spec IS NOT NULL", (run_id,)).fetchone()[0]

    # ── gate outcomes ──
    R["gate_failures"] = _d(conn, (
        "SELECT g.gate, COUNT(*) FROM gate_result g JOIN candidate c ON c.candidate_id=g.candidate_id "
        "WHERE c.run_id=? AND g.ok=0 GROUP BY 1 ORDER BY 2 DESC"), (run_id,))
    R["gate_pass_rate"] = {}
    for r in conn.execute(
        "SELECT g.gate, SUM(g.ok) AS ok, COUNT(*) AS n FROM gate_result g "
        "JOIN candidate c ON c.candidate_id=g.candidate_id WHERE c.run_id=? GROUP BY 1 ORDER BY 1", (run_id,)
    ):
        R["gate_pass_rate"][r["gate"]] = {"pass": r["ok"], "n": r["n"],
                                          "pct": round(100 * r["ok"] / max(1, r["n"]), 1)}

    # ── independent answer validation ──
    R["independent_answer"] = _d(conn, (
        "SELECT i.verdict, COUNT(*) FROM independent_answer i JOIN candidate c "
        "ON c.candidate_id=i.candidate_id WHERE c.run_id=? GROUP BY 1 ORDER BY 2 DESC"), (run_id,))

    # ── AI judge ──
    R["judge"] = _d(conn, (
        "SELECT j.verdict, COUNT(*) FROM judge_verdict j JOIN candidate c ON c.candidate_id=j.candidate_id "
        "WHERE c.run_id=? GROUP BY 1"), (run_id,))
    jd = {}
    for col in ("well_posed", "curriculum_ok", "answer_correct", "unique_answer", "concepts_real",
                "composition_real", "difficulty_plausible", "distractors_plausible"):
        row = conn.execute(
            f"SELECT SUM(CASE WHEN j.{col}=0 THEN 1 ELSE 0 END), COUNT(j.{col}) FROM judge_verdict j "
            f"JOIN candidate c ON c.candidate_id=j.candidate_id WHERE c.run_id=?", (run_id,)).fetchone()
        jd[col] = {"failed": row[0] or 0, "judged": row[1] or 0}
    R["judge_dimension_failures"] = jd
    R["judge_independence"] = _d(conn, (
        "SELECT j.independent, COUNT(*) FROM judge_verdict j JOIN candidate c "
        "ON c.candidate_id=j.candidate_id WHERE c.run_id=? GROUP BY 1"), (run_id,))

    # ── failure rates by class / subject / arm (the owner asked for each) ──
    def _fail_by(col, label):
        out = {}
        for r in conn.execute(
            f"SELECT {col} AS k, "
            f"SUM(CASE WHEN c.status='certified' THEN 1 ELSE 0 END) AS cert, COUNT(*) AS n "
            f"FROM candidate c JOIN generation_spec s ON s.spec_id=c.spec_id WHERE c.run_id=? GROUP BY 1",
            (run_id,)
        ):
            out[str(r["k"])] = {"certified": r["cert"], "n": r["n"],
                                "yield_pct": round(100 * r["cert"] / max(1, r["n"]), 1)}
        return out
    R["yield_by_class"] = _fail_by("s.class_level", "class")
    R["yield_by_subject"] = _fail_by("s.subject", "subject")
    R["yield_by_lane"] = _fail_by("s.lane", "lane")
    R["yield_by_arm"] = _fail_by("json_extract(s.planner_evidence,'$.arm')", "arm")
    R["yield_by_depth"] = _fail_by("s.intended_depth", "depth")
    R["yield_by_composition"] = _fail_by("s.composition", "composition")

    R["top_reject_reasons"] = _d(conn, (
        "SELECT substr(reject_reason, 1, 60), COUNT(*) FROM candidate WHERE run_id=? AND status='rejected' "
        "AND reject_reason IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 12"), (run_id,))
    R["top_quarantine_reasons"] = _d(conn, (
        "SELECT substr(reject_reason, 1, 60), COUNT(*) FROM candidate WHERE run_id=? AND status='quarantined' "
        "AND reject_reason IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 12"), (run_id,))

    cert = R["by_status"].get("certified", 0)
    R["certification_yield_pct"] = round(100 * cert / max(1, R["candidates_returned"]), 1)
    R["certified"] = cert

    R["telemetry"] = [dict(r) for r in conn.execute(
        "SELECT * FROM run_telemetry WHERE run_id=?", (run_id,))]

    R["measurement_limits"] = [
        "Per-request provider token counts and $ cost are NOT exposed to this harness. Generation ran through "
        "orchestrated Claude subagents, so tokens are reported as harness-measured aggregates where available "
        "and otherwise estimated from payload size — flagged wherever used.",
        "SVG/diagram RENDERING does not exist in the repo (0 lines; no renderer, no dependency). Visual "
        "metrics therefore cover SPEC emission only, never render success.",
        "The AI judge is the same model family as the generator. This is disclosed, not hidden: it is NOT "
        "full independence and cannot be claimed as such.",
    ]
    return R


def render(R: dict) -> str:
    L: List[str] = []
    a = L.append
    a(f"# Factory Trial — {R['run_id']}")
    a("")
    a(f"planned specs        : {R['planned_specs']}")
    a(f"candidates returned  : {R['candidates_returned']}  (never returned: {R['never_returned']})")
    a(f"generator refusals   : {R['generator_refusals']}")
    a(f"certified            : {R['certified']}   yield = {R['certification_yield_pct']}%")
    a(f"status               : {R['by_status']}")
    a("")
    a("## Yield by lane"); a(json.dumps(R["yield_by_lane"], indent=1))
    a("## Yield by subject"); a(json.dumps(R["yield_by_subject"], indent=1))
    a("## Yield by class"); a(json.dumps(R["yield_by_class"], indent=1))
    a("## Yield by arm (evidenced vs boundary_probe)"); a(json.dumps(R["yield_by_arm"], indent=1))
    a("## Independent answer validation"); a(json.dumps(R["independent_answer"], indent=1))
    a("## Gate failures"); a(json.dumps(R["gate_failures"], indent=1))
    a("## Judge"); a(json.dumps(R["judge"], indent=1))
    a("## Judge dimension failures"); a(json.dumps(R["judge_dimension_failures"], indent=1))
    a("## Top reject reasons"); a(json.dumps(R["top_reject_reasons"], indent=1))
    a("## Measurement limits")
    for m in R["measurement_limits"]:
        a(f"- {m}")
    return "\n".join(L)
