"""Persistent caches (R4-2), both backed by execution.db.

  * ResponseCache — request_sha256 -> the exact LLMResponse. THE reason a completed request is never re-sent: a
    cache hit short-circuits the whole queue/provider path (and is recorded in telemetry as a cache_hit). It is
    also what makes crash-resume free — a resumed batch reuses every already-completed call from here.
  * JudgeCache    — item_hash -> a judge verdict. A re-judged IDENTICAL item (same item_hash) is served from
    here instead of being sent to the model again (the roadmap's item_hash-keyed judge cache). Keying on
    item_hash — the content identity the factory already computes — means a byte-identical item anywhere reuses
    its verdict.

Both are plain sqlite tables opened writable through the shared opener; a hit is a cheap primary-key lookup.
"""
from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone
from typing import Optional

from kie.qie.execution.provider import LLMResponse


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


class ResponseCache:
    """request_sha256 -> LLMResponse, persisted. `get` returns a fresh LLMResponse (cache_hit=True) or None."""

    def __init__(self, conn: sqlite3.Connection):
        self.conn = conn

    def get(self, request_sha256: str) -> Optional[LLMResponse]:
        row = self.conn.execute("SELECT response_json FROM response_cache WHERE request_sha256=?",
                                (request_sha256,)).fetchone()
        if row is None:
            return None
        resp = LLMResponse.from_dict(json.loads(row["response_json"]))
        resp.cache_hit = True
        return resp

    def put(self, request_sha256: str, resp: LLMResponse, *, stage: str = None) -> None:
        # store the response as it was PRODUCED (cache_hit=False on the stored copy — the hit flag is a read-time
        # property, not a stored one).
        stored = LLMResponse.from_dict(resp.to_dict())
        stored.cache_hit = False
        self.conn.execute(
            "INSERT OR IGNORE INTO response_cache (request_sha256, stage, model, response_json, created_at) "
            "VALUES (?,?,?,?,?)",
            (request_sha256, stage, resp.model, json.dumps(stored.to_dict(), ensure_ascii=False), _now()))
        self.conn.commit()

    def __contains__(self, request_sha256: str) -> bool:
        return self.conn.execute("SELECT 1 FROM response_cache WHERE request_sha256=?",
                                 (request_sha256,)).fetchone() is not None


class JudgeCache:
    """(item_hash, judge FAMILY, model) -> a judge verdict dict. Keyed by the judge's ACTOR FAMILY (and model),
    NOT content alone (R2-1 / adversarial-verifier fix): a verdict is only ever reused for the SAME family, so a
    same-actor (non-independent) verdict can never be served to a cross-family request and laundered into a
    cross-family certification. The originating provenance is stored for fidelity."""

    def __init__(self, conn: sqlite3.Connection):
        self.conn = conn
        # defensive migration for a pre-fix execution.db (fresh stores are born with the composite key).
        cols = {r[1] for r in conn.execute("PRAGMA table_info(judge_cache)")}
        if cols and "family" not in cols:
            conn.execute("ALTER TABLE judge_cache ADD COLUMN family TEXT NOT NULL DEFAULT ''")
            conn.execute("ALTER TABLE judge_cache ADD COLUMN provenance_json TEXT")
            conn.commit()

    def get(self, item_hash: str, family: str, model: str = None) -> Optional[dict]:
        # FAMILY-scoped: never returns a verdict from a different judge family (independence-preserving).
        if not item_hash:
            return None
        sql = "SELECT verdict_json FROM judge_cache WHERE item_hash=? AND family=?"
        args = (item_hash, family or "")
        if model is not None:
            sql += " AND model=?"
            args = args + (model or "",)
        row = self.conn.execute(sql, args).fetchone()
        return json.loads(row["verdict_json"]) if row else None

    def put(self, item_hash: str, verdict: dict, *, family: str, model: str = None,
            provenance: dict = None) -> None:
        if not item_hash:
            return
        self.conn.execute(
            "INSERT OR IGNORE INTO judge_cache (item_hash, family, model, verdict_json, provenance_json, "
            "created_at) VALUES (?,?,?,?,?,?)",
            (item_hash, family or "", model or "", json.dumps(verdict, ensure_ascii=False),
             json.dumps(provenance, ensure_ascii=False) if provenance else None, _now()))
        self.conn.commit()

    def __contains__(self, key) -> bool:
        # key = item_hash (any family) OR (item_hash, family[, model])
        if isinstance(key, tuple):
            return self.get(*key) is not None
        return bool(key) and self.conn.execute(
            "SELECT 1 FROM judge_cache WHERE item_hash=?", (key,)).fetchone() is not None
