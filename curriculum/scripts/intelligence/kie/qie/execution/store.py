"""execution.db — the writable store for the R4-2 model-execution layer.

Routed through the R3-4 shared derived-store opener (`kie.qie.store_open`) so it inherits the standardized
pragmas (WAL, foreign_keys), the mode=ro fail-safe default, and the R0-4 path guard exactly like every other
derived estate DB. `execution.db` lives under KIE_HOME (`curriculum/knowledge/kie/execution.db`) and is therefore
gitignored like the rest of the derived estate — never committed.

SCOPE — this store holds ONLY the execution layer's own operational state (response cache, judge cache, the
resumable execution queue, per-call telemetry). It NEVER holds certified product: the factory corpus / question
bank remain the sole product-visible stores. The provenance + run_telemetry the factory certification lane
consumes are written into the FACTORY corpus by run_generation (from the bundles this layer produces), not here.

Tables (all keyed so re-runs are idempotent):
  * response_cache  — request_sha256 -> the exact LLMResponse (the cache/replay/idempotency key). A completed
                      request is never re-sent; this is what makes crash-resume free (queue.py).
  * judge_cache     — item_hash -> a judge verdict, so a re-judged identical item is not re-sent to the model.
  * exec_queue      — the resumable queue: request_sha256 -> {stage, status, attempts, payload}. A crash mid-batch
                      leaves rows in 'queued'/'in_flight'; a re-run reconciles against response_cache and only
                      re-sends what never completed.
  * exec_telemetry  — per-call {stage, model, actor, tokens, latency_ms, cost_usd, cache_hit, attempt} — the
                      cost-accounting + throughput ledger. run_telemetry (the R2-3 rows certify reads) is derived
                      from the provenance bundle by run_generation, not from this table.
"""
from __future__ import annotations

import sqlite3
from typing import Optional

from kie import config
from kie.qie import store_open as SO

EXECUTION_DB_PATH = config.KIE_HOME / "execution.db"

SCHEMA_VERSION = "execution-1"

_SCHEMA = """
CREATE TABLE IF NOT EXISTS exec_meta (
  key   TEXT PRIMARY KEY,
  value TEXT
);

-- request_sha256 -> the exact LLMResponse that request produced. THE cache/replay/idempotency key: a completed
-- request is never re-sent (queue resume + cache hit both read here).
CREATE TABLE IF NOT EXISTS response_cache (
  request_sha256 TEXT PRIMARY KEY,
  stage          TEXT,
  model          TEXT,
  response_json  TEXT NOT NULL,
  created_at     TEXT NOT NULL
);

-- item_hash -> a judge verdict. A re-judged identical item (same item_hash) reuses this instead of being sent.
CREATE TABLE IF NOT EXISTS judge_cache (
  item_hash    TEXT NOT NULL,
  family       TEXT NOT NULL DEFAULT '',   -- the judge ACTOR FAMILY that rendered this verdict (R2-1). Keyed on
                                           -- family (+ model) so a verdict is ONLY ever reused for the SAME
                                           -- family: a same-actor (non-independent) verdict can never be served
                                           -- to a cross-family request and laundered into a cross-family cert.
  model        TEXT NOT NULL DEFAULT '',
  verdict_json TEXT NOT NULL,
  provenance_json TEXT,                    -- the originating judge provenance bundle (carried for fidelity)
  created_at   TEXT NOT NULL,
  PRIMARY KEY (item_hash, family, model)
);

-- the resumable execution queue. status in ('queued','in_flight','done','failed'). A crash leaves non-'done'
-- rows; a re-run reconciles against response_cache (idempotent by request_sha256).
CREATE TABLE IF NOT EXISTS exec_queue (
  request_sha256 TEXT PRIMARY KEY,
  run_id         TEXT,
  stage          TEXT,
  status         TEXT NOT NULL,
  attempts       INTEGER DEFAULT 0,
  request_json   TEXT,
  error          TEXT,
  updated_at     TEXT NOT NULL
);

-- per-call cost / throughput ledger (cost accounting + telemetry).
CREATE TABLE IF NOT EXISTS exec_telemetry (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  request_sha256 TEXT,
  run_id         TEXT,
  stage          TEXT,
  model          TEXT,
  actor          TEXT,
  input_tokens   INTEGER,
  output_tokens  INTEGER,
  latency_ms     INTEGER,
  cost_usd       REAL,
  cache_hit      INTEGER NOT NULL DEFAULT 0,
  attempt        INTEGER,
  recorded_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_exec_telemetry_run ON exec_telemetry(run_id);
"""


def open_execution_store(path: Optional[str] = None, *, read_only: bool = False) -> sqlite3.Connection:
    """Open execution.db through the R3-4 shared opener. Writable by default (this IS the layer's write path);
    creates the schema idempotently. A read-only open (mode=ro) is available for telemetry/cost readers.

    `:memory:` is honored for tests — it skips the path guard and gives a private in-process store."""
    p = path or EXECUTION_DB_PATH
    conn = SO.open_store(p, read_only=read_only)
    if not read_only:
        conn.executescript(_SCHEMA)
        conn.execute("INSERT OR IGNORE INTO exec_meta(key, value) VALUES ('schema_version', ?)",
                     (SCHEMA_VERSION,))
        conn.commit()
    return conn
