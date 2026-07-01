// FIN-6 — installment / term-wise due schedule.
//
// A purely INFORMATIONAL, additive schedule generated at invoice creation from
// the school's `payments.due_days` + `payments.installment_terms` settings. It
// does NOT create multiple invoices and does NOT touch the invoice's single
// authoritative outstanding — it drives reminders/display only.
//
// `installment_terms` accepts:
//   • "1" (default) → a single annual term due at issue + due_days.
//   • an integer N > 1 → N equal terms, evenly spread across a 12-month window
//     (term k due at issue + round(k * 365 / N) days).
//   • a CSV of day offsets, e.g. "0,90,180,270" → one term per offset, each due
//     at issue + that many days. (Any parseable non-negative integers.)
//
// The per-term amount splits the invoice total evenly, with the final term
// absorbing the rounding remainder so the terms sum EXACTLY to the total.

import type { TenantQueryClient } from "../tenant_db.ts";
import { getFinanceSettingValue } from "./finance_settings_repository.ts";

export interface FinanceInvoiceInstallmentRow {
  id: string;
  organization_id: string;
  school_id: string;
  invoice_id: string;
  term_no: number;
  due_date: string;
  amount_minor: string;
  status: "pending" | "due" | "paid";
  created_at: string;
}

export interface InstallmentTermPlan {
  termNo: number;
  dueDate: string; // YYYY-MM-DD
  amount: number;
}

function addDaysIso(date: Date, days: number): string {
  const next = new Date(date);
  next.setUTCDate(next.getUTCDate() + days);
  return next.toISOString().slice(0, 10);
}

/** Round to 2 decimals to keep NUMERIC(12,2) exact. */
function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

/**
 * Parse `installment_terms` into a list of due-day offsets (days after issue).
 * Falls back to a single term at `dueDaysOffset` on any malformed input, so the
 * schedule generation can never throw on bad config.
 */
export function parseInstallmentOffsets(
  installmentTerms: string,
  dueDaysOffset: number,
): number[] {
  const trimmed = (installmentTerms ?? "").trim();
  if (trimmed === "" || trimmed === "1") return [dueDaysOffset];

  // CSV of explicit day offsets.
  if (trimmed.includes(",")) {
    const offsets = trimmed
      .split(",")
      .map((s) => parseInt(s.trim(), 10))
      .filter((n) => Number.isFinite(n) && n >= 0);
    return offsets.length > 0 ? offsets : [dueDaysOffset];
  }

  // A bare integer N > 1 → N terms evenly spread across ~one year.
  const n = parseInt(trimmed, 10);
  if (Number.isFinite(n) && n > 1) {
    const offsets: number[] = [];
    for (let k = 0; k < n; k++) {
      offsets.push(Math.round((k * 365) / n));
    }
    return offsets;
  }

  return [dueDaysOffset];
}

/**
 * Build the term plan (term_no, due_date, amount) for a given total. Amounts are
 * split evenly; the LAST term absorbs the rounding remainder so the terms sum
 * to EXACTLY `total`.
 */
export function buildInstallmentPlan(
  issueDate: Date,
  total: number,
  offsets: number[],
): InstallmentTermPlan[] {
  const count = Math.max(1, offsets.length);
  const per = round2(total / count);
  const plan: InstallmentTermPlan[] = [];
  let allocated = 0;
  for (let i = 0; i < count; i++) {
    const isLast = i === count - 1;
    const amount = isLast ? round2(total - allocated) : per;
    allocated = round2(allocated + amount);
    plan.push({
      termNo: i + 1,
      dueDate: addDaysIso(issueDate, offsets[i] ?? 0),
      amount,
    });
  }
  return plan;
}

/**
 * Generate + persist the installment schedule for a freshly created invoice.
 * Reads settings for due-days + terms. Best-effort: never throws (a failure to
 * write the informational schedule must never break invoice creation) — but the
 * caller passes the same `db` transaction so it is written atomically when it
 * succeeds.
 */
export async function generateInstallmentSchedule(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  invoiceId: string,
  invoiceDate: string,
  total: number,
): Promise<void> {
  const dueDays = parseInt(
    await getFinanceSettingValue(db, organizationId, schoolId, "payments", "due_days", "30"),
    10,
  ) || 30;
  const installmentTerms = await getFinanceSettingValue(
    db,
    organizationId,
    schoolId,
    "payments",
    "installment_terms",
    "1",
  );

  const issueDate = new Date(`${invoiceDate}T00:00:00.000Z`);
  const offsets = parseInstallmentOffsets(installmentTerms, dueDays);
  const plan = buildInstallmentPlan(issueDate, total, offsets);

  for (const term of plan) {
    await db.queryObject(
      `INSERT INTO finance_invoice_installments (
        organization_id, school_id, invoice_id, term_no, due_date, amount_minor, status
      ) VALUES ($1, $2, $3, $4, $5, $6, 'pending')
      ON CONFLICT (invoice_id, term_no) DO NOTHING`,
      [organizationId, schoolId, invoiceId, term.termNo, term.dueDate, term.amount],
    );
  }
}

export async function listInstallmentsForInvoice(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  invoiceId: string,
): Promise<FinanceInvoiceInstallmentRow[]> {
  return await db.queryObject<FinanceInvoiceInstallmentRow>(
    `SELECT * FROM finance_invoice_installments
     WHERE invoice_id = $1 AND organization_id = $2 AND school_id = $3
     ORDER BY term_no ASC`,
    [invoiceId, organizationId, schoolId],
  );
}
