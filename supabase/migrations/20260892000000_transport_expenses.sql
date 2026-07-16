-- PRC-A Batch 8 (slice 1) — Transport expense domain (caps 14–17) + kill the
-- static-mock cost served as live.
--
-- The audit found: the transport fleet fuel/maintenance/expense sub-domain does
-- NOT exist, and the dashboard "Fuel Cost (MTD) = ₹84K — Finance integration
-- placeholder" KPI is a STATIC SEED literal served verbatim to real pilot users
-- (config/live_release.json sets TRANSPORT_API_ENABLED=true). Every downstream
-- cost/income-vs-expense figure was therefore un-real.
--
-- DESIGN — reuse the architecture, not a table:
--   * Transport itself is a JSONB entity store (transport_entities), but a cost
--     ledger needs numeric aggregation (SUM by category/date/vehicle for the live
--     recompute), so this is a RELATIONAL table with typed columns — mirroring
--     finance's typed-numeric style, NOT crammed into an opaque JSONB payload.
--   * It reuses the EXACT transport_entities RLS shape (org + scope='school' +
--     school) and erp_tenant grant conventions.
--   * A recorded expense is corrected by VOIDing it (status='void'), never
--     hard-deleted — an auditable money ledger. No DELETE grant.

CREATE TABLE transport_expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  -- Cost category. Free-list kept tight so the cost recompute can bucket reliably;
  -- 'other' is the catch-all so a new cost type never needs a migration.
  category TEXT NOT NULL CHECK (category IN (
    'fuel', 'maintenance', 'insurance', 'salary', 'permit', 'toll', 'cleaning', 'other'
  )),
  -- Soft references into the JSONB entity store (transport_entities ids are TEXT).
  -- Nullable: an expense may be fleet-wide (insurance) with no single vehicle.
  vehicle_id TEXT,
  route_id TEXT,
  amount NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
  incurred_on DATE NOT NULL,
  vendor TEXT,
  reference TEXT,
  notes TEXT,
  -- A recorded expense counts toward cost; a voided one is excluded but preserved.
  status TEXT NOT NULL DEFAULT 'recorded' CHECK (status IN ('recorded', 'void')),
  void_reason TEXT,
  voided_by UUID,
  voided_at TIMESTAMPTZ,
  recorded_by UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- Covering index for the cost recompute (org+school, recorded, by date).
CREATE INDEX idx_transport_expenses_summary
  ON transport_expenses (organization_id, school_id, status, incurred_on);

CREATE TRIGGER transport_expenses_updated_at
  BEFORE UPDATE ON transport_expenses FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE transport_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE transport_expenses FORCE ROW LEVEL SECURITY;

-- Identical scope to transport_entities_school_scope: a school session sees/edits
-- only its own school's expenses; cross-school/cross-tenant rows are invisible.
CREATE POLICY transport_expenses_school_scope ON transport_expenses
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

-- SELECT, INSERT, UPDATE (for void) — deliberately NO DELETE (auditable ledger).
GRANT SELECT, INSERT, UPDATE ON transport_expenses TO erp_tenant;

-- RBAC: reuse the EXISTING viewTransport (read/summary) + manageTransport
-- (record/void) permissions — recording an expense is a transport write. No new slug.
