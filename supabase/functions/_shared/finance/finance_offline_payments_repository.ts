import type { TenantQueryClient } from "../tenant_db.ts";

export type OfflinePaymentMethod = "cash" | "cheque" | "dd";
export type OfflinePaymentStatus = "pending_reconciliation" | "reconciled";

const METHODS: readonly OfflinePaymentMethod[] = ["cash", "cheque", "dd"];

export interface FinanceOfflinePaymentRow {
  id: string;
  organization_id: string;
  school_id: string;
  invoice_id: string | null;
  student_name: string;
  amount: string;
  payment_method: OfflinePaymentMethod;
  reference_number: string;
  recorded_at: string;
  status: OfflinePaymentStatus;
  collection_id: string | null;
  reconciled_at: string | null;
  reconciled_by: string | null;
  notes: string | null;
  recorded_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreateOfflinePaymentInput {
  invoiceId?: string;
  studentName: string;
  amount: number;
  method: OfflinePaymentMethod;
  referenceNumber: string;
  recordedAt?: string;
  recordedBy: string;
}

export interface ReconcileOfflinePaymentInput {
  reconciledAt?: string;
  notes?: string;
  reconciledBy: string;
}

export class OfflinePaymentNotFoundError extends Error {
  constructor(id: string) {
    super(`Offline payment not found: ${id}`);
    this.name = "OfflinePaymentNotFoundError";
  }
}

export function isOfflinePaymentMethod(value: string): value is OfflinePaymentMethod {
  return (METHODS as readonly string[]).includes(value);
}

function formatAmount(value: number | string): string {
  const num = typeof value === "string" ? parseFloat(value) : value;
  if (!Number.isFinite(num)) return "0";
  return Number.isInteger(num) ? String(num) : num.toFixed(2);
}

/** Map a DB row to the camelCase API shape expected by the Flutter mapper. */
export function offlinePaymentToApi(row: FinanceOfflinePaymentRow): Record<string, unknown> {
  return {
    id: row.id,
    invoiceId: row.invoice_id ?? "",
    studentName: row.student_name,
    amount: formatAmount(row.amount),
    method: row.payment_method,
    referenceNumber: row.reference_number,
    recordedAt: row.recorded_at,
    status: row.status,
    collectionId: row.collection_id,
  };
}

export async function createOfflinePayment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateOfflinePaymentInput,
): Promise<FinanceOfflinePaymentRow> {
  const rows = await db.queryObject<FinanceOfflinePaymentRow>(
    `INSERT INTO finance_offline_payments (
      organization_id, school_id, invoice_id, student_name, amount,
      payment_method, reference_number, recorded_at, status, recorded_by
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7,
      COALESCE($8::timestamptz, timezone('utc', now())),
      'pending_reconciliation', $9
    )
    RETURNING *`,
    [
      organizationId,
      schoolId,
      input.invoiceId ?? null,
      input.studentName,
      input.amount,
      input.method,
      input.referenceNumber,
      input.recordedAt ?? null,
      input.recordedBy,
    ],
  );
  return rows[0]!;
}

export async function listOfflinePayments(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  pagination: { page: number; pageSize: number },
): Promise<{
  items: FinanceOfflinePaymentRow[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}> {
  const limit = Math.min(Math.max(pagination.pageSize, 1), 100);
  const offset = (Math.max(pagination.page, 1) - 1) * limit;

  const total = await db.queryCount(
    `SELECT count(*)::text AS count FROM finance_offline_payments
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );

  const items = await db.queryObject<FinanceOfflinePaymentRow>(
    `SELECT * FROM finance_offline_payments
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY recorded_at DESC, created_at DESC
     LIMIT $3 OFFSET $4`,
    [organizationId, schoolId, limit, offset],
  );

  return {
    items,
    total,
    page: Math.max(pagination.page, 1),
    pageSize: limit,
    hasMore: offset + items.length < total,
  };
}

export async function getOfflinePayment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  id: string,
): Promise<FinanceOfflinePaymentRow | null> {
  const rows = await db.queryObject<FinanceOfflinePaymentRow>(
    `SELECT * FROM finance_offline_payments
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [id, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export async function reconcileOfflinePayment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  id: string,
  input: ReconcileOfflinePaymentInput,
): Promise<FinanceOfflinePaymentRow> {
  const existing = await getOfflinePayment(db, organizationId, schoolId, id);
  if (!existing) {
    throw new OfflinePaymentNotFoundError(id);
  }

  const rows = await db.queryObject<FinanceOfflinePaymentRow>(
    `UPDATE finance_offline_payments
     SET status = 'reconciled',
         reconciled_at = COALESCE($4::timestamptz, timezone('utc', now())),
         reconciled_by = $5,
         notes = COALESCE($6, notes),
         updated_at = timezone('utc', now())
     WHERE id = $1 AND organization_id = $2 AND school_id = $3
     RETURNING *`,
    [
      id,
      organizationId,
      schoolId,
      input.reconciledAt ?? null,
      input.reconciledBy,
      input.notes ?? null,
    ],
  );
  return rows[0]!;
}
