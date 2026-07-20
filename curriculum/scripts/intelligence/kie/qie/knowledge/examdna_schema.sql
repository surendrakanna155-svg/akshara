-- Exam DNA — certified per-exam PLANNING distributions (JEE Main / JEE Advanced / NEET).
--
-- A SEPARATE store (examdna.db). The frozen knowledge_index.db (v1.4) is immutable and is NEVER written
-- from here; this schema only READS it (chapter lists, certified concept counts) to compute weights.
--
-- HONEST PROVENANCE (the standing law: wrong knowledge is worse than missing knowledge):
--   provenance_class distinguishes what a row actually is —
--     published            : real published exam structure (subject weightage from qpgen/blueprints.py)
--     evidence_proportional : COMPUTED from the frozen index (chapter weight = certified concept share);
--                             honest, reproducible, NOT PYQ-measured
--     derived_from_profiles : archetype mix derived from the curated profiles.py allow-lists
--     curated_prior         : an authored planning prior from documented exam CHARACTER (difficulty / depth);
--                             a defensible estimate, explicitly NOT a measured statistic
--   status:  curated  = passed the structural + provenance-honesty gates (what v1 is)
--            certified = reserved for MINED + independently-audited evidence (v2, the "then mine" phase)
--
-- No curated_prior row may ever be relabelled as a measurement. The mining phase replaces the estimated
-- dimensions in place, bumping the version and the provenance_class to a measured class.

CREATE TABLE IF NOT EXISTS examdna_meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- WEIGHTAGE: how planning mass is split across subjects, and within a subject across chapters.
CREATE TABLE IF NOT EXISTS exam_weight (
  exam             TEXT NOT NULL,          -- JEE_MAIN | JEE_ADVANCED | NEET
  subject          TEXT NOT NULL,          -- Physics | Chemistry | Biology | Mathematics
  scope_type       TEXT NOT NULL,          -- subject | chapter
  scope_id         TEXT NOT NULL,          -- '' for subject-level; chapter_id for chapter-level
  scope_label      TEXT,                   -- human-readable subject name / chapter title
  weight           REAL NOT NULL,          -- >= 0; per (exam, subject, scope_type) group sums to ~1.0
  basis            TEXT NOT NULL,          -- honest one-line provenance
  provenance_class TEXT NOT NULL,          -- published | evidence_proportional | curated_prior
  version          TEXT NOT NULL,          -- exam-DNA version (e.g. v1)
  status           TEXT NOT NULL DEFAULT 'curated',  -- curated | certified
  created_at       TEXT NOT NULL,
  PRIMARY KEY (exam, subject, scope_type, scope_id)
);
CREATE INDEX IF NOT EXISTS idx_ew_scope ON exam_weight(exam, subject, scope_type);

-- DISTRIBUTIONS: the target mix across difficulty / reasoning-depth / archetype buckets.
CREATE TABLE IF NOT EXISTS exam_distribution (
  exam             TEXT NOT NULL,
  subject          TEXT NOT NULL,          -- '' for exam-wide; else per-subject
  dimension        TEXT NOT NULL,          -- difficulty | depth | archetype
  bucket           TEXT NOT NULL,          -- easy|moderate|hard  |  1..5  |  archetype name
  probability      REAL NOT NULL,          -- >= 0; per (exam, subject, dimension) sums to ~1.0
  basis            TEXT NOT NULL,
  provenance_class TEXT NOT NULL,          -- published | derived_from_profiles | curated_prior
  version          TEXT NOT NULL,
  status           TEXT NOT NULL DEFAULT 'curated',
  created_at       TEXT NOT NULL,
  PRIMARY KEY (exam, subject, dimension, bucket)
);
CREATE INDEX IF NOT EXISTS idx_ed_dim ON exam_distribution(exam, subject, dimension);
