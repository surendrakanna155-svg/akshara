import type { TenantQueryClient } from "../tenant_db.ts";

export type QrSessionStatus = "pending" | "confirmed" | "expired";

export interface FinanceQrSessionRow {
  id: string;
  organization_id: string;
  school_id: string;
  invoice_id: string | null;
  amount: string;
  upi_payload: string;
  status: QrSessionStatus;
  receipt_number: string | null;
  expires_at: string;
  confirmed_at: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreateQrSessionInput {
  invoiceId?: string;
  amount: number;
  upiPayload: string;
  createdBy: string;
}

export class QrSessionNotFoundError extends Error {
  constructor(id: string) {
    super(`QR payment session not found: ${id}`);
    this.name = "QrSessionNotFoundError";
  }
}

/** P5 (red-team Round 2): thrown when a confirm targets a session that is no
 * longer 'pending' (already confirmed / expired / cancelled) — the status guard
 * lost the race, so exactly one confirm wins and a concurrent/repeat confirm is
 * rejected instead of silently re-confirming. */
export class QrSessionNotConfirmableError extends Error {
  constructor(id: string) {
    super(`QR payment session is not pending (already confirmed or expired): ${id}`);
    this.name = "QrSessionNotConfirmableError";
  }
}

function formatAmount(value: number | string): string {
  const num = typeof value === "string" ? parseFloat(value) : value;
  if (!Number.isFinite(num)) return "0";
  return Number.isInteger(num) ? String(num) : num.toFixed(2);
}

/** Map a DB row to the camelCase API shape expected by the Flutter mapper. */
export function qrSessionToApi(row: FinanceQrSessionRow): Record<string, unknown> {
  return {
    id: row.id,
    invoiceId: row.invoice_id ?? "",
    amount: formatAmount(row.amount),
    upiPayload: row.upi_payload,
    status: row.status,
    expiresAt: row.expires_at,
    receiptNumber: row.receipt_number,
  };
}

export async function createQrSession(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateQrSessionInput,
): Promise<FinanceQrSessionRow> {
  const rows = await db.queryObject<FinanceQrSessionRow>(
    `INSERT INTO finance_qr_sessions (
      organization_id, school_id, invoice_id, amount, upi_payload, status, created_by
    ) VALUES ($1, $2, $3, $4, $5, 'pending', $6)
    RETURNING *`,
    [
      organizationId,
      schoolId,
      input.invoiceId ?? null,
      input.amount,
      input.upiPayload,
      input.createdBy,
    ],
  );
  return rows[0]!;
}

/**
 * Fetch a session, flipping it to `expired` (and persisting) when it is still
 * pending past its expiry. Keeps the status the client sees consistent with the
 * stored lifecycle without a background job.
 */
export async function getQrSession(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  id: string,
): Promise<FinanceQrSessionRow | null> {
  const rows = await db.queryObject<FinanceQrSessionRow>(
    `SELECT * FROM finance_qr_sessions
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [id, organizationId, schoolId],
  );
  const row = rows[0] ?? null;
  if (!row) return null;
  if (row.status === "pending" && new Date(row.expires_at).getTime() < Date.now()) {
    const expired = await db.queryObject<FinanceQrSessionRow>(
      `UPDATE finance_qr_sessions
       SET status = 'expired', updated_at = timezone('utc', now())
       WHERE id = $1 AND organization_id = $2 AND school_id = $3 AND status = 'pending'
       RETURNING *`,
      [id, organizationId, schoolId],
    );
    return expired[0] ?? row;
  }
  return row;
}

export async function confirmQrSession(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  id: string,
  receiptNumber: string | undefined,
): Promise<FinanceQrSessionRow> {
  const existing = await getQrSession(db, organizationId, schoolId, id);
  if (!existing) {
    throw new QrSessionNotFoundError(id);
  }

  // P5 (red-team Round 2): the terminal 'confirmed' write is guarded on the
  // 'pending' pre-state (mirroring the sibling expireQrSession) so a concurrent
  // or repeated confirm of the same fee-payment session can double-apply neither
  // the confirm nor its downstream effect — exactly one caller wins; the loser
  // gets 0 rows → a clean not-confirmable error, never a second 200.
  const rows = await db.queryObject<FinanceQrSessionRow>(
    `UPDATE finance_qr_sessions
     SET status = 'confirmed',
         confirmed_at = timezone('utc', now()),
         receipt_number = COALESCE($4, receipt_number, $5),
         updated_at = timezone('utc', now())
     WHERE id = $1 AND organization_id = $2 AND school_id = $3
       AND status = 'pending'
     RETURNING *`,
    [
      id,
      organizationId,
      schoolId,
      receiptNumber ?? null,
      `QR-${id.slice(0, 8).toUpperCase()}`,
    ],
  );
  if (rows.length === 0) {
    throw new QrSessionNotConfirmableError(id);
  }
  return rows[0]!;
}
