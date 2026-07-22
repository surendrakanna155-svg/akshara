"""Program C — held-estate RE-CERTIFICATION runner (append-only; deterministic re-mine → cross-family judge).

Re-certifies a recalled cohort (the R0-2 recall: 22 factory questions) through the REAL certification chain with
a genuinely cross-family judge. It NEVER mutates the recalled originals or the product bank — it re-mines their
content VERBATIM into a FRESH run in a caller-supplied (dedicated/throwaway) store and drives the full chain:

    deterministic re-mine  ->  gates + sympy (independent answer)  ->  solution stage (model)
        ->  deterministic solution+distractor verification  ->  cross-family JUDGE (model)  ->  certify

INDEPENDENCE / PROVENANCE MODEL (documented — an integrity decision; confirm before the live run):
  * GENERATION = a DETERMINISTIC RE-MINE of the recalled content (no model, no drift, exact content preserved).
    Generator actor family is 'recalled-factory' — the honest origin — and every re-staged row carries a
    provenance link to its source recalled candidate_id. (The recalled originals' own family was 'generator-agent'
    — a BANNED placeholder — so re-mining under an honest, non-placeholder identity is required, not cosmetic.)
  * SOLUTION  = a model (OpenAI in the live routing) authors steps + distractor mis_relations, which a
    DETERMINISTIC sympy gate then proves — the model proposes, the gate certifies.
  * JUDGE     = a genuinely different family (Anthropic-via-OpenRouter, family 'anthropic') independently solves
    and disposes. cross_family holds because 'anthropic' != 'recalled-factory' (and != the solution author), so
    the judge is independent of BOTH the content origin and the solution author.

All model stages are driven by injected kie.qie.execution.ModelExecutor objects, so the whole runner is verified
end-to-end with Fake/Replay providers — NO network, NO key. Live providers slot into the SAME seam later.
"""
from __future__ import annotations

import json
import sqlite3
from typing import Dict, List, Optional

from kie.qie.factory import certify as CERT
from kie.qie.factory import corpus as CO
from kie.qie.factory import plan as PLAN
from kie.qie.factory import run_generation as RG
from kie.qie.factory import solutions as SOL

# honest generation-of-record identity for the deterministic re-mine (none of these may be a BANNED placeholder).
REMINE_MODEL = "recert-remine"
REMINE_MODEL_VERSION = "v1"
REMINE_ACTOR = "program-c-recert"
GENERATOR_FAMILY = "recalled-factory"
SOLUTION_ACTOR = "program-c-recert-solution"

RECALL_REASON = "audit-2026-07-21"   # the R0-2 status_audit reason marking the recalled cohort


# ── 1. load the recalled cohort (READ-ONLY on the source bank) ──────────────────────────────────────
def load_recalled_cohort(bank_db_path, limit: Optional[int] = None) -> List[dict]:
    """Return the recalled cohort as [{source_id, spec, item}] read-only from the source bank. The cohort is
    exactly the rows flipped certified->quarantined by R0-2 (status_audit), so it is the audited 22, never a
    guess. Only STRUCTURED_NUMERIC items (a declared structure sympy can re-derive) are returned — a qualitative
    item has no non-model re-derivation and cannot be certified by this architecture regardless of the judge."""
    conn = sqlite3.connect(f"file:{bank_db_path}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    try:
        recalled = [r["entity_id"] for r in conn.execute(
            "SELECT entity_id FROM status_audit WHERE from_status='certified' AND to_status='quarantined' "
            "AND reason=? ORDER BY entity_id", (RECALL_REASON,))]
        out = []
        for cid in recalled:
            c = conn.execute("SELECT * FROM candidate WHERE candidate_id=?", (cid,)).fetchone()
            s = conn.execute("SELECT * FROM generation_spec WHERE spec_id=?", (c["spec_id"],)).fetchone()
            if s is None or (s["lane"] or "") != "STRUCTURED_NUMERIC":
                continue
            out.append({
                "source_id": cid,
                "spec": dict(s),
                "item": {
                    "spec_id": c["spec_id"], "stem": c["stem"],
                    "options": json.loads(c["options"] or "{}"),
                    "answer_label": c["answer_label"], "answer_value": c["answer_value"],
                    "claimed": json.loads(c["claimed"] or "{}"),
                    "structure": json.loads(c["structure"] or "{}"),
                },
            })
            if limit and len(out) >= limit:
                break
        return out
    finally:
        conn.close()


# ── 2. deterministic re-mine → stage as fresh candidates (append-only) ──────────────────────────────
def _remine_provenance(cohort: List[dict]) -> dict:
    manifest = json.dumps(sorted(c["source_id"] for c in cohort))
    return {"model": REMINE_MODEL, "model_version": REMINE_MODEL_VERSION,
            "prompt_sha256": PLAN.brief_sha256(manifest), "actor": REMINE_ACTOR,
            "contract_version": PLAN.CONTRACT_VERSION, "generator_family": GENERATOR_FAMILY,
            "input_tokens": 0, "output_tokens": 0,
            "note": f"deterministic re-mine of {len(cohort)} recalled factory questions (R0-2)"}


def stage_cohort(conn: sqlite3.Connection, run_id: str, cohort: List[dict]) -> dict:
    """Save the specs (under the fresh run_id) and re-mine the cohort's content VERBATIM into fresh candidates,
    each carrying real re-mine generation provenance + a source link. Uses the tested generation ingest path, so
    the mandatory 'generation' telemetry + RI-8 provenance are written exactly as certification requires."""
    specs = []
    for c in cohort:
        s = dict(c["spec"])
        s["run_id"] = run_id
        s["created_at"] = CO._now()               # fresh re-mine timestamp (the spec is re-issued for this run)
        specs.append(s)
    CO.save_specs(conn, specs)
    items = []
    for c in cohort:
        it = dict(c["item"])
        it["raw_source_id"] = c["source_id"]          # deterministic provenance link to the recalled original
        items.append(it)
    m = RG.ingest_candidates(conn, run_id, items, _remine_provenance(cohort), batch="recert")
    return m


# ── 3. solution stage via an injected executor (the model authors; sympy proves) ────────────────────
def run_solution_stage(conn: sqlite3.Connection, run_id: str, executor) -> dict:
    """Author solutions + distractor mis_relations for the sympy-agreeing survivors via the executor, then attach
    and VERIFY them deterministically (SOL.ingest -> solution_verified + distractor_verified gates). Writes a
    'solution' telemetry row for complete provenance. Returns the SOL.ingest summary (or a no-op summary)."""
    survivors = SOL.survivors_for_solution(conn, run_id, only_certifiable=True)
    if not survivors:
        return {"in": 0, "verified": 0, "note": "no sympy-agreeing survivors to solution"}
    rows = SOL.worksheet(survivors)
    brief = SOL.SOLUTION_BRIEF + "\n".join(json.dumps(r, ensure_ascii=False) for r in rows) + \
        f"\n\nReturn ONLY the JSON array of {len(rows)} objects.\n"
    (payload, provenance) = executor.generate([brief], run_id=run_id)[0]
    m = SOL.ingest(conn, run_id, payload)
    CO.telemetry(conn, run_id, "solution", provenance.get("model", REMINE_MODEL),
                 actor=provenance.get("actor", SOLUTION_ACTOR), batches=1, items=m.get("in"),
                 input_tokens=provenance.get("input_tokens"), output_tokens=provenance.get("output_tokens"),
                 note=f"solution stage via {provenance.get('model')}")
    return m


# ── 4. the whole re-certification, providers injected ───────────────────────────────────────────────
def recertify(conn: sqlite3.Connection, run_id: str, cohort: List[dict],
              solution_executor, judge_executor) -> dict:
    """Drive the full append-only chain over `cohort` and return a disposition report. NO live calls of its own —
    it uses whatever providers the two executors wrap (Fake/Replay for verification; live later)."""
    staged = stage_cohort(conn, run_id, cohort)
    verify = RG.verify(conn, run_id)                              # deterministic gates + sympy (reads qie.db ro)
    solution = run_solution_stage(conn, run_id, solution_executor)
    judge = RG.judge_run(conn, run_id, judge_executor)            # cross-family judge + 'judge' telemetry
    certified = CERT.certify_run(conn, run_id, require_telemetry=True)
    status_counts = {r[0]: r[1] for r in conn.execute(
        "SELECT status, COUNT(*) FROM candidate WHERE run_id=? GROUP BY status", (run_id,))}
    cert_visible = conn.execute(
        "SELECT COUNT(*) FROM candidate WHERE run_id=? AND status=? AND certification_class=?",
        (run_id, CO.CERTIFIED, CO.CERT_CERTIFIED)).fetchone()[0]
    return {"run_id": run_id, "staged": staged, "verify": verify, "solution": solution,
            "judge": judge, "certify": certified, "status_counts": status_counts,
            "product_visible_certified": cert_visible}
