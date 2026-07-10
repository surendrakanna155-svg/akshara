-- Adaptive AI — P3-AI-3 / A5: atomic gateway quota reservations.
--
-- Closes the gateway's check-then-act TOCTOU race: the old flow read
-- trailing-window counts from ai_call_log, decided, called the provider (up
-- to 20s), and only then inserted the telemetry row — all inside the
-- request's single transaction, so N concurrent requests all saw the same
-- pre-increment counts and could overshoot every limit by N-1.
-- The gateway now reserves BEFORE the provider call on a dedicated
-- short-lived connection that commits immediately (see
-- ai_call_reservations_repository.ts): an advisory-lock-serialized
-- INSERT..SELECT that admits the call only if (committed ai_call_log window
-- counts + live pending reservations + this call) stay inside the limits.
-- After the call the reservation is consumed in the SAME transaction that
-- appends the ai_call_log row, so the pair swaps atomically and every call
-- is counted exactly once at every instant. Crash/rollback safety: an
-- abandoned 'pending' row stops counting after the reader TTL (2 min) and is
-- swept opportunistically — self-healing in the conservative (over-blocking)
-- direction, never the uncapped one.
--
-- RLS is tenant-boundary-only (no scope/school condition): this is internal
-- gateway accounting (no user content, no PII beyond the user FK), written
-- and read exclusively by server gateway code on its own accounting
-- connection — but the org wall stays hard.
--
-- ai_call_log itself is NOT touched here: migration 20260869 already made it
-- dual-scope (nullable school_id + ai_call_log_tenant_scope policy for the
-- school and organization buckets); the reservation connection selects the
-- bucket by setting scope='school'+school or scope='organization'.

CREATE TABLE ai_call_reservations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID REFERENCES schools (id),
  user_id UUID REFERENCES users (id),
  surface TEXT NOT NULL DEFAULT '',
  estimated_cost_micros BIGINT NOT NULL DEFAULT 0 CHECK (estimated_cost_micros >= 0),
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'consumed', 'released')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- Pending-window counts per school bucket and per user.
CREATE INDEX idx_ai_call_reservations_school
  ON ai_call_reservations (organization_id, school_id, status, created_at DESC);
CREATE INDEX idx_ai_call_reservations_user
  ON ai_call_reservations (organization_id, school_id, user_id, created_at DESC);

ALTER TABLE ai_call_reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_call_reservations FORCE ROW LEVEL SECURITY;

CREATE POLICY ai_call_reservations_tenant ON ai_call_reservations
  FOR ALL
  USING (organization_id = app_current_tenant_id())
  WITH CHECK (organization_id = app_current_tenant_id());

GRANT SELECT, INSERT, UPDATE, DELETE ON ai_call_reservations TO erp_tenant;
