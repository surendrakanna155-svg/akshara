-- PRA-P1-02 (S2) — guardian-link RLS must honour the link status.
--
-- The parent/student read policies added in 20260703100000 (exam) and
-- 20260704000000 (finance) gate a parent's visibility of a child's records
-- through a `student_guardians` sub-select — but they match ANY link row,
-- omitting the `status = 'active'` clause. `student_guardians.status` is
-- ('active' | 'inactive'); once the guardian-unlink writer (this stage) sets a
-- link to 'inactive', the parent-scope context resolution already stops
-- returning that child (auth_context.resolveParentContext filters
-- status='active'), but these RLS sub-selects would STILL leak that child's
-- invoices, collections, receipts, and enrollments to the unlinked guardian.
--
-- This migration re-creates the four affected policies verbatim with the single
-- added predicate `AND status = 'active'` on every student_guardians sub-select,
-- so an unlinked (inactive) guardian sees nothing. Idempotent (DROP ... IF
-- EXISTS + CREATE), purely tightening (never widens access).

-- ── finance_invoices: parent sees ACTIVE-linked children's invoices ─────────────
DROP POLICY IF EXISTS finance_invoices_parent_student_read ON finance_invoices;
CREATE POLICY finance_invoices_parent_student_read ON finance_invoices
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND (
      (
        app_current_scope() = 'parent'
        AND student_id IN (
          SELECT student_id FROM student_guardians
          WHERE guardian_user_id = app_current_parent_user_id()
            AND school_id = app_current_school_id()
            AND status = 'active'
        )
      )
      OR (
        app_current_scope() = 'student'
        AND student_id = app_current_student_id()
      )
    )
  );

-- ── finance_collections: same per-active-child / per-self restriction ───────────
DROP POLICY IF EXISTS finance_collections_parent_student_read ON finance_collections;
CREATE POLICY finance_collections_parent_student_read ON finance_collections
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND (
      (
        app_current_scope() = 'parent'
        AND student_id IN (
          SELECT student_id FROM student_guardians
          WHERE guardian_user_id = app_current_parent_user_id()
            AND school_id = app_current_school_id()
            AND status = 'active'
        )
      )
      OR (
        app_current_scope() = 'student'
        AND student_id = app_current_student_id()
      )
    )
  );

-- ── finance_receipts: gated via the parent's ACTIVE-linked collections ──────────
DROP POLICY IF EXISTS finance_receipts_parent_student_read ON finance_receipts;
CREATE POLICY finance_receipts_parent_student_read ON finance_receipts
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = ANY (ARRAY['parent', 'student'])
    AND collection_id IN (
      SELECT c.id FROM finance_collections c
      WHERE c.organization_id = app_current_tenant_id()
        AND c.school_id = app_current_school_id()
        AND (
          (
            app_current_scope() = 'parent'
            AND c.student_id IN (
              SELECT student_id FROM student_guardians
              WHERE guardian_user_id = app_current_parent_user_id()
                AND school_id = app_current_school_id()
                AND status = 'active'
            )
          )
          OR (
            app_current_scope() = 'student'
            AND c.student_id = app_current_student_id()
          )
        )
    )
  );

-- ── sis_student_enrollments: parent reads ACTIVE-linked children's enrollments ──
DROP POLICY IF EXISTS sis_student_enrollments_parent_student_read ON sis_student_enrollments;
CREATE POLICY sis_student_enrollments_parent_student_read ON sis_student_enrollments
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND (
      (
        app_current_scope() = 'parent'
        AND student_id IN (
          SELECT student_id FROM student_guardians
          WHERE guardian_user_id = app_current_parent_user_id()
            AND school_id = app_current_school_id()
            AND status = 'active'
        )
      )
      OR (
        app_current_scope() = 'student'
        AND student_id = app_current_student_id()
      )
    )
  );
