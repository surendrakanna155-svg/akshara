-- CERTIFIED KNOWLEDGE INDEX — the clean curriculum foundation.
--
-- This REPLACES kie.db `concepts` as QIE's planning input. It does not modify it.
-- kie.db `concepts` is contaminated and is NOT curriculum truth: grade there means
-- "which PDF mentioned this string" (doc-level attribution), subjects are mis-bound
-- (Gauss's law exists as Physics AND Chemistry AND Biology), and front matter, page
-- furniture, activity labels and OCR garbage were all promoted to concepts (a line of
-- the national anthem is an active Class-10 Mathematics concept).
--
-- THE CENTRAL DISTINCTION this schema enforces:
--   mentioned_in_source  — this string appeared somewhere in this document. Weak. Never a boundary.
--   taught_at_class      — this concept is TAUGHT at this class, evidenced by appearing as a
--                          NUMBERED curriculum section of that class's single-subject textbook.
-- Only `taught_at_class` may drive planning. `mentioned_in_source` is provenance only.
--
-- Accepted and rejected knowledge are persisted SEPARATELY and permanently: the rejects are
-- evidence about the corpus (and training signal for the process), not garbage to be discarded.
--
-- Rows are LOCAL-ONLY (curriculum/knowledge/ is gitignored). Only schema + code are committed.
--
-- ═══ THE TWO DIMENSIONS (v2) ═══════════════════════════════════════════════════════════════
-- A concept has TWO independent classifications, and BOTH are preserved. Collapsing them was
-- the v1 error that made integrated Science books unindexable:
--
--   subject             — the CURRICULUM SOURCE: the subject of the book as NCERT published it.
--                         PROVEN from the NCERT filename code. "Science" is a real, honest value
--                         for classes 6-10 — NCERT ships one integrated Science book.
--   academic_discipline — Physics | Chemistry | Biology | Mathematics | Interdisciplinary.
--                         INFERRED from chapter evidence and INDEPENDENTLY AUDITED. NCERT prints
--                         no discipline label inside an integrated book, so this can never be
--                         "proven" the way subject is — it is evidence-grounded inference, and it
--                         carries a basis + confidence + its own audit verdict to say so.
--
-- "NCERT Science Class 8 > Force and Pressure > Pressure" is curriculum source Science AND
-- discipline Physics. Both are true. Neither may overwrite the other.
--
-- CONCEPT ID STABILITY (owner rule 2/3): concept_id hashes (subject, class, canonical_name) —
-- the PROVEN dimension. It deliberately does NOT hash academic_discipline, because re-auditing a
-- discipline must never change an ID that questions, DPP and analytics already reference. It also
-- never hashes filenames, OCR order or row ids.

CREATE TABLE IF NOT EXISTS ki_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);

-- ── the source books this index is built from. subject is PROVABLE from the filename code. ──
CREATE TABLE IF NOT EXISTS ki_source (
  doc_id           TEXT PRIMARY KEY,
  rel_path         TEXT NOT NULL,
  book_code        TEXT,              -- NCERT code, e.g. hemh1dd
  subject          TEXT NOT NULL,     -- CURRICULUM SOURCE subject, DERIVED from the book code, never
                                      -- from source_documents.subject. May be 'Science' (integrated).
  taught_at_class  INTEGER NOT NULL,  -- the class whose textbook this IS (not "mentioned in")
  subject_basis    TEXT NOT NULL,     -- why we trust the subject (the filename-code proof)
  is_integrated    INTEGER NOT NULL DEFAULT 0,  -- 1 = combined Science book; concepts need discipline inference
  chunks           INTEGER,
  created_at       TEXT NOT NULL
);

-- ── chapters: the deterministic spine, from NUMBERED section headings only ──
CREATE TABLE IF NOT EXISTS ki_chapter (
  chapter_id       TEXT PRIMARY KEY,  -- CH_<subject>_<class>_<num>
  subject          TEXT NOT NULL,     -- CURRICULUM SOURCE subject (may be 'Science')
  taught_at_class  INTEGER NOT NULL,
  chapter_no       INTEGER NOT NULL,
  title            TEXT NOT NULL,     -- canonical, cleaned by the knowledge engineer
  raw_titles       TEXT,              -- json: the raw heading strings observed (audit trail)
  doc_id           TEXT NOT NULL REFERENCES ki_source(doc_id),
  -- ── dimension 2: inferred, audited, never proven ──
  academic_discipline    TEXT,        -- Physics|Chemistry|Biology|Mathematics|Interdisciplinary
  discipline_basis       TEXT,        -- the evidence sentence justifying it (REQUIRED when inferred)
  discipline_confidence  REAL,        -- 0..1
  discipline_audit_verdict TEXT,      -- accept | reject | quarantine (independent pass)
  discipline_audit_model   TEXT,
  status           TEXT NOT NULL DEFAULT 'accepted',   -- accepted | rejected
  reject_reason    TEXT,
  created_at       TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ki_ch ON ki_chapter(subject, taught_at_class);
-- indexes on the v2 columns are created by schema.migrate(), AFTER the ALTERs that add them

-- ── concepts: the planning unit. ONE row per canonical concept per (subject, class, chapter) ──
CREATE TABLE IF NOT EXISTS ki_concept (
  concept_id       TEXT PRIMARY KEY,  -- KC_<sha14(subject|class|canonical_name)> — see ID STABILITY above
  chapter_id       TEXT NOT NULL REFERENCES ki_chapter(chapter_id),
  subject          TEXT NOT NULL,     -- CURRICULUM SOURCE subject (may be 'Science') — dimension 1
  taught_at_class  INTEGER NOT NULL,  -- PROVEN: this is that class's own textbook
  canonical_name   TEXT NOT NULL,
  aliases          TEXT,              -- json[]
  sub_concepts     TEXT,              -- json[] — only where the source supports them
  prerequisites    TEXT,              -- json[] — ONLY where evidenced; empty is honest
  boundary         TEXT,              -- json: {in_scope[], out_of_scope[]} at this class
  evidence_chunks  TEXT NOT NULL,     -- json[] chunk_ids — the owned source this rests on
  evidence_pages   TEXT,              -- json[]
  section_heading  TEXT,              -- the numbered heading that proves taught-at
  extraction_basis TEXT,              -- section_path | text | both — HOW the heading was recovered
  -- ── dimension 2: inferred from evidence, independently audited, never proven ──
  academic_discipline    TEXT,        -- Physics|Chemistry|Biology|Mathematics|Interdisciplinary
  discipline_basis       TEXT,        -- evidence justifying it; for single-subject books this is the
                                      -- filename-code proof and confidence is 1.0
  discipline_confidence  REAL,
  engineer_model   TEXT NOT NULL,     -- provenance: proposes only; never self-certifies
  audit_verdict    TEXT,              -- accept | reject | quarantine  (INDEPENDENT second pass)
  audit_reasons    TEXT,
  audit_model      TEXT,
  status           TEXT NOT NULL DEFAULT 'proposed',  -- proposed | certified | rejected | quarantined
  created_at       TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ki_c_scope ON ki_concept(subject, taught_at_class, status);
CREATE INDEX IF NOT EXISTS idx_ki_c_chapter ON ki_concept(chapter_id);
CREATE INDEX IF NOT EXISTS idx_ki_c_name ON ki_concept(canonical_name);
-- idx_ki_c_disc is created by schema.migrate(), AFTER the ALTER that adds academic_discipline

-- ── mentioned_in_source — the WEAK signal, kept strictly apart from taught_at_class ──
-- A concept name appearing in some other book/class. Provenance only. NEVER a curriculum boundary
-- and never a planning input. Exists so "where else does this surface?" is answerable without
-- anyone being tempted to read it as "taught here".
CREATE TABLE IF NOT EXISTS ki_mention (
  concept_id  TEXT NOT NULL REFERENCES ki_concept(concept_id),
  doc_id      TEXT NOT NULL,
  class_label INTEGER,               -- the class of the book it was MENTIONED in
  subject     TEXT,
  chunk_id    TEXT,
  snippet     TEXT,
  created_at  TEXT NOT NULL,
  PRIMARY KEY (concept_id, doc_id, chunk_id)
);
CREATE INDEX IF NOT EXISTS idx_ki_mention_c ON ki_mention(concept_id);

-- ── permanent, honest record of corpus holes. A gap is EVIDENCE, not an error to hide. ──
CREATE TABLE IF NOT EXISTS ki_gap (
  gap_id      TEXT PRIMARY KEY,
  scope       TEXT NOT NULL,         -- e.g. "Chemistry|12|lech2dd"
  kind        TEXT NOT NULL,         -- corrupt_source | no_spine | missing_book | low_yield
  detail      TEXT NOT NULL,
  blocks      TEXT,                  -- what downstream coverage this denies
  created_at  TEXT NOT NULL
);

-- ── REJECTED knowledge — kept permanently and separately. This is evidence, not trash. ──
CREATE TABLE IF NOT EXISTS ki_rejected (
  reject_id        TEXT PRIMARY KEY,
  subject          TEXT,
  taught_at_class  INTEGER,
  raw_label        TEXT NOT NULL,     -- the string that was NOT admitted
  reject_class     TEXT NOT NULL,     -- front_matter | back_matter | page_furniture | activity_label |
                                      -- ocr_garbage | answer_apparatus | truncated_heading | not_a_concept |
                                      -- unsupported | duplicate
  reason           TEXT,
  source_ref       TEXT,              -- json: doc_id/chunk/section
  rejected_by      TEXT NOT NULL,     -- deterministic | engineer(<model>) | audit(<model>)
  created_at       TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ki_rej ON ki_rejected(reject_class);

-- ── RESUMABILITY ledger — the process must survive being stopped at any point ──
-- One row per (scope, stage). `scope` is a book (doc_id) or a discipline slice. A stage is only
-- marked `done` after its rows are committed, so a resume re-runs exactly what did not finish.
CREATE TABLE IF NOT EXISTS ki_progress (
  scope       TEXT NOT NULL,         -- doc_id | "<Discipline>|<class>" | "<Discipline>"
  stage       TEXT NOT NULL,         -- spine | engineer | audit | discipline | discipline_audit | report
  status      TEXT NOT NULL,         -- pending | in_progress | done | blocked
  detail      TEXT,
  updated_at  TEXT NOT NULL,
  PRIMARY KEY (scope, stage)
);
CREATE INDEX IF NOT EXISTS idx_ki_prog ON ki_progress(stage, status);

-- ── run telemetry ──
CREATE TABLE IF NOT EXISTS ki_run (
  run_id      TEXT NOT NULL,
  stage       TEXT NOT NULL,
  model       TEXT,
  items       INTEGER,
  tokens      INTEGER,
  wall_seconds REAL,
  note        TEXT,
  recorded_at TEXT NOT NULL,
  PRIMARY KEY (run_id, stage)
);
