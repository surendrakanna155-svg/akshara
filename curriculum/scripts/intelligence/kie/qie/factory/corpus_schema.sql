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
--
-- SCHEMA VERSION: factory-3 (remediation R2 — certification hardening: solution+distractor gates, proposer/
--   certifier independence, self-refuted-metadata replay).
--   Builds ADDITIVELY on factory-2 (R1-2 — append-only, content-bound certification records).
--   The evidence tables (gate_result / independent_answer / judge_verdict) are APPEND-ONLY: every attempt is a
--   new row (id AUTOINCREMENT) stamped with the candidate's item_hash AT CHECK TIME, so evidence is bound to
--   the exact content it was computed against. A `_latest` view exposes the most recent attempt for the
--   single-row readers. Certified rows are immutable; re-ingest over a certified id hard-fails in code.
--   In-place migrators upgrade older DBs: corpus.migrate_appendonly (factory-1 -> factory-2, table rebuild)
--   then corpus.migrate_r2 (factory-2 -> factory-3, additive ADD COLUMN). Both idempotent; see corpus.py.
--
--   factory-3 columns (all additive; a legacy certified row acquires NULLs here and so falls OUT of
--   product_inventory until re-certified under the R2 gates — the intended quarantine-by-construction):
--     candidate.evidence_class       {sympy_rederived | model_agreed_on_owned_evidence | source_proven}
--     candidate.certification_class  {certified | provisional}; provisional = same-actor review, product-invisible
--     candidate.generator_family     actor family of the proposer (structural same-actor rejection input)
--     candidate.earned_depth         reasoning depth EARNED by executing the step DAG (never the bare claim)
--     candidate.computed_archetype   QIE-detected archetype stamped at certification (never a refuted claim)
--     judge_verdict.judge_family     actor family of the disposing reviewer; `independent` is COMPUTED from it

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
  candidate_id       TEXT PRIMARY KEY,   -- CAND_ + sha256(run_id|spec_id)[:16] — collision-free (R1-2)
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
  relation_waiver    TEXT,               -- json {waived_by, reason, waived_at}: owner override for an
                                         -- UNGROUNDED relation. The ONLY escape from blocking grounding (R1-1);
                                         -- never set by the generator, always an explicit auditable owner act.
  item_hash          TEXT,               -- sha256(stem|options|answer) — dedup + judge cache key + content bind
  stem_norm_hash     TEXT,               -- normalized-stem hash for near-duplicate detection
  -- factory-3 (R2 certification hardening). Set ONLY at certification; a legacy row's NULLs keep it out of
  -- product_inventory (R0-2 quarantine-by-construction) until it is re-certified under the R2 gates.
  generator_family    TEXT,              -- R2-1: actor family of the proposer (structural same-actor rejection)
  evidence_class      TEXT,              -- R2-1: sympy_rederived | model_agreed_on_owned_evidence | source_proven
  certification_class TEXT,              -- R2-1: certified | provisional (same-actor => provisional, invisible)
  earned_depth        INTEGER,           -- R2-4: reasoning depth EARNED by executing the DAG (not the claim)
  computed_archetype  TEXT,              -- R2-4: QIE-detected archetype stamped at certification (not a claim)
  created_at         TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_cand_run ON candidate(run_id);
CREATE INDEX IF NOT EXISTS idx_cand_status ON candidate(status);
CREATE INDEX IF NOT EXISTS idx_cand_hash ON candidate(item_hash);
CREATE INDEX IF NOT EXISTS idx_cand_norm ON candidate(stem_norm_hash);
-- belt-and-suspenders behind the collision-free candidate_id: at most one candidate per (run_id, spec_id).
-- Doubles as the plain-INSERT guard for the immutability rule (a second ingest for the pair raises).
CREATE UNIQUE INDEX IF NOT EXISTS ux_candidate_run_spec ON candidate(run_id, spec_id);

-- ── every gate outcome, per candidate — APPEND-ONLY (nothing is ever overwritten) ───────────────────
-- Each row is one gate check for one attempt, stamped with the candidate's item_hash at check time. A later
-- re-check on new content appends a new row; the old evidence is retained. `gate_result_latest` exposes the
-- most recent row per (candidate_id, gate). Certification consumes ONLY rows whose item_hash matches the
-- candidate's CURRENT item_hash — evidence computed against different content can never certify (R1-2, [C1]).
CREATE TABLE IF NOT EXISTS gate_result (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  candidate_id  TEXT NOT NULL REFERENCES candidate(candidate_id),
  item_hash     TEXT NOT NULL,          -- candidate.item_hash at check time (content binding)
  gate          TEXT NOT NULL,
  ok            INTEGER NOT NULL,       -- 1 pass | 0 fail
  severity      TEXT NOT NULL,          -- fatal | quarantine | advisory
  detail        TEXT,                   -- json/text: what was checked and what was found
  checked_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_gate_cand ON gate_result(candidate_id, gate);
CREATE INDEX IF NOT EXISTS idx_gate_gate ON gate_result(gate, ok);
CREATE INDEX IF NOT EXISTS idx_gate_hash ON gate_result(candidate_id, item_hash);

-- ── independent answer validation — APPEND-ONLY (deterministic re-derivation; generator answer is NOT evidence)
CREATE TABLE IF NOT EXISTS independent_answer (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  candidate_id     TEXT NOT NULL REFERENCES candidate(candidate_id),
  item_hash        TEXT NOT NULL,       -- candidate.item_hash at check time (content binding)
  method           TEXT NOT NULL,       -- sympy_relation_solve | sympy_pipeline | none_available
  solver_answer    TEXT,
  generator_answer TEXT,
  verdict          TEXT NOT NULL,       -- agree | disagree | solver_failed | not_applicable | ambiguous
  detail           TEXT,
  checked_at       TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ind_cand ON independent_answer(candidate_id);

-- ── separate AI judge — APPEND-ONLY (semantic/quality review; independence limitations recorded honestly) ──
CREATE TABLE IF NOT EXISTS judge_verdict (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  candidate_id   TEXT NOT NULL REFERENCES candidate(candidate_id),
  item_hash      TEXT NOT NULL,         -- candidate.item_hash at check time (content binding)
  judge_model    TEXT NOT NULL,
  judge_family   TEXT,                  -- factory-3 (R2-1): actor family of the disposing reviewer. `independent`
                                        -- is COMPUTED as judge_family != generator_family, never caller-asserted.
  independent    INTEGER NOT NULL,      -- 0 when same actor family as generator (disclosed, not hidden)
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
CREATE INDEX IF NOT EXISTS idx_judge_cand ON judge_verdict(candidate_id);

-- ── latest-attempt views: the most recent row per candidate, so single-row readers keep working over an
--    append-only history without double-counting older attempts. ────────────────────────────────────────
CREATE VIEW IF NOT EXISTS independent_answer_latest AS
  SELECT ia.* FROM independent_answer ia
  JOIN (SELECT candidate_id, MAX(id) AS mid FROM independent_answer GROUP BY candidate_id) t
    ON t.mid = ia.id;

CREATE VIEW IF NOT EXISTS judge_verdict_latest AS
  SELECT jv.* FROM judge_verdict jv
  JOIN (SELECT candidate_id, MAX(id) AS mid FROM judge_verdict GROUP BY candidate_id) t
    ON t.mid = jv.id;

CREATE VIEW IF NOT EXISTS gate_result_latest AS
  SELECT gr.* FROM gate_result gr
  JOIN (SELECT candidate_id, gate, MAX(id) AS mid FROM gate_result GROUP BY candidate_id, gate) t
    ON t.mid = gr.id;

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
