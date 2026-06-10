-- Sprint 4 Phase 5C.0d — School-scoped teacher display names for Academic APIs
-- Allows erp_tenant (school scope) to read users.display_name only for users with
-- an active school_memberships row in the current school. Org/parent/student scopes
-- remain denied (existing policies unchanged).

CREATE POLICY users_school_staff_directory ON users
  FOR SELECT
  USING (
    app_current_scope() = 'school'
    AND EXISTS (
      SELECT 1
      FROM school_memberships sm
      INNER JOIN schools s ON s.id = sm.school_id
      WHERE sm.user_id = users.id
        AND sm.school_id = app_current_school_id()
        AND sm.status = 'active'
        AND s.organization_id = app_current_tenant_id()
    )
  );
