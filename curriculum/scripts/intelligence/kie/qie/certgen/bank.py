"""Write-back — the certified question bank.

WHY. The repository inventory audit found `grep -rn "INSERT|UPDATE|commit()" certgen/` returned nothing:
generated items lived only in memory. The consequences were structural, not cosmetic — no cross-session
deduplication (so `duplicate_exact` could only see the current run), no reuse, no accumulation, and no
record of what the engine had ever produced or why anything was refused.

DESIGN DECISIONS AND THEIR REASONS

  A SEPARATE STORE, not a table in `qie.db`. `qie.db` is a derived-knowledge store with its own lifecycle
  that other lanes read. Keeping the bank in its own file makes rollback trivial (delete it) and means a
  write here can never disturb a reader there.

  APPEND-ONLY. Matches the `gate_result` and `governed_fact` conventions. A certified row is never
  overwritten; a changed pipeline SUPERSEDES it and both remain readable.

  CONTENT-ADDRESSED IDS. `sha256(binding ∥ concept ∥ stem ∥ key)` — so re-running an unchanged pipeline is
  a NO-OP rather than a duplicate. The bank is idempotent, which is what makes it safe to run repeatedly.

  PIPELINE FINGERPRINT ON EVERY ROW. `{engine, index_fingerprint, binding_id}`. When the certified index is
  re-versioned, every affected item is identifiable for re-validation instead of silently ageing.

  QUARANTINE IS PERSISTED, NOT DISCARDED. The six currency-dimensional failures earlier in this programme
  were visible only because someone was watching the console. Persisting refusals turns gate failures into
  a queryable defect log.

  DEDUP IS CROSS-RUN. Both the exact `item_hash` and the numeral-masked `stem_norm_hash` are stored, so a
  later run that produces the same question — or the same question with different numbers — is detected
  against the WHOLE bank rather than just its own batch.

Deterministic. Writes only to its own store; every other store is untouched.
"""
from __future__ import annotations

import hashlib
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

from kie import config
from kie.qie.factory import gates as G

BANK_PATH = config.KIE_HOME / "certgen_bank.db"
ENGINE_VERSION = "certgen-1"

SCHEMA = """
CREATE TABLE IF NOT EXISTS bank_item (
  item_id           TEXT PRIMARY KEY,   -- content-addressed: sha256(binding|concept|stem|key)[:20]
  gen_id            TEXT NOT NULL,
  binding_id        TEXT NOT NULL,
  lane              TEXT,
  answer_format     TEXT NOT NULL,
  archetype         TEXT,
  concept_id        TEXT NOT NULL,      -- KC_ id (Lane C is KC-native: 100% resolution)
  concept_ids       TEXT NOT NULL,      -- json list
  class_level       INTEGER NOT NULL,
  subject           TEXT,
  discipline        TEXT,
  stem              TEXT NOT NULL,
  options           TEXT NOT NULL,      -- json (empty object for integer entry)
  answer_label      TEXT,
  answer_labels     TEXT,               -- json list for multi-correct
  answer_value      TEXT,
  answer_tolerance  REAL,
  answer_unit       TEXT,
  solution          TEXT NOT NULL,      -- json {steps, final}
  distractor_rationale TEXT NOT NULL,   -- json
  reasoning         TEXT,
  reasoning_depth   INTEGER,
  difficulty_band   TEXT,
  difficulty_score  REAL,
  provenance        TEXT NOT NULL,      -- json
  item_hash         TEXT NOT NULL,      -- exact-content dedup key
  stem_norm_hash    TEXT NOT NULL,      -- numeral-masked near-dup key
  status            TEXT NOT NULL,      -- certified | quarantined | rejected
  status_reason     TEXT,
  engine_version    TEXT NOT NULL,
  index_fingerprint TEXT NOT NULL,      -- certified-index identity at generation time
  superseded_by     TEXT,               -- append-only: a revision points here, never overwrites
  created_at        TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_bank_concept ON bank_item(concept_id);
CREATE INDEX IF NOT EXISTS idx_bank_norm    ON bank_item(stem_norm_hash);
CREATE INDEX IF NOT EXISTS idx_bank_status  ON bank_item(status);
CREATE INDEX IF NOT EXISTS idx_bank_cell    ON bank_item(class_level, discipline);

CREATE TABLE IF NOT EXISTS bank_gate (
  item_id   TEXT NOT NULL,
  gate      TEXT NOT NULL,
  ok        INTEGER NOT NULL,
  severity  TEXT NOT NULL,
  detail    TEXT,
  PRIMARY KEY (item_id, gate)
);

CREATE TABLE IF NOT EXISTS bank_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
"""


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def open_bank(path=None) -> sqlite3.Connection:
    p = Path(path or BANK_PATH)
    p.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(p))
    conn.row_factory = sqlite3.Row
    conn.executescript(SCHEMA)
    conn.execute("INSERT INTO bank_meta(key,value) VALUES('engine_version',?) "
                 "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (ENGINE_VERSION,))
    conn.commit()
    return conn


def index_fingerprint(iconn: sqlite3.Connection) -> str:
    """Identity of the certified index a batch was generated against.

    Counts certified concepts and accepted chapters. If either changes, previously banked items are
    identifiable as having been produced against a different curriculum snapshot.
    """
    c = iconn.execute("SELECT COUNT(*) FROM ki_concept WHERE status='certified'").fetchone()[0]
    ch = iconn.execute("SELECT COUNT(*) FROM ki_chapter WHERE status='accepted'").fetchone()[0]
    return hashlib.sha256(f"ki:{c}:{ch}".encode()).hexdigest()[:16]


def content_id(item: dict) -> str:
    key = "|".join([
        str(item.get("binding_id", "")), str(item.get("concept_id", "")),
        str(item.get("stem", "")),
        str(item.get("answer_value", "")), str(sorted(item.get("answer_labels") or [])),
    ])
    return hashlib.sha256(key.encode()).hexdigest()[:20]


def _item_hash(item: dict) -> str:
    payload = json.dumps({"stem": item.get("stem"), "options": item.get("options"),
                          "answer_value": item.get("answer_value"),
                          "answer_labels": sorted(item.get("answer_labels") or [])},
                         sort_keys=True, ensure_ascii=False)
    return "IH_" + hashlib.sha256(payload.encode()).hexdigest()[:20]


def bank_batch(items: Sequence[dict], iconn: sqlite3.Connection,
               conn: Optional[sqlite3.Connection] = None) -> Dict[str, int]:
    """Persist a gated batch. Idempotent: re-banking an unchanged batch changes nothing.

    Every item is written — certified AND refused — because a discarded refusal is a defect nobody can
    query later. Cross-run duplicates are recorded as `duplicate` rather than inserted twice.
    """
    own = conn is None
    conn = conn or open_bank()
    fp = index_fingerprint(iconn)
    m = {"certified": 0, "quarantined": 0, "duplicate": 0, "already_present": 0, "gates_written": 0}
    try:
        for it in items:
            iid = content_id(it)
            if conn.execute("SELECT 1 FROM bank_item WHERE item_id=?", (iid,)).fetchone():
                m["already_present"] += 1
                continue

            norm = G.norm_hash(it.get("stem", ""))
            ihash = _item_hash(it)
            passed = bool(it.get("passed"))
            status = "certified" if passed else "quarantined"
            reason = "" if passed else ("FATAL: " + ", ".join(it.get("fatal") or [])
                                        if it.get("fatal") else
                                        "QUARANTINE: " + ", ".join(it.get("quarantine") or []))

            # CROSS-RUN dedup: a certified row with this normalised stem already exists in the bank
            dup = conn.execute(
                "SELECT item_id FROM bank_item WHERE stem_norm_hash=? AND status='certified' LIMIT 1",
                (norm,)).fetchone()
            if dup and passed:
                status, reason = "duplicate", f"duplicate_of_certified: {dup[0]}"
                m["duplicate"] += 1
            elif passed:
                m["certified"] += 1
            else:
                m["quarantined"] += 1

            conn.execute(
                "INSERT INTO bank_item(item_id,gen_id,binding_id,lane,answer_format,archetype,concept_id,"
                "concept_ids,class_level,subject,discipline,stem,options,answer_label,answer_labels,"
                "answer_value,answer_tolerance,answer_unit,solution,distractor_rationale,reasoning,"
                "reasoning_depth,difficulty_band,difficulty_score,provenance,item_hash,stem_norm_hash,"
                "status,status_reason,engine_version,index_fingerprint,superseded_by,created_at) "
                "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (iid, it.get("gen_id"), it.get("binding_id"), it.get("lane"),
                 it.get("answer_format") or G.SINGLE_CORRECT, it.get("archetype"),
                 it.get("concept_id"), json.dumps(it.get("claimed", {}).get("concept_ids", [])),
                 it.get("class_level"), it.get("subject"), it.get("discipline"), it.get("stem"),
                 json.dumps(it.get("options") or {}, ensure_ascii=False), it.get("answer_label"),
                 json.dumps(it.get("answer_labels")) if it.get("answer_labels") else None,
                 str(it.get("answer_value")) if it.get("answer_value") is not None else None,
                 it.get("answer_tolerance"), it.get("answer_unit"),
                 json.dumps(it.get("solution") or {}, ensure_ascii=False),
                 json.dumps(it.get("distractor_rationale") or {}, ensure_ascii=False),
                 it.get("reasoning"), it.get("reasoning_depth"),
                 (it.get("difficulty") or {}).get("band"), (it.get("difficulty") or {}).get("score"),
                 json.dumps(it.get("provenance") or {}, ensure_ascii=False, default=str),
                 ihash, norm, status, reason, ENGINE_VERSION, fp, None, _now()))

            for g in (it.get("gates") or []):
                conn.execute("INSERT OR IGNORE INTO bank_gate(item_id,gate,ok,severity,detail) "
                             "VALUES (?,?,?,?,?)",
                             (iid, g.get("gate"), 1 if g.get("ok") else 0, g.get("severity"),
                              str(g.get("detail"))[:400]))
                m["gates_written"] += 1
        conn.commit()
    finally:
        if own:
            conn.close()
    return m


def stats(conn: Optional[sqlite3.Connection] = None) -> Dict[str, object]:
    own = conn is None
    conn = conn or open_bank()
    try:
        by_status = {r[0]: r[1] for r in conn.execute(
            "SELECT status, COUNT(*) FROM bank_item GROUP BY status")}
        return {
            "total": conn.execute("SELECT COUNT(*) FROM bank_item").fetchone()[0],
            "by_status": by_status,
            "by_format": {r[0]: r[1] for r in conn.execute(
                "SELECT answer_format, COUNT(*) FROM bank_item WHERE status='certified' GROUP BY 1")},
            "by_discipline": {r[0]: r[1] for r in conn.execute(
                "SELECT discipline, COUNT(*) FROM bank_item WHERE status='certified' GROUP BY 1")},
            "by_difficulty": {r[0]: r[1] for r in conn.execute(
                "SELECT difficulty_band, COUNT(*) FROM bank_item WHERE status='certified' GROUP BY 1")},
            "distinct_concepts": conn.execute(
                "SELECT COUNT(DISTINCT concept_id) FROM bank_item WHERE status='certified'").fetchone()[0],
            "gate_rows": conn.execute("SELECT COUNT(*) FROM bank_gate").fetchone()[0],
        }
    finally:
        if own:
            conn.close()


def certified_items(conn: Optional[sqlite3.Connection] = None,
                    class_level: Optional[int] = None,
                    discipline: Optional[str] = None) -> List[dict]:
    """The product-visible bank — certified rows only. Duplicates and refusals are never served."""
    own = conn is None
    conn = conn or open_bank()
    try:
        q = "SELECT * FROM bank_item WHERE status='certified' AND superseded_by IS NULL"
        args: List = []
        if class_level is not None:
            q += " AND class_level=?"
            args.append(class_level)
        if discipline:
            q += " AND discipline=?"
            args.append(discipline)
        return [dict(r) for r in conn.execute(q + " ORDER BY item_id", args)]
    finally:
        if own:
            conn.close()
