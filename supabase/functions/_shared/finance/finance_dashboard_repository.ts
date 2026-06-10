import type { TenantQueryClient } from "../tenant_db.ts";
import { getDailySummary } from "./finance_collections_repository.ts";

export interface DashboardRecentCollection {
  id: string;
  receipt_number: string;
  student_name: string;
  amount: number;
  payment_method: string;
  collection_date: string;
}

export interface DashboardRecentRefund {
  id: string;
  student_name: string;
  amount: number;
  status: string;
  requested_at: string;
}

export interface FinanceDashboardSnapshot {
  totalStudents: number;
  activeFeeAssignments: number;
  totalInvoiced: number;
  totalCollected: number;
  totalOutstanding: number;
  collectionRate: number;
  pendingInvoices: number;
  partiallyPaidInvoices: number;
  paidInvoices: number;
  pendingRefunds: number;
  processedRefunds: number;
  todayCollections: number;
  todayCollectionCount: number;
  recentCollections: DashboardRecentCollection[];
  recentRefunds: DashboardRecentRefund[];
}

export function computeCollectionRate(
  totalCollected: number,
  totalInvoiced: number,
): number {
  if (totalInvoiced <= 0) return 0;
  return Math.round((totalCollected / totalInvoiced) * 10000) / 100;
}

export async function getDashboard(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<FinanceDashboardSnapshot> {
  const dailySummary = await getDailySummary(db, organizationId, schoolId);

  const kpiRows = await db.queryObject<{
    total_students: string;
    active_assignments: string;
    total_invoiced: string;
    total_collected: string;
    pending_refunds: string;
    processed_refunds: string;
  }>(
    `SELECT
       (SELECT count(DISTINCT student_id)::text
        FROM finance_student_accounts
        WHERE organization_id = $1 AND school_id = $2 AND status = 'open') AS total_students,
       (SELECT count(*)::text
        FROM finance_fee_assignments
        WHERE organization_id = $1 AND school_id = $2 AND assignment_status = 'active') AS active_assignments,
       (SELECT COALESCE(SUM(total_amount), 0)::text
        FROM finance_invoices
        WHERE organization_id = $1 AND school_id = $2 AND invoice_status != 'cancelled') AS total_invoiced,
       (SELECT COALESCE(SUM(amount_collected), 0)::text
        FROM finance_collections
        WHERE organization_id = $1 AND school_id = $2
          AND collection_status IN ('completed', 'partially_refunded', 'refunded')) AS total_collected,
       (SELECT count(*)::text
        FROM finance_refunds
        WHERE organization_id = $1 AND school_id = $2 AND refund_status = 'pending') AS pending_refunds,
       (SELECT count(*)::text
        FROM finance_refunds
        WHERE organization_id = $1 AND school_id = $2 AND refund_status = 'processed') AS processed_refunds`,
    [organizationId, schoolId],
  );

  const kpi = kpiRows[0]!;
  const totalInvoiced = parseFloat(kpi.total_invoiced);
  const totalCollected = parseFloat(kpi.total_collected);

  const recentCollections = await db.queryObject<{
    id: string;
    receipt_number: string;
    student_name: string;
    amount: string;
    payment_method: string;
    collection_date: string;
  }>(
    `SELECT fc.id,
       fc.receipt_number,
       COALESCE(s.display_name, afh.student_name, '') AS student_name,
       fc.amount_collected::text AS amount,
       fc.payment_method,
       fc.collection_date::text AS collection_date
     FROM finance_collections fc
     LEFT JOIN students s
       ON s.id = fc.student_id
      AND s.organization_id = fc.organization_id
      AND s.school_id = fc.school_id
     LEFT JOIN LATERAL (
       SELECT student_name
       FROM admissions_fee_handoffs
       WHERE student_id = fc.student_id
         AND organization_id = fc.organization_id
         AND school_id = fc.school_id
       ORDER BY created_at DESC
       LIMIT 1
     ) afh ON true
     WHERE fc.organization_id = $1 AND fc.school_id = $2
       AND fc.collection_status IN ('completed', 'partially_refunded', 'refunded')
     ORDER BY fc.collection_date DESC, fc.created_at DESC
     LIMIT 10`,
    [organizationId, schoolId],
  );

  const recentRefunds = await db.queryObject<{
    id: string;
    student_name: string;
    amount: string;
    status: string;
    requested_at: string;
  }>(
    `SELECT fr.id,
       COALESCE(s.display_name, afh.student_name, '') AS student_name,
       fr.refund_amount::text AS amount,
       fr.refund_status AS status,
       fr.created_at::text AS requested_at
     FROM finance_refunds fr
     JOIN finance_collections fc ON fc.id = fr.collection_id
     LEFT JOIN students s
       ON s.id = fc.student_id
      AND s.organization_id = fr.organization_id
      AND s.school_id = fr.school_id
     LEFT JOIN LATERAL (
       SELECT student_name
       FROM admissions_fee_handoffs
       WHERE student_id = fc.student_id
         AND organization_id = fr.organization_id
         AND school_id = fr.school_id
       ORDER BY created_at DESC
       LIMIT 1
     ) afh ON true
     WHERE fr.organization_id = $1 AND fr.school_id = $2
     ORDER BY fr.created_at DESC
     LIMIT 10`,
    [organizationId, schoolId],
  );

  return {
    totalStudents: parseInt(kpi.total_students, 10),
    activeFeeAssignments: parseInt(kpi.active_assignments, 10),
    totalInvoiced,
    totalCollected,
    totalOutstanding: dailySummary.outstandingAmount,
    collectionRate: computeCollectionRate(totalCollected, totalInvoiced),
    pendingInvoices: dailySummary.pendingInvoices,
    partiallyPaidInvoices: dailySummary.partiallyPaidInvoices,
    paidInvoices: dailySummary.paidInvoices,
    pendingRefunds: parseInt(kpi.pending_refunds, 10),
    processedRefunds: parseInt(kpi.processed_refunds, 10),
    todayCollections: dailySummary.todayCollections,
    todayCollectionCount: dailySummary.todayCollectionCount,
    recentCollections: recentCollections.map((row) => ({
      id: row.id,
      receipt_number: row.receipt_number,
      student_name: row.student_name,
      amount: parseFloat(row.amount),
      payment_method: row.payment_method,
      collection_date: row.collection_date,
    })),
    recentRefunds: recentRefunds.map((row) => ({
      id: row.id,
      student_name: row.student_name,
      amount: parseFloat(row.amount),
      status: row.status,
      requested_at: row.requested_at,
    })),
  };
}
