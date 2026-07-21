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


def _gen_provenance(provenance: dict) -> dict:
    """Normalize + fail-close the generation provenance bundle (R2-3, RI-8). contract_version defaults to the
    planner→generator contract in force; everything else (real model id + version + prompt sha256 + actor) MUST
    be supplied by the caller/CLI — a model stage that cannot name what ran it does not get to persist."""
    prov = dict(provenance or {})
    prov.setdefault("contract_version", PLAN.CONTRACT_VERSION)
    CO._require_provenance(prov, kind="generation")
    return prov


def ingest_candidates(conn: sqlite3.Connection, run_id: str, items: List[dict], provenance: dict,
                      batch: str = "b1") -> dict:
    """THE generation model-stage ingest path (R2-3). REJECTS un-provenanced/placeholder payloads fail-closed,
    persists real provenance (payload_sha256 computed inside CO.ingest), and writes the MANDATORY `generation`
    telemetry row (real model + actor) that certify_run(require_telemetry=True) later demands."""
    prov = _gen_provenance(provenance)
    items = list(items)
    # generator_family (R2-1) rides on the provenance bundle when the execution layer supplies it (the provider's
    # actor family) so a same-family judge cannot later fake independence; absent it, CO.ingest defaults family to
    # the model string exactly as before — additive, no behaviour change for legacy callers.
    m = CO.ingest(conn, run_id, items, prov["model"], batch,
                  generator_family=prov.get("generator_family"), provenance=prov)
    CO.telemetry(conn, run_id, "generation", prov["model"], actor=prov["actor"], batches=1, items=len(items),
                 input_tokens=prov.get("input_tokens"), output_tokens=prov.get("output_tokens"),
                 wall_seconds=prov.get("wall_seconds"),
                 note=prov.get("note") or f"generation via {prov['model']} ({prov['model_version']})")
    return m


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


def ingest_judgements(conn: sqlite3.Connection, run_id: str, payload: List[dict], provenance: dict,
                      require_controls: bool = False) -> dict:
    """THE judge model-stage ingest path (R2-3). REJECTS un-provenanced/placeholder judge payloads fail-closed
    (judge fields: model, model_version, prompt_sha256, actor), threads the judge provenance into
    JUDGE.ingest (which computes the judge payload_sha256), and writes the MANDATORY `judge` telemetry row.
    Independence stays COMPUTED from actor families in JUDGE.ingest (R2-1) — `judge_family` rides on the
    provenance bundle, never a caller-asserted `independent` flag."""
    prov = dict(provenance or {})
    CO._require_provenance(prov, fields=CO._JUDGE_PROVENANCE_FIELDS, kind="judge")
    m = JUDGE.ingest(conn, run_id, payload, prov["model"], judge_family=prov.get("judge_family"),
                     require_controls=require_controls, provenance=prov)
    CO.telemetry(conn, run_id, "judge", prov["model"], actor=prov["actor"], batches=1, items=m.get("in"),
                 input_tokens=prov.get("input_tokens"), output_tokens=prov.get("output_tokens"),
                 wall_seconds=prov.get("wall_seconds"),
                 note=prov.get("note") or f"judge via {prov['model']} ({prov['model_version']})")
    return m


# ── R4-2: the CANONICAL model-execution path (provider-agnostic ModelExecutor) ──────────────────────
# generate_candidates / judge_run drive the R4-2 executor (execution queue -> cache -> provider -> telemetry) and
# then feed the EXISTING ingest paths above. The executor produces exactly the provenance bundles + token
# telemetry those paths require, so a real run satisfies certify_run(require_telemetry=True). The scratchpad-file
# helpers below remain the manual fallback. `executor` is a kie.qie.execution.ModelExecutor (duck-typed here to
# avoid importing the execution layer at module load).
def generate_candidates(conn: sqlite3.Connection, run_id: str, executor, specs: List[dict],
                        brief: str = None, batch: str = "b1") -> dict:
    """Generate candidates for `specs` via the executor, then ingest them (with executor-produced provenance +
    generation telemetry). One concept BRIEF for the batch (built from specs unless one is supplied); the model
    PROPOSES the candidate array, the deterministic factory later CERTIFIES. Returns the ingest summary."""
    brief = brief if brief is not None else generator_brief(specs)
    (payload, provenance) = executor.generate([brief], run_id=run_id)[0]
    return ingest_candidates(conn, run_id, payload, provenance, batch=batch)


def judge_run(conn: sqlite3.Connection, run_id: str, executor) -> dict:
    """Judge the run's still-'candidate' items via the executor, then ingest the verdicts (with executor-produced
    judge provenance + judge telemetry). The seeded known-bad controls are appended to the worksheet and verified
    on ingest (require_controls=True); the item_hash-keyed judge cache short-circuits already-judged identical
    items inside the executor. Returns the ingest summary."""
    items = JUDGE.to_judge(conn, run_id)
    rows = JUDGE.worksheet(items)
    item_hashes = {r["candidate_id"]: r["item_hash"] for r in conn.execute(
        "SELECT candidate_id, item_hash FROM candidate WHERE run_id=? AND status='candidate'", (run_id,))}
    controls = [{k: c[k] for k in ("candidate_id", "class", "subject", "stem", "options", "claims")}
                for c in JUDGE.judge_control_items()]
    payload, provenance = executor.judge(rows, item_hashes=item_hashes, brief=JUDGE.JUDGE_BRIEF,
                                         controls=controls, run_id=run_id)
    return ingest_judgements(conn, run_id, payload, provenance, require_controls=True)


def certify(conn: sqlite3.Connection, run_id: str) -> dict:
    """Promote only gates AND sympy-agree AND judge-accept. Never certifies on judge agreement alone.

    require_telemetry=True (R2-3): this is the PRODUCTION certification entrypoint, so a run cannot certify
    without the mandatory generation+judge telemetry rows written by the ingest paths above (RI-8)."""
    return CERT.certify_run(conn, run_id, require_telemetry=True)


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
