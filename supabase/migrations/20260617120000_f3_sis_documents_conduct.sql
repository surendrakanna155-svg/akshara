-- F3 — student documents, conduct incidents (SIS + Student 360)

CREATE TABLE student_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL REFERENCES students (id) ON DELETE CASCADE,
  document_type TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  file_uri TEXT,
  uploaded_by UUID REFERENCES users (id),
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  verified_by UUID REFERENCES users (id),
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT student_documents_status_check
    CHECK (status IN ('pending', 'verified', 'rejected'))
);

CREATE INDEX idx_student_documents_student
  ON student_documents (organization_id, school_id, student_id, uploaded_at DESC);

CREATE TRIGGER student_documents_updated_at
  BEFORE UPDATE ON student_documents
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE student_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_documents FORCE ROW LEVEL SECURITY;

CREATE POLICY student_documents_school_scope ON student_documents
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

GRANT SELECT, INSERT, UPDATE ON student_documents TO erp_tenant;

CREATE TABLE student_conduct_incidents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL REFERENCES students (id) ON DELETE CASCADE,
  incident_type TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open',
  occurred_on DATE NOT NULL DEFAULT CURRENT_DATE,
  remarks TEXT,
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT student_conduct_status_check
    CHECK (status IN ('open', 'resolved', 'escalated'))
);

CREATE INDEX idx_student_conduct_student
  ON student_conduct_incidents (organization_id, school_id, student_id, occurred_on DESC);

CREATE TRIGGER student_conduct_updated_at
  BEFORE UPDATE ON student_conduct_incidents
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE student_conduct_incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_conduct_incidents FORCE ROW LEVEL SECURITY;

CREATE POLICY student_conduct_school_scope ON student_conduct_incidents
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

GRANT SELECT, INSERT, UPDATE ON student_conduct_incidents TO erp_tenant;

-- Probe fixtures (School A student a4000000-0000-4000-8000-000000000001)
INSERT INTO student_documents (
  id, organization_id, school_id, student_id, document_type, status, file_uri, uploaded_at
) VALUES (
  'bd000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'a4000000-0000-4000-8000-000000000001',
  'birth_certificate',
  'verified',
  'storage://documents/birth-cert-probe.pdf',
  timezone('utc', now())
);

INSERT INTO student_conduct_incidents (
  id, organization_id, school_id, student_id, incident_type, status, occurred_on, remarks
) VALUES (
  'bc000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'a4000000-0000-4000-8000-000000000001',
  'late_arrival',
  'resolved',
  '2026-05-12',
  'Generally cooperative in class.'
);
