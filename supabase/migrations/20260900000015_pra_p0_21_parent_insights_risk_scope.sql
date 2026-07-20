-- PRA-P0-21 (S6): Parent Insights AI served every parent fabricated data.
--
-- The Parent Insights generator (parent_insights_service.ts) reads
-- intel_student_risk_snapshots to build the narrative. That table's RLS
-- (migration 20260621000000) is SCHOOL-scope only:
--     app_current_scope() = 'school'
-- so a parent token (scope = 'parent') matched ZERO rows for its OWN child's
-- studentId. The service then silently defaulted the missing metrics to
-- 85% / 80% / 70% / "your child" and had the model narrate the fabrication as
-- real school data — on a paid plan.
--
-- This adds a PARENT-scope SELECT policy so a parent can read ONLY their own
-- ACTIVE-linked child's risk snapshot (mirrors the students / parent_insight
-- policies at 20260609100000 and 20260725000000). It does NOT grant parents any
-- write access, and the existing school FOR ALL policy is untouched — multiple
-- permissive policies OR together per command, so school staff are unaffected.
--
-- Combined with (a) the handler child_ids ownership gate and (b) the service no
-- longer defaulting on a missing snapshot (it now raises ParentInsightsNoDataError
-- → honest 404), the feature serves REAL data for the parent's own child or an
-- honest "no data yet" — never fabrication.

DROP POLICY IF EXISTS intel_student_risk_parent_read ON intel_student_risk_snapshots;

CREATE POLICY intel_student_risk_parent_read ON intel_student_risk_snapshots
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'parent'
    AND school_id = app_current_school_id()
    AND student_id IN (
      SELECT sg.student_id
      FROM student_guardians sg
      WHERE sg.guardian_user_id = app_current_parent_user_id()
        AND sg.status = 'active'
    )
  );
