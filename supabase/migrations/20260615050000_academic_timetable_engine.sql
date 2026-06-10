-- v7.5 — Smart Timetable + Workload Engine

CREATE TABLE academic_timetables (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  academic_year_id UUID NOT NULL REFERENCES academic_years (id),
  section_id UUID NOT NULL REFERENCES sections (id),
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'validated', 'published', 'archived')),
  version INTEGER NOT NULL DEFAULT 1,
  periods_per_day SMALLINT NOT NULL DEFAULT 6,
  days_per_week SMALLINT NOT NULL DEFAULT 5,
  validation_summary JSONB NOT NULL DEFAULT '{}'::jsonb,
  published_at TIMESTAMPTZ,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, academic_year_id, section_id, version)
);

CREATE TABLE academic_timetable_periods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  timetable_id UUID NOT NULL REFERENCES academic_timetables (id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  day_of_week SMALLINT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
  period_number SMALLINT NOT NULL CHECK (period_number >= 1),
  subject_label TEXT NOT NULL,
  teacher_id UUID,
  teacher_assignment_id UUID REFERENCES teacher_assignments (id),
  room_label TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (timetable_id, day_of_week, period_number)
);

CREATE INDEX idx_academic_timetables_school_year
  ON academic_timetables (organization_id, school_id, academic_year_id, status);
CREATE INDEX idx_academic_timetable_periods_teacher
  ON academic_timetable_periods (organization_id, school_id, teacher_id, day_of_week, period_number);
CREATE INDEX idx_academic_timetable_periods_room
  ON academic_timetable_periods (organization_id, school_id, room_label, day_of_week, period_number);

CREATE TRIGGER academic_timetables_updated_at BEFORE UPDATE ON academic_timetables
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE academic_timetables ENABLE ROW LEVEL SECURITY;
ALTER TABLE academic_timetables FORCE ROW LEVEL SECURITY;
ALTER TABLE academic_timetable_periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE academic_timetable_periods FORCE ROW LEVEL SECURITY;

CREATE POLICY academic_timetables_school ON academic_timetables
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

CREATE POLICY academic_timetable_periods_school ON academic_timetable_periods
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

GRANT SELECT, INSERT, UPDATE ON academic_timetables TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON academic_timetable_periods TO erp_tenant;

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewAcademicTimetable', 'AcademicTimetable', 'view', 'school', 'View academic timetables and workload'),
  ('manageAcademicTimetable', 'AcademicTimetable', 'manage', 'school', 'Generate and validate academic timetables'),
  ('publishAcademicTimetable', 'AcademicTimetable', 'publish', 'school', 'Publish validated academic timetables')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'viewAcademicTimetable'),
  ('superAdmin', 'manageAcademicTimetable'),
  ('superAdmin', 'publishAcademicTimetable'),
  ('schoolAdmin', 'viewAcademicTimetable'),
  ('schoolAdmin', 'manageAcademicTimetable'),
  ('schoolAdmin', 'publishAcademicTimetable'),
  ('principal', 'viewAcademicTimetable'),
  ('principal', 'manageAcademicTimetable'),
  ('principal', 'publishAcademicTimetable')
ON CONFLICT DO NOTHING;

-- Tenant isolation probe seeds (School A / School B)
INSERT INTO academic_timetables (
  id, organization_id, school_id, academic_year_id, section_id, status, version,
  periods_per_day, days_per_week, created_by
) VALUES
  (
    'd0500000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'ce100000-0000-4000-8000-000000000001',
    'd0100000-0000-4000-8000-000000000001',
    'draft',
    1,
    6,
    5,
    'a3000000-0000-4000-8000-000000000001'
  ),
  (
    'd0500000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000002',
    'ce100000-0000-4000-8000-000000000002',
    'd0100000-0000-4000-8000-000000000003',
    'draft',
    1,
    6,
    5,
    'a3000000-0000-4000-8000-000000000001'
  )
ON CONFLICT (id) DO NOTHING;
