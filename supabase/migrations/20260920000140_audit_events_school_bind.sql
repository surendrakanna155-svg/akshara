-- ICA-B6 (P2, Security) — bind school_id in the audit_events INSERT policy.
--
-- LEAK. The audit_events INSERT policy (defined once, verbatim below, in
-- 20260614500000_audit_ingestion_domain_events.sql:74-78) gated a write with
-- ONLY:
--
--     organization_id = app_current_tenant_id()
--     AND app_current_scope() IN ('organization', 'school', 'parent', 'student')
--
-- It never bound `school_id`. A school-scoped caller could therefore INSERT an
-- audit row tagged with a DIFFERENT school's `school_id` within its own org —
-- forging/mis-attributing the forensic trail (the very trail RLS is meant to
-- protect). The SELECT policy (`audit_events_tenant_read`) already binds
-- `school_id = app_current_school_id()` in school scope, and the house write
-- pattern (`notification_templates_school_write`, `comm_broadcasts_school`,
-- `comm_messages_school`) binds it too; the INSERT policy was the outlier.
--
-- FIX. Add `AND (school_id IS NULL OR school_id = app_current_school_id())` to
-- the WITH CHECK, matching the SELECT/finance house pattern. Both audit writers
-- derive `school_id` from `claims.school_id`, which is exactly the value
-- `app.set_request_context` loads into `app.school_id` (=> app_current_school_id()),
-- so legitimate writes are unaffected:
--   * organization scope  -> claims.school_id NULL  -> row school_id NULL   (IS NULL branch)
--   * school/parent/student scope -> row school_id = app_current_school_id() (match branch)
-- Only a cross-school override (the attack, e.g. a client-supplied event.schoolId
-- for another school) is now rejected at the DB boundary.
--
-- Idempotent: DROP IF EXISTS + CREATE. The scope list and org predicate are
-- reproduced verbatim from the original so no other behaviour changes.

DROP POLICY IF EXISTS audit_events_tenant_insert ON audit_events;

CREATE POLICY audit_events_tenant_insert ON audit_events
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school', 'parent', 'student')
    AND (school_id IS NULL OR school_id = app_current_school_id())
  );
