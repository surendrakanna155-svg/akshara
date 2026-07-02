-- COM-1 + thread-RLS security fix — communication module.
--
-- (a) COM-1: link every notification delivery back to the broadcast that
--     produced it, so a per-broadcast delivery/read report can be computed off
--     the authoritative `notification_deliveries` ledger (status set by the
--     drain, is_read set by the mark-read handlers). `comm_recipients` remains
--     the intended-audience record (delivery_status stays 'pending') and is NOT
--     used for the report.
--
-- (b) SECURITY FIX (P1 — cross-scope thread leak): the original policies from
--     20260614700000_communication_hub.sql let ANY school-scoped user read and
--     write EVERY parent<->teacher thread and its messages:
--       * comm_threads_participant's USING ended with a blanket
--         `OR app_current_scope() = 'school'`, so a school-scoped user matched
--         every thread regardless of whether they were its teacher participant.
--       * comm_messages_thread gated only on
--         `app_current_scope() IN ('parent','school')` with NO check that the
--         caller actually participates in the message's thread — so any
--         school-scoped (and any parent-scoped) user could read/write messages
--         in threads they are not part of.
--     A teacher/admin at a school could therefore read another teacher's private
--     parent conversations. This migration recreates both policies so visibility
--     is PARTICIPANT-ONLY: a row is visible only to the thread's parent
--     participant (parent scope) or its teacher participant (school scope).
--     Grants and FORCE RLS are unchanged.

-- ── (a) COM-1: broadcast linkage on the delivery ledger ──────────────────────

ALTER TABLE notification_deliveries
  ADD COLUMN broadcast_id UUID REFERENCES comm_broadcasts (id) ON DELETE SET NULL;

CREATE INDEX idx_notification_deliveries_broadcast
  ON notification_deliveries (broadcast_id)
  WHERE broadcast_id IS NOT NULL;

-- ── (b) SECURITY FIX: participant-only thread + message visibility ────────────

-- comm_threads: a school-scoped user may only see/write threads where they are
-- the teacher participant; a parent-scoped user only threads where they are the
-- parent participant. The old blanket `OR scope = 'school'` is removed. A writer
-- must also be a participant (WITH CHECK repeats the participant predicate).
DROP POLICY IF EXISTS comm_threads_participant ON comm_threads;
CREATE POLICY comm_threads_participant ON comm_threads
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND (
      (app_current_scope() = 'parent' AND parent_user_id = app_current_user_id())
      OR (app_current_scope() = 'school' AND teacher_user_id = app_current_user_id())
    )
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND (
      (app_current_scope() = 'parent' AND parent_user_id = app_current_user_id())
      OR (app_current_scope() = 'school' AND teacher_user_id = app_current_user_id())
    )
  );

-- comm_messages: a message is visible/writable only if the caller participates
-- in its parent thread (as the thread's parent OR teacher participant). The old
-- blanket `scope IN ('parent','school')` check is replaced by an EXISTS against
-- the owning thread.
DROP POLICY IF EXISTS comm_messages_thread ON comm_messages;
CREATE POLICY comm_messages_thread ON comm_messages
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND EXISTS (
      SELECT 1 FROM comm_threads t
       WHERE t.id = comm_messages.thread_id
         AND t.organization_id = app_current_tenant_id()
         AND (
           t.parent_user_id = app_current_user_id()
           OR t.teacher_user_id = app_current_user_id()
         )
    )
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND EXISTS (
      SELECT 1 FROM comm_threads t
       WHERE t.id = comm_messages.thread_id
         AND t.organization_id = app_current_tenant_id()
         AND (
           t.parent_user_id = app_current_user_id()
           OR t.teacher_user_id = app_current_user_id()
         )
    )
  );
