-- v6.1 Sprint 3 Phase 3B Slice 3 — admissions_documents

CREATE TABLE admissions_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  lead_id UUID REFERENCES admissions_leads (id),
  application_id UUID REFERENCES admissions_applications (id),
  student_name TEXT NOT NULL DEFAULT '',
  class_label TEXT NOT NULL DEFAULT '',
  document_type TEXT NOT NULL,
  file_name TEXT NOT NULL,
  is_required BOOLEAN NOT NULL DEFAULT true,
  status TEXT NOT NULL DEFAULT 'missing'
    CHECK (status IN ('missing', 'uploaded', 'verified', 'rejected')),
  uploaded_at TIMESTAMPTZ,
  verified_by TEXT,
  reviewer_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_admissions_documents_school ON admissions_documents (school_id);
CREATE INDEX idx_admissions_documents_application ON admissions_documents (application_id);

CREATE TRIGGER admissions_documents_updated_at
  BEFORE UPDATE ON admissions_documents
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE admissions_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE admissions_documents FORCE ROW LEVEL SECURITY;

CREATE POLICY admissions_documents_school_scope ON admissions_documents
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

GRANT SELECT, INSERT, UPDATE ON admissions_documents TO erp_tenant;
