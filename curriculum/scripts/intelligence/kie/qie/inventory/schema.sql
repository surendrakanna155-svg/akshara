-- unified_inventory.db — the R4-1 reconciled certified/verified inventory MANIFEST.
-- A provenance-complete REGISTRY (NOT a second question bank): one row per verified/certified asset across
-- qie.db + qpl_question_bank.db + factory_corpus.db + the frozen index crosswalk. Product surfaces read
-- QUESTIONS only from qpl_question_bank (RI-6); they may read THIS manifest for provenance/coverage.
-- WRITABLE derived store under KIE_HOME; local-only (gitignored). Deterministic to rebuild.

CREATE TABLE IF NOT EXISTS unified_inventory (
  uid                  TEXT PRIMARY KEY,   -- sha256(source_store|source_table|source_id)
  source_store         TEXT NOT NULL,      -- qie.db | qpl_question_bank.db | factory_corpus.db
  source_table         TEXT NOT NULL,      -- pilot_verified_item | governed_relation | governed_fact | kvs_assertion | candidate
  source_id            TEXT NOT NULL,
  source_status        TEXT,               -- the source's OWN status (certified/verified/quarantined/rejected) — preserved
  asset_class          TEXT NOT NULL,      -- question_item | relation | fact | kvs_assertion
  subject              TEXT,
  exam                 TEXT,
  concept_code_src     TEXT,               -- as stored in the source (legacy / "Subject::Chapter")
  concept_kc           TEXT,               -- resolved KC_ id, or NULL (honest-null crosswalk)
  verification_methods TEXT,               -- json list of method labels (the battery)
  is_deterministic     INTEGER NOT NULL,   -- 1 iff every method is a non-model (deterministic) verifier
  evidence_class       TEXT,               -- sympy_rederived | source_proven | deterministic_kb | model_agreed_on_owned_evidence
  evidence_refs        TEXT,               -- json: provenance / fact_keys / relation_id / gate summary
  item_hash            TEXT,               -- factory dedup key (computed on the fly for pilot rows)
  norm_hash            TEXT,               -- factory near-dup key
  dedup_group          TEXT,               -- shared across duplicates (norm_hash-based)
  promotion_status     TEXT NOT NULL,      -- promotable | practice_tier_eligible | eligible | held_qualitative
                                           --   | held_low_quality | honest_null | quarantined | duplicate | rejected_source
  promotion_target     TEXT,               -- qpl_question_bank candidate_id if genuinely promoted, else NULL
  reverified_at        TEXT,
  reverify_method      TEXT,
  reverify_ok          INTEGER,            -- 1 agree | 0 disagree | NULL honest-null (not evaluable)
  created_at           TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ui_store   ON unified_inventory(source_store, source_table);
CREATE INDEX IF NOT EXISTS idx_ui_class   ON unified_inventory(asset_class, promotion_status);
CREATE INDEX IF NOT EXISTS idx_ui_norm    ON unified_inventory(norm_hash);
CREATE INDEX IF NOT EXISTS idx_ui_dedup   ON unified_inventory(dedup_group);

-- The legacy/topic -> KC_ resolution (R5-2 edge-table pattern), recorded so a consumer sees both the source
-- code AND the resolved id, with unresolved kept as honest nulls.
CREATE TABLE IF NOT EXISTS crosswalk (
  src_code   TEXT NOT NULL,
  subject    TEXT,
  kc_id      TEXT,                          -- NULL = unresolved (honest-null)
  method     TEXT,                          -- name_match | alias_match | unresolved
  resolved   INTEGER NOT NULL,
  PRIMARY KEY (src_code, subject)
);

CREATE TABLE IF NOT EXISTS unified_meta (
  key   TEXT PRIMARY KEY,
  value TEXT
);
