-- F4 — exam administration sessions + mark entry extensions

CREATE TABLE exam_sessions (
  id TEXT NOT NULL,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  title TEXT NOT NULL,
  subject TEXT NOT NULL,
  grade TEXT NOT NULL,
  section_name TEXT NOT NULL DEFAULT '',
  term_label TEXT NOT NULL DEFAULT '',
  date_label TEXT NOT NULL DEFAULT '',
  time_label TEXT NOT NULL DEFAULT '',
  venue_label TEXT NOT NULL DEFAULT '',
  syllabus_label TEXT NOT NULL DEFAULT '',
  max_marks INTEGER NOT NULL DEFAULT 100,
  phase TEXT NOT NULL DEFAULT 'draft',
  exam_type TEXT NOT NULL DEFAULT 'unit_test',
  coordinator_verified_by TEXT,
  coordinator_verified_at TIMESTAMPTZ,
  rejection_comment TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id, id),
  CONSTRAINT exam_sessions_phase_check CHECK (
    phase IN ('draft', 'scheduled', 'marks_entry', 'processed', 'published')
  )
);

CREATE INDEX idx_exam_sessions_school_phase
  ON exam_sessions (organization_id, school_id, phase, updated_at DESC);

CREATE TRIGGER exam_sessions_updated_at
  BEFORE UPDATE ON exam_sessions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE exam_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_sessions FORCE ROW LEVEL SECURITY;

CREATE POLICY exam_sessions_school_scope ON exam_sessions
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

GRANT SELECT, INSERT, UPDATE ON exam_sessions TO erp_tenant;

ALTER TABLE exam_mark_entries
  ADD COLUMN IF NOT EXISTS student_name TEXT,
  ADD COLUMN IF NOT EXISTS roll_number TEXT,
  ADD COLUMN IF NOT EXISTS student_code TEXT,
  ADD COLUMN IF NOT EXISTS published BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS grade_letter TEXT,
  ADD COLUMN IF NOT EXISTS marks_entered BOOLEAN NOT NULL DEFAULT false;

-- Probe session aligned with mock/Patrol (exam_math_8a)
INSERT INTO exam_sessions (
  id, organization_id, school_id, title, subject, grade, section_name,
  term_label, date_label, time_label, venue_label, syllabus_label,
  max_marks, phase, exam_type
) VALUES (
  'exam_math_8a',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'Unit Test — Mathematics',
  'Mathematics',
  '8',
  'A',
  'Term 2',
  '12 Jun 2026',
  '9:00 AM - 10:30 AM',
  'Room 8A',
  'Algebra, Linear Equations',
  50,
  'marks_entry',
  'unit_test'
) ON CONFLICT DO NOTHING;

INSERT INTO exam_mark_entries (
  id, organization_id, school_id, student_id, exam_id, exam_title, class_label,
  marks_obtained, max_marks, student_name, roll_number, student_code, published,
  marks_entered
)
SELECT
  'exam_math_8a_' || e.roll_number,
  e.organization_id,
  e.school_id,
  e.student_id,
  'exam_math_8a',
  'Unit Test — Mathematics',
  e.class_name || '-' || e.section_name,
  CASE WHEN e.roll_number = '06' THEN 0 ELSE 42 END,
  50,
  s.display_name,
  e.roll_number,
  s.student_code,
  false,
  true
FROM sis_student_enrollments e
JOIN students s ON s.id = e.student_id
WHERE e.organization_id = 'a1000000-0000-4000-8000-000000000001'
  AND e.school_id = 'a2000000-0000-4000-8000-000000000001'
  AND e.class_name = '8'
  AND e.section_name = 'A'
  AND e.is_current = true
ON CONFLICT (id) DO NOTHING;
