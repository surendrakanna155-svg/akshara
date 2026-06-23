-- Batch 4 (money loop): let parents/students READ their own finance records so
-- the fees → invoice → collection → receipt loop actually reaches the parent app.
--
-- Before this, finance_invoices / finance_collections / finance_receipts were
-- school-scope ONLY. The parent endpoints overlay real finance data under parent
-- scope (see overlayFeesSnapshotFromFinance + the receipts overlay), so every
-- parent/student SELECT returned zero rows and the app silently fell back to the
-- stale seed snapshot — invoices and receipts never reached the parent.
--
-- Access is restricted to the caller's OWN children (parent, via student_guardians)
-- or their OWN record (student). No write access is granted to parent/student.

-- ── finance_invoices: parent sees linked children's invoices; student sees own ──
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
        )
      )
      OR (
        app_current_scope() = 'student'
        AND student_id = app_current_student_id()
      )
    )
  );

-- ── finance_collections: same per-child / per-self restriction ──────────────────
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
        )
      )
      OR (
        app_current_scope() = 'student'
        AND student_id = app_current_student_id()
      )
    )
  );

-- ── finance_receipts: no student_id column; gate via the parent's visible
--    collections. The finance_collections policy above already restricts the
--    sub-select to the caller's own children / own record. ────────────────────────
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
            )
          )
          OR (
            app_current_scope() = 'student'
            AND c.student_id = app_current_student_id()
          )
        )
    )
  );
