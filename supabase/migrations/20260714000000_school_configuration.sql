-- B1 — Per-school capability gating ("feels built for my school").
--
-- The Smart School Discovery wizard (FV-PLAT-14) lets an admin/principal pick
-- their school type, curriculum, operations model and toggle the ERP modules
-- their school actually uses (transport / hostel / library / inventory / alumni
-- / HR-payroll / multi-branch / trust). Until now that configuration only lived
-- in app memory + SharedPreferences, so it was neither tenant-authoritative nor
-- cross-device. This makes it durable and school-scoped: one row per school,
-- carrying the capability flags (JSONB), school_type and curriculum.
--
-- Security: school scope. Reads gate on `viewSchoolSetup`; writes on
-- `manageSchoolSetup` (both already granted to schoolAdmin / principal /
-- superAdmin in 20260623400000_evolution_permissions.sql). The row additionally
-- enforces school-scope RLS — a parent/student/other-school token matches none
-- of the policy, so it can neither read nor write another school's gating.

CREATE TABLE school_configuration (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  school_type TEXT NOT NULL DEFAULT 'day_school',
  curriculum TEXT NOT NULL DEFAULT 'cbse',
  operations_model TEXT NOT NULL DEFAULT 'single_school',
  branch_count INTEGER NOT NULL DEFAULT 1,
  capabilities JSONB NOT NULL DEFAULT '{}'::jsonb,
  configured_by UUID REFERENCES users (id),
  configured_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (school_id)
);

CREATE INDEX idx_school_configuration_school
  ON school_configuration (school_id);
CREATE INDEX idx_school_configuration_org
  ON school_configuration (organization_id);

CREATE TRIGGER school_configuration_updated_at
  BEFORE UPDATE ON school_configuration
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─── RLS: school-scope, defence-in-depth ────────────────────────────────────

ALTER TABLE school_configuration ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_configuration FORCE ROW LEVEL SECURITY;

CREATE POLICY school_configuration_school_scope ON school_configuration
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

GRANT SELECT, INSERT, UPDATE ON school_configuration TO erp_tenant;
