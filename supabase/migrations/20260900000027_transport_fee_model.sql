-- W4 (Owner decisions #2 + #3, FINAL/approved) — HYBRID transport fee model.
--
-- OWNER #2 (fee model): the transport fee is HYBRID — a school picks EXACTLY ONE
-- pricing model and the engine bills off it:
--     distance  → rate-per-km × the stop/route distance,
--     route     → a flat per-route amount,
--     stop      → a flat per-stop amount,
--     flat      → a single school-wide amount.
--   The choice is CONFIG PER SCHOOL (transport_fee_config, one row per school).
--
-- OWNER #3 (per-student): a student's transport REQUIREMENT is one of
--     bus | own_transport | parent_pickup.
--   own_transport / parent_pickup DEFAULT to ₹0 (a child dropped by a parent owes
--   no transport fee), and an EXPLICIT, nullable per-student fee OVERRIDE WINS over
--   the computed model fee (a school can bill/zero any single student by hand).
--   Both live on transport_student_transport (one row per student).
--
-- WHERE FEES REACH FINANCE TODAY (unchanged): TRN-9 raiseTransportDemandFor
-- (transport_write_handlers.ts) DEFINES a transport fee and RAISES a Finance
-- demand via assignFeeStructure. This migration adds the CONFIG these tables drive;
-- the computed amount is recorded authoritatively on the transport `demand` entity
-- and the ₹0 requirement gates the demand off entirely. NO Finance schema changes,
-- NO fork of the billing path.
--
-- DESIGN
--   * Money is the finance-standard NUMERIC(14,2) rupees — the SAME unit
--     transport_expenses.amount / finance_invoices.total_amount already use, so no
--     minor-unit scaling. Amounts are CHECK (… >= 0); a fee can be exactly ₹0.
--   * All three tables reuse the EXACT transport_entities RLS shape
--     (org + scope='school' + school) and the erp_tenant grant conventions, and the
--     shared set_updated_at() trigger (as transport_expenses does).
--   * transport_entities (routes/stops/allocations) and transport_allocation_history
--     are UNTOUCHED — this is purely additive config. allocation ids stay TEXT, and
--     these config tables soft-reference route/stop ids and sis_student_id as TEXT.
--   * GRANT SELECT, INSERT, UPDATE (config is edited in place via upsert) — NO
--     DELETE (a model is switched, not deleted; a student requirement is reset to
--     'bus', not removed). RBAC reuses the existing viewTransport / manageTransport
--     permissions — no new slug.
--   * Migration 20260900000027 is the next free slot after …026 in this band.

-- ── 1. Per-SCHOOL fee-config: the school's CHOSEN model + its rate inputs ──────
CREATE TABLE IF NOT EXISTS transport_fee_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  -- The single model this school bills off (owner #2). Tight CHECK so the compute
  -- engine's exhaustive switch can never meet an unknown model.
  fee_model TEXT NOT NULL CHECK (fee_model IN ('distance', 'route', 'stop', 'flat')),
  -- distance model: rate per km …
  rate_per_km NUMERIC(14, 2) CHECK (rate_per_km IS NULL OR rate_per_km >= 0),
  -- … and WHERE the distance for a student comes from — the student's pickup STOP
  -- or the whole ROUTE (per-stop/per-route distance lives on transport_fee_rate).
  distance_source TEXT NOT NULL DEFAULT 'route'
    CHECK (distance_source IN ('route', 'stop')),
  -- flat model: the single school-wide amount.
  flat_amount NUMERIC(14, 2) CHECK (flat_amount IS NULL OR flat_amount >= 0),
  -- route/stop models: the fallback amount used when a specific route/stop has no
  -- transport_fee_rate row of its own (so a school can set one number and refine
  -- per route/stop later).
  default_route_amount NUMERIC(14, 2) CHECK (default_route_amount IS NULL OR default_route_amount >= 0),
  default_stop_amount NUMERIC(14, 2) CHECK (default_stop_amount IS NULL OR default_stop_amount >= 0),
  updated_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  -- Exactly one active model config per school (the school CHOOSES one).
  UNIQUE (organization_id, school_id)
);

CREATE TRIGGER transport_fee_config_updated_at
  BEFORE UPDATE ON transport_fee_config FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE transport_fee_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE transport_fee_config FORCE ROW LEVEL SECURITY;

CREATE POLICY transport_fee_config_school_scope ON transport_fee_config
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON transport_fee_config TO erp_tenant;

-- ── 2. Per-ROUTE / per-STOP rate inputs (route/stop/distance models) ──────────
-- One row per priced route or stop: its per-route/per-stop AMOUNT (route/stop
-- models) and/or its DISTANCE in km (distance model). scope+entity_id soft-
-- reference the transport_entities route id / stop id (both TEXT).
CREATE TABLE IF NOT EXISTS transport_fee_rate (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  scope TEXT NOT NULL CHECK (scope IN ('route', 'stop')),
  entity_id TEXT NOT NULL CHECK (length(trim(entity_id)) > 0),
  -- Per-route (route model) or per-stop (stop model) fee.
  amount NUMERIC(14, 2) CHECK (amount IS NULL OR amount >= 0),
  -- Distance of this route/stop, for the distance model.
  distance_km NUMERIC(10, 2) CHECK (distance_km IS NULL OR distance_km >= 0),
  updated_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  -- One rate row per (route|stop) entity per school (upsert target).
  UNIQUE (organization_id, school_id, scope, entity_id)
);

CREATE INDEX IF NOT EXISTS idx_transport_fee_rate_lookup
  ON transport_fee_rate (organization_id, school_id, scope, entity_id);

CREATE TRIGGER transport_fee_rate_updated_at
  BEFORE UPDATE ON transport_fee_rate FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE transport_fee_rate ENABLE ROW LEVEL SECURITY;
ALTER TABLE transport_fee_rate FORCE ROW LEVEL SECURITY;

CREATE POLICY transport_fee_rate_school_scope ON transport_fee_rate
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON transport_fee_rate TO erp_tenant;

-- ── 3. Per-STUDENT transport requirement + fee override (owner #3) ─────────────
-- One row per student. requirement drives the ₹0 default for own_transport /
-- parent_pickup; fee_override (nullable) WINS over the computed model fee when set.
CREATE TABLE IF NOT EXISTS transport_student_transport (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  -- The SIS student display id the allocation + demand path keys on (TEXT).
  sis_student_id TEXT NOT NULL CHECK (length(trim(sis_student_id)) > 0),
  requirement TEXT NOT NULL DEFAULT 'bus'
    CHECK (requirement IN ('bus', 'own_transport', 'parent_pickup')),
  -- Explicit per-student override of the computed model fee. NULL = "use the model
  -- (or the ₹0 requirement default)"; a set value (incl. 0) WINS over everything.
  fee_override NUMERIC(14, 2) CHECK (fee_override IS NULL OR fee_override >= 0),
  updated_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, sis_student_id)
);

CREATE INDEX IF NOT EXISTS idx_transport_student_transport_lookup
  ON transport_student_transport (organization_id, school_id, sis_student_id);

CREATE TRIGGER transport_student_transport_updated_at
  BEFORE UPDATE ON transport_student_transport FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE transport_student_transport ENABLE ROW LEVEL SECURITY;
ALTER TABLE transport_student_transport FORCE ROW LEVEL SECURITY;

CREATE POLICY transport_student_transport_school_scope ON transport_student_transport
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON transport_student_transport TO erp_tenant;
