-- Adaptive AI — W2 persona rollout: make per-user Persona Memory reachable by the
-- per-user personas (teacher/parent/student), not only school-scope sessions.
--
-- `ai_persona_memory` holds ONE row per (organization, school, user) capturing a
-- user's OWN feed preferences + accept/dismiss learning. The original policy
-- (migration 20260868) inherited an `app_current_scope() = 'school'` clause that
-- was copy-pasted from the genuinely school-shared cache/profile tables. But a
-- per-user preferences row is NOT a school-shared resource — that clause silently
-- blocked parent/student sessions (app_current_scope() = 'parent' | 'student')
-- from persisting their own feed dismissals, even though the row is unambiguously
-- theirs (teacher sessions are already scope='school', so they were unaffected).
--
-- The relaxed policy keeps FULL per-user isolation — organization + school +
-- user_id — and drops only the scope clause. app.set_request_context sets
-- app.user_id to the caller's own user id for EVERY scope
-- (tenant_db.ts claimsToTenantParams: userId = claims.sub), and app.school_id is
-- likewise set for parent/student sessions, so a parent/student can read/write
-- ONLY their own (org, school, user) row. No cross-user or cross-scope exposure
-- is introduced; this strictly widens which session scopes may touch their own
-- row, not which rows any session may touch.

DROP POLICY IF EXISTS ai_persona_memory_user_scope ON ai_persona_memory;

CREATE POLICY ai_persona_memory_user_scope ON ai_persona_memory
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND user_id = app_current_user_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND user_id = app_current_user_id()
  );
