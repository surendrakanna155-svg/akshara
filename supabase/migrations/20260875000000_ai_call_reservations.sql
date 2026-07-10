-- Adaptive AI — P3-AI-3 / A5: atomic gateway quota reservations (+ org-bucket
-- telemetry fix).
--
-- (1) ai_call_reservations — closes the gateway's check-then-act TOCTOU race:
-- the old flow read trailing-window counts from ai_call_log, decided, called
-- the provider (up to 20s), and only then inserted the telemetry row — all
-- inside the request's single transaction, so N concurrent requests all saw
-- the same pre-increment counts and could overshoot every limit by N-1.
-- The gateway now reserves BEFORE the provider call on a dedicated short-lived
-- connection that commits immediately (see ai_call_reservations_repository.ts):
-- an advisory-lock-serialized INSERT..SELECT that admits the call only if
-- (committed ai_call_log window counts + live pending reservations + this
-- call) stay inside the limits. After the call the reservation is consumed in
-- the SAME transaction that appends the ai_call_log row, so the pair swaps
-- atomically and every call is counted exactly once at every instant.
-- Crash/rollback safety: an abandoned 'pending' row stops counting after the
-- reader TTL (2 min) and is swept opportunistically — self-healing in the
-- conservative (over-blocking) direction, never the uncapped one.
--
-- RLS is tenant-boundary-only (no scope/school condition): this is internal
-- gateway accounting (no user content, no PII beyond the user FK), written
-- and read exclusively by server gateway code — but the org wall stays hard.
--
-- (2) ai_call_log org-bucket fix: org-scoped gateway calls (director summary /
-- org-builder / onboarding pass school_id NULL by design — see GatewayContext)
-- violated the NOT NULL column + the school-only RLS policy, so their
-- telemetry INSERTs failed and were silently swallowed by safeRecord():
-- unlogged AND therefore uncapped surfaces. school_id becomes nullable (the
-- repository already matches with IS NOT DISTINCT FROM) and the policy is
-- split: SELECT stays scope-aware (a school session sees only its school's
-- rows; the NULL org bucket is visible only to a NULL-school accounting
-- context), INSERT requires only the tenant boundary so every governed call
-- can be recorded.

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

-- ── ai_call_log org-bucket fix ───────────────────────────────────────────────

ALTER TABLE ai_call_log ALTER COLUMN school_id DROP NOT NULL;

DROP POLICY ai_call_log_school_scope ON ai_call_log;

-- Reads stay bucket-scoped: a school session (scope='school', school set) sees
-- exactly its school's rows; the gateway's accounting context (school NULL)
-- sees exactly the org bucket. IS NOT DISTINCT FROM makes NULL a real bucket
-- instead of an always-false predicate.
CREATE POLICY ai_call_log_read_bucket ON ai_call_log
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id IS NOT DISTINCT FROM app_current_school_id()
  );

-- Appends need only the tenant boundary so org-scoped calls are never dropped;
-- the table stays append-only for erp_tenant (no UPDATE/DELETE grant).
CREATE POLICY ai_call_log_insert_tenant ON ai_call_log
  FOR INSERT
  WITH CHECK (organization_id = app_current_tenant_id());
