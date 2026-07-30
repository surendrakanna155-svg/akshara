-- ICA-E2 (P2, Data-Model) — Referential integrity for three "soft-FK" operational columns.
--
-- FINDING (audit): three UUID NOT NULL columns carry a student/user identifier with
-- NO REFERENCES, so orphan rows are possible and no ON DELETE behaviour is defined:
--     * attendance_records.student_id   (20260614800000_pilot_operations.sql:26)
--     * homework_submissions.student_id  (20260614800000_pilot_operations.sql:61)
--     * comm_recipients.user_id          (20260614700000_communication_hub.sql:120)
--
-- VERIFY — was the missing FK a DELIBERATE decoupling that must be preserved?  NO.
--   The audit cites 20260618000000_academic_soft_fk.sql as "the deliberate soft-FK
--   pattern", but that migration is a *different* concern: it adds NULLABLE academic
--   *catalog* columns (academic_year_id / class_id / section_id) with ON DELETE SET
--   NULL, and DROPS no FK. It does not touch any of the three columns above. The three
--   columns were simply born without a FK on 2026-06-14 (four days BEFORE
--   20260618000000) — there is no evidence of an intentional decoupling, and no real
--   FK was ever deliberately removed. Verified there is no out-of-order-insert path:
--     - attendance_records rows are written for students already enrolled in the
--       session's class; the RLS/writers require the student to pre-exist.
--     - homework_submissions rows are written by an existing student/parent (its RLS
--       joins students + student_guardians), so the student pre-exists.
--     - comm_recipients rows are a delivery fan-out resolved from existing users at
--       broadcast send time, so the user pre-exists.
--   The parents are the canonical `students(id)` and `users(id)`. Every sibling
--   operational child of a student in this schema already uses
--   `REFERENCES students(id) ON DELETE CASCADE` (student_guardians, sis enrollments,
--   intelligence layer, teacher_assistant, parent_insights, …), and students ARE
--   hard-deleted on exactly one path — import rollback
--   (20260715000000_onboarding_rollback_student_secdef.sql: DELETE FROM students) —
--   where the intent is that all of the student's rows disappear with them. Users are
--   NEVER hard-deleted anywhere (soft-delete via users.deleted_at; grep: zero
--   `DELETE FROM users`). comm_recipients is non-authoritative per-user delivery
--   bookkeeping that ALREADY cascades from comm_broadcasts(id) ON DELETE CASCADE.
--
-- DECISION — restore a REAL FK on all three columns (the roadmap's preferred branch:
--   "restore real FKs with explicit ON DELETE where decoupling isn't required"),
--   because decoupling is NOT required for any of them:
--     * attendance_records.student_id  -> students(id) ON DELETE CASCADE
--     * homework_submissions.student_id -> students(id) ON DELETE CASCADE
--         WHY CASCADE: attendance/homework are per-student operational facts, worthless
--         without the student; this matches the ubiquitous `students(id) ON DELETE
--         CASCADE` convention and makes the import-rollback hard-delete clean (today it
--         leaves orphans; with the FK the rows cascade automatically).
--     * comm_recipients.user_id -> users(id) ON DELETE CASCADE
--         WHY CASCADE: comm_recipients is non-authoritative delivery bookkeeping that
--         already cascades from its broadcast. Users are soft-deleted, so this clause
--         effectively never fires; but if a user is ever truly purged (e.g. erasure),
--         CASCADE removes their stale delivery rows instead of orphaning them or (as a
--         RESTRICT FK would) BLOCKING the purge on bookkeeping rows.
--
-- DEPLOY RISK — this repo/live pilot may ALREADY contain orphan rows (that is the very
--   defect). Adding a validated FK would ABORT the deploy if any orphan exists. To be
--   non-destructive AND deploy-safe, each FK is added `NOT VALID`: it is fully enforced
--   for every new INSERT/UPDATE immediately, but existing rows are not scanned, so the
--   migration cannot fail on legacy orphans and never silently deletes data. The
--   constraint is upgraded to fully-trusted later via the documented two-step:
--       1) SELECT * FROM detect_orphan_operational_rows();   -- find offenders
--       2) reconcile/remove the offending rows (ops decision, not a blind migration DELETE)
--       3) ALTER TABLE <t> VALIDATE CONSTRAINT <c>;           -- SHARE UPDATE EXCLUSIVE, non-blocking
--   (On a fresh DB these three tables' rows all reference seeded parents, so a VALIDATE
--   there passes immediately; NOT VALID exists purely to protect the live pilot.)
--
-- Additive + idempotent (guarded ADD CONSTRAINT via pg_constraint check; CREATE OR
-- REPLACE FUNCTION). Safe to re-run.

-- ─── 1. attendance_records.student_id -> students(id) ───────────────────────────────
DO $do$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'attendance_records_student_id_fkey'
      AND conrelid = 'public.attendance_records'::regclass
  ) THEN
    ALTER TABLE public.attendance_records
      ADD CONSTRAINT attendance_records_student_id_fkey
      FOREIGN KEY (student_id) REFERENCES public.students (id)
      ON DELETE CASCADE
      NOT VALID;
  END IF;
END
$do$;

COMMENT ON CONSTRAINT attendance_records_student_id_fkey ON public.attendance_records IS
  'ICA-E2: student_id must reference students(id); ON DELETE CASCADE (per-student '
  'operational fact). Added NOT VALID to be deploy-safe over legacy orphans — VALIDATE '
  'after detect_orphan_operational_rows() reconciliation.';

-- ─── 2. homework_submissions.student_id -> students(id) ─────────────────────────────
DO $do$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'homework_submissions_student_id_fkey'
      AND conrelid = 'public.homework_submissions'::regclass
  ) THEN
    ALTER TABLE public.homework_submissions
      ADD CONSTRAINT homework_submissions_student_id_fkey
      FOREIGN KEY (student_id) REFERENCES public.students (id)
      ON DELETE CASCADE
      NOT VALID;
  END IF;
END
$do$;

COMMENT ON CONSTRAINT homework_submissions_student_id_fkey ON public.homework_submissions IS
  'ICA-E2: student_id must reference students(id); ON DELETE CASCADE (per-student '
  'operational fact). Added NOT VALID to be deploy-safe over legacy orphans — VALIDATE '
  'after detect_orphan_operational_rows() reconciliation.';

-- ─── 3. comm_recipients.user_id -> users(id) ────────────────────────────────────────
DO $do$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'comm_recipients_user_id_fkey'
      AND conrelid = 'public.comm_recipients'::regclass
  ) THEN
    ALTER TABLE public.comm_recipients
      ADD CONSTRAINT comm_recipients_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES public.users (id)
      ON DELETE CASCADE
      NOT VALID;
  END IF;
END
$do$;

COMMENT ON CONSTRAINT comm_recipients_user_id_fkey ON public.comm_recipients IS
  'ICA-E2: user_id must reference users(id); ON DELETE CASCADE (non-authoritative '
  'delivery bookkeeping, already cascades from comm_broadcasts). Added NOT VALID to be '
  'deploy-safe over legacy orphans — VALIDATE after detect_orphan_operational_rows().';

-- ─── Orphan-detection (ops tool + co-requisite for the VALIDATE two-step) ───────────
-- Lists every operational row whose identifier has no parent, so ops can reconcile
-- before VALIDATE CONSTRAINT (and can monitor for orphans introduced by any legacy
-- pre-FK path). SECURITY DEFINER + pinned search_path + REVOKE-from-PUBLIC, matching
-- the ICA-D3 reaper posture (20260920000130): all three tables are FORCE ROW LEVEL
-- SECURITY with school-scope policies, so a cross-tenant integrity sweep MUST run under
-- the RLS-bypassing privileged owner role and MUST NOT be reachable from the client
-- `erp_tenant` edge role.
CREATE OR REPLACE FUNCTION detect_orphan_operational_rows()
RETURNS TABLE (
  source_table text,
  key_column   text,
  orphan_id    uuid,
  missing_ref  uuid
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
  SELECT 'attendance_records'::text, 'student_id'::text, ar.id, ar.student_id
    FROM attendance_records ar
    LEFT JOIN students s ON s.id = ar.student_id
   WHERE s.id IS NULL
  UNION ALL
  SELECT 'homework_submissions'::text, 'student_id'::text, hs.id, hs.student_id
    FROM homework_submissions hs
    LEFT JOIN students s ON s.id = hs.student_id
   WHERE s.id IS NULL
  UNION ALL
  SELECT 'comm_recipients'::text, 'user_id'::text, cr.id, cr.user_id
    FROM comm_recipients cr
    LEFT JOIN users u ON u.id = cr.user_id
   WHERE u.id IS NULL;
$fn$;

-- Privileged ops-lane only; never the tenant edge role.
REVOKE ALL ON FUNCTION detect_orphan_operational_rows() FROM PUBLIC;

COMMENT ON FUNCTION detect_orphan_operational_rows() IS
  'ICA-E2 orphan detector for the NOT VALID FKs on attendance_records.student_id, '
  'homework_submissions.student_id and comm_recipients.user_id. Returns one row per '
  'orphan (source_table, key_column, orphan_id, missing_ref). SECURITY DEFINER so it '
  'sweeps across tenants past FORCE RLS; PUBLIC-revoked so only the privileged ops role '
  'runs it. OPS: run on the existing ops-cron lane under the privileged DB role, e.g. '
  '`docker exec <akshara-postgres> psql -U <admin> -d <db> -c "SELECT * FROM '
  'detect_orphan_operational_rows();"` — reconcile any rows, then '
  '`ALTER TABLE <t> VALIDATE CONSTRAINT <t>_<col>_fkey;` to fully trust each FK.';
