"""Candidate Corpus store — open, ingest, and enforce the quarantine boundary.

The boundary is the point of this module. `candidate` and `quarantined` rows are NOT inventory: nothing here is
visible to qpgen, DPP composition, or any student/teacher surface. Promotion to `certified` is a separate,
explicit act that requires the full evidence chain, and it is never a side effect of generation.

Deliberately a SEPARATE database from qie.db, so a generator's proposal can never be mistaken for — or silently
merge into — certified evidence. A model's own prior output is not truth merely because it was stored.
"""
from __future__ import annotations

import hashlib
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Iterable, List, Optional

from kie import config
from kie.qie.factory.gates import item_hash, norm_hash

SCHEMA_PATH = Path(__file__).resolve().parent / "corpus_schema.sql"
SCHEMA_VERSION = "factory-2"          # R1-2: append-only, content-bound certification records
CORPUS_DB_PATH = config.KIE_HOME / "factory_corpus.db"

# The lifecycle. Only CERTIFIED may ever be promoted to product inventory.
CANDIDATE, QUARANTINED, REJECTED, CERTIFIED = "candidate", "quarantined", "rejected", "certified"
PRODUCT_VISIBLE = (CERTIFIED,)


class CorpusIntegrityError(Exception):
    """A write would have violated the append-only / immutability contract (R1-2, [C1]).

    Raised, never swallowed: re-ingesting over a certified row, a duplicate (run_id, spec_id), or a guarded
    status transition that matched zero rows are all integrity breaches. The factory fails CLOSED rather than
    silently overwriting certified evidence or promoting on stale evidence.
    """


def _now() -> str:
    # Millisecond resolution (R1-2): evidence recorded in the same wall-clock second as candidate creation must
    # still satisfy the `checked_at >= created_at` certification precondition on fast runs and in tests.
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


def open_store(db_path=None) -> sqlite3.Connection:
    path = db_path or CORPUS_DB_PATH
    if str(path) != ":memory:":
        Path(path).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path))
    conn.row_factory = sqlite3.Row
    if str(path) != ":memory:":
        conn.execute("PRAGMA journal_mode = WAL")
    # Upgrade an existing factory-1 store to the append-only shape BEFORE the schema script runs: the _latest
    # views reference the new id/item_hash columns, so the evidence tables must already be new-shape when the
    # view DDL validates. On a fresh DB this is a no-op (no tables yet) and the schema creates everything.
    migrate_appendonly(conn)
    conn.executescript(SCHEMA_PATH.read_text())
    conn.execute("PRAGMA foreign_keys = ON")
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
    # Collision-free deterministic identity (R1-2). The old truncated form (run_id[-6:]+spec_id[-12:]) collided
    # whenever two run ids shared their last 6 chars ('prod_jm_math'/'gen_jm_math'), letting a second run's
    # ingest silently overwrite the first. A full sha256 of run|spec cannot collide across runs. Kept a pure
    # deterministic function of its inputs so callers/tests can reproduce a candidate_id without a DB read.
    return "CAND_" + hashlib.sha256(f"{run_id}|{spec_id}".encode()).hexdigest()[:16]


def _guard_ingest(conn: sqlite3.Connection, run_id: str, sid: str) -> None:
    """Immutability + no-overwrite guard (R1-2). A certified row is immutable; any (run_id, spec_id) already
    ingested must not be re-written. Re-ingesting new content belongs in a FRESH run, never over an existing
    candidate — that is the replay bypass the audit proved."""
    prior = conn.execute("SELECT candidate_id, status FROM candidate WHERE run_id=? AND spec_id=?",
                         (run_id, sid)).fetchone()
    if prior is None:
        return
    if prior["status"] == CERTIFIED:
        raise CorpusIntegrityError(
            f"refuse ingest: certified {prior['candidate_id']} is immutable; ingest into a fresh run")
    raise CorpusIntegrityError(
        f"refuse ingest: {prior['candidate_id']} already ingested for ({run_id},{sid}); "
        f"re-ingest into a fresh run")


def ingest(conn: sqlite3.Connection, run_id: str, raw_items: Iterable[dict], generator_model: str,
           batch: str) -> dict:
    """Ingest raw generator output. Records EVERYTHING — including refusals and malformed payloads — because
    the trial must measure the generator's real behaviour, not a cleaned-up version of it.

    Fails CLOSED (R1-2): a plain INSERT, guarded by _guard_ingest, so re-ingesting different content over an
    existing candidate (certified or otherwise) raises CorpusIntegrityError instead of silently overwriting.
    """
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
        _guard_ingest(conn, run_id, sid)
        if it.get("refuse"):
            conn.execute(
                "INSERT INTO candidate (candidate_id, run_id, spec_id, generator_model, "
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
            "INSERT INTO candidate (candidate_id, run_id, spec_id, generator_model, "
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


def _current_item_hash(conn: sqlite3.Connection, candidate_id: str) -> str:
    """The candidate's CURRENT item_hash — stamped onto every evidence row so certification can bind evidence
    to the exact content it was computed against (R1-2). Evidence whose item_hash != the candidate's current
    item_hash (the replay case) can never certify."""
    r = conn.execute("SELECT item_hash FROM candidate WHERE candidate_id=?", (candidate_id,)).fetchone()
    if r is None:
        raise CorpusIntegrityError(f"no candidate {candidate_id} to bind evidence to")
    return r["item_hash"] or ""


def record_gates(conn: sqlite3.Connection, candidate_id: str, results: List[dict]) -> None:
    ih = _current_item_hash(conn, candidate_id)
    ts = _now()
    conn.executemany(
        "INSERT INTO gate_result (candidate_id, item_hash, gate, ok, severity, detail, checked_at) "
        "VALUES (?,?,?,?,?,?,?)",
        [(candidate_id, ih, g["gate"], int(g["ok"]), g["severity"], g["detail"], ts) for g in results])


def set_status(conn: sqlite3.Connection, candidate_id: str, status: str, reason: str = "",
               expected: str = CANDIDATE) -> None:
    """Guarded lifecycle transition (R1-2 — the project's documented money-integrity race pattern). The UPDATE
    is conditioned on the row still being in `expected` state and MUST touch exactly one row; a certified or
    already-moved row therefore throws instead of being silently flipped. Every current caller transitions
    from `candidate`, so the default `expected=CANDIDATE` needs no call-site changes."""
    cur = conn.execute("UPDATE candidate SET status=?, reject_reason=? WHERE candidate_id=? AND status=?",
                       (status, reason[:400], candidate_id, expected))
    if cur.rowcount != 1:
        raise CorpusIntegrityError(
            f"set_status blocked: {candidate_id} not in expected state {expected!r} "
            f"(rowcount={cur.rowcount}) — refusing to overwrite a moved/certified row")


def record_independent(conn: sqlite3.Connection, candidate_id: str, method: str, solver_answer,
                       generator_answer, verdict: str, detail: str) -> None:
    ih = _current_item_hash(conn, candidate_id)
    conn.execute(
        "INSERT INTO independent_answer (candidate_id, item_hash, method, solver_answer, generator_answer, "
        "verdict, detail, checked_at) VALUES (?,?,?,?,?,?,?,?)",
        (candidate_id, ih, method, str(solver_answer), str(generator_answer), verdict, detail[:500], _now()))


def record_judge(conn: sqlite3.Connection, candidate_id: str, judge_model: str, independent: bool,
                 v: dict) -> None:
    ih = _current_item_hash(conn, candidate_id)
    conn.execute(
        "INSERT INTO judge_verdict (candidate_id, item_hash, judge_model, independent, verdict, well_posed, "
        "curriculum_ok, answer_correct, unique_answer, concepts_real, composition_real, "
        "difficulty_plausible, distractors_plausible, visual_judgement, reasons, checked_at) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (candidate_id, ih, judge_model, int(independent), v.get("verdict", "quarantine"),
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


# ── in-place schema migration: factory-1 → factory-2 (append-only, content-bound) ────────────────────
# Idempotent. Called by open_store on every open, and runnable standalone against an EXISTING factory DB via
# kie.qie.remediation.migrate_factory_appendonly. Adds candidate.relation_waiver, rebuilds the three evidence
# tables into append-only shape (id AUTOINCREMENT + item_hash), and backfills item_hash from each candidate's
# CURRENT item_hash — correct because, pre-migration, each candidate has had exactly one attempt, so its
# current item_hash IS the content the stored evidence was computed against. Never re-promotes or re-quarantines;
# candidate_id is left untouched so all evidence linkage stays intact.
def _table_exists(conn: sqlite3.Connection, name: str) -> bool:
    return conn.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,)).fetchone() is not None


def _has_col(conn: sqlite3.Connection, table: str, col: str) -> bool:
    return any(r["name"] == col for r in conn.execute(f"PRAGMA table_info({table})"))


_APPENDONLY_REBUILD = {
    "gate_result": (
        """CREATE TABLE gate_result_new (
             id INTEGER PRIMARY KEY AUTOINCREMENT,
             candidate_id TEXT NOT NULL REFERENCES candidate(candidate_id),
             item_hash TEXT NOT NULL, gate TEXT NOT NULL, ok INTEGER NOT NULL,
             severity TEXT NOT NULL, detail TEXT, checked_at TEXT NOT NULL)""",
        """INSERT INTO gate_result_new (candidate_id, item_hash, gate, ok, severity, detail, checked_at)
             SELECT g.candidate_id,
                    COALESCE((SELECT c.item_hash FROM candidate c WHERE c.candidate_id=g.candidate_id), ''),
                    g.gate, g.ok, g.severity, g.detail, g.checked_at
             FROM gate_result g""",
    ),
    "independent_answer": (
        """CREATE TABLE independent_answer_new (
             id INTEGER PRIMARY KEY AUTOINCREMENT,
             candidate_id TEXT NOT NULL REFERENCES candidate(candidate_id),
             item_hash TEXT NOT NULL, method TEXT NOT NULL, solver_answer TEXT,
             generator_answer TEXT, verdict TEXT NOT NULL, detail TEXT, checked_at TEXT NOT NULL)""",
        """INSERT INTO independent_answer_new
             (candidate_id, item_hash, method, solver_answer, generator_answer, verdict, detail, checked_at)
             SELECT i.candidate_id,
                    COALESCE((SELECT c.item_hash FROM candidate c WHERE c.candidate_id=i.candidate_id), ''),
                    i.method, i.solver_answer, i.generator_answer, i.verdict, i.detail, i.checked_at
             FROM independent_answer i""",
    ),
    "judge_verdict": (
        """CREATE TABLE judge_verdict_new (
             id INTEGER PRIMARY KEY AUTOINCREMENT,
             candidate_id TEXT NOT NULL REFERENCES candidate(candidate_id),
             item_hash TEXT NOT NULL, judge_model TEXT NOT NULL, independent INTEGER NOT NULL,
             verdict TEXT NOT NULL, well_posed INTEGER, curriculum_ok INTEGER, answer_correct INTEGER,
             unique_answer INTEGER, concepts_real INTEGER, composition_real INTEGER,
             difficulty_plausible INTEGER, distractors_plausible INTEGER, visual_judgement TEXT,
             reasons TEXT, checked_at TEXT NOT NULL)""",
        """INSERT INTO judge_verdict_new
             (candidate_id, item_hash, judge_model, independent, verdict, well_posed, curriculum_ok,
              answer_correct, unique_answer, concepts_real, composition_real, difficulty_plausible,
              distractors_plausible, visual_judgement, reasons, checked_at)
             SELECT j.candidate_id,
                    COALESCE((SELECT c.item_hash FROM candidate c WHERE c.candidate_id=j.candidate_id), ''),
                    j.judge_model, j.independent, j.verdict, j.well_posed, j.curriculum_ok, j.answer_correct,
                    j.unique_answer, j.concepts_real, j.composition_real, j.difficulty_plausible,
                    j.distractors_plausible, j.visual_judgement, j.reasons, j.checked_at
             FROM judge_verdict j""",
    ),
}


def _rebuild_appendonly(conn: sqlite3.Connection, table: str) -> None:
    create_sql, copy_sql = _APPENDONLY_REBUILD[table]
    conn.execute(f"DROP TABLE IF EXISTS {table}_new")
    conn.execute(create_sql)
    conn.execute(copy_sql)
    conn.execute(f"DROP TABLE {table}")
    conn.execute(f"ALTER TABLE {table}_new RENAME TO {table}")


def migrate_appendonly(conn: sqlite3.Connection) -> bool:
    """Idempotent factory-1 → factory-2 in-place upgrade. Returns True if anything changed. No-op on a fresh DB
    (tables not yet created) and on an already-migrated DB."""
    changed = False

    if _table_exists(conn, "candidate"):
        if not _has_col(conn, "candidate", "relation_waiver"):
            conn.execute("ALTER TABLE candidate ADD COLUMN relation_waiver TEXT")
            conn.commit()
            changed = True
        # Fail CLOSED before the schema tries to add UNIQUE(run_id, spec_id): a clear diagnostic beats a raw
        # integrity error from executescript.
        dupes = conn.execute(
            "SELECT run_id, spec_id, COUNT(*) c FROM candidate GROUP BY run_id, spec_id HAVING c>1"
        ).fetchall()
        if dupes:
            raise CorpusIntegrityError(
                f"cannot enforce UNIQUE(run_id, spec_id): {len(dupes)} duplicate pair(s) already present; "
                f"resolve before migrating (e.g. {tuple(dupes[0])[:2]})")

    needs = [t for t in ("gate_result", "independent_answer", "judge_verdict")
             if _table_exists(conn, t) and not _has_col(conn, t, "item_hash")]
    if needs:
        prior_fk = conn.execute("PRAGMA foreign_keys").fetchone()[0]
        conn.commit()
        conn.execute("PRAGMA foreign_keys=OFF")
        try:
            for t in needs:
                _rebuild_appendonly(conn, t)
            conn.commit()
            changed = True
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.execute(f"PRAGMA foreign_keys={'ON' if prior_fk else 'OFF'}")
    return changed


def _status_counts(conn: sqlite3.Connection) -> Dict[str, int]:
    if not _table_exists(conn, "candidate"):
        return {}
    return {str(r[0]): r[1] for r in conn.execute("SELECT status, COUNT(*) FROM candidate GROUP BY status")}


def migrate_db(db_path) -> dict:
    """Standalone, idempotent in-place migration of an EXISTING factory DB to the append-only shape (R1-2).

    Asserts the certified count is UNCHANGED (no re-promotion, no re-quarantine) and returns a summary. Safe to
    run repeatedly. Path must live under KIE_HOME. This never runs the certify_run promotion — it only reshapes
    storage and backfills item_hash — so the 22 live certified rows are neither flipped nor re-promoted here.
    """
    if str(db_path) != ":memory:":
        config.assert_under_kie_home(db_path)
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    try:
        before = _status_counts(conn)
        changed = migrate_appendonly(conn)
        conn.executescript(SCHEMA_PATH.read_text())           # create views/indexes; bump nothing it already has
        conn.execute("PRAGMA foreign_keys = ON")
        conn.execute("INSERT INTO factory_meta(key, value) VALUES ('schema_version', ?) "
                     "ON CONFLICT(key) DO UPDATE SET value = excluded.value", (SCHEMA_VERSION,))
        conn.commit()
        after = _status_counts(conn)
        if before.get(CERTIFIED, 0) != after.get(CERTIFIED, 0):
            raise CorpusIntegrityError(
                f"migration altered certified count {before.get(CERTIFIED, 0)} -> {after.get(CERTIFIED, 0)} "
                f"— aborting (a migration must never promote or demote)")
        return {"changed": changed, "schema_version": SCHEMA_VERSION, "before": before, "after": after}
    finally:
        conn.close()
