-- Program B (PYQ Re-attribution & Re-mining) — DERIVED store `pyq_corpus.db`.
-- Built ON TOP of the FROZEN kie.db (opened mode=ro): the frozen substrate is NEVER written. Local-only
-- (gitignored), deterministic rebuild, versioned to (frozen_fingerprint, corpus_fingerprint). This store holds
-- ALL Program B output so examdna.db v1 is left byte-identical (OD-6: never mutate a previously certified dataset).

-- ── B1 — corpus role classification (one row per kie.db source_documents.doc_id) ─────────────────────────
-- Reconstructs the provenance the ingester discarded: it lifted only the TOP path folder into `category`
-- (so 861 docs read `exam='Cursor_Downloads'`, a dump folder — defect D5). This re-derives role/exam/year from
-- the FULL rel_path + the doc's own content chunks, FAIL-CLOSED: a folder token never assigns an exam; a
-- path/content conflict → honest-null. OD-1: only genuine_pyq feeds exam DNA; dpp/mock/practice are separate.
CREATE TABLE IF NOT EXISTS pyq_source_class (
  doc_id            TEXT PRIMARY KEY,
  rel_path          TEXT,
  source_role       TEXT NOT NULL,   -- genuine_pyq | practice_dpp | mock | sample_paper | textbook | solution_key | unknown
  role_method       TEXT NOT NULL,   -- how the role was decided (doc_type / path-archive / content)
  source_authority  TEXT,            -- official | third_party | unknown  (jeeadv.ac.in archive = official; mirrors = third_party)
  exam_resolved     TEXT,            -- NEET | JEE_MAIN | JEE_ADVANCED | AIPMT | AIIMS | NULL (honest-null)
  exam_family       TEXT,            -- NEET | JEE | NULL   (AIPMT/AIIMS → NEET family; recorded, never collapsed on exam_resolved)
  exam_method       TEXT NOT NULL,   -- path_content_corroborated | path_token | content_only | content_disambiguated | ambiguous | honest_null
  subject_hint      TEXT,            -- doc-level subject IF the doc is unambiguously single-subject; else NULL (full papers are multi-subject → resolved per-question at B2/B3)
  subject_method    TEXT NOT NULL,   -- source_doc_single | multi_subject_defer | honest_null
  year_resolved     INTEGER,         -- NULL honest-null
  year_method       TEXT NOT NULL,   -- source_doc | path_or_filename | honest_null | ambiguous
  eligible_for_dna  INTEGER NOT NULL DEFAULT 0,  -- 1 IFF source_role='genuine_pyq' AND exam_resolved IS NOT NULL AND not an aptitude sub-test
  signals           TEXT,            -- json: raw signals captured (path tokens, content exam hits) for audit
  created_at        TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_psc_role     ON pyq_source_class(source_role);
CREATE INDEX IF NOT EXISTS idx_psc_exam     ON pyq_source_class(exam_resolved);
CREATE INDEX IF NOT EXISTS idx_psc_eligible ON pyq_source_class(eligible_for_dna);

CREATE TABLE IF NOT EXISTS pyq_meta (key TEXT PRIMARY KEY, value TEXT);
