-- v6.1 Sprint 3 Phase 3B Slice 1 — admissions_leads
-- Rules: FORCE RLS, school-scope operational access, erp_tenant grants

CREATE TABLE admissions_leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  parent_name TEXT NOT NULL,
  student_name TEXT NOT NULL,
  class_label TEXT NOT NULL,
  phone TEXT NOT NULL,
  source TEXT NOT NULL DEFAULT 'website',
  campaign TEXT NOT NULL DEFAULT '',
  stage TEXT NOT NULL DEFAULT 'new_enquiry',
  counselor TEXT NOT NULL DEFAULT '',
  score TEXT NOT NULL DEFAULT 'warm',
  next_follow_up_label TEXT NOT NULL DEFAULT 'Not scheduled',
  email TEXT,
  address TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_admissions_leads_school ON admissions_leads (school_id);
CREATE INDEX idx_admissions_leads_org ON admissions_leads (organization_id);

CREATE TRIGGER admissions_leads_updated_at
  BEFORE UPDATE ON admissions_leads
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE admissions_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE admissions_leads FORCE ROW LEVEL SECURITY;

CREATE POLICY admissions_leads_school_scope ON admissions_leads
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

GRANT SELECT, INSERT, UPDATE ON admissions_leads TO erp_tenant;

-- Isolation probe fixtures
INSERT INTO admissions_leads (
  id, organization_id, school_id, parent_name, student_name, class_label, phone,
  source, stage, counselor, score
) VALUES
  (
    'b5000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'Probe Parent A', 'Probe Student A', '5', '9000000001',
    'website', 'new_enquiry', 'Probe Counselor', 'warm'
  ),
  (
    'b5000000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000002',
    'Probe Parent B', 'Probe Student B', '6', '9000000002',
    'website', 'new_enquiry', 'Probe Counselor', 'warm'
  );
