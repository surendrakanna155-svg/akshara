-- ASIP — Phase 2, migration: ASIP-8 Continuous Learning knowledge base.
--
-- Resolved incidents/clusters feed a knowledge base that improves FUTURE
-- diagnosis. The KB lives entirely inside the platform-support mirror domain
-- (Owner Decision A1): every row is scoped to the fixed PLATFORM_ORG and carries
-- the SAME RLS as support_platform_incident — a school session can never read or
-- write it; only a PLATFORM_ORG (support) session can. Because both the learn
-- (on resolve) and the recall (on investigate/detail) run under a support
-- session, no SECURITY DEFINER bridge is needed here — the org wall is untouched.
--
-- Recall is DETERMINISTIC-FIRST: an article is keyed by the same deterministic
-- cluster fingerprint (category|module|error-signature) the clustering engine
-- uses, so "investigate once, resolve many" becomes "remember forever" — a new
-- incident with the same signature recalls the prior resolution by exact key,
-- no embeddings required. Semantic recall (support_kb_embedding, pgvector) is an
-- OPTIONAL similarity layer that stays fully dormant when pgvector or an
-- embeddings provider is absent, exactly like the W2.8 semantic cache — the
-- deterministic KB is unaffected.
--
-- Additive; PLATFORM_ORG must already be seeded for the tables to receive rows
-- (owner/deploy-gated, same as the rest of Phase 2).

-- ─── KB article (one per resolved signature; deterministic recall key) ─────────

CREATE TABLE support_kb_article (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform_org_id UUID NOT NULL,

  -- Deterministic recall key = clusterFingerprint(category, module, signature).
  -- One active article per fingerprint per platform org (idempotent learning).
  fingerprint TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'unknown',
  module_key TEXT,
  error_signature TEXT NOT NULL DEFAULT 'none',

  title TEXT NOT NULL DEFAULT '',
  root_cause TEXT NOT NULL DEFAULT '',
  resolution TEXT NOT NULL DEFAULT '',

  -- Provenance: the incident/cluster whose resolution produced (last updated)
  -- this article, and how broadly the signature has been seen.
  source_incident_ref TEXT,
  source_cluster_id UUID,
  resolved_count INT NOT NULL DEFAULT 1,   -- times this signature was resolved
  schools_seen INT NOT NULL DEFAULT 1,     -- widest cluster breadth at resolution

  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'archived')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),

  CONSTRAINT support_kb_article_fp_uq UNIQUE (platform_org_id, fingerprint),
  CONSTRAINT support_kb_article_title_len_ck CHECK (char_length(title) <= 400),
  CONSTRAINT support_kb_article_res_len_ck CHECK (char_length(resolution) <= 4000)
);

-- Deterministic recall reads by (category, module_key); the "related" fallback
-- scans this prefix. Recency/frequency ordering uses updated_at/resolved_count.
CREATE INDEX idx_support_kb_article_lookup
  ON support_kb_article (platform_org_id, category, module_key);
CREATE INDEX idx_support_kb_article_recent
  ON support_kb_article (platform_org_id, status, updated_at DESC);

ALTER TABLE support_kb_article ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_kb_article FORCE ROW LEVEL SECURITY;

-- Identical wall to the mirror: readable/writable ONLY by a PLATFORM_ORG session.
CREATE POLICY support_kb_article_platform_scope ON support_kb_article
  FOR ALL
  USING (
    app_current_tenant_id() = app_support_platform_org()
    AND platform_org_id = app_support_platform_org()
  )
  WITH CHECK (
    app_current_tenant_id() = app_support_platform_org()
    AND platform_org_id = app_support_platform_org()
  );

GRANT SELECT, INSERT, UPDATE ON support_kb_article TO erp_tenant;

-- ─── KB embedding (OPTIONAL semantic recall — dormant without pgvector) ─────────

-- Defensive by design (same lesson as 20260876 ai_semantic_cache): pgvector may
-- not be provisioned on the pilot Postgres. The embedding table+policy are
-- created ONLY when the 'vector' extension is available; otherwise nothing is
-- created and deterministic KB recall carries the whole feature. The runtime
-- probes for the table (to_regclass) and keeps semantic recall dormant when
-- absent. Provisioning pgvector is an ops task, never a precondition of this
-- bundle.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'vector') THEN
    CREATE EXTENSION IF NOT EXISTS vector;

    -- 1024 dims = the supported embedding models' default (embeddings_client.ts);
    -- a provider change that alters dimensionality is a new migration.
    CREATE TABLE IF NOT EXISTS support_kb_embedding (
      article_id UUID PRIMARY KEY
        REFERENCES support_kb_article (id) ON DELETE CASCADE,
      platform_org_id UUID NOT NULL,
      embedding vector(1024) NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
    );

    ALTER TABLE support_kb_embedding ENABLE ROW LEVEL SECURITY;
    ALTER TABLE support_kb_embedding FORCE ROW LEVEL SECURITY;

    CREATE POLICY support_kb_embedding_platform_scope ON support_kb_embedding
      FOR ALL
      USING (
        app_current_tenant_id() = app_support_platform_org()
        AND platform_org_id = app_support_platform_org()
      )
      WITH CHECK (
        app_current_tenant_id() = app_support_platform_org()
        AND platform_org_id = app_support_platform_org()
      );

    GRANT SELECT, INSERT, UPDATE, DELETE ON support_kb_embedding TO erp_tenant;
  ELSE
    RAISE NOTICE 'pgvector unavailable — ASIP-8 KB semantic recall stays dormant; deterministic recall is unaffected';
  END IF;
END
$$;
