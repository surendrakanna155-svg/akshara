-- Quality Intelligence Engine (QIE) — local SQLite store `qie.db`.
-- LOCAL-ONLY (gitignored per the storage lock). SEPARATE from the certified kie.db: QIE never writes engine
-- tables. Table shapes anticipate the dormant Postgres edu_* Item-Model/distractor shapes so promotion is 1:1.
-- Additive-only. Derived knowledge (rows) stays local; only this schema/code/tests are committed.

CREATE TABLE IF NOT EXISTS qie_meta (
  key   TEXT PRIMARY KEY,
  value TEXT
);

-- ── Question DNA (L2 analysis) — structure only, never source wording ─────────────────────────
CREATE TABLE IF NOT EXISTS question_dna (
  dna_id            TEXT PRIMARY KEY,          -- stable hash of the versioned structural core (NOT source text)
  lane              TEXT NOT NULL,             -- one of kie.qie.lanes.LANES
  subject           TEXT,
  concept_code      TEXT,                      -- resolved canonical concept (references kie.db concepts, by value)
  archetype         TEXT,
  provenance        TEXT,                      -- json: resource_id, page, bbox, question_number, license_status, confidence
  construction      TEXT,                      -- json: givens/unknown/units/answer_rule (numeric) OR KVS fact refs
  distractor_dna    TEXT,                      -- json: per-wrong-option {misconception_type, transform}
  solution_dna      TEXT,                      -- json: key_insight, ordered_steps, relations_used, common_mistake
  difficulty_drivers TEXT,                     -- json: measured driver vector (per-profile)
  quality_flags     TEXT,                      -- json: ocr_damaged, diagram_locked, ambiguous_source, ...
  source_class      TEXT,                      -- licence class (analysis-only lanes never enter L3 wording)
  extraction_confidence REAL,
  created_at        TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_dna_lane_concept ON question_dna(lane, concept_code);

-- ── Item Models (L3 generative mould) — extends the intent of the empty kie.db question_templates ──
CREATE TABLE IF NOT EXISTS item_model (
  item_model_id     TEXT PRIMARY KEY,
  version           INTEGER NOT NULL DEFAULT 1,
  lane              TEXT NOT NULL,
  archetype         TEXT,
  concept_scope     TEXT NOT NULL,             -- json list of canonical concept_codes (EXACT binding; no keyword substr)
  assessment_construct TEXT,
  cognitive_chain   TEXT,                      -- json ordered operations
  difficulty_band   TEXT,                      -- json: per-driver target ranges -> predicted band
  stem_structure    TEXT,                      -- parametric skeleton (typed slots; NO source sentence)
  variable_schema   TEXT,                      -- json {symbol,type,unit,role}
  parameter_constraints TEXT,                  -- json ranges/relational constraints (learned from DNA)
  answer_function   TEXT,                      -- numeric: relation ref; conceptual: verification_ref (KVS)
  verification_ref  TEXT,                      -- KVS store + key for non-numeric independent verification
  distractor_generators TEXT,                  -- json list {misconception_type, transform, applicability}
  visual_generator  TEXT,                      -- nullable semantic visual spec (Phase E)
  solution_strategy TEXT,
  allowed_profiles  TEXT,                      -- json list (NEET|JEE_MAIN|CBSE_X|FOUNDATION|...)
  forbidden_combinations TEXT,
  n_dna             INTEGER NOT NULL DEFAULT 0, -- distinct DNA distilled from  (yield gate: >=5)
  n_resources       INTEGER NOT NULL DEFAULT 0, -- distinct source resources    (yield gate: >=2)
  certification_status TEXT NOT NULL DEFAULT 'draft', -- draft|ai_validated|teacher_validated|certified
  retired           INTEGER NOT NULL DEFAULT 0,
  provenance        TEXT,
  created_at        TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_im_lane_concept ON item_model(lane, concept_scope);

-- ── Distractor DNA (misconception store) — kie.db distractors is empty; this is its intended purpose ──
CREATE TABLE IF NOT EXISTS distractor_dna (
  distractor_id     TEXT PRIMARY KEY,
  item_model_id     TEXT REFERENCES item_model(item_model_id),
  misconception_type TEXT NOT NULL,
  transform         TEXT,                      -- numeric: op on the correct value; conceptual: confusion source
  provenance        TEXT,
  created_at        TEXT NOT NULL
);

-- ── Knowledge Verification Substrate (KVS) — non-numeric independent-verification backbone ─────────
-- assertion_base: subject-predicate-object facts, each with >=2 independent evidence sources.
CREATE TABLE IF NOT EXISTS kvs_assertion (
  assertion_id      TEXT PRIMARY KEY,
  subject_term      TEXT NOT NULL,
  predicate         TEXT NOT NULL,
  object_term       TEXT NOT NULL,
  concept_code      TEXT,
  evidence          TEXT NOT NULL,             -- json list of >=2 source refs (doc_id/chunk_id)
  evidence_count    INTEGER NOT NULL DEFAULT 0,
  created_at        TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_kvs_subject ON kvs_assertion(subject_term, predicate);

-- taxonomy_store / sequence_store / structure_function_map / comparison_matrix (seeded in later A-slices).
CREATE TABLE IF NOT EXISTS kvs_taxonomy (
  node_id TEXT PRIMARY KEY, class_name TEXT NOT NULL, member TEXT NOT NULL,
  is_member INTEGER NOT NULL, discriminating_attr TEXT, evidence TEXT, created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS kvs_sequence (
  seq_id TEXT PRIMARY KEY, process_name TEXT NOT NULL, ordered_steps TEXT NOT NULL, evidence TEXT, created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS kvs_structure_function (
  sf_id TEXT PRIMARY KEY, structure TEXT NOT NULL, function TEXT NOT NULL, location TEXT, system TEXT, evidence TEXT, created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS kvs_comparison (
  cmp_id TEXT PRIMARY KEY, entity TEXT NOT NULL, attribute TEXT NOT NULL, value TEXT NOT NULL, evidence TEXT, created_at TEXT NOT NULL);

-- ── Generated instances + verdicts (calibration/audit) — kie.db generated_items is empty; mirror it here ──
CREATE TABLE IF NOT EXISTS generated_item (
  gen_id            TEXT PRIMARY KEY,
  item_model_id     TEXT REFERENCES item_model(item_model_id),
  item_model_version INTEGER,                  -- lineage: which model version produced this instance
  lane              TEXT,
  seed              INTEGER,
  stem              TEXT,
  options           TEXT,                      -- json
  answer            TEXT,
  solution_steps    TEXT,                      -- json
  predicted_difficulty TEXT,
  gate_verdicts     TEXT,                      -- json: per-gate pass/fail + evidence
  created_at        TEXT NOT NULL
);

-- ── E-lite ingestion boundary (A4) — preserve structure the frozen phase2/phase4 currently drop ──────
-- Additive + separate: E-lite runs ALONGSIDE the frozen ingestion phases (never modifies them) and captures,
-- for newly ingested docs, the question/option/answer/solution boundaries + visual assets that phase4 loses
-- at the parse->chunk boundary. Populated from a doc's parsed structure; LOCAL-ONLY.
CREATE TABLE IF NOT EXISTS elite_question (
  question_id       TEXT PRIMARY KEY,
  doc_id            TEXT NOT NULL,
  page              INTEGER,
  question_number   TEXT,
  stem              TEXT,
  options           TEXT,                      -- json {1..4 / A..D}
  answer_key        TEXT,                      -- detected key (option label) if present
  solution_ref      TEXT,                      -- solution text/anchor if present
  bbox              TEXT,                      -- json [x0,y0,x1,y1] when available
  linked_visual_ids TEXT,                      -- json list
  extraction_confidence REAL,
  created_at        TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_elite_q_doc ON elite_question(doc_id);

CREATE TABLE IF NOT EXISTS elite_visual_asset (
  asset_id          TEXT PRIMARY KEY,
  doc_id            TEXT NOT NULL,
  page              INTEGER,
  kind              TEXT,                      -- raster | vector | equation | table
  bbox              TEXT,
  digest            TEXT,
  dims              TEXT,
  raw               TEXT,                      -- equation raw/latex where available
  linked_question_id TEXT,
  created_at        TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_elite_v_doc ON elite_visual_asset(doc_id);

-- ── Tier-2 model-verification cache (B6) — governed, cached, OFFLINE independent-model agreement ──────
-- Non-numeric clusters the deterministic KVS cannot reach (esp. Biology) are verified by an independent
-- model reading stem+options+stated-answer (the Phase-0b agreement architecture, 91.7% on Biology). Verdicts
-- are CACHED by item content hash so the model is never re-run (I9: offline at certification, zero runtime AI).
CREATE TABLE IF NOT EXISTS tier2_verdict (
  item_hash    TEXT PRIMARY KEY,          -- sha256 of (stem|options|stated_answer)
  fact_key     TEXT,                      -- the (concept,answer) fact this item attests
  subject      TEXT,
  verdict      TEXT NOT NULL,             -- agree | disagree | unverifiable
  model        TEXT,                      -- judge model id (provenance)
  note         TEXT,
  created_at   TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_tier2_fact ON tier2_verdict(fact_key);

-- ── Concept-canonicalization ledger (A2) — which junk pseudo-concepts were quarantined, reversibly ──
CREATE TABLE IF NOT EXISTS concept_canon_ledger (
  concept_code      TEXT PRIMARY KEY,
  reason            TEXT NOT NULL,             -- ocr_junk | non_concept | prefix_domain_mismatch | duplicate_of:<code>
  evidence          TEXT,
  proposed_status   TEXT,                      -- rejected (auto-quarantine) | review (needs human check)
  prior_status      TEXT,                      -- concepts.status BEFORE apply (for precise rollback)
  applied           INTEGER NOT NULL DEFAULT 0, -- 0 = candidate only (analysis); 1 = applied to kie.db
  applied_at        TEXT,
  created_at        TEXT NOT NULL
);
