import type { TenantQueryClient } from "../tenant_db.ts";
import type { FinanceInvoiceRow } from "./finance_invoices_repository.ts";
import {
  type FinanceCollectionRow,
  listAllCollectionsForAccount,
} from "./finance_collections_repository.ts";

// FIN-2 — printable student fee statement / ledger. Read-only aggregation over
// existing tables (student account + its invoices + its collections). Nothing
// here writes.

export interface StudentLedgerAccount {
  id: string;
  student_id: string;
  student_name: string;
  admission_number: string;
  class_label: string;
  academic_year: string;
  total_fee: string;
  amount_paid: string;
  outstanding_amount: string;
  status: string;
}

// PRA-P1-11 (S1): a processed refund the statement ledger must debit. Only the
// fields the ledger needs — the (possibly partial) refunded amount, the date it
// was processed (for chronological placement), and the original receipt for
// context in the printed row.
export interface StudentLedgerRefund {
  id: string;
  refund_amount: string;
  refund_status: string;
  refund_date: string;
  receipt_number: string | null;
}

export interface StudentLedger {
  account: StudentLedgerAccount;
  invoices: FinanceInvoiceRow[];
  collections: FinanceCollectionRow[];
  // PRA-P1-11 (S1): processed refunds, debited in the ledger so the running
  // balance reconciles to account.outstanding_amount. Optional so existing
  // in-memory constructions of StudentLedger remain valid.
  refunds?: StudentLedgerRefund[];
}

/** Load the student account (with student/admission/class labels) by its id. */
export async function getLedgerAccount(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentAccountId: string,
): Promise<StudentLedgerAccount | null> {
  const rows = await db.queryObject<StudentLedgerAccount>(
    `SELECT fsa.id,
       fsa.student_id,
       COALESCE(s.display_name, afh.student_name, '') AS student_name,
       COALESCE(afh.admission_number, '') AS admission_number,
       COALESCE(afh.class_label, '') AS class_label,
       fsa.academic_year,
       fsa.total_fee::text AS total_fee,
       fsa.amount_paid::text AS amount_paid,
       fsa.outstanding_amount::text AS outstanding_amount,
       fsa.status
     FROM finance_student_accounts fsa
     LEFT JOIN students s
       ON s.id = fsa.student_id
      AND s.organization_id = fsa.organization_id
      AND s.school_id = fsa.school_id
     LEFT JOIN LATERAL (
       SELECT student_name, admission_number, class_label
       FROM admissions_fee_handoffs
       WHERE student_id = fsa.student_id
         AND organization_id = fsa.organization_id
         AND school_id = fsa.school_id
       ORDER BY created_at DESC
       LIMIT 1
     ) afh ON true
     WHERE fsa.id = $1 AND fsa.organization_id = $2 AND fsa.school_id = $3`,
    [studentAccountId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

/** All invoices for the account's student in the account's academic year. */
async function listInvoicesForAccount(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  academicYear: string,
): Promise<FinanceInvoiceRow[]> {
  return await db.queryObject<FinanceInvoiceRow>(
    `SELECT * FROM finance_invoices
     WHERE student_id = $1
       AND academic_year = $2
       AND organization_id = $3
       AND school_id = $4
     ORDER BY invoice_date ASC, created_at ASC`,
    [studentId, academicYear, organizationId, schoolId],
  );
}

// PRA-P1-11 (S1): all PROCESSED refunds for the account. `processed` is the
// terminal refund state (see applyProcessedRefund), and it is the only state
// that actually moved money — it added the refunded amount back to
// account.outstanding_amount and subtracted it from amount_paid. The statement
// ledger must therefore debit exactly these rows to reconcile to the summary.
// Each row carries only its own (possibly partial) refund_amount, so summing
// per-row does NOT double-count a partially-refunded collection. The collection
// join is LEFT (receipt context only) so a refund is never dropped for it.
async function listProcessedRefundsForAccount(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentAccountId: string,
): Promise<StudentLedgerRefund[]> {
  return await db.queryObject<StudentLedgerRefund>(
    `SELECT fr.id,
       fr.refund_amount::text AS refund_amount,
       fr.refund_status,
       COALESCE(fr.approved_at, fr.updated_at)::date::text AS refund_date,
       fc.receipt_number
     FROM finance_refunds fr
     LEFT JOIN finance_collections fc ON fc.id = fr.collection_id
     WHERE fr.student_account_id = $1
       AND fr.organization_id = $2
       AND fr.school_id = $3
       AND fr.refund_status = 'processed'
     ORDER BY fr.approved_at ASC, fr.created_at ASC`,
    [studentAccountId, organizationId, schoolId],
  );
}

/** Build the full ledger for a student account, or null when it doesn't exist. */
export async function getStudentLedger(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentAccountId: string,
): Promise<StudentLedger | null> {
  const account = await getLedgerAccount(db, organizationId, schoolId, studentAccountId);
  if (!account) return null;

  const invoices = await listInvoicesForAccount(
    db,
    organizationId,
    schoolId,
    account.student_id,
    account.academic_year,
  );
  const collections = await listAllCollectionsForAccount(
    db,
    organizationId,
    schoolId,
    studentAccountId,
  );
  // PRA-P1-11 (S1): also load processed refunds so the mapper can debit them.
  const refunds = await listProcessedRefundsForAccount(
    db,
    organizationId,
    schoolId,
    studentAccountId,
  );

  return { account, invoices, collections, refunds };
}
