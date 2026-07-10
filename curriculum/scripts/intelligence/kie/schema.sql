-- Knowledge Intelligence Engine — local SQLite knowledge store.
-- LOCAL-ONLY (curriculum/knowledge/kie/kie.db is gitignored per the storage lock).
-- Table shapes MIRROR the dormant Postgres edu_* / canonical_concepts schema so the
-- Knowledge Intake Center (intake.py) can promote rows 1:1 into production later.
-- Additive-only; all phases share this file. Phase 1 fills source_documents + stage_ledger.

CREATE TABLE IF NOT EXISTS schema_meta (
  key   TEXT PRIMARY KEY,
  value TEXT
);

-- ── Phase 1: source-document registry (verifier verdict + provenance) ───────────
CREATE TABLE IF NOT EXISTS source_documents (
  doc_id           TEXT PRIMARY KEY,          -- stable id = sha256[:16]
  corpus           TEXT NOT NULL,             -- foundation | board
  rel_path         TEXT NOT NULL,
  category         TEXT,                      -- top folder: JEE_Main, NEET, AIIMS, NCERT, ...
  exam             TEXT,
  subject          TEXT,
  class_label      TEXT,
  doc_type         TEXT,
  year             INTEGER,
  language         TEXT,
  kind             TEXT,                      -- pdf | archive | other
  bytes            INTEGER,
  pages            INTEGER,
  sha256           TEXT NOT NULL,
  integrity_ok     INTEGER NOT NULL,          -- 0/1
  corruption_reason TEXT,
  encrypted        INTEGER NOT NULL DEFAULT 0,
  parser_class     TEXT,                      -- born_digital_text|sparse_text|scanned_image|archive|corrupt|unknown
  parser_strategy  TEXT,                      -- text_extract|ocr|unpack|exclude|...
  is_duplicate     INTEGER NOT NULL DEFAULT 0,
  duplicate_of     TEXT,                      -- sha256 of canonical
  verify_status    TEXT NOT NULL,             -- verified | corrupt | encrypted
  certify_status   TEXT NOT NULL,             -- certified | quarantined | duplicate   (D-5)
  certify_reason   TEXT,
  created_at       TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_srcdoc_corpus  ON source_documents(corpus);
CREATE INDEX IF NOT EXISTS idx_srcdoc_certify ON source_documents(certify_status);
CREATE INDEX IF NOT EXISTS idx_srcdoc_sha     ON source_documents(sha256);

-- ── Idempotent per-(doc, stage) checkpoint ledger (recovery) ────────────────────
CREATE TABLE IF NOT EXISTS stage_ledger (
  doc_id       TEXT NOT NULL,
  stage        TEXT NOT NULL,                 -- verify|parse|metadata|chunk|concept|graph|questions|generate
  status       TEXT NOT NULL,                 -- pending|done|failed|skipped
  input_sha256 TEXT,
  output_ref   TEXT,
  error        TEXT,
  updated_at   TEXT NOT NULL,
  PRIMARY KEY (doc_id, stage)
);

-- ── Phase 2/3: parsed document output is persisted to parsed/<doc_id>.json ───────
-- (page text + tables + blocks); a lightweight index row lives here.
CREATE TABLE IF NOT EXISTS parsed_documents (
  doc_id       TEXT PRIMARY KEY REFERENCES source_documents(doc_id),
  method       TEXT,                          -- pymupdf|pdfplumber|tesseract|mixed
  pages        INTEGER,
  char_count   INTEGER,
  table_count  INTEGER,
  ocr_used     INTEGER NOT NULL DEFAULT 0,
  output_ref   TEXT,                          -- parsed/<doc_id>.json
  confidence   REAL,
  created_at   TEXT NOT NULL
);

-- ── Phase 3: document section outline (headings → chapters/topics) ──────────────
CREATE TABLE IF NOT EXISTS document_sections (
  section_id TEXT PRIMARY KEY,             -- <doc_id>#s<ordinal>
  doc_id     TEXT NOT NULL REFERENCES source_documents(doc_id),
  ordinal    INTEGER NOT NULL,
  level      INTEGER NOT NULL,             -- 1 = chapter, 2 = topic, ...
  title      TEXT NOT NULL,
  page       INTEGER,
  path       TEXT                          -- breadcrumb, e.g. "Real Numbers > Euclid's Lemma"
);
CREATE INDEX IF NOT EXISTS idx_sections_doc ON document_sections(doc_id);

-- ── Phase 3: document-level catalog metadata (JEE/NEET facets, deterministic) ────
-- Derived from source path + archive provenance + parsed structure. doc_type,
-- language and class_label live on source_documents (existing columns); the facets
-- with no home there land here. All deterministic — no LLM.
CREATE TABLE IF NOT EXISTS document_metadata (
  doc_id           TEXT PRIMARY KEY REFERENCES source_documents(doc_id),
  stream           TEXT,     -- Medical | Engineering | Foundation | Both
  source_authority TEXT,     -- official | mirror | third_party | unknown
  provider         TEXT,     -- NTA | Careers360 | Embibe | AskIITians | ...
  session          TEXT,     -- Set-CC | Shift-2 | Morning | H2 | ...
  content_profile  TEXT,     -- question_paper | solutions | theory | reference | mixed
  title            TEXT,
  confidence       REAL,     -- 0..1 fraction of core facets resolved
  created_at       TEXT NOT NULL
);

-- ── Phase 4: structure-aware chunks + FTS5 lexical index ────────────────────────
CREATE TABLE IF NOT EXISTS chunks (
  chunk_id     TEXT PRIMARY KEY,              -- <doc_id>#<ordinal>
  doc_id       TEXT NOT NULL REFERENCES source_documents(doc_id),
  ordinal      INTEGER NOT NULL,
  page_start   INTEGER,
  page_end     INTEGER,
  char_start   INTEGER,
  char_end     INTEGER,
  block_type   TEXT,                          -- heading|paragraph|list|table|figure_caption|question|option|solution|formula|example
  section_path TEXT,
  text         TEXT NOT NULL,
  token_est    INTEGER,
  sha256       TEXT,
  lang         TEXT
);
CREATE INDEX IF NOT EXISTS idx_chunks_doc ON chunks(doc_id);
CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(text, chunk_id UNINDEXED);

-- ── Phase 5/6: concept spine (mirrors canonical_concepts) ───────────────────────
CREATE TABLE IF NOT EXISTS concepts (
  concept_code          TEXT PRIMARY KEY,     -- e.g. PHY_G11_MECH_NEWTON2_001
  title                 TEXT NOT NULL,
  definition            TEXT,
  subject_domain        TEXT,
  typical_grade_low     INTEGER,
  typical_grade_high    INTEGER,
  bloom_levels          TEXT,                 -- json array
  difficulty_min        TEXT,
  difficulty_max        TEXT,
  curriculum_boundary   TEXT,                 -- json
  foundation_boundary   TEXT,                 -- json
  common_misconceptions TEXT,                 -- json
  reference_facts       TEXT,                 -- json (formulas/laws/theorems/definitions)
  status                TEXT NOT NULL DEFAULT 'active',
  merged_into           TEXT,
  evidence              TEXT,                 -- json: {chunk_ids[], method, confidence}
  created_at            TEXT NOT NULL
);

-- ── Phase 6: concept graph edges (mirrors concept_prerequisites) ────────────────
CREATE TABLE IF NOT EXISTS concept_edges (
  from_concept      TEXT NOT NULL REFERENCES concepts(concept_code),
  to_concept        TEXT NOT NULL REFERENCES concepts(concept_code),
  relationship_type TEXT NOT NULL DEFAULT 'prerequisite',   -- prerequisite|parent_child|related|confused_with
  strength          REAL,
  notes             TEXT,
  evidence          TEXT,
  PRIMARY KEY (from_concept, to_concept, relationship_type),
  CHECK (from_concept <> to_concept)
);

-- ── Phase 6: concept ↔ board/exam mapping (mirrors concept_board_mappings) ───────
CREATE TABLE IF NOT EXISTS concept_board_mappings (
  concept_code      TEXT NOT NULL REFERENCES concepts(concept_code),
  board_code        TEXT NOT NULL DEFAULT '',
  exam_profile_code TEXT NOT NULL DEFAULT '',
  chapter           TEXT NOT NULL DEFAULT '',
  topic             TEXT NOT NULL DEFAULT '',
  alignment         TEXT NOT NULL DEFAULT 'exact',           -- exact|partial|extends
  PRIMARY KEY (concept_code, board_code, exam_profile_code, chapter, topic)
);

-- ── Phase 5: first-class formulas/laws (mined into reference_facts too) ──────────
CREATE TABLE IF NOT EXISTS formulas (
  formula_id   TEXT PRIMARY KEY,
  concept_code TEXT REFERENCES concepts(concept_code),
  kind         TEXT,                          -- formula|law|theorem|definition
  expression   TEXT,
  symbols      TEXT,                          -- json
  evidence     TEXT
);

-- ── Phase 7: question intelligence (patterns → families → templates; mirrors edu_*) ─
CREATE TABLE IF NOT EXISTS question_patterns (
  pattern_id    TEXT PRIMARY KEY,
  concept_code  TEXT REFERENCES concepts(concept_code),
  exam          TEXT,
  subject       TEXT,
  question_type TEXT,                         -- mcq|numerical|assertion_reason|match|short_answer|...
  bloom         TEXT,
  difficulty    TEXT,
  stem_skeleton TEXT,                         -- ORIGINAL structural skeleton — never copied source text (Rule 7)
  frequency     INTEGER,
  years         TEXT,                         -- json list
  evidence      TEXT
);
CREATE TABLE IF NOT EXISTS question_families (
  family_code  TEXT PRIMARY KEY,
  concept_code TEXT REFERENCES concepts(concept_code),
  title        TEXT,
  description  TEXT,
  status       TEXT NOT NULL DEFAULT 'draft',
  created_at   TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS question_templates (
  template_code       TEXT PRIMARY KEY,
  family_code         TEXT REFERENCES question_families(family_code),
  concept_code        TEXT REFERENCES concepts(concept_code),
  question_type       TEXT,
  stem_template       TEXT,
  parameter_variables TEXT,                   -- json
  constraints         TEXT,                   -- json
  generation_rules    TEXT,                   -- json
  validation_rules    TEXT,                   -- json
  difficulty_min      TEXT,
  difficulty_max      TEXT,
  status              TEXT NOT NULL DEFAULT 'draft',
  created_at          TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS distractors (
  distractor_id     TEXT PRIMARY KEY,
  concept_code      TEXT REFERENCES concepts(concept_code),
  distractor_text   TEXT,
  misconception_type TEXT,
  difficulty        TEXT,
  evidence          TEXT
);

-- ── Phase 8 (GATED): generated instances (deterministic default / offline-AI when authorized) ─
CREATE TABLE IF NOT EXISTS generated_items (
  item_id         TEXT PRIMARY KEY,
  template_code   TEXT REFERENCES question_templates(template_code),
  concept_code    TEXT REFERENCES concepts(concept_code),
  question_text   TEXT,
  answer_text     TEXT,
  options         TEXT,                        -- json
  difficulty      TEXT,
  bloom           TEXT,
  origin          TEXT,                        -- deterministic | ai_offline
  solver_verified INTEGER NOT NULL DEFAULT 0,
  trust_status    TEXT NOT NULL DEFAULT 'draft',
  created_at      TEXT NOT NULL
);
