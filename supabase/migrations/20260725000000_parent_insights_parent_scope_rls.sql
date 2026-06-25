-- B3 — Parent Insights surfaced for parents.
--
-- The original Parent Insights tables (v10.8) were authored before the feature
-- was wired into the parent app: their RLS assumed *school* scope only and did
-- not restrict a parent to their own children. Surfacing the feature to parents
-- exposed two gaps:
--   1) parents (scope = 'parent') were blocked entirely;
--   2) the school-scope policy did not scope rows to the parent's own children.
--
-- This migration replaces both policies with parent-aware versions that mirror
-- the canonical pattern from 20260609100000 (students_scope_access): a parent
-- may only touch snapshots for students linked to them via active
-- student_guardians, and only their own language-preference rows. School staff
-- (scope = 'school') retain full school-scoped access for staff-generated
-- summaries. Per-child authorization now lives in the database, not just the
-- edge handler.

-- ── parent_insight_snapshots ────────────────────────────────────────────────
DROP POLICY IF EXISTS parent_insight_snapshots_school_scope ON parent_insight_snapshots;

CREATE POLICY parent_insight_snapshots_access ON parent_insight_snapshots
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND (
      app_current_scope() = 'school'
      OR (
        app_current_scope() = 'parent'
        AND student_id IN (
          SELECT sg.student_id
          FROM student_guardians sg
          WHERE sg.guardian_user_id = app_current_parent_user_id()
            AND sg.status = 'active'
        )
      )
    )
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND (
      app_current_scope() = 'school'
      OR (
        app_current_scope() = 'parent'
        AND student_id IN (
          SELECT sg.student_id
          FROM student_guardians sg
          WHERE sg.guardian_user_id = app_current_parent_user_id()
            AND sg.status = 'active'
        )
      )
    )
  );

-- ── parent_language_preferences ─────────────────────────────────────────────
DROP POLICY IF EXISTS parent_language_preferences_scope ON parent_language_preferences;

CREATE POLICY parent_language_preferences_access ON parent_language_preferences
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND (
      app_current_scope() = 'school'
      OR (
        app_current_scope() = 'parent'
        AND user_id = app_current_parent_user_id()
      )
    )
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND (
      app_current_scope() = 'school'
      OR (
        app_current_scope() = 'parent'
        AND user_id = app_current_parent_user_id()
      )
    )
  );

-- ── organization_subscriptions: server-side entitlement resolution for parents ─
-- The edge entitlement resolver (`resolveSubscription`) reads the org's plan
-- under the *caller's* tenant context. Parent/student scopes previously could
-- not read this row, so wrapping a persona route with `withEntitlement` made the
-- resolver fall back to Trial and wrongly return 402. Allow read for parent and
-- student scope, restricted to their own org. The raw row is never returned to
-- the client — only the server-side entitlement decision uses it.
DROP POLICY IF EXISTS organization_subscriptions_read ON organization_subscriptions;

CREATE POLICY organization_subscriptions_read ON organization_subscriptions
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = ANY (
      ARRAY['organization', 'school', 'parent', 'student']
    )
  );

-- ── domain_events / audit_events: allow persona-scope mutation audits ─────────
-- A parent-driven mutation (e.g. generating an insight) must be audited like any
-- other. `audit_events` already permits parent/student inserts; the companion
-- `domain_events` outbox did not, so the audit emit failed under parent scope.
-- Mirror the audit_events grant so persona-scope writes are fully auditable.
DROP POLICY IF EXISTS domain_events_school_insert ON domain_events;
CREATE POLICY domain_events_school_insert ON domain_events
  FOR INSERT
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = ANY (
      ARRAY['organization', 'school', 'parent', 'student']
    )
  );

DROP POLICY IF EXISTS domain_events_school_update ON domain_events;
CREATE POLICY domain_events_school_update ON domain_events
  FOR UPDATE
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = ANY (
      ARRAY['organization', 'school', 'parent', 'student']
    )
  );
