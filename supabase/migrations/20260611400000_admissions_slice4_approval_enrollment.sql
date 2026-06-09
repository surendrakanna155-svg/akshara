-- v6.1 Sprint 3 Phase 3B Slice 4 — approval, enrollment, student/parent linking

CREATE TABLE admissions_approvals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  application_id UUID NOT NULL REFERENCES admissions_applications (id),
  student_name TEXT NOT NULL,
  class_label TEXT NOT NULL,
  parent_name TEXT NOT NULL,
  counselor TEXT NOT NULL DEFAULT '',
  decision TEXT NOT NULL DEFAULT 'pending'
    CHECK (decision IN ('pending', 'approved', 'rejected')),
  ai_score INT NOT NULL DEFAULT 75,
  submitted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (application_id)
);

CREATE TABLE admissions_enrollments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  application_id UUID REFERENCES admissions_applications (id),
  student_id UUID REFERENCES students (id),
  guardian_user_id UUID REFERENCES users (id),
  student_name TEXT NOT NULL,
  seeking_class TEXT NOT NULL,
  section TEXT NOT NULL DEFAULT '',
  academic_year TEXT NOT NULL DEFAULT '',
  guardian_name TEXT NOT NULL,
  phone TEXT NOT NULL DEFAULT '',
  gender TEXT NOT NULL DEFAULT '',
  date_of_birth TEXT NOT NULL DEFAULT '',
  conversion_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (conversion_status IN ('pending', 'converted', 'failed')),
  admission_number TEXT,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_admissions_approvals_school ON admissions_approvals (school_id);
CREATE INDEX idx_admissions_enrollments_school ON admissions_enrollments (school_id);
CREATE INDEX idx_admissions_enrollments_student ON admissions_enrollments (student_id);

CREATE TRIGGER admissions_approvals_updated_at
  BEFORE UPDATE ON admissions_approvals
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE admissions_approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE admissions_approvals FORCE ROW LEVEL SECURITY;
ALTER TABLE admissions_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE admissions_enrollments FORCE ROW LEVEL SECURITY;

CREATE POLICY admissions_approvals_school_scope ON admissions_approvals
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

CREATE POLICY admissions_enrollments_school_scope ON admissions_enrollments
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

-- School staff may create students and guardian links during enrollment (erp_tenant path)
CREATE POLICY students_school_insert ON students
  FOR INSERT
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

CREATE POLICY student_guardians_school_insert ON student_guardians
  FOR INSERT
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

-- Guardian lookup for enrollment parent linking (no service_role)
CREATE OR REPLACE FUNCTION app.lookup_guardian_user_for_enrollment(p_phone text)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM users WHERE phone = p_phone LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION app.lookup_guardian_user_for_enrollment TO erp_tenant;

GRANT SELECT, INSERT, UPDATE ON admissions_approvals TO erp_tenant;
GRANT SELECT, INSERT, UPDATE ON admissions_enrollments TO erp_tenant;
GRANT INSERT ON students, student_guardians TO erp_tenant;
