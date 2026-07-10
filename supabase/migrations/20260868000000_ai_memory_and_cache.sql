-- Adaptive AI — P3-AI-1 / W1.2: memory stores + response cache.
--
-- The cost moat (design doc 03). Four tenant-scoped tables + interaction-memory
-- columns on the existing ai_copilot_sessions. All follow the proven intel_*
-- RLS pattern (org+school, ENABLE + FORCE, USING + WITH CHECK, erp_tenant
-- grants). Additive/dormant: no existing row is touched; ai_copilot_sessions
-- gains only nullable/defaulted columns.
--
-- W1 uses ai_response_cache now (Tier-2 write-through, wired into the Model
-- Gateway). ai_fact_signals is populated by the Signal Refinery (W1.4);
-- ai_school_profile (learned thresholds) and ai_persona_memory (preferences /
-- recommendation feedback) are the substrate for the W2 adaptive wave — landed
-- here as schema so the RLS/isolation suite covers them from the start.

-- ─── ai_response_cache (Tier-2 exact-key cache) ──────────────────────────────

CREATE TABLE ai_response_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  cache_key TEXT NOT NULL,
  surface TEXT NOT NULL DEFAULT '',
  language TEXT NOT NULL DEFAULT 'english',
  payload TEXT NOT NULL,
  entity_tags TEXT[] NOT NULL DEFAULT '{}',
  model TEXT NOT NULL DEFAULT '',
  tokens_saved INT NOT NULL DEFAULT 0 CHECK (tokens_saved >= 0),
  hit_count INT NOT NULL DEFAULT 0 CHECK (hit_count >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  expires_at TIMESTAMPTZ,
  UNIQUE (organization_id, school_id, cache_key)
);

CREATE INDEX idx_ai_response_cache_lookup
  ON ai_response_cache (organization_id, school_id, cache_key);
CREATE INDEX idx_ai_response_cache_tags
  ON ai_response_cache USING GIN (entity_tags);
CREATE INDEX idx_ai_response_cache_expiry
  ON ai_response_cache (expires_at);

ALTER TABLE ai_response_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_response_cache FORCE ROW LEVEL SECURITY;

CREATE POLICY ai_response_cache_school_scope ON ai_response_cache
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

GRANT SELECT, INSERT, UPDATE, DELETE ON ai_response_cache TO erp_tenant;

-- ─── ai_school_profile (learned per-school defaults; one row per school) ──────

CREATE TABLE ai_school_profile (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  profile JSONB NOT NULL DEFAULT '{}'::jsonb,
  learned_thresholds JSONB NOT NULL DEFAULT '{}'::jsonb,
  profile_version INT NOT NULL DEFAULT 1 CHECK (profile_version >= 1),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id)
);

ALTER TABLE ai_school_profile ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_school_profile FORCE ROW LEVEL SECURITY;

CREATE POLICY ai_school_profile_school_scope ON ai_school_profile
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

GRANT SELECT, INSERT, UPDATE ON ai_school_profile TO erp_tenant;

-- ─── ai_persona_memory (per-user preferences + feedback; one row per user) ────

CREATE TABLE ai_persona_memory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  user_id UUID NOT NULL REFERENCES users (id),
  preferences JSONB NOT NULL DEFAULT '{}'::jsonb,
  recommendation_feedback JSONB NOT NULL DEFAULT '{}'::jsonb,
  usage_stats JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, user_id)
);

ALTER TABLE ai_persona_memory ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_persona_memory FORCE ROW LEVEL SECURITY;

CREATE POLICY ai_persona_memory_user_scope ON ai_persona_memory
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
    AND user_id = app_current_user_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
    AND user_id = app_current_user_id()
  );

GRANT SELECT, INSERT, UPDATE ON ai_persona_memory TO erp_tenant;

-- ─── ai_fact_signals (materialized rollups; Signal Refinery target, W1.4) ─────

CREATE TABLE ai_fact_signals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  signal_type TEXT NOT NULL,
  scope_key TEXT NOT NULL DEFAULT '',
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  computed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, signal_type, scope_key)
);

CREATE INDEX idx_ai_fact_signals_lookup
  ON ai_fact_signals (organization_id, school_id, signal_type, scope_key);

ALTER TABLE ai_fact_signals ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_fact_signals FORCE ROW LEVEL SECURITY;

CREATE POLICY ai_fact_signals_school_scope ON ai_fact_signals
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

GRANT SELECT, INSERT, UPDATE, DELETE ON ai_fact_signals TO erp_tenant;

-- ─── Interaction Memory: extend ai_copilot_sessions (additive, defaulted) ─────

ALTER TABLE ai_copilot_sessions
  ADD COLUMN IF NOT EXISTS rolling_summary TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS summary_updated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS summarized_message_count INT NOT NULL DEFAULT 0;
