-- EXM-D2 (grace marks / moderation) + EXM-D5 (seating arrangement).
--
-- Two additive, school-scoped tables plus one new granular RBAC permission.
-- 🔴 Integrity (frozen): the ORIGINAL entered mark on exam_mark_entries is NEVER
-- overwritten. A coordinator "grace" is recorded here as a SEPARATE, audited
-- delta row (supplementary/audit-safe). The EFFECTIVE mark at publish/report time
-- = original marks_obtained + SUM(deltas), bounds-capped to [0, max_marks]. Only
-- coordinators/principals see the adjustment breakdown; parents/students see only
-- the final effective mark.
--
-- Everything below is additive + backward-compatible: no existing table/column is
-- altered, so present behaviour (mark entry, verify→publish gate, published
-- immutability, AB/ML/DB exclusion, per-row audit) is unchanged.

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) EXM-D2 — grace marks / moderation ledger.
-- ═══════════════════════════════════════════════════════════════════════════
--
-- One row per (coordinator) adjustment for a (exam, student). `delta` is a signed
-- INTEGER (grace is normally positive but a downward moderation is allowed);
-- multiple rows accumulate. `reason` is mandatory (the app enforces non-empty; the
-- column defaults to '' only as a DB fallback). `adjusted_by` binds the actor.
CREATE TABLE exam_mark_adjustments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  -- exam_sessions PK is (organization_id, school_id, id) with a TEXT id.
  exam_id TEXT NOT NULL,
  -- The student the adjustment applies to (UUID, matches exam_mark_entries.student_id).
  student_id UUID NOT NULL,
  delta INTEGER NOT NULL,
  reason TEXT NOT NULL DEFAULT '',
  adjusted_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_exam_mark_adjustments_exam
  ON exam_mark_adjustments (organization_id, school_id, exam_id, student_id, created_at);

ALTER TABLE exam_mark_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_mark_adjustments FORCE ROW LEVEL SECURITY;

-- School-scope only: an adjustment is never visible/writable across schools, and
-- is never exposed to parent/student scopes (no parent/student read policy). The
-- effective mark parents see is computed server-side and never carries the deltas.
CREATE POLICY exam_mark_adjustments_school_read ON exam_mark_adjustments
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY exam_mark_adjustments_school_insert ON exam_mark_adjustments
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT ON exam_mark_adjustments TO erp_tenant;

-- The EFFECTIVE (original + grace) mark, baked ONLY at publish. The original
-- marks_obtained is NEVER overwritten (audit-safe). Parent/student reads cannot
-- see exam_mark_adjustments (school-scope RLS), so the effective score they see
-- must be materialised here — WITHOUT ever exposing the per-delta breakdown.
-- NULL until published (or when the student had no marks / is non-present).
ALTER TABLE exam_mark_entries
  ADD COLUMN IF NOT EXISTS effective_marks INTEGER NULL;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) EXM-D5 — seating arrangement (room + seat per student for an exam).
-- ═══════════════════════════════════════════════════════════════════════════
--
-- A generated seating plan for one exam. Regenerating replaces the plan (the
-- handler deletes the exam's rows first), so a (exam, student) is unique.
CREATE TABLE exam_seating_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  exam_id TEXT NOT NULL,
  student_id UUID NOT NULL,
  room_label TEXT NOT NULL DEFAULT '',
  seat_no INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (organization_id, school_id, exam_id, student_id)
);

CREATE INDEX idx_exam_seating_exam
  ON exam_seating_assignments (organization_id, school_id, exam_id, room_label, seat_no);

ALTER TABLE exam_seating_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_seating_assignments FORCE ROW LEVEL SECURITY;

CREATE POLICY exam_seating_school_read ON exam_seating_assignments
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY exam_seating_school_write ON exam_seating_assignments
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

-- DELETE too: regenerating a plan clears the exam's existing rows first.
GRANT SELECT, INSERT, UPDATE, DELETE ON exam_seating_assignments TO erp_tenant;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) EXM-D2 — new granular RBAC permission: moderateExamMarks.
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Recording a grace/moderation delta is a coordinator-level oversight action —
-- NOT something a plain subject teacher may do. It mirrors the verifyExamResults
-- grant set (the "coordinator + leadership" roles). Registered server-side so the
-- grace handler can enforce the SAME granular gate the client uses.
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('moderateExamMarks', 'Exams', 'moderate', 'school',
   'Record grace / moderation adjustments on processed exam marks (coordinator)')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'moderateExamMarks'),
  ('schoolAdmin', 'moderateExamMarks'),
  ('principal', 'moderateExamMarks'),
  ('vicePrincipal', 'moderateExamMarks'),
  ('management', 'moderateExamMarks')
ON CONFLICT DO NOTHING;
