-- Adaptive AI — P3-AI-1 / W1 residual: govern org-scoped model callers too.
--
-- ai_call_log was school-scoped (W1.1). Org-level AI surfaces — the director
-- executive summary, org-builder recommendations, onboarding school-builder —
-- have no single school, so they could not be logged or spend-capped. This
-- makes ai_call_log dual-scope: school_id may be NULL, and a NULL row is an
-- org-scoped call visible only to an organization-scope session. School rows
-- are unchanged. Additive/dormant (prod at 20260866).
--
-- (ai_response_cache stays school-scoped; org-level shared generations — e.g.
-- one director digest per org per week — are a W2 shared-generation concern.)

ALTER TABLE ai_call_log ALTER COLUMN school_id DROP NOT NULL;

DROP POLICY ai_call_log_school_scope ON ai_call_log;

CREATE POLICY ai_call_log_tenant_scope ON ai_call_log
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND (
      (app_current_scope() = 'school' AND school_id = app_current_school_id())
      OR (app_current_scope() = 'organization' AND school_id IS NULL)
    )
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND (
      (app_current_scope() = 'school' AND school_id = app_current_school_id())
      OR (app_current_scope() = 'organization' AND school_id IS NULL)
    )
  );
