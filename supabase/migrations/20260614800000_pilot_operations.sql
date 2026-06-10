-- Pilot Operations — attendance, leave, homework, exams, timetable

CREATE TABLE attendance_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  class_id UUID REFERENCES classes (id),
  section_id UUID REFERENCES sections (id),
  class_label TEXT NOT NULL DEFAULT '',
  session_date DATE NOT NULL DEFAULT CURRENT_DATE,
  taken_by UUID NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT attendance_sessions_status_check CHECK (status IN ('draft', 'submitted'))
);

CREATE INDEX idx_attendance_sessions_school_date
  ON attendance_sessions (organization_id, school_id, session_date DESC);

CREATE TABLE attendance_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES attendance_sessions (id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL,
  mark TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT attendance_records_mark_check CHECK (
    mark IN ('present', 'absent', 'late', 'excused')
  ),
  UNIQUE (session_id, student_id)
);

CREATE TABLE mobile_leave_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  requester_user_id UUID NOT NULL,
  requester_scope TEXT NOT NULL,
  student_id UUID,
  type_label TEXT NOT NULL DEFAULT 'sick',
  from_date_label TEXT NOT NULL,
  to_date_label TEXT NOT NULL,
  reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  has_attachment BOOLEAN NOT NULL DEFAULT false,
  attachment_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT mobile_leave_scope_check CHECK (requester_scope IN ('parent', 'teacher')),
  CONSTRAINT mobile_leave_status_check CHECK (
    status IN ('pending', 'approved', 'rejected', 'cancelled')
  )
);

CREATE TABLE homework_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL,
  homework_id TEXT NOT NULL,
  notes TEXT NOT NULL DEFAULT '',
  attachment_label TEXT,
  status TEXT NOT NULL DEFAULT 'submitted',
  grade TEXT,
  comment TEXT,
  reviewed_by UUID,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT homework_submissions_status_check CHECK (
    status IN ('submitted', 'reviewed', 'returned')
  )
);

CREATE UNIQUE INDEX idx_homework_submissions_student_hw
  ON homework_submissions (organization_id, school_id, student_id, homework_id);

CREATE TABLE exam_mark_entries (
  id TEXT PRIMARY KEY,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL,
  exam_id TEXT NOT NULL,
  exam_title TEXT NOT NULL DEFAULT '',
  class_label TEXT NOT NULL DEFAULT '',
  marks_obtained INTEGER NOT NULL DEFAULT 0,
  max_marks INTEGER NOT NULL DEFAULT 100,
  updated_by UUID,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, exam_id, student_id)
);

CREATE TABLE timetable_slots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  class_id UUID REFERENCES classes (id),
  section_id UUID REFERENCES sections (id),
  class_label TEXT NOT NULL DEFAULT '',
  day_of_week SMALLINT NOT NULL,
  period_number SMALLINT NOT NULL,
  subject_label TEXT NOT NULL,
  teacher_user_id UUID,
  room_label TEXT,
  substitute_teacher_user_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT timetable_day_check CHECK (day_of_week BETWEEN 1 AND 7)
);

CREATE INDEX idx_timetable_slots_class
  ON timetable_slots (organization_id, school_id, class_label, day_of_week);

CREATE TRIGGER attendance_sessions_updated_at
  BEFORE UPDATE ON attendance_sessions FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER mobile_leave_requests_updated_at
  BEFORE UPDATE ON mobile_leave_requests FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER homework_submissions_updated_at
  BEFORE UPDATE ON homework_submissions FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE attendance_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_sessions FORCE ROW LEVEL SECURITY;
ALTER TABLE attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_records FORCE ROW LEVEL SECURITY;
ALTER TABLE mobile_leave_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE mobile_leave_requests FORCE ROW LEVEL SECURITY;
ALTER TABLE homework_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE homework_submissions FORCE ROW LEVEL SECURITY;
ALTER TABLE exam_mark_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_mark_entries FORCE ROW LEVEL SECURITY;
ALTER TABLE timetable_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE timetable_slots FORCE ROW LEVEL SECURITY;

CREATE POLICY attendance_sessions_school ON attendance_sessions
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'parent', 'student')
  );

CREATE POLICY attendance_records_school ON attendance_records
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'parent', 'student')
  );

CREATE POLICY mobile_leave_scope ON mobile_leave_requests
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND (
      (app_current_scope() = 'parent' AND requester_user_id = app_current_user_id())
      OR (app_current_scope() = 'school' AND (
        requester_user_id = app_current_user_id()
        OR app_current_user_id() IN (
          SELECT user_id FROM school_memberships WHERE school_id = app_current_school_id()
        )
      ))
    )
  );

CREATE POLICY homework_submissions_scope ON homework_submissions
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND (
      (app_current_scope() = 'student' AND student_id = app_current_student_id())
      OR app_current_scope() = 'school'
      OR (app_current_scope() = 'parent' AND student_id IN (
        SELECT student_id FROM student_guardians
        WHERE guardian_user_id = app_current_parent_user_id()
          AND school_id = app_current_school_id()
      ))
    )
  );

CREATE POLICY exam_mark_entries_school ON exam_mark_entries
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'parent', 'student')
  );

CREATE POLICY timetable_slots_read ON timetable_slots
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON attendance_sessions TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON attendance_records TO erp_tenant;
GRANT SELECT, INSERT, UPDATE ON mobile_leave_requests TO erp_tenant;
GRANT SELECT, INSERT, UPDATE ON homework_submissions TO erp_tenant;
GRANT SELECT, INSERT, UPDATE ON exam_mark_entries TO erp_tenant;
GRANT SELECT ON timetable_slots TO erp_tenant;

-- Seed timetable + exam mark for School A
INSERT INTO timetable_slots (
  id, organization_id, school_id, class_label, day_of_week, period_number,
  subject_label, teacher_user_id, room_label
) VALUES (
  'd4000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  '8-A', 1, 1, 'Mathematics',
  'a3000000-0000-4000-8000-000000000001', 'Room 201'
);

INSERT INTO exam_mark_entries (
  id, organization_id, school_id, student_id, exam_id, exam_title, class_label,
  marks_obtained, max_marks
) VALUES (
  'mark_1',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'a4000000-0000-4000-8000-000000000001',
  'exam_unit_2', 'Unit Test 2', '8-A', 0, 50
);
