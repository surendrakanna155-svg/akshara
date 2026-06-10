-- v6.1 Sprint 4 Phase 5C.0a — Academic Foundation (schema, RLS, fixtures)
-- Canonical catalog: academic_years, classes, sections, teacher_assignments

-- ─── academic_years ──────────────────────────────────────────────────────────

CREATE TABLE academic_years (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  year_label TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  is_current BOOLEAN NOT NULL DEFAULT false,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'archived', 'draft')),
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (school_id, year_label),
  CHECK (end_date >= start_date)
);

CREATE UNIQUE INDEX academic_years_one_current_per_school
  ON academic_years (school_id)
  WHERE is_current = true;

CREATE INDEX idx_academic_years_org_school
  ON academic_years (organization_id, school_id);

CREATE TRIGGER academic_years_updated_at
  BEFORE UPDATE ON academic_years
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE academic_years ENABLE ROW LEVEL SECURITY;
ALTER TABLE academic_years FORCE ROW LEVEL SECURITY;

CREATE POLICY academic_years_school_scope ON academic_years
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

GRANT SELECT, INSERT, UPDATE ON academic_years TO erp_tenant;

-- ─── classes ─────────────────────────────────────────────────────────────────

CREATE TABLE classes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  academic_year_id UUID NOT NULL REFERENCES academic_years (id) ON DELETE RESTRICT,
  class_name TEXT NOT NULL,
  display_order INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'archived')),
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (academic_year_id, class_name)
);

CREATE INDEX idx_classes_org_school
  ON classes (organization_id, school_id);
CREATE INDEX idx_classes_academic_year
  ON classes (academic_year_id);

CREATE TRIGGER classes_updated_at
  BEFORE UPDATE ON classes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes FORCE ROW LEVEL SECURITY;

CREATE POLICY classes_school_scope ON classes
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

GRANT SELECT, INSERT, UPDATE ON classes TO erp_tenant;

-- ─── sections ────────────────────────────────────────────────────────────────

CREATE TABLE sections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  class_id UUID NOT NULL REFERENCES classes (id) ON DELETE RESTRICT,
  section_name TEXT NOT NULL,
  capacity INT,
  strength INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'archived')),
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (class_id, section_name)
);

CREATE INDEX idx_sections_org_school
  ON sections (organization_id, school_id);
CREATE INDEX idx_sections_class
  ON sections (class_id);

CREATE TRIGGER sections_updated_at
  BEFORE UPDATE ON sections
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE sections FORCE ROW LEVEL SECURITY;

CREATE POLICY sections_school_scope ON sections
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

GRANT SELECT, INSERT, UPDATE ON sections TO erp_tenant;

-- ─── teacher_assignments (section-based; class via sections → classes) ───────

CREATE TABLE teacher_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  teacher_id UUID NOT NULL REFERENCES users (id),
  section_id UUID NOT NULL REFERENCES sections (id) ON DELETE RESTRICT,
  role TEXT NOT NULL
    CHECK (role IN ('class_teacher', 'subject_teacher', 'coordinator')),
  is_primary BOOLEAN NOT NULL DEFAULT false,
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE UNIQUE INDEX teacher_assignments_one_primary_class_teacher
  ON teacher_assignments (section_id)
  WHERE role = 'class_teacher' AND is_primary = true;

CREATE INDEX idx_teacher_assignments_org_school
  ON teacher_assignments (organization_id, school_id);
CREATE INDEX idx_teacher_assignments_teacher
  ON teacher_assignments (teacher_id);
CREATE INDEX idx_teacher_assignments_section
  ON teacher_assignments (section_id);

CREATE TRIGGER teacher_assignments_updated_at
  BEFORE UPDATE ON teacher_assignments
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE teacher_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_assignments FORCE ROW LEVEL SECURITY;

CREATE POLICY teacher_assignments_school_scope ON teacher_assignments
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

GRANT SELECT, INSERT, UPDATE ON teacher_assignments TO erp_tenant;

-- ─── Probe fixtures: teacher users (School A + School B) ─────────────────────

INSERT INTO users (id, phone, email, display_name)
VALUES
  (
    'd1000000-0000-4000-8000-000000000001',
    '+919876543213',
    'staging.teacher.a@aksharaerp.com',
    'Staging Teacher A'
  ),
  (
    'd1000000-0000-4000-8000-000000000002',
    '+919876543214',
    'staging.teacher.b@aksharaerp.com',
    'Staging Teacher B'
  )
ON CONFLICT (phone) DO NOTHING;

INSERT INTO school_memberships (user_id, school_id, role, status, permissions_version)
VALUES
  (
    'd1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'teacher',
    'active',
    1
  ),
  (
    'd1000000-0000-4000-8000-000000000002',
    'a2000000-0000-4000-8000-000000000002',
    'teacher',
    'active',
    1
  )
ON CONFLICT (user_id, school_id) DO NOTHING;

-- ─── School A fixtures ───────────────────────────────────────────────────────

INSERT INTO academic_years (
  id, organization_id, school_id, year_label, start_date, end_date,
  is_current, status, created_by
) VALUES (
  'ce100000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  '2026-27',
  '2026-04-01',
  '2027-03-31',
  true,
  'active',
  'a3000000-0000-4000-8000-000000000001'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO classes (
  id, organization_id, school_id, academic_year_id, class_name, display_order,
  status, created_by
) VALUES
  (
    'cf100000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'ce100000-0000-4000-8000-000000000001',
    '5',
    1,
    'active',
    'a3000000-0000-4000-8000-000000000001'
  ),
  (
    'cf100000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'ce100000-0000-4000-8000-000000000001',
    '6',
    2,
    'active',
    'a3000000-0000-4000-8000-000000000001'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO sections (
  id, organization_id, school_id, class_id, section_name, capacity, strength,
  status, created_by
) VALUES
  (
    'd0100000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'cf100000-0000-4000-8000-000000000001',
    'A',
    40,
    0,
    'active',
    'a3000000-0000-4000-8000-000000000001'
  ),
  (
    'd0100000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'cf100000-0000-4000-8000-000000000002',
    'B',
    40,
    0,
    'active',
    'a3000000-0000-4000-8000-000000000001'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO teacher_assignments (
  id, organization_id, school_id, teacher_id, section_id, role, is_primary,
  created_by
) VALUES (
  'd2000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'd1000000-0000-4000-8000-000000000001',
  'd0100000-0000-4000-8000-000000000001',
  'class_teacher',
  true,
  'a3000000-0000-4000-8000-000000000001'
)
ON CONFLICT (id) DO NOTHING;

-- ─── School B fixtures ───────────────────────────────────────────────────────

INSERT INTO academic_years (
  id, organization_id, school_id, year_label, start_date, end_date,
  is_current, status, created_by
) VALUES (
  'ce100000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  '2026-27',
  '2026-04-01',
  '2027-03-31',
  true,
  'active',
  'a3000000-0000-4000-8000-000000000001'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO classes (
  id, organization_id, school_id, academic_year_id, class_name, display_order,
  status, created_by
) VALUES
  (
    'cf100000-0000-4000-8000-000000000003',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000002',
    'ce100000-0000-4000-8000-000000000002',
    '5',
    1,
    'active',
    'a3000000-0000-4000-8000-000000000001'
  ),
  (
    'cf100000-0000-4000-8000-000000000004',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000002',
    'ce100000-0000-4000-8000-000000000002',
    '6',
    2,
    'active',
    'a3000000-0000-4000-8000-000000000001'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO sections (
  id, organization_id, school_id, class_id, section_name, capacity, strength,
  status, created_by
) VALUES
  (
    'd0100000-0000-4000-8000-000000000003',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000002',
    'cf100000-0000-4000-8000-000000000003',
    'A',
    40,
    0,
    'active',
    'a3000000-0000-4000-8000-000000000001'
  ),
  (
    'd0100000-0000-4000-8000-000000000004',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000002',
    'cf100000-0000-4000-8000-000000000004',
    'B',
    40,
    0,
    'active',
    'a3000000-0000-4000-8000-000000000001'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO teacher_assignments (
  id, organization_id, school_id, teacher_id, section_id, role, is_primary,
  created_by
) VALUES (
  'd2000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'd1000000-0000-4000-8000-000000000002',
  'd0100000-0000-4000-8000-000000000003',
  'class_teacher',
  true,
  'a3000000-0000-4000-8000-000000000001'
)
ON CONFLICT (id) DO NOTHING;
