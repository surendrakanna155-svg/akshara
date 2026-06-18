-- F5 — attendance correction requests (A5)

CREATE TABLE attendance_corrections (
  id TEXT NOT NULL,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  sis_student_id TEXT NOT NULL,
  student_id UUID,
  student_name TEXT NOT NULL,
  class_label TEXT NOT NULL,
  section_name TEXT NOT NULL DEFAULT '',
  date_label TEXT NOT NULL,
  session_date DATE,
  from_mark TEXT NOT NULL,
  to_mark TEXT NOT NULL,
  reason TEXT NOT NULL,
  requester_id TEXT NOT NULL,
  requester_name TEXT NOT NULL,
  requester_role TEXT NOT NULL,
  present_delta INTEGER NOT NULL DEFAULT 1,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id, id),
  CONSTRAINT attendance_corrections_status_check CHECK (
    status IN ('pending', 'approved', 'rejected', 'cancelled')
  )
);

CREATE INDEX idx_attendance_corrections_school_status
  ON attendance_corrections (organization_id, school_id, status, created_at DESC);

CREATE TRIGGER attendance_corrections_updated_at
  BEFORE UPDATE ON attendance_corrections
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE attendance_corrections ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_corrections FORCE ROW LEVEL SECURITY;

CREATE POLICY attendance_corrections_school_scope ON attendance_corrections
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

GRANT SELECT, INSERT, UPDATE ON attendance_corrections TO erp_tenant;
