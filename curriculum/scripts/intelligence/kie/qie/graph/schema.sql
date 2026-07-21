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
