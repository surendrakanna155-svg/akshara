"""Candidate Corpus store — open, ingest, and enforce the quarantine boundary.

The boundary is the point of this module. `candidate` and `quarantined` rows are NOT inventory: nothing here is
visible to qpgen, DPP composition, or any student/teacher surface. Promotion to `certified` is a separate,
explicit act that requires the full evidence chain, and it is never a side effect of generation.

Deliberately a SEPARATE database from qie.db, so a generator's proposal can never be mistaken for — or silently
merge into — certified evidence. A model's own prior output is not truth merely because it was stored.
"""
from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Iterable, List, Optional

from kie import config
from kie.qie.factory.gates import item_hash, norm_hash

SCHEMA_PATH = Path(__file__).resolve().parent / "corpus_schema.sql"
SCHEMA_VERSION = "factory-1"
CORPUS_DB_PATH = config.KIE_HOME / "factory_corpus.db"

# The lifecycle. Only CERTIFIED may ever be promoted to product inventory.
CANDIDATE, QUARANTINED, REJECTED, CERTIFIED = "candidate", "quarantined", "rejected", "certified"
PRODUCT_VISIBLE = (CERTIFIED,)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def open_store(db_path=None) -> sqlite3.Connection:
    path = db_path or CORPUS_DB_PATH
    if str(path) != ":memory:":
        Path(path).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    if str(path) != ":memory:":
        conn.execute("PRAGMA journal_mode = WAL")
    conn.executescript(SCHEMA_PATH.read_text())
    conn.execute("INSERT INTO factory_meta(key, value) VALUES ('schema_version', ?) "
                 "ON CONFLICT(key) DO UPDATE SET value = excluded.value", (SCHEMA_VERSION,))
    conn.commit()
    return conn


def save_specs(conn: sqlite3.Connection, specs: List[dict]) -> int:
    cols = ("spec_id", "run_id", "lane", "board", "exam_profile", "class_level", "subject", "concept_code",
            "concept_title", "concept_codes_all", "composition", "archetype", "question_type",
            "intended_depth", "intended_difficulty", "visual_required", "boundary", "planner_evidence",
            "created_at")
    rows = [tuple(s.get(c) for c in cols) for s in specs]
    conn.executemany(f"INSERT OR REPLACE INTO generation_spec ({','.join(cols)}) "
                     f"VALUES ({','.join('?' * len(cols))})", rows)
    conn.commit()
    return len(rows)


def _cid(run_id: str, spec_id: str) -> str:
    return f"CAND_{run_id[-6:]}_{spec_id[-12:]}"


def ingest(conn: sqlite3.Connection, run_id: str, raw_items: Iterable[dict], generator_model: str,
           batch: str) -> dict:
    """Ingest raw generator output. Records EVERYTHING — including refusals and malformed payloads — because
    the trial must measure the generator's real behaviour, not a cleaned-up version of it."""
    m = {"ingested": 0, "refused": 0, "malformed": 0, "unknown_spec": 0}
    known = {r["spec_id"] for r in conn.execute("SELECT spec_id FROM generation_spec WHERE run_id=?", (run_id,))}
    for it in raw_items:
        if not isinstance(it, dict) or not it.get("spec_id"):
            m["malformed"] += 1
            continue
        sid = it["spec_id"]
        if sid not in known:
            m["unknown_spec"] += 1
            continue
        cid = _cid(run_id, sid)
        if it.get("refuse"):
            conn.execute(
                "INSERT OR REPLACE INTO candidate (candidate_id, run_id, spec_id, generator_model, "
                "generator_batch, stem, options, answer_label, status, reject_reason, raw, created_at) "
                "VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
                (cid, run_id, sid, generator_model, batch, "", "{}", None, REJECTED,
                 f"generator_refused: {it.get('reason', '')}"[:400], json.dumps(it), _now()))
            m["refused"] += 1
            continue
        stem = (it.get("stem") or "").strip()
        options = it.get("options") or {}
        ans = it.get("answer_label")
        conn.execute(
            "INSERT OR REPLACE INTO candidate (candidate_id, run_id, spec_id, generator_model, "
            "generator_batch, stem, options, answer_label, answer_value, claimed, structure, solution, "
            "distractor_rationale, visual_spec, raw, status, item_hash, stem_norm_hash, created_at) "
            "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (cid, run_id, sid, generator_model, batch, stem, json.dumps(options), ans,
             str(it.get("answer_value") or ""), json.dumps(it.get("claimed") or {}),
             json.dumps(it.get("structure") or {}), json.dumps(it.get("solution") or {}),
             json.dumps(it.get("distractor_rationale") or {}),
             json.dumps(it.get("visual_spec")) if it.get("visual_spec") else None,
             json.dumps(it), CANDIDATE, item_hash(stem, options, str(ans)), norm_hash(stem), _now()))
        m["ingested"] += 1
    conn.commit()
    return m


def record_gates(conn: sqlite3.Connection, candidate_id: str, results: List[dict]) -> None:
    conn.executemany(
        "INSERT OR REPLACE INTO gate_result (candidate_id, gate, ok, severity, detail, checked_at) "
        "VALUES (?,?,?,?,?,?)",
        [(candidate_id, g["gate"], int(g["ok"]), g["severity"], g["detail"], _now()) for g in results])


def set_status(conn: sqlite3.Connection, candidate_id: str, status: str, reason: str = "") -> None:
    conn.execute("UPDATE candidate SET status=?, reject_reason=? WHERE candidate_id=?",
                 (status, reason[:400], candidate_id))


def record_independent(conn: sqlite3.Connection, candidate_id: str, method: str, solver_answer,
                       generator_answer, verdict: str, detail: str) -> None:
    conn.execute(
        "INSERT OR REPLACE INTO independent_answer (candidate_id, method, solver_answer, generator_answer, "
        "verdict, detail, checked_at) VALUES (?,?,?,?,?,?,?)",
        (candidate_id, method, str(solver_answer), str(generator_answer), verdict, detail[:500], _now()))


def record_judge(conn: sqlite3.Connection, candidate_id: str, judge_model: str, independent: bool,
                 v: dict) -> None:
    conn.execute(
        "INSERT OR REPLACE INTO judge_verdict (candidate_id, judge_model, independent, verdict, well_posed, "
        "curriculum_ok, answer_correct, unique_answer, concepts_real, composition_real, "
        "difficulty_plausible, distractors_plausible, visual_judgement, reasons, checked_at) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (candidate_id, judge_model, int(independent), v.get("verdict", "quarantine"),
         _b(v.get("well_posed")), _b(v.get("curriculum_ok")), _b(v.get("answer_correct")),
         _b(v.get("unique_answer")), _b(v.get("concepts_real")), _b(v.get("composition_real")),
         _b(v.get("difficulty_plausible")), _b(v.get("distractors_plausible")),
         v.get("visual_judgement"), json.dumps(v.get("reasons") or v.get("reason") or ""), _now()))


def _b(x) -> Optional[int]:
    return None if x is None else int(bool(x))


def telemetry(conn: sqlite3.Connection, run_id: str, stage: str, model: str, **kw) -> None:
    conn.execute(
        "INSERT OR REPLACE INTO run_telemetry (run_id, stage, model, batches, items, input_tokens, "
        "output_tokens, wall_seconds, note, recorded_at) VALUES (?,?,?,?,?,?,?,?,?,?)",
        (run_id, stage, model, kw.get("batches"), kw.get("items"), kw.get("input_tokens"),
         kw.get("output_tokens"), kw.get("wall_seconds"), kw.get("note"), _now()))
    conn.commit()


def product_inventory(conn: sqlite3.Connection, run_id: str) -> List[sqlite3.Row]:
    """The ONLY function any product surface may ever call. Certified rows exclusively — the quarantine
    boundary expressed as code rather than as a convention someone has to remember."""
    return conn.execute(
        f"SELECT * FROM candidate WHERE run_id=? AND status IN ({','.join('?' * len(PRODUCT_VISIBLE))})",
        (run_id, *PRODUCT_VISIBLE)).fetchall()
