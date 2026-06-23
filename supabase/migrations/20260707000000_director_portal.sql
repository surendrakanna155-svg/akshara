-- Director Portal — org-scope, multi-school executive analytics.
--
-- Batch 6 (2026-06-23). The Director portal is the group/trust owner's
-- cross-school cockpit: portfolio KPIs, revenue, growth, admissions funnel,
-- marketing ROI, compliance monitoring and strategic reports — all AGGREGATED
-- ("Aggregated data only · No student PII"). Most figures are computed live
-- from real operational tables (students / finance / admissions / sis) scoped
-- to the caller's organization. The few inputs that have no operational source
-- (marketing spend, operating expense, physical capacity) live in
-- `director_metric_inputs`; compliance items and the strategic-report catalog
-- are real persisted tables. Nothing here is fabricated — unset inputs surface
-- as honest zeros rather than invented numbers.
--
-- Security: Director is ORGANIZATION scope. Two new permissions gate it,
-- granted only to organization/group roles. The aggregation reads run on the
-- service connection with a hard `organization_id = <jwt tenant_id>` filter
-- (an org-scope token cannot satisfy the school-scoped RLS on operational
-- tables); the director-owned tables below additionally enforce org-scope RLS.

-- ─── Permissions ────────────────────────────────────────────────────────────

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewDirectorPortal', 'Director', 'view', 'organization', 'View director portal'),
  ('manageDirectorPortal', 'Director', 'manage', 'organization', 'Manage director portal')
ON CONFLICT (slug) DO NOTHING;

-- Granted to org/group leadership + platform super admin (view + manage).
INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('organizationOwner', 'viewDirectorPortal'),
  ('organizationOwner', 'manageDirectorPortal'),
  ('organizationAdmin', 'viewDirectorPortal'),
  ('organizationAdmin', 'manageDirectorPortal'),
  ('schoolGroupDirector', 'viewDirectorPortal'),
  ('schoolGroupDirector', 'manageDirectorPortal'),
  ('superAdmin', 'viewDirectorPortal'),
  ('superAdmin', 'manageDirectorPortal')
ON CONFLICT DO NOTHING;

-- ─── Compliance monitoring (real, acknowledge persists) ─────────────────────

CREATE TABLE director_compliance_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID REFERENCES schools (id),
  school_name TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL,
  requirement TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'compliant'
    CHECK (status IN ('compliant', 'dueSoon', 'overdue', 'notApplicable')),
  due_date DATE NOT NULL,
  owner TEXT NOT NULL DEFAULT '',
  evidence_uploaded BOOLEAN NOT NULL DEFAULT false,
  acknowledged BOOLEAN NOT NULL DEFAULT false,
  acknowledged_by UUID REFERENCES users (id),
  acknowledged_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_director_compliance_org
  ON director_compliance_items (organization_id, due_date);

CREATE TRIGGER director_compliance_items_updated_at
  BEFORE UPDATE ON director_compliance_items
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─── Strategic report catalog (real) ────────────────────────────────────────

CREATE TABLE director_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  file_type TEXT NOT NULL DEFAULT 'PDF',
  last_generated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  generated_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_director_reports_org
  ON director_reports (organization_id, last_generated_at DESC);

CREATE TRIGGER director_reports_updated_at
  BEFORE UPDATE ON director_reports
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─── Non-derivable metric inputs (spend / expense / capacity) ───────────────
-- Per-school, per-month figures that no operational table can produce. Read
-- into revenue (expenses, margin), marketing (spend, CPL, ROI) and growth
-- (capacity). Empty until a school enters them → those metrics report zero.

CREATE TABLE director_metric_inputs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  period_month DATE NOT NULL,
  marketing_spend_inr NUMERIC(14, 2) NOT NULL DEFAULT 0,
  operating_expense_inr NUMERIC(14, 2) NOT NULL DEFAULT 0,
  student_capacity INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, period_month)
);

CREATE INDEX idx_director_metric_inputs_org
  ON director_metric_inputs (organization_id, school_id, period_month DESC);

CREATE TRIGGER director_metric_inputs_updated_at
  BEFORE UPDATE ON director_metric_inputs
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─── RLS: org-scope defence-in-depth on all three director-owned tables ─────

ALTER TABLE director_compliance_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE director_compliance_items FORCE ROW LEVEL SECURITY;
ALTER TABLE director_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE director_reports FORCE ROW LEVEL SECURITY;
ALTER TABLE director_metric_inputs ENABLE ROW LEVEL SECURITY;
ALTER TABLE director_metric_inputs FORCE ROW LEVEL SECURITY;

CREATE POLICY director_compliance_items_org_scope ON director_compliance_items
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school_group', 'platform')
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school_group', 'platform')
  );

CREATE POLICY director_reports_org_scope ON director_reports
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school_group', 'platform')
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school_group', 'platform')
  );

CREATE POLICY director_metric_inputs_org_scope ON director_metric_inputs
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school_group', 'platform')
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school_group', 'platform')
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON director_compliance_items TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON director_reports TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON director_metric_inputs TO erp_tenant;

-- ─── Org-scope read access on operational tables (additive, read-only) ──────
-- The Director portal aggregates these tables across every school in the org.
-- `schools` and `organizations` already permit an `organization` scope read;
-- the operational tables below were school-scoped only. These PERMISSIVE
-- SELECT policies OR in an org-level read path WITHOUT touching the existing
-- school/parent/student policies — a school/parent token (scope != org/group/
-- platform) still matches none of these, so its visibility is unchanged.
-- Read-only: org tokens can SEE aggregates but cannot write operational rows.

CREATE POLICY students_director_org_read ON students
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school_group', 'platform')
  );

CREATE POLICY sis_student_enrollments_director_org_read ON sis_student_enrollments
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school_group', 'platform')
  );

CREATE POLICY finance_invoices_director_org_read ON finance_invoices
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school_group', 'platform')
  );

CREATE POLICY finance_collections_director_org_read ON finance_collections
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school_group', 'platform')
  );

CREATE POLICY admissions_leads_director_org_read ON admissions_leads
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school_group', 'platform')
  );

CREATE POLICY admissions_applications_director_org_read ON admissions_applications
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school_group', 'platform')
  );

CREATE POLICY admissions_enrollments_director_org_read ON admissions_enrollments
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school_group', 'platform')
  );

CREATE POLICY attendance_records_director_org_read ON attendance_records
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school_group', 'platform')
  );

CREATE POLICY exam_mark_entries_director_org_read ON exam_mark_entries
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school_group', 'platform')
  );
