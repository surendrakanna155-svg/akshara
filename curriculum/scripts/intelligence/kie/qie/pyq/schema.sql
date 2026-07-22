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

-- ── B2 — subject attribution (per minable chunk of an eligible genuine_pyq doc) ──────────────────────────
-- OD-4: subject is determined from the SOURCE DOCUMENT's own structure (its subject-section headers), BEFORE
-- any concept resolution, and NEVER from a legacy concept-code prefix. A subject-section header ("PART I :
-- PHYSICS", "Physics : Section-A", "BOTANY SECTION") sets the CURRENT subject for the chunks that follow, in
-- document order, until the next header. Chunks before the first header (or in a doc with no header) are
-- honest-null (subject NULL) — never guessed. B3 inherits each extracted question's subject from its chunk.
CREATE TABLE IF NOT EXISTS pyq_chunk_subject (
  doc_id        TEXT NOT NULL,
  ordinal       INTEGER NOT NULL,
  subject       TEXT,              -- Physics | Chemistry | Mathematics | Biology | NULL (honest-null)
  subject_method TEXT NOT NULL,    -- section_path | text_header | continuation | inherited_from_header | mixed_boundary | honest_null
                                    --   (continuation: a deep header repeating the CURRENT subject — a sub-section/per-question tag, not a boundary)
                                    --   (mixed_boundary: chunk straddles a subject boundary → honest-null, no single subject is correct)
  is_header     INTEGER NOT NULL DEFAULT 0,   -- 1 = this chunk IS the subject-section header that set the subject
  PRIMARY KEY (doc_id, ordinal)
);
CREATE INDEX IF NOT EXISTS idx_pcs_subject ON pyq_chunk_subject(subject);

-- ── B3 — re-mined question INSTANCES with a DETERMINISTIC PROVENANCE CHAIN (OD-2) ─────────────────────────
-- Each row is ONE question INSTANCE, reconstructable end-to-end: item → chunk_ids → doc_id → (exam, year via B1)
-- → (subject via B2). A row exists ONLY with that chain; anything unreconstructable is not a row (never a
-- phantom). A marker becomes a question only if its BOUNDED span has real question STRUCTURE (≥3 MCQ options, or
-- numerical/assertion/match), is READABLE (rejects OCR garble / non-English papers), and is not an instruction
-- block (rejects exam instructions, NTA notices, syllabus/experiment lists). NOTE: one PDF may hold several
-- BOOKLET CODES / a solutions restatement of the same paper → the same question yields several INSTANCES; exact
-- + content-fingerprint (`stem_fp`) within-doc dedup collapses what it safely can, and B5 dedups corpus-wide by
-- `stem_fp` + counts DISTINCT DOCS for the OD-5 N≥30 floor + normalizes per-doc, so instance duplication never
-- distorts a measured distribution.
CREATE TABLE IF NOT EXISTS pyq_item (
  item_id        TEXT PRIMARY KEY,   -- content-addressed: sha256(doc_id|qnum|span_sha)[:16]
  doc_id         TEXT NOT NULL,
  exam           TEXT NOT NULL,      -- from B1 (eligible ⇒ resolved)
  year           INTEGER,            -- from B1 (honest-null)
  subject        TEXT,               -- from B2 pyq_chunk_subject of the marker's chunk (honest-null)
  question_number INTEGER,
  question_type  TEXT NOT NULL,      -- mcq | numerical | assertion_reason | match | short_answer | unknown
  type_method    TEXT NOT NULL,
  concept_kc     TEXT,               -- subject-scoped resolution (honest-null unless a certified name is present verbatim)
  concept_method TEXT NOT NULL,
  chunk_ids      TEXT NOT NULL,      -- json ["<doc_id>#<ordinal>", …] — the chunk(s) this question spans (provenance)
  chunk_sha256   TEXT NOT NULL,      -- json of the spanned chunks' sha256 (content-addressed, RI-2 style)
  span_len       INTEGER NOT NULL,
  stem_fp        TEXT,               -- OCR-tolerant content fingerprint (longest words) for corpus-wide dedup at B5
  ocr_flagged    INTEGER NOT NULL DEFAULT 0,  -- reserved; kept items are readable-by-construction (0)
  extraction_confidence TEXT NOT NULL,        -- high | medium | low (per-doc: kept questions / candidate markers)
  created_at     TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_item_stemfp ON pyq_item(stem_fp);
CREATE INDEX IF NOT EXISTS idx_item_exam    ON pyq_item(exam);
CREATE INDEX IF NOT EXISTS idx_item_subject ON pyq_item(subject);
CREATE INDEX IF NOT EXISTS idx_item_type    ON pyq_item(question_type);
CREATE INDEX IF NOT EXISTS idx_item_concept ON pyq_item(concept_kc);

-- ── B4 — structural difficulty (OD-3: STRUCTURAL only; NEVER a measured student-difficulty claim) ─────────
-- A deterministic complexity PROXY from a question's own structure (question TYPE + span LENGTH only — coarse
-- by design). `difficulty_basis` is ALWAYS 'structural_proxy' — measured (pilot p-value) difficulty
-- stays honest-null until the ERP response spine has pilot data (roadmap R5-5). B5 surfaces this as a labelled
-- structural distribution, distinct from any measured one.
CREATE TABLE IF NOT EXISTS pyq_item_difficulty (
  item_id          TEXT PRIMARY KEY,   -- FK → pyq_item.item_id
  difficulty_label TEXT NOT NULL,      -- easy | moderate | hard
  difficulty_basis TEXT NOT NULL,      -- structural_proxy (never 'measured' / 'pilot')
  complexity_score INTEGER NOT NULL,
  signals          TEXT
);
CREATE INDEX IF NOT EXISTS idx_diff_label ON pyq_item_difficulty(difficulty_label);

-- ── B4 — marking scheme (OD-6: parsed-from-paper where stated; published fallback; else honest-null) ──────
-- A row per (exam, question_type) where a scheme can be established. Marks a paper STATES are `parsed_from_paper`;
-- a stable, well-known official scheme fills a gap as `published`; anything variable/unknown (e.g. JEE Advanced's
-- section-dependent partial marking, JEE Main numerical negative-marking that changed by year) is honest-null —
-- never fabricated. B5 gates any "exam-representative marks" claim on this.
CREATE TABLE IF NOT EXISTS marking_scheme (
  exam             TEXT NOT NULL,
  question_type    TEXT NOT NULL,      -- mcq | numerical | assertion_reason | match | any
  marks_correct    INTEGER,            -- NULL honest-null
  marks_incorrect  INTEGER,            -- NULL honest-null (e.g. no negative marking); 0 = explicitly no penalty
  partial_rule     TEXT,               -- e.g. 'none' | 'partial_jee_adv' | honest-null
  provenance_class TEXT NOT NULL,      -- parsed_from_paper | published | honest_null
  source_doc_id    TEXT,               -- when parsed_from_paper
  n_docs_evidence  INTEGER,            -- how many eligible docs stated a consistent scheme (parsed)
  note             TEXT,
  PRIMARY KEY (exam, question_type)
);

CREATE TABLE IF NOT EXISTS pyq_meta (key TEXT PRIMARY KEY, value TEXT);
