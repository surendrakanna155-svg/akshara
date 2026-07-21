-- R5-1 [C13] — derived, versioned PREREQUISITE edge-resolution table, built ON TOP of the frozen index.
-- The frozen ki_concept.prerequisites are unkeyed NAME strings; this resolves each to a KC_ concept_id via the
-- certified crosswalk (canonical_name + aliases, subject-scoped). Unresolved OR ambiguous multi-target names are
-- kept as HONEST NULL (never guessed). WRITABLE derived store under KIE_HOME; local-only; deterministic rebuild.
-- The frozen index itself is NEVER written (opened mode=ro) — this is a derived layer, not a foundation change.

CREATE TABLE IF NOT EXISTS prereq_edge (
  concept_id          TEXT NOT NULL,     -- the concept that DECLARES the prerequisite
  subject             TEXT,
  prereq_name         TEXT NOT NULL,     -- the raw prerequisite name string, as stored in the frozen index
  prereq_norm         TEXT NOT NULL,     -- normalized form used for matching
  resolved_concept_id TEXT,              -- KC_ id, or NULL (honest-null: unresolved OR ambiguous)
  resolution_method   TEXT NOT NULL,     -- subject_name | cross_subject_unique | ambiguous | unresolved
  candidate_count     INTEGER NOT NULL,  -- how many DISTINCT concept_ids the name matched (0=unresolved, >1=ambiguous)
  PRIMARY KEY (concept_id, prereq_norm)
);
CREATE INDEX IF NOT EXISTS idx_prereq_resolved ON prereq_edge(resolved_concept_id);
CREATE INDEX IF NOT EXISTS idx_prereq_method   ON prereq_edge(resolution_method);

CREATE TABLE IF NOT EXISTS prereq_meta (key TEXT PRIMARY KEY, value TEXT);

-- R5-2 [C14] — concept-namespace convergence on the KC_ spine. Three live ontologies (KC_ ids, authored
-- "Subject :: topic" governed-fact codes, legacy factory kie.db codes) cannot join for mastery/coverage/dedup.
-- This maps every non-KC_ source concept to its KC_ id (or honest-null), and RETIRES OCR-junk legacy codes so
-- they can never be treated as a real concept. Derived, on TOP of the frozen index; never mutates a source store.
CREATE TABLE IF NOT EXISTS concept_namespace (
  src_ontology  TEXT NOT NULL,       -- governed_fact_topic | factory_legacy_code
  src_id        TEXT NOT NULL,       -- fact_id | (ontology-scoped) concept_code
  src_code      TEXT,                -- the raw code / "Subject :: topic" string
  subject       TEXT,
  resolved_kc   TEXT,                -- KC_ id, or NULL (honest-null: unresolved / ambiguous / retired)
  method        TEXT NOT NULL,       -- topic_name | chapter_fallback | subject_name | cross_subject_unique
                                      --   | already_kc | unknown_kc | ambiguous | unresolved | ocr_junk_retired
  retired       INTEGER NOT NULL DEFAULT 0,  -- 1 = OCR-junk legacy code; never a product concept
  PRIMARY KEY (src_ontology, src_id)
);
CREATE INDEX IF NOT EXISTS idx_ns_resolved ON concept_namespace(resolved_kc);
CREATE INDEX IF NOT EXISTS idx_ns_method   ON concept_namespace(method);
