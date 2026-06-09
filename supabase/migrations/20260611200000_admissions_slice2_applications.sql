-- v6.1 Sprint 3 Phase 3B Slice 2 — admissions_applications

CREATE TABLE admissions_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  lead_id UUID REFERENCES admissions_leads (id),
  student_name TEXT NOT NULL,
  class_label TEXT NOT NULL,
  parent_name TEXT NOT NULL,
  counselor TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN (
      'draft', 'submitted', 'documents_pending', 'under_review',
      'approved', 'rejected'
    )),
  submitted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_admissions_applications_school ON admissions_applications (school_id);
CREATE INDEX idx_admissions_applications_lead ON admissions_applications (lead_id);

CREATE TRIGGER admissions_applications_updated_at
  BEFORE UPDATE ON admissions_applications
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE admissions_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE admissions_applications FORCE ROW LEVEL SECURITY;

CREATE POLICY admissions_applications_school_scope ON admissions_applications
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

GRANT SELECT, INSERT, UPDATE ON admissions_applications TO erp_tenant;
