-- FIN-D1 — Day-close lock (block back-dated fee entries; supervisor reopen).
--
-- Once a cashier's day is closed, no new collection (or cancellation) may be
-- dated on or before the latest closed date — this prevents back-dating money
-- movements into a reconciled/handed-over day. A closed day can be reopened by a
-- supervisor (manageFinance); both actions are audited. One row per (org, school,
-- close_date).
--
-- The guard is enforced in the application layer (isDateLocked → 422 before any
-- collection insert/cancel); this table is the durable state it reads. Additive:
-- it does NOT touch the collection/invoice money path. RBAC is the existing
-- finance gate (viewFinance to list, manageFinance to close/reopen).

CREATE TABLE finance_day_close (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  close_date DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'closed'
    CHECK (status IN ('open', 'closed')),
  closed_by UUID,
  closed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  reopened_by UUID,
  reopened_at TIMESTAMPTZ,
  UNIQUE (organization_id, school_id, close_date)
);

CREATE INDEX idx_finance_day_close_school_date
  ON finance_day_close (organization_id, school_id, close_date DESC);

ALTER TABLE finance_day_close ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_day_close FORCE ROW LEVEL SECURITY;

CREATE POLICY day_close_school_read ON finance_day_close
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY day_close_school_insert ON finance_day_close
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY day_close_school_update ON finance_day_close
  FOR UPDATE USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON finance_day_close TO erp_tenant;
