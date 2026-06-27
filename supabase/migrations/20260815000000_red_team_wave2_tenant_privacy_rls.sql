-- Red Team Wave 2 — Tenant & Privacy (Row-Level Security).
-- Source of truth: docs/RED_TEAM_MASTER_TRACKER.md (RT-09 … RT-15).
--
-- Wave 1 closed the *transactional* gaps (duplicates / lost updates). Wave 2
-- closes the *isolation* gaps: a set of tables whose RLS gated only
-- organization + school but NOT the acting persona, so under `parent`/`student`
-- scope one family could read or write another family's data, or a school could
-- pollute a sibling school's audit trail within the same org.
--
-- Every fix below REPLACES an existing policy with a stricter one that keeps the
-- legitimate caller working (verified against the live edge handlers) while
-- denying the cross-tenant vector each finding reproduced live. The canonical
-- per-child predicate mirrors 20260725000000 (parent_insights) /
-- 20260609100000 (students_scope_access): a parent may only touch rows for
-- students linked to them via an ACTIVE student_guardians row.
--
-- No table is created here; this is pure policy hardening. All affected tables
-- already grant the necessary privileges to erp_tenant (unchanged).

-- ─────────────────────────────────────────────────────────────────────────────
-- RT-09 (Critical / P1) — Parent academic summaries: cross-family PII.
--   `parent_academic_summaries_scope` gated only org+school, so any parent could
--   read/alter ANY child's academic summary (probe: rows_visible=1 for a
--   non-guardian parent). The parent edge path (`getParentAcademicSummary`)
--   already calls `assertParentChildAccess` at the app layer; this adds the
--   DB-level guardian pin as the last line of defence, and a WITH CHECK so the
--   parent-scope UPSERT (generate-on-read) cannot write a foreign child either.
--   School scope (staff who generate the summaries) retains full school access.
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS parent_academic_summaries_scope ON parent_academic_summaries;

CREATE POLICY parent_academic_summaries_access ON parent_academic_summaries
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

-- ─────────────────────────────────────────────────────────────────────────────
-- RT-10 (Medium / P3) — Parent engagement snapshots: cross-parent metric leak.
--   `parent_engagement_scope` gated only org+school, so a parent could read
--   another parent's engagement row (probe: score=99 visible). The only callers
--   are STAFF dashboards (`getParentActivationStats`, gated `viewPilotDashboard`;
--   communication analytics) — there is no parent-facing read path. Restrict the
--   table to `school` scope; parent/student scope is denied entirely, which
--   fully closes the leak with zero functional impact.
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS parent_engagement_scope ON parent_engagement_snapshots;

CREATE POLICY parent_engagement_scope ON parent_engagement_snapshots
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'school'
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'school'
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- RT-11 (High / P1) — Parent meeting summaries: cross-family meeting-summary leak.
--   `parent_meeting_summaries_scope` gated only org+school (no scope check at
--   all), so any parent could read another family's parent-teacher meeting
--   summary (probe: rows_visible=1). The only caller is the TEACHER write path
--   (`POST /intelligence/teacher-effectiveness/parent-meeting-summary`, school
--   scope) — there is no parent-facing surface. Restrict to `school` scope,
--   which fully closes the cross-family leak. (If a parent surface is ever
--   added, swap to the guardian-pin predicate used for RT-09 above.)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS parent_meeting_summaries_scope ON parent_meeting_summaries;

CREATE POLICY parent_meeting_summaries_scope ON parent_meeting_summaries
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'school'
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'school'
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- RT-12 (High / P1) — Communication Hub: parent reads/posts into ANY thread.
--   `comm_messages_thread` allowed `scope IN ('parent','school')` with no
--   thread-participation check, so parent A could read parent B's private
--   message and inject into B's thread (probe: read "PRIVATE-MSG-FOR-FAMILY-B").
--   The sibling `comm_threads_participant` already pins a parent to threads where
--   `parent_user_id = app_current_user_id()`. Mirror that here: a parent may only
--   touch messages whose thread they participate in (USING + WITH CHECK, so the
--   participation check also gates posting). School scope retains full access.
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS comm_messages_thread ON comm_messages;

CREATE POLICY comm_messages_thread ON comm_messages
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND (
      app_current_scope() = 'school'
      OR (
        app_current_scope() = 'parent'
        AND EXISTS (
          SELECT 1
          FROM comm_threads t
          WHERE t.id = comm_messages.thread_id
            AND t.organization_id = app_current_tenant_id()
            AND t.school_id = app_current_school_id()
            AND t.parent_user_id = app_current_user_id()
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
        AND EXISTS (
          SELECT 1
          FROM comm_threads t
          WHERE t.id = comm_messages.thread_id
            AND t.organization_id = app_current_tenant_id()
            AND t.school_id = app_current_school_id()
            AND t.parent_user_id = app_current_user_id()
        )
      )
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- RT-13 (High / P2) — School Memories: parent/student can WRITE school content.
--   The three `school_memory_*_school` policies were `FOR ALL USING (… scope IN
--   ('school','parent','student'))` with no WITH CHECK, so the broad USING
--   doubled as the write check: a parent/student could INSERT/UPDATE/DELETE
--   school-wide memory rows (probe: parent INSERT → INSERT 0 1). Reads to
--   parents/students are intentional (they view memories), so split each table
--   into a broad READ policy and a school-only WRITE policy. INSERT/UPDATE/DELETE
--   now require `school` scope; SELECT stays open to school/parent/student.
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS school_memory_events_school ON school_memory_events;
CREATE POLICY school_memory_events_read ON school_memory_events
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'parent', 'student')
  );
CREATE POLICY school_memory_events_write ON school_memory_events
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'school'
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'school'
  );

DROP POLICY IF EXISTS school_memory_albums_school ON school_memory_albums;
CREATE POLICY school_memory_albums_read ON school_memory_albums
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'parent', 'student')
  );
CREATE POLICY school_memory_albums_write ON school_memory_albums
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'school'
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'school'
  );

DROP POLICY IF EXISTS school_memory_media_school ON school_memory_media;
CREATE POLICY school_memory_media_read ON school_memory_media
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'parent', 'student')
  );
CREATE POLICY school_memory_media_write ON school_memory_media
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'school'
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() = 'school'
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- RT-14 (Medium / P3) — Audit / domain_events: within-org cross-school pollution.
--   `domain_events_school_insert` WITH CHECK pinned only `organization_id` and
--   the scope set, NOT `school_id`, so a school-A context could INSERT an event
--   tagged school-B (probe: INSERT 0 1). The companion UPDATE policy was equally
--   loose. Pin `school_id = app_current_school_id()` for the per-school scopes
--   (school/parent/student); `organization` scope is genuinely org-wide (the
--   outbox drain `publishPendingDomainEvents` runs WHERE organization_id only)
--   and keeps unrestricted school_id. Parent/student INSERT is retained (B3
--   persona-mutation audit) but now pinned to the caller's own school.
--   `enqueueDomainEvent` always writes school_id = claims.school_id, so this is a
--   no-op for every legitimate emit and a hard stop for a forged school_id.
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS domain_events_school_insert ON domain_events;
CREATE POLICY domain_events_school_insert ON domain_events
  FOR INSERT
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND (
      app_current_scope() = 'organization'
      OR (
        app_current_scope() IN ('school', 'parent', 'student')
        AND school_id = app_current_school_id()
      )
    )
  );

DROP POLICY IF EXISTS domain_events_school_update ON domain_events;
CREATE POLICY domain_events_school_update ON domain_events
  FOR UPDATE
  USING (
    organization_id = app_current_tenant_id()
    AND (
      app_current_scope() = 'organization'
      OR (
        app_current_scope() = 'school'
        AND school_id = app_current_school_id()
      )
    )
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND (
      app_current_scope() = 'organization'
      OR (
        app_current_scope() = 'school'
        AND school_id = app_current_school_id()
      )
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- RT-15 (Low / P4) — Platform secret vault: defence-in-depth.
--   Live probe found `erp_tenant` has NO grant on `platform_secret_vault`
--   (permission denied) so it is not reachable today — a FALSE POSITIVE for
--   current exploitability. But the table was created without RLS enabled, so it
--   relies solely on the absence of a grant. Add the missing belt-and-braces:
--   enable + force RLS and install a deny-all policy, so even if a grant is ever
--   added by mistake, no tenant role can read the encrypted secrets. The platform
--   service role (BYPASSRLS / table owner) is unaffected.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE platform_secret_vault ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_secret_vault FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS platform_secret_vault_deny_all ON platform_secret_vault;
CREATE POLICY platform_secret_vault_deny_all ON platform_secret_vault
  FOR ALL
  USING (false)
  WITH CHECK (false);
