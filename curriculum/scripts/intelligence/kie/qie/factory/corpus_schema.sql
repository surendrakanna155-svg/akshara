-- Candidate Corpus — the QUARANTINE boundary for AI-generated question candidates.
--
-- GOVERNANCE (non-negotiable): rows here are NOT product inventory. `candidate` and `quarantined` items are
-- invisible to qpgen / DPP / any student- or teacher-facing surface. ONLY status='certified' may ever be
-- promoted, and promotion is a separate, explicit act — never a side effect of generation.
--
-- This store is deliberately SEPARATE from qie.db (certified evidence) so that a generator's output can never
-- be mistaken for, or silently merge into, the certified registry. A model's own prior output is not truth
-- merely because it was stored.
--
-- Rows are LOCAL-ONLY (curriculum/knowledge/ is gitignored). Only this schema + the harness code are committed.

CREATE TABLE IF NOT EXISTS factory_meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- ── the generation PLAN: one row per spec QIE emits for the generator to satisfy ────────────────────
CREATE TABLE IF NOT EXISTS generation_spec (
  spec_id            TEXT PRIMARY KEY,
  run_id             TEXT NOT NULL,
  lane               TEXT NOT NULL,      -- STRUCTURED_NUMERIC | QUALITATIVE
  board              TEXT,               -- CBSE | ...
  exam_profile       TEXT,               -- SCHOOL | JEE_MAIN | JEE_ADVANCED | NEET
  class_level        INTEGER NOT NULL,   -- 6..12
  subject            TEXT NOT NULL,
  concept_code       TEXT,               -- kie.db concepts.concept_code (planning anchor)
  concept_title      TEXT,
  concept_codes_all  TEXT,               -- json: multi-concept composition members
  composition        TEXT NOT NULL,      -- single | multi
  archetype          TEXT NOT NULL,      -- kie.qie.archetypes.ARCHETYPES
  question_type      TEXT NOT NULL,      -- MCQ | ...
  intended_depth     INTEGER NOT NULL,   -- 1..5 reasoning depth
  intended_difficulty TEXT NOT NULL,     -- easy | moderate | hard
  visual_required    INTEGER NOT NULL DEFAULT 0,
  boundary           TEXT,               -- json: allowed/forbidden prerequisite evidence handed to generator
  planner_evidence   TEXT,               -- json: WHY this spec is legitimate (grade source, method, edges)
  created_at         TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_spec_run ON generation_spec(run_id);
CREATE INDEX IF NOT EXISTS idx_spec_cls ON generation_spec(class_level, subject);

-- ── the CANDIDATE CORPUS ───────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS candidate (
  candidate_id       TEXT PRIMARY KEY,
  run_id             TEXT NOT NULL,
  spec_id            TEXT REFERENCES generation_spec(spec_id),
  generator_model    TEXT NOT NULL,      -- provenance: which model proposed this
  generator_batch    TEXT,               -- batch/agent id within the run
  -- raw candidate (exactly as the generator emitted it)
  stem               TEXT NOT NULL,
  options            TEXT,               -- json {label: text}
  answer_label       TEXT,
  answer_value       TEXT,
  -- generator-PROPOSED metadata (claims — never trusted, always independently tested)
  claimed            TEXT,               -- json: concepts, archetype, depth, difficulty, composition
  structure          TEXT,               -- json: givens/relation/solve_for/steps (the checkable substrate)
  solution           TEXT,               -- json: ordered steps + final
  distractor_rationale TEXT,             -- json {label: why-wrong}
  visual_spec        TEXT,               -- json structured visual specification (NOT an image)
  raw                TEXT,               -- json: the untouched generator payload
  -- lifecycle
  status             TEXT NOT NULL DEFAULT 'candidate',  -- candidate|quarantined|rejected|certified
  reject_reason      TEXT,
  item_hash          TEXT,               -- sha256(stem|options|answer) — dedup + judge cache key
  stem_norm_hash     TEXT,               -- normalized-stem hash for near-duplicate detection
  created_at         TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_cand_run ON candidate(run_id);
CREATE INDEX IF NOT EXISTS idx_cand_status ON candidate(status);
CREATE INDEX IF NOT EXISTS idx_cand_hash ON candidate(item_hash);
CREATE INDEX IF NOT EXISTS idx_cand_norm ON candidate(stem_norm_hash);

-- ── every gate outcome, per candidate (the audit trail; nothing is overwritten) ─────────────────────
CREATE TABLE IF NOT EXISTS gate_result (
  candidate_id  TEXT NOT NULL REFERENCES candidate(candidate_id),
  gate          TEXT NOT NULL,
  ok            INTEGER NOT NULL,       -- 1 pass | 0 fail
  severity      TEXT NOT NULL,          -- fatal | quarantine | advisory
  detail        TEXT,                   -- json/text: what was checked and what was found
  checked_at    TEXT NOT NULL,
  PRIMARY KEY (candidate_id, gate)
);
CREATE INDEX IF NOT EXISTS idx_gate_gate ON gate_result(gate, ok);

-- ── independent answer validation (deterministic re-derivation; generator answer is NOT evidence) ───
CREATE TABLE IF NOT EXISTS independent_answer (
  candidate_id     TEXT PRIMARY KEY REFERENCES candidate(candidate_id),
  method           TEXT NOT NULL,       -- sympy_relation_solve | sympy_pipeline | none_available
  solver_answer    TEXT,
  generator_answer TEXT,
  verdict          TEXT NOT NULL,       -- agree | disagree | solver_failed | not_applicable | ambiguous
  detail           TEXT,
  checked_at       TEXT NOT NULL
);

-- ── separate AI judge (semantic/quality review; independence limitations recorded honestly) ─────────
CREATE TABLE IF NOT EXISTS judge_verdict (
  candidate_id   TEXT PRIMARY KEY REFERENCES candidate(candidate_id),
  judge_model    TEXT NOT NULL,
  independent    INTEGER NOT NULL,      -- 0 when same model family as generator (disclosed, not hidden)
  verdict        TEXT NOT NULL,         -- accept | reject | quarantine
  well_posed     INTEGER,
  curriculum_ok  INTEGER,
  answer_correct INTEGER,
  unique_answer  INTEGER,
  concepts_real  INTEGER,               -- are the CLAIMED concepts genuinely required to solve it?
  composition_real INTEGER,             -- is a claimed multi-concept item really multi-concept?
  difficulty_plausible INTEGER,
  distractors_plausible INTEGER,
  visual_judgement TEXT,                -- ok | missing | unnecessary
  reasons        TEXT,
  checked_at     TEXT NOT NULL
);

-- ── run-level telemetry (cost/throughput evidence) ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS run_telemetry (
  run_id        TEXT NOT NULL,
  stage         TEXT NOT NULL,          -- generation | gates | independent | judge | solution_verify
  model         TEXT,
  batches       INTEGER,
  items         INTEGER,
  input_tokens  INTEGER,
  output_tokens INTEGER,
  wall_seconds  REAL,
  note          TEXT,
  recorded_at   TEXT NOT NULL,
  PRIMARY KEY (run_id, stage, model)
);
