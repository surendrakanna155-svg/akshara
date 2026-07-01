import type { TenantQueryClient } from "../tenant_db.ts";
import type { FinanceInvoiceRow } from "./finance_invoices_repository.ts";
import { getSettingsRow } from "./finance_settings_repository.ts";

// FIN-D5 — late-fee accrual + waive.
//
// Accrual is ADDITIVE: for every issued/partially_paid invoice past
// (due_date + grace_days) that has not yet accrued (late_fee_amount = 0), a late
// fee = min(cap, total * percent% [+ flat]) is computed from the school's
// settings, stored on the invoice, and ADDED to both the invoice outstanding and
// the student-account outstanding. It never touches the collection→invoice
// payment-reduction math. Idempotent: already-accrued invoices are skipped.

export interface LateFeeSettings {
  gracePeriodDays: number;
  latePercent: number;
  lateFlat: number;
  lateCap: number;
}

export interface LateFeeAccrualResult {
  accruedCount: number;
  totalLateFee: number;
}

export class LateFeeNotFoundError extends Error {
  constructor(invoiceId: string) {
    super(`Invoice not found: ${invoiceId}`);
    this.name = "LateFeeNotFoundError";
  }
}

export class NoLateFeeError extends Error {
  constructor(invoiceId: string) {
    super(`Invoice has no late fee to waive: ${invoiceId}`);
    this.name = "NoLateFeeError";
  }
}

function toNumber(value: string | number | null | undefined): number {
  if (value == null) return 0;
  const n = typeof value === "number" ? value : parseFloat(value);
  return Number.isFinite(n) ? n : 0;
}

function formatNumeric(value: number): string {
  const rounded = Math.round(value * 100) / 100;
  return Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(2);
}

/** Read the school's late-fee settings (payments.* keys) with safe defaults. */
export async function loadLateFeeSettings(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<LateFeeSettings> {
  const row = await getSettingsRow(db, organizationId, schoolId);
  const s = row?.settings ?? {};
  return {
    gracePeriodDays: Math.max(0, Math.trunc(toNumber(s["payments.grace_days"]))),
    latePercent: Math.max(0, toNumber(s["payments.late_fee_percent"])),
    lateFlat: Math.max(0, toNumber(s["payments.late_fee_flat"])),
    lateCap: Math.max(0, toNumber(s["payments.late_fee_cap"])),
  };
}

/** Compute a single invoice's late fee from settings (never negative). */
export function computeLateFee(
  invoiceTotal: number,
  settings: LateFeeSettings,
): number {
  if (settings.latePercent <= 0 && settings.lateFlat <= 0) return 0;
  let fee = (invoiceTotal * settings.latePercent) / 100 + settings.lateFlat;
  if (settings.lateCap > 0) fee = Math.min(fee, settings.lateCap);
  fee = Math.max(0, Math.round(fee * 100) / 100);
  return fee;
}

/**
 * Accrue late fees across all overdue, not-yet-accrued invoices for the school.
 * Uses CURRENT_DATE - grace_days as the cutoff. Each accrual increases the
 * invoice outstanding + the student-account outstanding by the computed fee.
 */
export async function accrueLateFees(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<LateFeeAccrualResult> {
  const settings = await loadLateFeeSettings(db, organizationId, schoolId);

  // Nothing configured → no-op (avoids scanning/locking with a zero result).
  if (settings.latePercent <= 0 && settings.lateFlat <= 0) {
    return { accruedCount: 0, totalLateFee: 0 };
  }

  // Eligible = issued/partially_paid, past due (+ grace), not already accrued.
  // Row-lock each candidate so a concurrent collection on the same invoice
  // serializes against the outstanding update.
  const candidates = await db.queryObject<FinanceInvoiceRow & { student_account_id: string }>(
    `SELECT fi.*, fsa.id AS student_account_id
       FROM finance_invoices fi
       JOIN finance_student_accounts fsa
         ON fsa.fee_assignment_id = fi.fee_assignment_id
        AND fsa.organization_id = fi.organization_id
        AND fsa.school_id = fi.school_id
      WHERE fi.organization_id = $1 AND fi.school_id = $2
        AND fi.invoice_status IN ('issued', 'partially_paid')
        AND fi.late_fee_amount = 0
        AND fi.due_date + ($3 || ' days')::interval < CURRENT_DATE
      FOR UPDATE OF fi`,
    [organizationId, schoolId, String(settings.gracePeriodDays)],
  );

  let accruedCount = 0;
  let totalLateFee = 0;

  for (const invoice of candidates) {
    const fee = computeLateFee(toNumber(invoice.total_amount), settings);
    if (fee <= 0) continue;

    const newOutstanding = toNumber(invoice.outstanding_amount) + fee;

    await db.queryObject(
      `UPDATE finance_invoices SET
         late_fee_amount = $1,
         late_fee_accrued_at = timezone('utc', now()),
         outstanding_amount = $2,
         updated_at = timezone('utc', now())
       WHERE id = $3 AND organization_id = $4 AND school_id = $5`,
      [
        formatNumeric(fee),
        formatNumeric(newOutstanding),
        invoice.id,
        organizationId,
        schoolId,
      ],
    );

    await db.queryObject(
      `UPDATE finance_student_accounts SET
         outstanding_amount = outstanding_amount + $1,
         updated_at = timezone('utc', now())
       WHERE id = $2 AND organization_id = $3 AND school_id = $4`,
      [formatNumeric(fee), invoice.student_account_id, organizationId, schoolId],
    );

    accruedCount += 1;
    totalLateFee += fee;
  }

  return {
    accruedCount,
    totalLateFee: Math.round(totalLateFee * 100) / 100,
  };
}

/**
 * Waive the late fee accrued on a single invoice: reverse the amount from the
 * invoice + student-account outstanding and reset late_fee_amount to 0.
 */
export async function waiveLateFee(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  invoiceId: string,
): Promise<{ invoice: FinanceInvoiceRow; waivedAmount: number }> {
  const rows = await db.queryObject<FinanceInvoiceRow & { student_account_id: string }>(
    `SELECT fi.*, fsa.id AS student_account_id
       FROM finance_invoices fi
       JOIN finance_student_accounts fsa
         ON fsa.fee_assignment_id = fi.fee_assignment_id
        AND fsa.organization_id = fi.organization_id
        AND fsa.school_id = fi.school_id
      WHERE fi.id = $1 AND fi.organization_id = $2 AND fi.school_id = $3
      FOR UPDATE OF fi`,
    [invoiceId, organizationId, schoolId],
  );
  const invoice = rows[0];
  if (!invoice) throw new LateFeeNotFoundError(invoiceId);

  const lateFee = toNumber(invoice.late_fee_amount);
  if (lateFee <= 0) throw new NoLateFeeError(invoiceId);

  const newOutstanding = Math.max(0, toNumber(invoice.outstanding_amount) - lateFee);

  const updated = await db.queryObject<FinanceInvoiceRow>(
    `UPDATE finance_invoices SET
       late_fee_amount = 0,
       late_fee_accrued_at = NULL,
       outstanding_amount = $1,
       updated_at = timezone('utc', now())
     WHERE id = $2 AND organization_id = $3 AND school_id = $4
     RETURNING *`,
    [formatNumeric(newOutstanding), invoiceId, organizationId, schoolId],
  );

  await db.queryObject(
    `UPDATE finance_student_accounts SET
       outstanding_amount = GREATEST(0, outstanding_amount - $1),
       updated_at = timezone('utc', now())
     WHERE id = $2 AND organization_id = $3 AND school_id = $4`,
    [formatNumeric(lateFee), invoice.student_account_id, organizationId, schoolId],
  );

  return { invoice: updated[0]!, waivedAmount: lateFee };
}
