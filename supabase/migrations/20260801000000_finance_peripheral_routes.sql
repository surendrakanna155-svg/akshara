-- Wave 3 — Finance peripheral routes backing tables.
--
-- The Flutter client + DTOs already ship the offline-payments, QR/UPI session,
-- finance settings, and scholarship surfaces. This migration adds the relational
-- backing for those routes. Defaulters/reports are derived live from existing
-- finance_invoices + student/guardian records (no new table needed). The
-- finance_discount_rules table already exists (reused by GET /finance/discounts).
--
-- All tables are multi-tenant (organization_id + school_id), RLS school-scoped,
-- and granted SELECT/INSERT/UPDATE to erp_tenant (no DELETE — erp_tenant has no
-- DELETE privilege; lifecycle is handled via status flips). IF NOT EXISTS is used
-- defensively because migrations are forward-only.

-- ─── Offline payments (cash / cheque / DD) — STF-1 ───────────────────────────
CREATE TABLE IF NOT EXISTS finance_offline_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  invoice_id UUID,
  student_name TEXT NOT NULL DEFAULT '',
  amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  payment_method TEXT NOT NULL DEFAULT 'cash'
    CHECK (payment_method IN ('cash', 'cheque', 'dd')),
  reference_number TEXT NOT NULL DEFAULT '',
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  status TEXT NOT NULL DEFAULT 'pending_reconciliation'
    CHECK (status IN ('pending_reconciliation', 'reconciled')),
  collection_id UUID,
  reconciled_at TIMESTAMPTZ,
  reconciled_by UUID,
  notes TEXT,
  recorded_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_finance_offline_payments_school
  ON finance_offline_payments (organization_id, school_id, recorded_at DESC);

DROP TRIGGER IF EXISTS finance_offline_payments_updated_at ON finance_offline_payments;
CREATE TRIGGER finance_offline_payments_updated_at
  BEFORE UPDATE ON finance_offline_payments
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE finance_offline_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_offline_payments FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS finance_offline_payments_access ON finance_offline_payments;
CREATE POLICY finance_offline_payments_access ON finance_offline_payments
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'school'
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'school'
  );

GRANT SELECT, INSERT, UPDATE ON finance_offline_payments TO erp_tenant;

-- ─── QR / UPI payment sessions — STF-2 ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS finance_qr_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  invoice_id UUID,
  amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  upi_payload TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'confirmed', 'expired')),
  receipt_number TEXT,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (timezone('utc', now()) + INTERVAL '15 minutes'),
  confirmed_at TIMESTAMPTZ,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_finance_qr_sessions_school
  ON finance_qr_sessions (organization_id, school_id, created_at DESC);

DROP TRIGGER IF EXISTS finance_qr_sessions_updated_at ON finance_qr_sessions;
CREATE TRIGGER finance_qr_sessions_updated_at
  BEFORE UPDATE ON finance_qr_sessions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE finance_qr_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_qr_sessions FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS finance_qr_sessions_access ON finance_qr_sessions;
CREATE POLICY finance_qr_sessions_access ON finance_qr_sessions
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'school'
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'school'
  );

GRANT SELECT, INSERT, UPDATE ON finance_qr_sessions TO erp_tenant;

-- ─── Finance settings (one row per school, upserted) — STF-3 ─────────────────
CREATE TABLE IF NOT EXISTS finance_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  academic_year TEXT NOT NULL DEFAULT '',
  -- Free-form key/value settings store keyed by "<section_id>.<item_id>".
  settings JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id)
);

DROP TRIGGER IF EXISTS finance_settings_updated_at ON finance_settings;
CREATE TRIGGER finance_settings_updated_at
  BEFORE UPDATE ON finance_settings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE finance_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_settings FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS finance_settings_access ON finance_settings;
CREATE POLICY finance_settings_access ON finance_settings
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'school'
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'school'
  );

GRANT SELECT, INSERT, UPDATE ON finance_settings TO erp_tenant;

-- ─── Scholarships — STF-5 ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS finance_scholarships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'merit'
    CHECK (type IN ('merit', 'need_based', 'sibling', 'staff_child', 'sports')),
  max_discount TEXT NOT NULL DEFAULT '',
  eligibility TEXT NOT NULL DEFAULT '',
  active_assignments INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'archived')),
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_finance_scholarships_school
  ON finance_scholarships (organization_id, school_id, created_at DESC);

DROP TRIGGER IF EXISTS finance_scholarships_updated_at ON finance_scholarships;
CREATE TRIGGER finance_scholarships_updated_at
  BEFORE UPDATE ON finance_scholarships
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE finance_scholarships ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_scholarships FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS finance_scholarships_access ON finance_scholarships;
CREATE POLICY finance_scholarships_access ON finance_scholarships
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'school'
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'school'
  );

GRANT SELECT, INSERT, UPDATE ON finance_scholarships TO erp_tenant;
