-- ICA-F5 (P2, Architecture) — Reconciliation/orphan detector for the two-tier
-- JSONB↔relational soft cross-module references.
--
-- ── THE FINDING ──────────────────────────────────────────────────────────────
-- ~11 operational modules persist their domain state as OPAQUE JSONB in a shared
-- `{module}_entities` table (transport, hostel, library, inventory, alumni,
-- parent, teacher, hr, leave, management, control_center), while finance /
-- admissions / sis / academic are RELATIONAL. Where a JSONB module has to point
-- at a relational row it stores the target's key as a plain string INSIDE the
-- JSONB payload with NO foreign key — a "soft" cross-module reference. The
-- load-bearing example is a MONEY reference: the transport fee seam
-- (transport_write_handlers.ts handleRaiseTransportDemand ~:1821) writes a
-- `demand` row into `transport_entities` whose payload carries
-- `invoiceId` / `assignmentId` / `accountId`, each a UUID string pointing into a
-- relational Finance table, and the revoke path
-- (stopStudentTransport ~:578, `String(demand.invoiceId ?? "")`) reads it back.
-- Because the payload is JSONB, Postgres cannot enforce a FK on those strings.
--
-- ── VERIFIER CORRECTION: High → Low (defense-in-depth, NOT a live bug) ─────────
-- These soft refs CANNOT dangle today. Every enumerated target is delete-proof:
--   • `erp_tenant` (the edge role) is NOT granted DELETE on finance_invoices,
--     finance_fee_assignments, finance_student_accounts or students
--     (grep GRANT: those tables are SELECT/INSERT/UPDATE only — see
--     20260612400000:56, 20260612300000, 20260612100000). Finance "cancels"
--     an invoice by moving invoice_status → 'cancelled' (cancel-by-status), it
--     never rows-out the invoice; the transport soft ref keeps resolving after a
--     cancel because the row still EXISTS.
--   • The ONLY student hard-delete is onboarding import-rollback
--     (20260715000000 onboarding_rollback_student — SECURITY DEFINER), which is
--     scoped to freshly-import-created students. Such a student has no transport
--     demand raised yet; and the moment a demand IS raised, assignFeeStructure
--     creates finance_invoices/finance_fee_assignments/finance_student_accounts
--     rows whose `student_id` REFERENCES students(id) with the DEFAULT
--     (NO ACTION / RESTRICT) — so the DELETE FROM students in rollback would
--     be BLOCKED by those FKs. The student cannot be purged while a transport
--     demand (and therefore its finance rows) exists. The identity ref is
--     RESTRICT-protected transitively.
--   • Raise and revoke both run inside the caller's SINGLE tenant transaction
--     (withTenantContext), so the JSONB demand and its Finance rows are written /
--     cancelled in lockstep — there is no partial-commit window that could
--     strand one side.
-- Net: no path can orphan these refs on the certified trunk. This migration is
-- therefore NOT a bug fix — it (a) DOCUMENTS the invariant that must hold for
-- every soft cross-module reference, and (b) ships a privileged RECONCILIATION
-- detector so any FUTURE regression (a new hard-delete path, a broken lockstep,
-- a bad backfill) is caught operationally instead of silently mis-stating money.
-- Promoting the high-integrity JSONB modules to real relational tables + FKs is
-- the durable fix but is far out of scope for a P2 (multi-module rewrite).
--
-- ── THE INVARIANT (one row per soft cross-module reference) ───────────────────
--   source (JSONB payload field)                     → target (relational key)      owner / why soft
--   ------------------------------------------------   ---------------------------   -------------------------------
--   transport_entities[demand].invoiceId             → finance_invoices.id          Finance owns the invoice; transport
--                                                                                    only points at it. MONEY ref.
--   transport_entities[demand].assignmentId          → finance_fee_assignments.id   Finance owns the assignment. MONEY.
--   transport_entities[demand].accountId             → finance_student_accounts.id  Finance owns the account. MONEY.
--   transport_entities[demand].studentUuid           → students.id                  SIS owns identity; transport stores
--                                                                                    a display code + the resolved UUID.
--   library_entities[fine|issue].sisStudentId        → students.student_code
--                                                        OR student_profiles.admission_number
--                                                                                    Library ledger is JSONB keyed by the
--                                                                                    SIS display code; the SIS no-dues gate
--                                                                                    (sis_certificates_repository
--                                                                                    libraryDuesForStudent) reads it to
--                                                                                    block a TC. A fine whose code resolves
--                                                                                    to no student is an UN-attributable due.
-- INVARIANT: for every row above, the target must resolve within the SAME
-- (organization_id, school_id). The detector returns any row that does not.
--
-- ── POSTURE (mirrors the ICA-E2 detector 20260920000160 + ICA-D3 reaper 130) ──
-- All source and target tables are FORCE ROW LEVEL SECURITY with school-scope
-- policies, so a cross-tenant integrity sweep MUST run under the RLS-bypassing
-- privileged owner role and MUST NOT be reachable from the client `erp_tenant`
-- edge role: SECURITY DEFINER + pinned search_path + REVOKE ALL FROM PUBLIC.
-- LANGUAGE sql, pure read-only SELECT — it detects, it never mutates.
--
-- ── OPS INVOCATION (same ops-cron lane as the E2 detector / D3 reaper) ─────────
-- There is no pg_cron in this DB; run on the existing privileged ops-cron lane
-- (deploy/akshara-vps/backup/install-ops-cron.sh runs `docker exec <pg> psql`):
--     docker exec <akshara-postgres> psql -U <admin> -d <db> \
--       -c "SELECT * FROM detect_orphan_cross_module_refs();"
-- Any returned row is an integrity alarm: reconcile the offending JSONB payload
-- (or the missing relational target) before trusting downstream money/no-dues.
-- Zero rows on a fresh seeded DB (the seed writes no runtime demand/fine/issue
-- rows), so a non-empty result is always a real regression, never seed noise.
--
-- Additive + idempotent (CREATE OR REPLACE FUNCTION). Safe to re-run.

CREATE OR REPLACE FUNCTION detect_orphan_cross_module_refs()
RETURNS TABLE (
  source_module        text,
  source_id            text,
  ref_field            text,
  missing_target_table text,
  missing_id           text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
  -- 1. MONEY: transport demand → finance_invoices(id).
  --    id::text comparison (never ::uuid cast on the payload) so a malformed
  --    payload string is reported as an orphan, not a cast exception.
  SELECT 'transport'::text, te.id, 'invoiceId'::text,
         'finance_invoices'::text, te.payload->>'invoiceId'
    FROM transport_entities te
   WHERE te.entity_type = 'demand'
     AND COALESCE(te.payload->>'invoiceId', '') <> ''
     AND NOT EXISTS (
       SELECT 1 FROM finance_invoices fi
        WHERE fi.id::text = te.payload->>'invoiceId'
          AND fi.organization_id = te.organization_id
          AND fi.school_id       = te.school_id
     )
  UNION ALL
  -- 2. MONEY: transport demand → finance_fee_assignments(id).
  SELECT 'transport'::text, te.id, 'assignmentId'::text,
         'finance_fee_assignments'::text, te.payload->>'assignmentId'
    FROM transport_entities te
   WHERE te.entity_type = 'demand'
     AND COALESCE(te.payload->>'assignmentId', '') <> ''
     AND NOT EXISTS (
       SELECT 1 FROM finance_fee_assignments fa
        WHERE fa.id::text = te.payload->>'assignmentId'
          AND fa.organization_id = te.organization_id
          AND fa.school_id       = te.school_id
     )
  UNION ALL
  -- 3. MONEY: transport demand → finance_student_accounts(id).
  SELECT 'transport'::text, te.id, 'accountId'::text,
         'finance_student_accounts'::text, te.payload->>'accountId'
    FROM transport_entities te
   WHERE te.entity_type = 'demand'
     AND COALESCE(te.payload->>'accountId', '') <> ''
     AND NOT EXISTS (
       SELECT 1 FROM finance_student_accounts sa
        WHERE sa.id::text = te.payload->>'accountId'
          AND sa.organization_id = te.organization_id
          AND sa.school_id       = te.school_id
     )
  UNION ALL
  -- 4. IDENTITY: transport demand → students(id). RESTRICT-protected transitively
  --    (see header), monitored for defense-in-depth against a future purge path.
  SELECT 'transport'::text, te.id, 'studentUuid'::text,
         'students'::text, te.payload->>'studentUuid'
    FROM transport_entities te
   WHERE te.entity_type = 'demand'
     AND COALESCE(te.payload->>'studentUuid', '') <> ''
     AND NOT EXISTS (
       SELECT 1 FROM students s
        WHERE s.id::text = te.payload->>'studentUuid'
          AND s.organization_id = te.organization_id
          AND s.school_id       = te.school_id
     )
  UNION ALL
  -- 5. NO-DUES: library fine/issue → students, keyed by the SIS display code.
  --    Resolution mirrors sis_student_resolver.resolveStudentId EXACTLY:
  --    students.student_code OR student_profiles.admission_number, same tenant.
  --    An un-resolvable code = a library due nobody's no-dues gate can attribute.
  SELECT 'library'::text, le.id, 'sisStudentId'::text,
         'students'::text, le.payload->>'sisStudentId'
    FROM library_entities le
   WHERE le.entity_type IN ('fine', 'issue')
     AND COALESCE(le.payload->>'sisStudentId', '') <> ''
     AND NOT EXISTS (
       SELECT 1
         FROM students s
         LEFT JOIN student_profiles sp
           ON sp.student_id      = s.id
          AND sp.organization_id = s.organization_id
          AND sp.school_id       = s.school_id
        WHERE s.organization_id = le.organization_id
          AND s.school_id       = le.school_id
          AND (
                s.student_code       = le.payload->>'sisStudentId'
             OR sp.admission_number  = le.payload->>'sisStudentId'
          )
     );
$fn$;

-- Cross-tenant integrity sweep: privileged ops role only, never the tenant edge.
REVOKE ALL ON FUNCTION detect_orphan_cross_module_refs() FROM PUBLIC;

COMMENT ON FUNCTION detect_orphan_cross_module_refs() IS
  'ICA-F5 reconciliation detector for JSONB↔relational soft cross-module refs. '
  'Returns one row per unresolved reference (source_module, source_id, ref_field, '
  'missing_target_table, missing_id) for: transport_entities[demand] '
  'invoiceId→finance_invoices, assignmentId→finance_fee_assignments, '
  'accountId→finance_student_accounts, studentUuid→students; and '
  'library_entities[fine|issue] sisStudentId→students(student_code|admission_number). '
  'SECURITY DEFINER so it sweeps across tenants past FORCE RLS; PUBLIC-revoked so '
  'only the privileged ops role runs it. Zero rows on a healthy DB — any row is an '
  'integrity regression (broken raise/revoke lockstep or a new hard-delete path). '
  'OPS: run on the existing ops-cron lane under the privileged DB role, e.g. '
  '`docker exec <akshara-postgres> psql -U <admin> -d <db> -c "SELECT * FROM '
  'detect_orphan_cross_module_refs();"` then reconcile any offending payload/target.';
