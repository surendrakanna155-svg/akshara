-- Finance discount rules — relational backing for the discounts module.
-- A discount rule is a named, percentage-based rule applied to a fee scope
-- (e.g. "Early bird payment — 5% off annual fee"). Mirrors the app's
-- DiscountRule model (id, name, discountPercent, appliesTo, status).

CREATE TABLE finance_discount_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  name TEXT NOT NULL,
  discount_percent NUMERIC(5, 2) NOT NULL DEFAULT 0,
  applies_to TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'active')),
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_finance_discount_rules_school
  ON finance_discount_rules (organization_id, school_id, created_at DESC);

CREATE TRIGGER finance_discount_rules_updated_at
  BEFORE UPDATE ON finance_discount_rules
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE finance_discount_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_discount_rules FORCE ROW LEVEL SECURITY;

-- School-scoped read/write only; tenant + school must match the active context.
CREATE POLICY finance_discount_rules_access ON finance_discount_rules
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

GRANT SELECT, INSERT, UPDATE, DELETE ON finance_discount_rules TO erp_tenant;
