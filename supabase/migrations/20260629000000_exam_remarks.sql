-- Exam-session remarks (one per student per exam session), authored by the
-- class teacher, with an audit trail. Mirrors the app's mock model.

CREATE TABLE exam_remarks (
  id TEXT NOT NULL, -- "<examId>|<studentId>"
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  exam_id TEXT NOT NULL,
  student_id UUID NOT NULL,
  text TEXT NOT NULL DEFAULT '',
  author_id UUID,
  author_name TEXT NOT NULL DEFAULT '',
  author_role TEXT NOT NULL DEFAULT 'classTeacher',
  history JSONB NOT NULL DEFAULT '[]'::jsonb, -- append-only audit trail
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id, id),
  CONSTRAINT exam_remarks_author_role_check CHECK (
    author_role IN ('classTeacher', 'principal', 'vicePrincipal')
  )
);

CREATE INDEX idx_exam_remarks_exam
  ON exam_remarks (organization_id, school_id, exam_id);

CREATE TRIGGER exam_remarks_updated_at
  BEFORE UPDATE ON exam_remarks
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE exam_remarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_remarks FORCE ROW LEVEL SECURITY;

-- School staff read/write; a parent may read their own child's remark; only the
-- school scope may write (WITH CHECK).
CREATE POLICY exam_remarks_access ON exam_remarks
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND (
      app_current_scope() = 'school'
      OR (app_current_scope() = 'parent' AND student_id IN (
        SELECT student_id FROM student_guardians
        WHERE guardian_user_id = app_current_parent_user_id()
          AND school_id = app_current_school_id()
      ))
    )
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON exam_remarks TO erp_tenant;
