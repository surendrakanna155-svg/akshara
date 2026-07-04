import type { TenantQueryClient } from "../tenant_db.ts";

// FIN-R3/R4/R5/R6 — fee-recovery CRM data access over the tables created in
// 20260823000000_finance_recovery_crm.sql. Additive: never touches the
// collection/invoice money path.

export interface RecoveryContactRow {
  id: string;
  student_id: string;
  fee_account_id: string | null;
  channel: string;
  outcome: string;
  notes: string;
  contacted_by: string | null;
  created_at: string;
}

export interface PromiseToPayRow {
  id: string;
  student_id: string;
  student_name: string;
  fee_account_id: string | null;
  amount_minor: string;
  promise_date: string;
  status: string;
  notes: string;
  created_by: string | null;
  created_at: string;
  resolved_by: string | null;
  resolved_at: string | null;
}

export interface RecoveryTargetRow {
  id: string;
  collector_user_id: string | null;
  period_month: string;
  target_minor: string;
  created_at: string;
  updated_at: string;
}

export async function insertRecoveryContact(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string;
    studentId: string;
    feeAccountId: string | null;
    channel: string;
    outcome: string;
    notes: string;
    contactedBy: string | null;
  },
): Promise<RecoveryContactRow> {
  const rows = await db.queryObject<RecoveryContactRow>(
    `INSERT INTO finance_recovery_contacts (
       organization_id, school_id, student_id, fee_account_id, channel, outcome,
       notes, contacted_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING id, student_id, fee_account_id, channel, outcome, notes,
               contacted_by, created_at`,
    [
      input.organizationId,
      input.schoolId,
      input.studentId,
      input.feeAccountId,
      input.channel,
      input.outcome,
      input.notes,
      input.contactedBy,
    ],
  );
  return rows[0]!;
}

export async function listRecoveryContactsForStudent(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  studentId: string,
  limit = 100,
): Promise<RecoveryContactRow[]> {
  return await db.queryObject<RecoveryContactRow>(
    `SELECT id, student_id, fee_account_id, channel, outcome, notes,
            contacted_by, created_at
       FROM finance_recovery_contacts
      WHERE organization_id = $1 AND school_id = $2 AND student_id = $3
      ORDER BY created_at DESC
      LIMIT $4`,
    [orgId, schoolId, studentId, limit],
  );
}

/// Recent contacts for a batch of students (for the defaulters list enrichment).
export async function listRecentContactsForStudents(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  studentIds: string[],
  perStudent = 5,
): Promise<RecoveryContactRow[]> {
  if (studentIds.length === 0) return [];
  return await db.queryObject<RecoveryContactRow>(
    `SELECT id, student_id, fee_account_id, channel, outcome, notes,
            contacted_by, created_at
       FROM (
         SELECT c.*,
                row_number() OVER (
                  PARTITION BY student_id ORDER BY created_at DESC
                ) AS rn
           FROM finance_recovery_contacts c
          WHERE organization_id = $1 AND school_id = $2
            AND student_id = ANY($3::uuid[])
       ) t
      WHERE t.rn <= $4
      ORDER BY student_id, created_at DESC`,
    [orgId, schoolId, studentIds, perStudent],
  );
}

export interface CallQueueRow {
  student_id: string;
  student_name: string;
  admission_number: string;
  class_label: string;
  outstanding: string;
  fee_account_id: string;
  days_overdue: string;
  guardian_phone: string | null;
  last_contact_at: string | null;
  pending_promise_date: string | null;
  has_broken_promise: boolean;
}

/// FIN-R2 — the telecaller call-queue candidate pool: the SAME open/overdue
/// student accounts the defaulters list is built from (no duplicate source),
/// enriched per student with the signals a telecaller prioritises on — last
/// contact time, the nearest pending promise date, and whether a promise was
/// broken. Ranking + reason are computed by the pure functions in the handler
/// (testable); this only pulls the rows. Bounded to the highest-balance arrears.
export async function listCallQueue(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  limit = 100,
): Promise<CallQueueRow[]> {
  return await db.queryObject<CallQueueRow>(
    `SELECT
        fsa.student_id,
        COALESCE(s.display_name, 'Student') AS student_name,
        COALESCE(
          (SELECT afh.admission_number FROM admissions_fee_handoffs afh
            WHERE afh.student_id = fsa.student_id
              AND afh.organization_id = fsa.organization_id LIMIT 1),
          s.student_code, '') AS admission_number,
        COALESCE(
          (SELECT afh.class_label FROM admissions_fee_handoffs afh
            WHERE afh.student_id = fsa.student_id
              AND afh.organization_id = fsa.organization_id LIMIT 1),
          '') AS class_label,
        COALESCE(fsa.outstanding_amount, 0)::text AS outstanding,
        fsa.id::text AS fee_account_id,
        COALESCE((
          SELECT MAX(EXTRACT(day FROM now() - fi.due_date))::int
            FROM finance_invoices fi
           WHERE fi.student_id = fsa.student_id
             AND fi.organization_id = fsa.organization_id
             AND fi.invoice_status IN ('issued', 'partially_paid')
             AND fi.due_date < CURRENT_DATE), 0)::text AS days_overdue,
        (SELECT u.phone FROM student_guardians sg
           JOIN users u ON u.id = sg.guardian_user_id
          WHERE sg.student_id = fsa.student_id AND u.phone IS NOT NULL
          ORDER BY sg.is_primary DESC LIMIT 1) AS guardian_phone,
        (SELECT MAX(c.created_at) FROM finance_recovery_contacts c
          WHERE c.organization_id = fsa.organization_id
            AND c.school_id = fsa.school_id
            AND c.student_id = fsa.student_id) AS last_contact_at,
        (SELECT MIN(p.promise_date)::text FROM finance_promises_to_pay p
          WHERE p.organization_id = fsa.organization_id
            AND p.school_id = fsa.school_id
            AND p.student_id = fsa.student_id
            AND p.status = 'pending') AS pending_promise_date,
        EXISTS(SELECT 1 FROM finance_promises_to_pay p
          WHERE p.organization_id = fsa.organization_id
            AND p.school_id = fsa.school_id
            AND p.student_id = fsa.student_id
            AND p.status = 'broken') AS has_broken_promise
      FROM finance_student_accounts fsa
      LEFT JOIN students s ON s.id = fsa.student_id
     WHERE fsa.organization_id = $1 AND fsa.school_id = $2
       AND fsa.status = 'open'
       AND fsa.outstanding_amount > 0
     ORDER BY fsa.outstanding_amount DESC
     LIMIT $3`,
    [orgId, schoolId, limit],
  );
}

export async function insertPromiseToPay(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string;
    studentId: string;
    feeAccountId: string | null;
    amountMinor: number;
    promiseDate: string;
    notes: string;
    createdBy: string | null;
  },
): Promise<PromiseToPayRow> {
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO finance_promises_to_pay (
       organization_id, school_id, student_id, fee_account_id, amount_minor,
       promise_date, notes, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING id`,
    [
      input.organizationId,
      input.schoolId,
      input.studentId,
      input.feeAccountId,
      input.amountMinor,
      input.promiseDate,
      input.notes,
      input.createdBy,
    ],
  );
  const created = await getPromiseToPay(db, input.organizationId, input.schoolId, rows[0]!.id);
  return created!;
}

export async function getPromiseToPay(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  id: string,
): Promise<PromiseToPayRow | null> {
  const rows = await db.queryObject<PromiseToPayRow>(
    `SELECT p.id, p.student_id,
            COALESCE(s.display_name, 'Student') AS student_name,
            p.fee_account_id, p.amount_minor::text AS amount_minor,
            p.promise_date::text AS promise_date, p.status, p.notes,
            p.created_by, p.created_at, p.resolved_by, p.resolved_at
       FROM finance_promises_to_pay p
       LEFT JOIN students s ON s.id = p.student_id
      WHERE p.organization_id = $1 AND p.school_id = $2 AND p.id = $3`,
    [orgId, schoolId, id],
  );
  return rows[0] ?? null;
}

export async function listPromisesToPay(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  statusFilter?: string,
): Promise<PromiseToPayRow[]> {
  return await db.queryObject<PromiseToPayRow>(
    `SELECT p.id, p.student_id,
            COALESCE(s.display_name, 'Student') AS student_name,
            p.fee_account_id, p.amount_minor::text AS amount_minor,
            p.promise_date::text AS promise_date, p.status, p.notes,
            p.created_by, p.created_at, p.resolved_by, p.resolved_at
       FROM finance_promises_to_pay p
       LEFT JOIN students s ON s.id = p.student_id
      WHERE p.organization_id = $1 AND p.school_id = $2
        AND ($3::text IS NULL OR p.status = $3)
      ORDER BY
        CASE p.status WHEN 'pending' THEN 0 ELSE 1 END,
        p.promise_date ASC`,
    [orgId, schoolId, statusFilter ?? null],
  );
}

export async function resolvePromiseToPay(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  id: string,
  status: "kept" | "broken" | "cancelled",
  resolvedBy: string | null,
): Promise<PromiseToPayRow | null> {
  const rows = await db.queryObject<{ id: string }>(
    `UPDATE finance_promises_to_pay
        SET status = $4, resolved_by = $5, resolved_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2 AND id = $3
        AND status = 'pending'
      RETURNING id`,
    [orgId, schoolId, id, status, resolvedBy],
  );
  if (rows.length === 0) return null;
  return await getPromiseToPay(db, orgId, schoolId, id);
}

export async function upsertRecoveryTarget(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string;
    collectorUserId: string | null;
    periodMonth: string;
    targetMinor: number;
    createdBy: string | null;
  },
): Promise<RecoveryTargetRow> {
  const rows = await db.queryObject<RecoveryTargetRow>(
    `INSERT INTO finance_recovery_targets (
       organization_id, school_id, collector_user_id, period_month,
       target_minor, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6)
     ON CONFLICT (organization_id, school_id, collector_user_id, period_month)
       DO UPDATE SET target_minor = EXCLUDED.target_minor,
                     updated_at = timezone('utc', now())
     RETURNING id, collector_user_id, period_month, target_minor::text AS target_minor,
               created_at, updated_at`,
    [
      input.organizationId,
      input.schoolId,
      input.collectorUserId,
      input.periodMonth,
      input.targetMinor,
      input.createdBy,
    ],
  );
  return rows[0]!;
}

export async function listRecoveryTargets(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  periodMonth: string,
): Promise<RecoveryTargetRow[]> {
  return await db.queryObject<RecoveryTargetRow>(
    `SELECT id, collector_user_id, period_month, target_minor::text AS target_minor,
            created_at, updated_at
       FROM finance_recovery_targets
      WHERE organization_id = $1 AND school_id = $2 AND period_month = $3
      ORDER BY collector_user_id NULLS FIRST`,
    [orgId, schoolId, periodMonth],
  );
}

export interface CollectorPerformanceRow {
  collector_id: string;
  collector_name: string;
  contacts_made: string;
  promises_obtained: string;
  amount_recovered_minor: string;
  collections_count: string;
}

/// FIN-R5 — collector performance for a month: contacts made, PTPs obtained, and
/// ₹ recovered (completed collections) per collector, derived from real rows.
export async function collectorPerformanceForMonth(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  monthStart: string,
): Promise<CollectorPerformanceRow[]> {
  return await db.queryObject<CollectorPerformanceRow>(
    `WITH contacts AS (
       SELECT contacted_by AS uid, count(*)::text AS n
         FROM finance_recovery_contacts
        WHERE organization_id = $1 AND school_id = $2
          AND contacted_by IS NOT NULL
          AND created_at >= $3::date
        GROUP BY contacted_by
     ), promises AS (
       SELECT created_by AS uid, count(*)::text AS n
         FROM finance_promises_to_pay
        WHERE organization_id = $1 AND school_id = $2
          AND created_by IS NOT NULL
          AND created_at >= $3::date
        GROUP BY created_by
     ), recovered AS (
       SELECT collected_by AS uid,
              count(*)::text AS n,
              COALESCE(sum(amount_collected), 0)::text AS amt
         FROM finance_collections
        WHERE organization_id = $1 AND school_id = $2
          AND collected_by IS NOT NULL
          AND collection_status = 'completed'
          AND collection_date >= $3::date
        GROUP BY collected_by
     ), uids AS (
       SELECT uid FROM contacts
       UNION SELECT uid FROM promises
       UNION SELECT uid FROM recovered
     )
     SELECT u.uid AS collector_id,
            COALESCE(usr.display_name, 'Staff') AS collector_name,
            COALESCE(c.n, '0') AS contacts_made,
            COALESCE(p.n, '0') AS promises_obtained,
            COALESCE(r.amt, '0') AS amount_recovered_minor,
            COALESCE(r.n, '0') AS collections_count
       FROM uids u
       LEFT JOIN contacts c ON c.uid = u.uid
       LEFT JOIN promises p ON p.uid = u.uid
       LEFT JOIN recovered r ON r.uid = u.uid
       LEFT JOIN users usr ON usr.id = u.uid
      ORDER BY (COALESCE(r.amt, '0'))::numeric DESC`,
    [orgId, schoolId, monthStart],
  );
}

export interface RecoveryAggregates {
  ptp_pending: string;
  ptp_due_today: string;
  ptp_overdue: string;
  ptp_kept: string;
  ptp_broken: string;
  contacts_this_month: string;
  recovered_this_month_minor: string;
}

/// FIN-R1 — headline recovery numbers for the dashboard.
export async function recoveryAggregates(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  monthStart: string,
): Promise<RecoveryAggregates> {
  const rows = await db.queryObject<RecoveryAggregates>(
    `SELECT
        (SELECT count(*) FROM finance_promises_to_pay
          WHERE organization_id = $1 AND school_id = $2 AND status = 'pending')::text AS ptp_pending,
        (SELECT count(*) FROM finance_promises_to_pay
          WHERE organization_id = $1 AND school_id = $2 AND status = 'pending'
            AND promise_date = CURRENT_DATE)::text AS ptp_due_today,
        (SELECT count(*) FROM finance_promises_to_pay
          WHERE organization_id = $1 AND school_id = $2 AND status = 'pending'
            AND promise_date < CURRENT_DATE)::text AS ptp_overdue,
        (SELECT count(*) FROM finance_promises_to_pay
          WHERE organization_id = $1 AND school_id = $2 AND status = 'kept')::text AS ptp_kept,
        (SELECT count(*) FROM finance_promises_to_pay
          WHERE organization_id = $1 AND school_id = $2 AND status = 'broken')::text AS ptp_broken,
        (SELECT count(*) FROM finance_recovery_contacts
          WHERE organization_id = $1 AND school_id = $2
            AND created_at >= $3::date)::text AS contacts_this_month,
        (SELECT COALESCE(sum(amount_collected), 0) FROM finance_collections
          WHERE organization_id = $1 AND school_id = $2
            AND collection_status = 'completed'
            AND collection_date >= $3::date)::text AS recovered_this_month_minor`,
    [orgId, schoolId, monthStart],
  );
  return rows[0]!;
}
