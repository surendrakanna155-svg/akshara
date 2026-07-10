-- Knowledge Intake Center — CONTROL tables (additive; the core kie/schema.sql stays FROZEN).
--
-- These tables live in the production kie.db ALONGSIDE the certified content. They record
-- the incremental-ingestion review queue, per-file dispositions, and document version
-- lineage. They NEVER modify the certified content tables (source_documents, chunks,
-- concepts, ...): promotion writes into those are strictly additive (see promote.py).
--
-- Applied idempotently by intake.store_ext.apply_intake_schema(); loading it does not
-- touch or re-run Phases 1-7 or their schema.

-- ── One row per import operation (single/multiple/folder/zip/drag_drop/watch/url) ──
CREATE TABLE IF NOT EXISTS intake_batches (
  batch_id     TEXT PRIMARY KEY,
  source_kind  TEXT NOT NULL,          -- single|multiple|folder|zip|drag_drop|watch|url
  label        TEXT,
  status       TEXT NOT NULL,          -- open|staged|closed
  staging_ref  TEXT,                   -- path to this batch's staging kie.db (local-only)
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL
);

-- ── One row per file seen in a batch (the reviewable unit) ─────────────────────────
CREATE TABLE IF NOT EXISTS intake_items (
  item_id        TEXT PRIMARY KEY,     -- <batch_id>#<n>
  batch_id       TEXT NOT NULL REFERENCES intake_batches(batch_id),
  doc_id         TEXT,                 -- sha256[:16]  (content-addressed; null only if unhashable)
  sha256         TEXT,
  original_name  TEXT NOT NULL,
  source_path    TEXT,                 -- absolute path of the imported file (audit trail)
  corpus         TEXT NOT NULL DEFAULT 'intake',
  rel_path       TEXT,                 -- <doc_id>/<name> under resources/intake
  category       TEXT,
  lineage_key    TEXT,                 -- logical-document identity used for versioning
  verify_status  TEXT,                 -- verified|corrupt|encrypted
  certify_status TEXT,                 -- certified|quarantined|duplicate  (D-5)
  disposition    TEXT NOT NULL,        -- new|new_version|exact_duplicate|quarantined
  version_of     TEXT,                 -- prior doc_id this supersedes (new_version only)
  version_no     INTEGER,
  review_status  TEXT NOT NULL DEFAULT 'pending',  -- pending|needs_review|approved|rejected|skipped
  flags          TEXT,                 -- json array of auto-flags (low_ocr|parse_failed|no_concepts|...)
  stats          TEXT,                 -- json: {chunks,concepts,formulas,patterns} produced in staging
  reviewer       TEXT,
  decided_at     TEXT,
  promoted_at    TEXT,
  notes          TEXT,
  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_intake_items_batch  ON intake_items(batch_id);
CREATE INDEX IF NOT EXISTS idx_intake_items_status ON intake_items(review_status);
CREATE INDEX IF NOT EXISTS idx_intake_items_sha    ON intake_items(sha256);
CREATE INDEX IF NOT EXISTS idx_intake_items_doc    ON intake_items(doc_id);

-- ── Version lineage: append-only, never overwritten (yearly NCERT/JEE/NEET updates) ─
CREATE TABLE IF NOT EXISTS document_versions (
  version_id    TEXT PRIMARY KEY,      -- <lineage_key>@v<version_no>
  lineage_key   TEXT NOT NULL,
  doc_id        TEXT NOT NULL,
  version_no    INTEGER NOT NULL,
  sha256        TEXT NOT NULL,
  year          INTEGER,
  source_item   TEXT,                  -- intake_items.item_id that introduced this version
  superseded_by TEXT,                  -- doc_id of the newer version (NULL = current head)
  created_at    TEXT NOT NULL,
  UNIQUE (lineage_key, version_no)
);
CREATE INDEX IF NOT EXISTS idx_docversions_lineage ON document_versions(lineage_key);
CREATE INDEX IF NOT EXISTS idx_docversions_doc     ON document_versions(doc_id);

-- ── Local watch-folder state: content hash of every file already seen ──────────────
CREATE TABLE IF NOT EXISTS watch_state (
  folder    TEXT NOT NULL,
  rel_path  TEXT NOT NULL,
  sha256    TEXT NOT NULL,
  seen_at   TEXT NOT NULL,
  PRIMARY KEY (folder, rel_path)
);
