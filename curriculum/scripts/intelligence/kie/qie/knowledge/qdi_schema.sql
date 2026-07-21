-- CERTIFIED QUESTION DESIGN INTELLIGENCE (QDI)
--
-- DISTINCT FROM, AND COMPLEMENTARY TO, THE CERTIFIED KNOWLEDGE INDEX (ki_*).
--   ki_*   answers: WHAT may legitimately be asked at this class/subject? (curriculum boundary + evidence)
--   qdi_*  answers: HOW is a genuinely good question of this kind BUILT?    (design structure from real exams)
-- Concept-only generation is insufficient for top-quality JEE/NEET, hard/twisted items and genuine
-- multi-concept composition. Those two layers together feed the QIE planner. Neither replaces the other.
--
-- WHY A NEW LAYER RATHER THAN REUSING question_dna / question_patterns:
-- both exist but are structurally empty for this purpose (measured, not assumed):
--   qie.db question_dna   : 2996 rows, construction = {"relation":"sum_n","answer":3.0}; distractor
--                           transforms are the literal string "other" with numeric deltas; provenance EMPTY;
--                           solution_dna 0/2996; difficulty_drivers 0/2996.
--   kie.db question_patterns: 4853 rows, stem_skeleton = "mcq|bloom=analyze|difficulty=hard|options=4"
--                           — a metadata string, not a structure. All rows exam='foundation', subject ''.
-- The RAW material, however, is owned and already chunked (no re-download, no re-OCR): ~20k chunks of real
-- NEET/JEE-Main/JEE-Advanced/AIIMS papers, many carrying the question AND its answer/solution.
--
-- HARD RULES (locked by the owner):
--   * NEVER copy source-question wording. No source stem, option text, or phrasing is stored as a template.
--     Only ABSTRACT STRUCTURE is stored: what mechanism made the question work.
--   * AI interpretation is NOT automatic truth. A pattern is `proposed` until an INDEPENDENT audit accepts it.
--   * Source provenance is preserved on every pattern (doc_id/chunk_id/exam/year) so any claim is traceable.
--
-- Rows are LOCAL-ONLY (curriculum/knowledge/ is gitignored). Only schema + code are committed.

CREATE TABLE IF NOT EXISTS qdi_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);

-- ── the real-exam sources design intelligence was learned FROM (provenance, never wording) ──
CREATE TABLE IF NOT EXISTS qdi_source (
  doc_id       TEXT PRIMARY KEY,
  rel_path     TEXT NOT NULL,
  exam         TEXT,              -- NEET | JEE_Main | JEE_Advanced | AIIMS
  subject      TEXT,
  year         INTEGER,
  chunks       INTEGER,
  created_at   TEXT NOT NULL
);

-- ── a certified DESIGN PATTERN: the abstract machinery of a good question, not the question ──
CREATE TABLE IF NOT EXISTS qdi_pattern (
  pattern_id        TEXT PRIMARY KEY,     -- QDP_<hash>
  exam              TEXT NOT NULL,        -- the exam whose real items evidence this pattern
  subject           TEXT NOT NULL,
  archetype         TEXT NOT NULL,        -- kie.qie.archetypes.ARCHETYPES (proven, not invented)
  pattern_name      TEXT NOT NULL,        -- e.g. "switched-capacitor energy redistribution"
  design_summary    TEXT NOT NULL,        -- ABSTRACT: how this kind of item is constructed. No source wording.

  -- what makes it a real multi-concept item rather than a relabelled single-concept one
  concept_roles     TEXT,                 -- json[]: [{role, what_it_contributes}] — roles, not concept names
  composition_kind  TEXT,                 -- single | sequential_chain | constraint_coupled | state_change | ...
  dependency        TEXT,                 -- json: how concept B consumes concept A's output (the real link)

  -- the reasoning machinery
  reasoning_chain   TEXT,                 -- json[]: ordered abstract steps (no numbers, no wording)
  step_depth        INTEGER,              -- earned from the chain length, not asserted
  operators         TEXT,                 -- json[]: operators/relations applied between concepts
  constraints       TEXT,                 -- json[]: constraint structures that must hold

  -- what makes it hard / twisted (the owner's explicit target)
  difficulty_mechanism TEXT,              -- json[]: e.g. ["non-obvious intermediate", "state change mid-problem"]
  transformation    TEXT,                 -- json[]: information transformation / indirect presentation patterns
  difficulty_band   TEXT,                 -- easy | moderate | hard  (evidenced from the real item's role)

  -- distractor + misconception structure
  distractor_structure TEXT,              -- json[]: [{misconception, produces}] — NAMED, not "other"
  misconceptions    TEXT,                 -- json[]

  -- visual + solution structure
  visual_archetype  TEXT,                 -- null | geometry | circuit | ray | graph | force_diagram | schematic
  visual_necessity  TEXT,                 -- required | optional | decorative(reject)
  solution_structure TEXT,                -- json[]: abstract solution shape that works for this pattern

  -- provenance + governance
  evidence_refs     TEXT NOT NULL,        -- json[]: [{doc_id, chunk_id, exam, year}] — traceable, no wording
  evidence_count    INTEGER NOT NULL DEFAULT 1,   -- COMPUTED from evidence_refs (item count), never analyst-asserted
  evidence_resource_count INTEGER,        -- R1-3: distinct evidence doc_id count, COMPUTED at ingest (>=2 required)
  analyst_model     TEXT NOT NULL,        -- proposes only; never self-certifies
  audit_verdict     TEXT,                 -- accept | reject | quarantine (INDEPENDENT second pass)
  audit_reasons     TEXT,
  audit_model       TEXT,
  -- R1-3 deterministic-floor evidence: a pattern may be certified ONLY if the mandatory floor ran and passed
  -- (anti-copy fetched real evidence AND the exam+subject provenance invariant held). NULL => floor never
  -- cleared this pattern; ingest_qdi_audit refuses to certify it.
  floor_passed_at   TEXT,                 -- ISO ts stamped ONLY by deterministic_floor on a genuine pass
  provenance_verified INTEGER DEFAULT 0,  -- 1 only when every ref's doc canonical exam+chunk subject == pattern
  status            TEXT NOT NULL DEFAULT 'proposed',  -- proposed | certified | rejected | quarantined
  created_at        TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_qdp_scope ON qdi_pattern(exam, subject, status);
CREATE INDEX IF NOT EXISTS idx_qdp_arch ON qdi_pattern(archetype, status);
CREATE INDEX IF NOT EXISTS idx_qdp_diff ON qdi_pattern(difficulty_band, status);

-- ── rejected design intelligence — kept separately and permanently (evidence, not trash) ──
CREATE TABLE IF NOT EXISTS qdi_rejected (
  reject_id     TEXT PRIMARY KEY,
  exam          TEXT,
  subject       TEXT,
  pattern_name  TEXT,
  reject_class  TEXT NOT NULL,   -- copies_source_wording | not_a_pattern | unsupported_by_evidence |
                                 -- relabelled_single_concept | ocr_garbage | duplicate | fabricated
  reason        TEXT,
  evidence_refs TEXT,
  rejected_by   TEXT NOT NULL,   -- deterministic | analyst(<model>) | audit(<model>)
  created_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_qdr ON qdi_rejected(reject_class);

-- ── which certified patterns are legal for a given curriculum scope (the join to ki_*) ──
-- A pattern is only usable where the curriculum layer says its machinery is in-scope. This is the
-- explicit seam between "HOW to build a good question" and "WHAT may be asked at this class".
CREATE TABLE IF NOT EXISTS qdi_scope_link (
  pattern_id   TEXT NOT NULL REFERENCES qdi_pattern(pattern_id),
  subject      TEXT NOT NULL,
  min_class    INTEGER,          -- earliest class whose certified boundary supports this machinery
  exam_profile TEXT,             -- SCHOOL | JEE_MAIN | JEE_ADVANCED | NEET
  basis        TEXT,             -- why this pattern is legal at this scope
  PRIMARY KEY (pattern_id, subject, exam_profile)
);
