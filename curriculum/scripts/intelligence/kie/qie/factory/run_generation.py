"""Candidate generation driver — run CERTIFIED QuestionBlueprints through the AI candidate factory.

Pipeline (Decision C — split-lane AI candidate factory):
  certified blueprint -> generator brief -> [MODEL proposes candidate] -> deterministic gates + sympy
  independent solve -> [MODEL judges] -> certify (gates AND sympy-agree AND judge-accept).

Only STRUCTURED_NUMERIC blueprints are certifiable here: sympy independently re-derives the answer from the
declared structure. QUALITATIVE blueprints have no non-model re-derivation and stay on the owned-source lane
(they park as quarantined `awaiting_independent_evidence`). The model PROPOSES; deterministic checks CERTIFY.
"""
from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import List

from kie import config
from kie.qie.factory import certify as CERT
from kie.qie.factory import corpus as CO
from kie.qie.factory import judge as JUDGE
from kie.qie.factory import plan as PLAN
from kie.qie.factory import validate_run as VR
from kie.qie.knowledge import blueprint_store as BS
from kie.qie.knowledge import run_planner as RP

QIE_STORE = config.KIE_HOME / "qie.db"


def stage_blueprints(conn: sqlite3.Connection, exam: str, run_id: str, n: int = 60,
                     lane: str = "STRUCTURED_NUMERIC", limit: int = None,
                     examdna_path=None) -> List[dict]:
    """Plan certified blueprints, keep the sympy-certifiable lane, persist to a fresh run, return spec rows."""
    out = RP.plan_blueprints(exam, n, examdna_path=examdna_path)
    bps = [b for b in out["issued"] if b["lane"] == lane]
    if limit:
        bps = bps[:limit]
    for b in bps:
        b["run_id"] = run_id
    BS.save_blueprints(conn, bps)
    rows = conn.execute("SELECT * FROM generation_spec WHERE run_id=? ORDER BY spec_id", (run_id,)).fetchall()
    return [dict(r) for r in rows]


def generator_brief(spec_rows: List[dict]) -> str:
    """The prompt a generator model receives — concept/archetype/difficulty/boundary; NEVER an answer."""
    return PLAN.compact_brief(spec_rows)


def ingest_candidates(conn: sqlite3.Connection, run_id: str, items: List[dict],
                      model: str = "generator-agent", batch: str = "b1") -> dict:
    return CO.ingest(conn, run_id, items, model, batch)


def verify(conn: sqlite3.Connection, run_id: str) -> dict:
    """Deterministic Stage 2: controls + gate battery + sympy independent solve. No model calls."""
    qconn = sqlite3.connect(f"file:{QIE_STORE}?mode=ro", uri=True)
    qconn.row_factory = sqlite3.Row
    try:
        return VR.run(conn, qconn, run_id)
    finally:
        qconn.close()


def judge_worksheet(conn: sqlite3.Connection, run_id: str) -> List[dict]:
    """Student-view worksheet for the judge (stem + options + claims only; never structure/solution)."""
    return JUDGE.worksheet(JUDGE.to_judge(conn, run_id))


def ingest_judgements(conn: sqlite3.Connection, run_id: str, payload: List[dict],
                      model: str = "judge-agent", independent: bool = False) -> dict:
    # Legacy single-actor path: it issues a plain worksheet (no seeded controls) and can only ever produce
    # PROVISIONAL rows (its judge shares the generator family), so control enforcement does not apply here.
    # TODO(R2-3/R4-2): the real cross-family judge lane must issue worksheet_with_controls and keep the default.
    return JUDGE.ingest(conn, run_id, payload, model, independent=independent, require_controls=False)


def certify(conn: sqlite3.Connection, run_id: str) -> dict:
    """Promote only gates AND sympy-agree AND judge-accept. Never certifies on judge agreement alone."""
    return CERT.certify_run(conn, run_id)


def report(conn: sqlite3.Connection, run_id: str) -> dict:
    """Run summary + the certified inventory (the ONLY product-visible rows)."""
    status = {r[0]: r[1] for r in conn.execute(
        "SELECT status, COUNT(*) FROM candidate WHERE run_id=? GROUP BY status", (run_id,))}
    certified = [dict(r) for r in CO.product_inventory(conn, run_id)]
    return {"status": status, "certified_count": len(certified),
            "certified": [{"concept": json.loads(c["claimed"] or "{}").get("concepts"),
                           "stem": c["stem"], "answer": c["answer_value"]} for c in certified]}


# ── thin file helpers so an external generator/judge agent can round-trip via the scratchpad ──
def write_brief(spec_rows: List[dict], path: str) -> int:
    Path(path).write_text(generator_brief(spec_rows))
    return len(spec_rows)


def load_json_array(path: str) -> List[dict]:
    txt = Path(path).read_text().strip()
    # tolerate a fenced ```json block
    if txt.startswith("```"):
        txt = txt.split("```", 2)[1]
        if txt.startswith("json"):
            txt = txt[4:]
    return json.loads(txt)
