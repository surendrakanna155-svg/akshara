-- W4 Staff Duty models — Owner decision #6 (FINAL): DEDICATED data models for
-- staff duties, NEVER overloaded onto the attendance tables.
--
-- Three separate, purpose-built tables record what staff are assigned to do
-- OUTSIDE the normal timetable — the three PRC-A "staff workload intelligence"
-- caps:
--   • staff_substitute_classes          → cap 131 (Substitution burden)
--   • staff_non_teaching_duties          → cap 132 (Non-teaching duties)
--   • staff_exam_invigilation_duties     → cap 133 (Exam and event duties)
--
-- Why NOT the attendance tables: attendance records WHO WAS PRESENT; a duty
-- records WHAT A STAFF MEMBER IS ASSIGNED TO DO. Conflating the two (e.g.
-- writing an invigilation row onto staff_check_ins) would corrupt attendance
-- analytics and the workload rollup alike. These tables NEVER reference
-- staff_check_ins / staff_attendance_requests / school_attendance_geofences.
--
-- Append-only spirit: a duty assignment is a historical record. erp_tenant is
-- granted SELECT + INSERT only — no UPDATE, no DELETE (a correction is a new
-- row, mirroring the payroll_finance_postings "postings are never deleted"
-- posture). created_at is the record timestamp.
--
-- RLS / grants mirror the per-school payroll_finance_postings + hr_entities
-- tables (school scope; org+school wall via app_current_* — the intel_* / SCE-1
-- pattern). Migration number 20260900000020 is the next free slot in the
-- feature band (…015–019 used), clear of the Data-Reliability / PRC
-- 20260877–20260890 band so a later merge cannot collide.

-- ─── cap 131 — Substitution burden ──────────────────────────────────────────
-- A substitute teacher covers a period for an absent teacher. The BURDEN accrues
-- to substitute_teacher_id (the one who actually took the class); absent_teacher_id
-- is recorded for context/audit. period_label + timetable_period_id capture the
-- period/timetable reference (timetable_period_id is a soft reference — no FK —
-- so this module never couples to the timetable's internal row lifecycle).
CREATE TABLE IF NOT EXISTS staff_substitute_classes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  absent_teacher_id UUID NOT NULL REFERENCES users (id),
  substitute_teacher_id UUID NOT NULL REFERENCES users (id),
  duty_date DATE NOT NULL,
  period_label TEXT NOT NULL DEFAULT '',
  -- Soft reference to academic_timetable_periods (no FK — decoupled by design).
  timetable_period_id UUID,
  reason TEXT NOT NULL DEFAULT '',
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_staff_substitute_classes_substitute
  ON staff_substitute_classes (organization_id, school_id, substitute_teacher_id, duty_date);
CREATE INDEX IF NOT EXISTS idx_staff_substitute_classes_absent
  ON staff_substitute_classes (organization_id, school_id, absent_teacher_id, duty_date);
CREATE INDEX IF NOT EXISTS idx_staff_substitute_classes_date
  ON staff_substitute_classes (organization_id, school_id, duty_date);

ALTER TABLE staff_substitute_classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_substitute_classes FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS staff_substitute_classes_school_scope ON staff_substitute_classes;
CREATE POLICY staff_substitute_classes_school_scope ON staff_substitute_classes
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

-- Append-only: SELECT + INSERT only; never UPDATE/DELETE (a correction is a new row).
GRANT SELECT, INSERT ON staff_substitute_classes TO erp_tenant;

-- ─── cap 133 — Exam and event duties (invigilation) ─────────────────────────
-- A staff member is assigned an invigilation/exam-hall duty. exam_id is a soft
-- reference (no FK) to the exam being invigilated; exam_label carries a
-- human-readable exam name so the record is self-describing even if the exam row
-- is later archived. room + session locate the duty within the exam.
CREATE TABLE IF NOT EXISTS staff_exam_invigilation_duties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  staff_id UUID NOT NULL REFERENCES users (id),
  -- Soft reference to the exam (no FK — decoupled from the exam lifecycle).
  exam_id UUID,
  exam_label TEXT NOT NULL DEFAULT '',
  duty_date DATE NOT NULL,
  room TEXT NOT NULL DEFAULT '',
  session TEXT NOT NULL DEFAULT '',
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_staff_exam_invigilation_staff
  ON staff_exam_invigilation_duties (organization_id, school_id, staff_id, duty_date);
CREATE INDEX IF NOT EXISTS idx_staff_exam_invigilation_date
  ON staff_exam_invigilation_duties (organization_id, school_id, duty_date);
CREATE INDEX IF NOT EXISTS idx_staff_exam_invigilation_exam
  ON staff_exam_invigilation_duties (organization_id, school_id, exam_id);

ALTER TABLE staff_exam_invigilation_duties ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_exam_invigilation_duties FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS staff_exam_invigilation_duties_school_scope ON staff_exam_invigilation_duties;
CREATE POLICY staff_exam_invigilation_duties_school_scope ON staff_exam_invigilation_duties
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

GRANT SELECT, INSERT ON staff_exam_invigilation_duties TO erp_tenant;

-- ─── cap 132 — Non-teaching duties ──────────────────────────────────────────
-- A staff member is assigned a non-teaching duty (ground duty, morning
-- assembly, committee work, event coordination, …). duty_type is a free-form
-- category; the duty spans [start_date, end_date] — a single day when end_date
-- is NULL. description carries the specifics.
CREATE TABLE IF NOT EXISTS staff_non_teaching_duties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  staff_id UUID NOT NULL REFERENCES users (id),
  duty_type TEXT NOT NULL,
  start_date DATE NOT NULL,
  -- NULL end_date = a single-day duty (start_date only).
  end_date DATE,
  description TEXT NOT NULL DEFAULT '',
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE INDEX IF NOT EXISTS idx_staff_non_teaching_duties_staff
  ON staff_non_teaching_duties (organization_id, school_id, staff_id, start_date);
CREATE INDEX IF NOT EXISTS idx_staff_non_teaching_duties_date
  ON staff_non_teaching_duties (organization_id, school_id, start_date);

ALTER TABLE staff_non_teaching_duties ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_non_teaching_duties FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS staff_non_teaching_duties_school_scope ON staff_non_teaching_duties;
CREATE POLICY staff_non_teaching_duties_school_scope ON staff_non_teaching_duties
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

GRANT SELECT, INSERT ON staff_non_teaching_duties TO erp_tenant;
