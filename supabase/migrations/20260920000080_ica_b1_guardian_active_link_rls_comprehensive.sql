-- ICA-B1 (P0, Security) — comprehensive guardian ACTIVE-link RLS tightening.
--
-- LEAK. The guardian-unlink writer is a SOFT unlink: it sets
-- `student_guardians.status = 'inactive'` and RETAINS the row (the table's
-- CHECK allows only 'active' | 'inactive'; see 20260609100000:32). RLS is
-- therefore the true de-authorization boundary. A family of parent-scope
-- policies gate a parent's visibility of a child's records through a
-- `student_guardians` sub-select of the shape
--
--     student_id IN (SELECT student_id FROM student_guardians
--                    WHERE guardian_user_id = app_current_parent_user_id()
--                      AND school_id = app_current_school_id())
--
-- which matches ANY link row regardless of `status`. So once a guardian is
-- unlinked (status -> 'inactive'), the parent-context resolver already stops
-- returning that child (auth_context.resolveParentContext filters
-- status='active'), but these RLS sub-selects would STILL leak the revoked
-- child's records to the de-authorized guardian — a read AND (for attendance
-- corrections) a write path.
--
-- SCOPE. PRA-P1-02 (20260900000012) fixed FOUR such policies (finance_invoices,
-- finance_collections, finance_receipts, sis_student_enrollments) but MISSED
-- SEVEN more. This migration closes those seven:
--
--   1. attendance_records_parent_student_read   (attendance_records,           SELECT)
--   2. exam_mark_entries_school                 (exam_mark_entries,            FOR ALL / USING)
--   3. exam_remarks_access                      (exam_remarks,                 FOR ALL / USING)
--   4. homework_submissions_parent_read         (homework_submissions,         SELECT)
--   5. intel_parent_guidance_parent_scope       (intel_parent_guidance_reports, SELECT)
--   6. attendance_corrections_parent_read       (attendance_corrections,       SELECT)
--   7. attendance_corrections_parent_insert     (attendance_corrections,       INSERT / WITH CHECK)
--
-- FIX. Each policy is re-created VERBATIM from its current/effective definition
-- with exactly one predicate added inside every `student_guardians` sub-select:
-- `AND sg.status = 'active'`. The table is aliased `student_guardians sg` with
-- its columns qualified, matching the canonical template `students_scope_access`
-- (20260609100000_phase2_rls_scope.sql:260-263). This is PURELY TIGHTENING — it
-- can only remove rows an inactive (unlinked) guardian would otherwise see; it
-- never widens access. Idempotent: DROP POLICY IF EXISTS + CREATE.
--
-- NOTE. For intel_parent_guidance_parent_scope and attendance_corrections_parent_insert
-- the OUTER `status` predicate is a DIFFERENT column (the report's 'published'
-- status / the correction's 'pending' status) and is left UNCHANGED; the added
-- `sg.status = 'active'` lives strictly inside the guardian sub-select. For
-- exam_remarks_access the WITH CHECK is school-scope only (no guardian
-- sub-select) and is left UNCHANGED.
--
-- Table grants are unaffected (grants live on the table, not the policy).

-- ── 1. attendance_records: parent reads only ACTIVE-linked children ─────────────
DROP POLICY IF EXISTS attendance_records_parent_student_read ON attendance_records;
CREATE POLICY attendance_records_parent_student_read ON attendance_records
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND (
      (
        app_current_scope() = 'parent'
        AND student_id IN (
          SELECT sg.student_id FROM student_guardians sg
          WHERE sg.guardian_user_id = app_current_parent_user_id()
            AND sg.school_id = app_current_school_id()
            AND sg.status = 'active'
        )
      )
      OR (
        app_current_scope() = 'student'
        AND student_id = app_current_student_id()
      )
    )
  );

-- ── 2. exam_mark_entries: parent path restricted to ACTIVE-linked children ──────
DROP POLICY IF EXISTS exam_mark_entries_school ON exam_mark_entries;
CREATE POLICY exam_mark_entries_school ON exam_mark_entries
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND (
      app_current_scope() = 'school'
      OR (app_current_scope() = 'parent' AND student_id IN (
        SELECT sg.student_id FROM student_guardians sg
        WHERE sg.guardian_user_id = app_current_parent_user_id()
          AND sg.school_id = app_current_school_id()
          AND sg.status = 'active'
      ))
    )
  );

-- ── 3. exam_remarks: parent read path restricted to ACTIVE-linked children ──────
--     (WITH CHECK is school-scope only — left unchanged.)
DROP POLICY IF EXISTS exam_remarks_access ON exam_remarks;
CREATE POLICY exam_remarks_access ON exam_remarks
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND (
      app_current_scope() = 'school'
      OR (app_current_scope() = 'parent' AND student_id IN (
        SELECT sg.student_id FROM student_guardians sg
        WHERE sg.guardian_user_id = app_current_parent_user_id()
          AND sg.school_id = app_current_school_id()
          AND sg.status = 'active'
      ))
    )
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

-- ── 4. homework_submissions: parent reads only ACTIVE-linked children ───────────
DROP POLICY IF EXISTS homework_submissions_parent_read ON homework_submissions;
CREATE POLICY homework_submissions_parent_read ON homework_submissions
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'parent'
    AND student_id IN (
      SELECT sg.student_id FROM student_guardians sg
      WHERE sg.guardian_user_id = app_current_parent_user_id()
        AND sg.school_id = app_current_school_id()
        AND sg.status = 'active'
    )
  );

-- ── 5. intel_parent_guidance_reports: parent reads only ACTIVE-linked children ──
--     (outer `status = 'published'` is the REPORT status — left unchanged.)
DROP POLICY IF EXISTS intel_parent_guidance_parent_scope ON intel_parent_guidance_reports;
CREATE POLICY intel_parent_guidance_parent_scope ON intel_parent_guidance_reports
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'parent'
    AND status = 'published'
    AND school_id = app_current_school_id()
    AND student_id IN (
      SELECT sg.student_id FROM student_guardians sg
      WHERE sg.guardian_user_id = app_current_parent_user_id()
        AND sg.school_id = app_current_school_id()
        AND sg.status = 'active'
    )
  );

-- ── 6. attendance_corrections: parent reads only ACTIVE-linked children ─────────
DROP POLICY IF EXISTS attendance_corrections_parent_read ON attendance_corrections;
CREATE POLICY attendance_corrections_parent_read ON attendance_corrections
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'parent'
    AND student_id IN (
      SELECT sg.student_id FROM student_guardians sg
      WHERE sg.guardian_user_id = app_current_parent_user_id()
        AND sg.school_id = app_current_school_id()
        AND sg.status = 'active'
    )
  );

-- ── 7. attendance_corrections: parent may file corrections ONLY for ACTIVE-linked
--     children (write side — a de-authorized guardian must not file corrections
--     for a revoked child). Outer `status = 'pending'` is the CORRECTION status —
--     left unchanged.
DROP POLICY IF EXISTS attendance_corrections_parent_insert ON attendance_corrections;
CREATE POLICY attendance_corrections_parent_insert ON attendance_corrections
  FOR INSERT
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'parent'
    AND requester_role = 'parent'
    AND status = 'pending'
    AND student_id IN (
      SELECT sg.student_id FROM student_guardians sg
      WHERE sg.guardian_user_id = app_current_parent_user_id()
        AND sg.school_id = app_current_school_id()
        AND sg.status = 'active'
    )
  );
