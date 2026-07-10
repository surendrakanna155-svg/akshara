-- Adaptive AI — P3-AI-1 / W1.1: Model Gateway telemetry (append-only)
--
-- One row per governed model-gateway invocation (see
-- supabase/functions/_shared/ai/model_gateway.ts). This is the single
-- telemetry sink that closes audit findings AI-1 (no spend visibility) and
-- AI-3/AI-4 (no timeout/no-key observability): it records every T3 attempt
-- — served, refused, or fallback — with tokens, estimated cost, latency and
-- outcome, so rate-limit and monthly spend-cap decisions can be computed from
-- it and the Control Center can render per-tenant AI economics (N10 / W1.5).
--
-- Append-only: erp_tenant is granted SELECT + INSERT only (no UPDATE/DELETE),
-- mirroring the intel_communication_drafts audit-trail table. Org+school RLS
-- follows the proven intel_* pattern (ENABLE + FORCE, USING + WITH CHECK).
-- Additive/dormant: no existing table or row is touched.
--
-- estimated_cost_micros is micro-USD (1_000_000 = US$1), a deterministic
-- estimate from the gateway's static price table — never a fabricated number.

CREATE TABLE ai_call_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  user_id UUID REFERENCES users (id),
  surface TEXT NOT NULL DEFAULT '',
  provider TEXT NOT NULL DEFAULT '',
  model TEXT NOT NULL DEFAULT '',
  outcome TEXT NOT NULL
    CHECK (outcome IN (
      'ok',
      'refused',
      'fallback_no_key',
      'fallback_rate_user',
      'fallback_rate_school',
      'fallback_spend_cap',
      'fallback_timeout',
      'fallback_error'
    )),
  input_tokens INT NOT NULL DEFAULT 0 CHECK (input_tokens >= 0),
  output_tokens INT NOT NULL DEFAULT 0 CHECK (output_tokens >= 0),
  estimated_cost_micros BIGINT NOT NULL DEFAULT 0 CHECK (estimated_cost_micros >= 0),
  latency_ms INT NOT NULL DEFAULT 0 CHECK (latency_ms >= 0),
  cache_written BOOLEAN NOT NULL DEFAULT false,
  fallback_used BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- Per-user rate-limit window (token-bucket count over the trailing hour).
CREATE INDEX idx_ai_call_log_user_recent
  ON ai_call_log (organization_id, school_id, user_id, created_at DESC);

-- Per-school rate-limit window + monthly spend-cap sum.
CREATE INDEX idx_ai_call_log_school_recent
  ON ai_call_log (organization_id, school_id, created_at DESC);

ALTER TABLE ai_call_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_call_log FORCE ROW LEVEL SECURITY;

CREATE POLICY ai_call_log_school_scope ON ai_call_log
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

-- Append-only: no UPDATE/DELETE grant.
GRANT SELECT, INSERT ON ai_call_log TO erp_tenant;
