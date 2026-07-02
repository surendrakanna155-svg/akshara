-- TCH-9 — "My Attendance" (P1): staff self-service read path for staff_check_ins.
--
-- Until now the ONLY read policy on staff_check_ins was the school-scoped
-- staff_check_ins_school_read (migration 20260818000000) — correct for the
-- HR muster / principal reporting, but it gave the self-service path no
-- row-level guarantee of its own: any school-scoped read reached the WHOLE
-- school ledger. The new read-only GET /staff-attendance/my-history route lets
-- every authenticated staff member read THEIR OWN check-in history, so the
-- ledger gets a SELF-scoped SELECT policy pinned to the JWT subject.
-- Defense-in-depth: the API handler ALSO binds every query to claims.sub, so
-- self-scoping is enforced twice (SQL predicate + RLS).
--
-- Deliberately unchanged:
--   • staff_check_ins_school_read stays — HR/principal reporting still reads
--     the school ledger (policies are permissive; this one only ADDS a path).
--   • NO UPDATE/DELETE grant — staff_check_ins remains append-only
--     (a check-in is an immutable record of fact).
--   • staff_attendance_requests needs no new policy: its self-read path for
--     one's own manual requests already exists via attendance_request_school_read
--     (SELECT USING org + school scope, migration 20260820000000) — every
--     requester is school-scoped staff, so their own rows are always visible.

CREATE POLICY staff_check_ins_self_read ON staff_check_ins
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND user_id = app_current_user_id()
  );
