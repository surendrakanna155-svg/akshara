-- v6.1 Sprint 4 Phase 5A0 — SIS Schema Foundation
-- Architecture: docs/ArchitectureReview/v6.1-SIS-Foundation-Mapping.md
-- Identity anchor: students (created by Admissions enrollment)
-- Profile: student_profiles | Placement: sis_student_enrollments

-- ─── students audit column ───────────────────────────────────────────────────

ALTER TABLE students
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES users (id);

-- ─── student_profiles ────────────────────────────────────────────────────────

CREATE TABLE student_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL REFERENCES students (id) ON DELETE CASCADE,
  admission_number TEXT NOT NULL,
  date_of_birth DATE,
  gender TEXT,
  blood_group TEXT,
  address TEXT,
  city TEXT,
  state TEXT,
  postal_code TEXT,
  country TEXT,
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (student_id)
);

CREATE INDEX idx_student_profiles_org_school
  ON student_profiles (organization_id, school_id);
CREATE INDEX idx_student_profiles_school_admission
  ON student_profiles (school_id, admission_number);
CREATE INDEX idx_student_profiles_student
  ON student_profiles (student_id);

CREATE TRIGGER student_profiles_updated_at
  BEFORE UPDATE ON student_profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE student_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_profiles FORCE ROW LEVEL SECURITY;

CREATE POLICY student_profiles_school_scope ON student_profiles
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

GRANT SELECT, INSERT, UPDATE ON student_profiles TO erp_tenant;

-- ─── sis_student_enrollments ─────────────────────────────────────────────────

CREATE TABLE sis_student_enrollments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL REFERENCES students (id) ON DELETE CASCADE,
  academic_year TEXT NOT NULL,
  class_name TEXT NOT NULL,
  section_name TEXT,
  roll_number TEXT,
  is_current BOOLEAN NOT NULL DEFAULT true,
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (student_id, academic_year)
);

CREATE INDEX idx_sis_student_enrollments_org_school
  ON sis_student_enrollments (organization_id, school_id);
CREATE INDEX idx_sis_student_enrollments_student
  ON sis_student_enrollments (student_id);
CREATE INDEX idx_sis_student_enrollments_school_year_class
  ON sis_student_enrollments (school_id, academic_year, class_name, section_name);
CREATE INDEX idx_sis_student_enrollments_current
  ON sis_student_enrollments (school_id, student_id)
  WHERE is_current = true;

CREATE TRIGGER sis_student_enrollments_updated_at
  BEFORE UPDATE ON sis_student_enrollments
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE sis_student_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE sis_student_enrollments FORCE ROW LEVEL SECURITY;

CREATE POLICY sis_student_enrollments_school_scope ON sis_student_enrollments
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

GRANT SELECT, INSERT, UPDATE ON sis_student_enrollments TO erp_tenant;

-- ─── students / student_guardians school UPDATE policies ─────────────────────

CREATE POLICY students_school_update ON students
  FOR UPDATE
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

CREATE POLICY student_guardians_school_update ON student_guardians
  FOR UPDATE
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

GRANT UPDATE ON students, student_guardians TO erp_tenant;

-- ─── Probe fixtures (School A + School B) ───────────────────────────────────

INSERT INTO student_profiles (
  id, organization_id, school_id, student_id, admission_number,
  date_of_birth, gender, blood_group, address, city, state, postal_code, country,
  created_by
) VALUES (
  'bc000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'a4000000-0000-4000-8000-000000000001',
  'ADM-2026-PROBE001',
  '2014-05-15',
  'male',
  'O+',
  '12 Akshara Lane',
  'Hyderabad',
  'Telangana',
  '500001',
  'India',
  'a3000000-0000-4000-8000-000000000001'
),
(
  'bc000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'a4000000-0000-4000-8000-000000000002',
  'ADM-2026-PROBE002',
  '2015-08-20',
  'female',
  'A+',
  '45 School B Road',
  'Hyderabad',
  'Telangana',
  '500002',
  'India',
  'a3000000-0000-4000-8000-000000000001'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO sis_student_enrollments (
  id, organization_id, school_id, student_id, academic_year,
  class_name, section_name, roll_number, is_current, created_by
) VALUES (
  'bc100000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'a4000000-0000-4000-8000-000000000001',
  '2026-27',
  '5',
  'A',
  '12',
  true,
  'a3000000-0000-4000-8000-000000000001'
),
(
  'bc100000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'a4000000-0000-4000-8000-000000000002',
  '2026-27',
  '6',
  'B',
  '7',
  true,
  'a3000000-0000-4000-8000-000000000001'
)
ON CONFLICT (id) DO NOTHING;
