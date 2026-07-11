-- Adaptive AI — P3-AI-3 / W2.8: Stage-2 semantic cache substrate (pgvector).
--
-- Stage 1 (W1.5) collapses paraphrases via deterministic intent
-- fingerprinting into ai_response_cache's exact-key lookup. Stage 2 (doc 03
-- §3.2) adds embedding-nearest matching over the SAME cached answers, per
-- school+surface+language: on a Stage-1 miss the gateway embeds the question
-- and serves the nearest unexpired cached payload within a cosine-distance
-- threshold. Embedding rows are school-scoped (RLS mirrors ai_response_cache)
-- and each row keys back to its ai_response_cache entry by cache_key.
--
-- DEFENSIVE BY DESIGN (audit round-2 lesson: a migration must never abort the
-- deploy bundle over an environment assumption): pgvector may not be
-- installed on the pilot Postgres. The whole feature is created ONLY when the
-- 'vector' extension is available; otherwise this migration logs a NOTICE and
-- creates nothing. The application probes for the table at runtime
-- (to_regclass) and keeps Stage-2 dormant when absent — Stage-1 and the live
-- model path are unaffected. Provisioning pgvector is an ops task on the
-- LIVE-1 ledger, not a precondition of this bundle.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'vector') THEN
    CREATE EXTENSION IF NOT EXISTS vector;

    -- 1024 dims = the default of the supported embedding models (see
    -- embeddings_client.ts); a provider change that alters dimensionality is
    -- a new migration, not a config flip.
    CREATE TABLE IF NOT EXISTS ai_semantic_cache_embeddings (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      organization_id UUID NOT NULL REFERENCES organizations (id),
      school_id UUID NOT NULL REFERENCES schools (id),
      cache_key TEXT NOT NULL,
      surface TEXT NOT NULL DEFAULT '',
      language TEXT NOT NULL DEFAULT 'english',
      -- SHA-256 of the normalized question text — the "embedding calls are
      -- themselves cached by text hash" rule (doc 03 §3.2): the same question
      -- never pays for a second embedding call.
      question_hash TEXT NOT NULL,
      embedding vector(1024) NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
      UNIQUE (organization_id, school_id, question_hash)
    );

    -- Nearest-neighbor scans are per (school, surface, language) and pilot
    -- cardinality is hundreds of rows per school — an exact scan under this
    -- btree prefilter beats maintaining an ANN index; add HNSW when a school
    -- crosses ~50k cached answers.
    CREATE INDEX IF NOT EXISTS idx_ai_semantic_cache_scope
      ON ai_semantic_cache_embeddings (organization_id, school_id, surface, language);

    ALTER TABLE ai_semantic_cache_embeddings ENABLE ROW LEVEL SECURITY;
    ALTER TABLE ai_semantic_cache_embeddings FORCE ROW LEVEL SECURITY;

    CREATE POLICY ai_semantic_cache_school_scope ON ai_semantic_cache_embeddings
      FOR ALL
      USING (
        organization_id = app_current_tenant_id()
        AND app_current_scope() = 'school'
        AND school_id = app_current_school_id()
      )
      WITH CHECK (
        organization_id = app_current_tenant_id()
        AND app_current_scope() = 'school'
        AND school_id = app_current_school_id()
      );

    GRANT SELECT, INSERT, DELETE ON ai_semantic_cache_embeddings TO erp_tenant;
  ELSE
    RAISE NOTICE 'pgvector unavailable — W2.8 semantic cache stays dormant (provision the vector extension, then re-run this migration)';
  END IF;
END
$$;
