-- MJ-C6a: allow school/organization scope to WRITE notification_templates.
--
-- The original communication-hub migration (20260614700000) put FORCE ROW LEVEL
-- SECURITY on notification_templates but defined only a SELECT policy
-- (notification_templates_school_read). With FORCE RLS and no permissive policy
-- for INSERT, the new POST /communications/templates handler (handleCreateTemplate)
-- could never persist a row under the erp_tenant role — the INSERT had no
-- applicable policy and was silently denied. This adds a school-scoped write
-- policy mirroring comm_broadcasts_school so created templates persist and then
-- appear in GET /communications/templates. The existing SELECT-read policy is
-- left intact (broader: also allows org-wide NULL-school templates to be read).

CREATE POLICY notification_templates_school_write ON notification_templates
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND (
      (app_current_scope() = 'school' AND (school_id IS NULL OR school_id = app_current_school_id()))
      OR (app_current_scope() = 'organization' AND school_id IS NULL)
    )
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND (
      (app_current_scope() = 'school' AND (school_id IS NULL OR school_id = app_current_school_id()))
      OR (app_current_scope() = 'organization' AND school_id IS NULL)
    )
  );
