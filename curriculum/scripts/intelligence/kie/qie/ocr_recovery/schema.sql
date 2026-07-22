-- OCR Recovery Lane — DERIVED store `ocr_recovery.db`.
-- Built ON TOP of the FROZEN kie.db (opened mode=ro): the frozen substrate is NEVER written. Local-only
-- (gitignored under knowledge/), deterministic-rebuildable, idempotent-upsert audit (a re-run with identical settings is a no-op). This store holds the FULL
-- before/after evidence (original_text + recovered_text + both scores + settings + verdict) so that a
-- FUTURE, version-bumped, independently-gated rebuild of kie.db could consume the verified-improvement
-- manifest. NOTHING here is ever applied to kie.db by this lane.

-- ── candidate set — one row per low-quality document detected against the frozen kie.db ──────────────────
CREATE TABLE IF NOT EXISTS recovery_candidate (
  doc_id         TEXT PRIMARY KEY,
  corpus         TEXT NOT NULL,
  rel_path       TEXT NOT NULL,
  sha256         TEXT NOT NULL,          -- frozen source_documents.sha256 (grounds the local PDF, verified before OCR)
  pages          INTEGER,
  parser_class   TEXT,                   -- scanned_image | sparse_text | … (why it is a candidate, part 1)
  trigger        TEXT NOT NULL,          -- parser_class | low_score | parser_class+low_score (why it is a candidate, part 2)
  current_score  REAL,                   -- deterministic quality.score() of the concatenated frozen chunk text (0..1)
  worst_pages    TEXT,                   -- json: [{"page":n,"score":x}, …] lowest-scoring pages (re-OCR targets)
  n_chunks       INTEGER,
  detected_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_rc_score   ON recovery_candidate(current_score);
CREATE INDEX IF NOT EXISTS idx_rc_trigger ON recovery_candidate(trigger);

-- ── per-page recovery result — the before/after audit (idempotent upsert on the settings key) ─────────────
-- One row per (doc_id, page, engine_settings_hash). PRESERVES BOTH texts + BOTH scores + the exact settings
-- + the verdict, so every decision is independently re-checkable. A re-run with identical settings is
-- idempotent (content-addressed result_id + ON CONFLICT upsert) — deterministic, never a phantom row.
CREATE TABLE IF NOT EXISTS recovery_result (
  result_id            TEXT PRIMARY KEY,          -- sha256(doc_id|page|engine_settings_hash|orig_sha|recov_sha)[:16]
  doc_id               TEXT NOT NULL,
  page                 INTEGER NOT NULL,          -- 1-based page number (source_documents/chunks convention)
  engine_settings_hash TEXT NOT NULL,             -- deterministic id of the IMPROVED settings used
  ground_settings_hash TEXT,                      -- settings of the independent grounding pass (no-fabrication anchor)
  original_text        TEXT,                      -- frozen kie.db page text (may be NULL if the page had no chunks)
  recovered_text       TEXT,                      -- improved re-OCR (NULL = honest-null: render/OCR failed, never fabricated)
  original_score       REAL,
  recovered_score      REAL,
  improved             INTEGER NOT NULL DEFAULT 0, -- 1 IFF recovered_score - original_score >= margin
  verdict              TEXT NOT NULL,             -- kept_recovered | kept_original | rejected_fabrication | ocr_failed
  reason               TEXT,                      -- machine reason (gate that decided it), for audit
  checked_at           TEXT NOT NULL,
  UNIQUE (doc_id, page, engine_settings_hash)
);
CREATE INDEX IF NOT EXISTS idx_rr_doc     ON recovery_result(doc_id);
CREATE INDEX IF NOT EXISTS idx_rr_verdict ON recovery_result(verdict);

-- ── verified-improvement manifest — the KEPT subset a future gated rebuild could consume (NOT applied here) ─
-- A VIEW, not a table: it is always exactly the set of results that passed BOTH the strict-improvement gate
-- AND the no-fabrication gate. It carries no authority to mutate kie.db; consumption is a separate, gated step.
CREATE VIEW IF NOT EXISTS recovery_manifest AS
  SELECT doc_id, page, engine_settings_hash, original_score, recovered_score,
         (recovered_score - original_score) AS score_delta, recovered_text, checked_at
  FROM recovery_result
  WHERE verdict = 'kept_recovered';

CREATE TABLE IF NOT EXISTS recovery_meta (key TEXT PRIMARY KEY, value TEXT);
