// W4 — source adapters: map an EXISTING source module's already-recorded expense
// row into a canonical ledger entry, then post it (idempotently).
//
// These import ONLY the source modules' row TYPES (read-only) — they never modify
// a source module. Each source has:
//   * a PURE `map…` function (row -> ExpenseLedgerInput | null) so the mapping is
//     unit-testable DB-free, and
//   * a thin `post…` wrapper that calls the repository's idempotent postExpense.
//
// Live adapters today: Transport, Payroll, Inventory purchases (the three sources
// that already persist expense/cost rows). Maintenance / Utilities / other are
// declared in the ExpenseSourceModule enum but have NO source table yet, so they
// get NO adapter here (a future adapter lands with each new source) — a partial-
// but-honest ledger, never fabricated.
//
// WIRING FOLLOW-UP (out of scope for this isolated module): the source modules
// must CALL these post… functions at their commit points —
//   * transport: after recordTransportExpense (and post a void→exclude follow-up),
//   * payroll:   after postPayrollRunToFinance,
//   * inventory: after approvePurchaseOrder,
// and management_payload_builders.ts must swap `expenseBreakdown: []` for
// buildExpenseBreakdown(listExpenseEntries(...)). The parent wires these post-merge.

import type { TenantQueryClient } from "../tenant_db.ts";
import type { TransportExpenseRow } from "../transport/transport_expenses_repository.ts";
import type { PayrollFinancePosting } from "../hr/hr_finance_posting_repository.ts";
import type { PurchaseOrderRow } from "../inventory_finance/inventory_finance_repository.ts";
import { type ExpenseLedgerInput, postExpense } from "./expense_ledger_repository.ts";

function composeDescription(parts: Array<string | null | undefined>): string | null {
  const joined = parts.map((p) => (p ?? "").trim()).filter((p) => p.length > 0);
  return joined.length > 0 ? joined.join(" · ") : null;
}

// ─── Transport ───────────────────────────────────────────────────────────────

/**
 * Map a `transport_expenses` row into a ledger entry. Returns `null` for a VOIDed
 * expense (status !== 'recorded') — a voided cost must never count toward the
 * ledger. The row already carries org/school + a per-cost `category`
 * (fuel/maintenance/insurance/…), which we preserve as the ledger category so the
 * by-category breakdown keeps transport's cost granularity.
 */
export function mapTransportExpense(row: TransportExpenseRow): ExpenseLedgerInput | null {
  if (row.status !== "recorded") return null;
  return {
    organizationId: row.organization_id,
    schoolId: row.school_id,
    sourceModule: "transport",
    sourceRef: row.id,
    category: row.category,
    amount: Number(row.amount),
    incurredOn: row.incurred_on,
    description: composeDescription([row.vendor, row.reference, row.notes]),
  };
}

/** Post a transport expense row to the ledger (skips a voided row). */
export async function postTransportExpense(
  db: TenantQueryClient,
  row: TransportExpenseRow,
): Promise<{ posted: boolean; entryId: string | null }> {
  const input = mapTransportExpense(row);
  if (input === null) return { posted: false, entryId: null };
  return await postExpense(db, input);
}

// ─── Payroll ─────────────────────────────────────────────────────────────────

/**
 * Map a processed payroll run's finance posting into a ledger entry. The EXPENSE
 * (cost incurred) is the GROSS amount (Σ basic + allowances) — net is the amount
 * disbursed, not the cost — so the ledger records grossAmount. Category is
 * 'salary'. `incurredOn` is supplied by the caller (the run's disbursement date),
 * because a payroll run's `period` is a free-form label, not a date.
 */
export function mapPayrollExpense(
  organizationId: string,
  schoolId: string,
  posting: PayrollFinancePosting,
  incurredOn: string,
): ExpenseLedgerInput {
  return {
    organizationId,
    schoolId,
    sourceModule: "payroll",
    sourceRef: posting.payrollRunId,
    category: "salary",
    amount: posting.grossAmount,
    incurredOn,
    description: composeDescription([
      posting.period ? `Payroll ${posting.period}` : "Payroll",
      posting.employeeCount ? `${posting.employeeCount} employees` : null,
    ]),
  };
}

/** Post a payroll run's finance posting to the ledger. */
export async function postPayrollExpense(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  posting: PayrollFinancePosting,
  incurredOn: string,
): Promise<{ posted: boolean; entryId: string | null }> {
  return await postExpense(
    db,
    mapPayrollExpense(organizationId, schoolId, posting, incurredOn),
  );
}

// ─── Inventory purchases ───────────────────────────────────────────────────────

const INVENTORY_EXPENSE_STATUSES = new Set([
  "approved",
  "partially_received",
  "received",
]);

/**
 * Map an approved purchase order into a ledger entry. Returns `null` for a PO that
 * is not yet an incurred expense (draft / rejected) — the cost is committed on
 * approval (approvePurchaseOrder raises the AP commitment), so only approved-or-
 * later POs post. Amount is the PO `total_amount`; category is 'procurement'.
 * `incurredOn` defaults to the PO's creation date when the caller does not pass
 * the approval date.
 */
export function mapInventoryPurchaseExpense(
  organizationId: string,
  schoolId: string,
  po: PurchaseOrderRow,
  incurredOn?: string,
): ExpenseLedgerInput | null {
  if (!INVENTORY_EXPENSE_STATUSES.has(po.status)) return null;
  return {
    organizationId,
    schoolId,
    sourceModule: "inventory",
    sourceRef: po.id,
    category: "procurement",
    amount: Number(po.total_amount),
    incurredOn: incurredOn ?? String(po.created_at).slice(0, 10),
    description: po.po_number ? `PO ${po.po_number}` : null,
  };
}

/** Post an approved purchase order to the ledger (skips a non-approved PO). */
export async function postInventoryPurchaseExpense(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  po: PurchaseOrderRow,
  incurredOn?: string,
): Promise<{ posted: boolean; entryId: string | null }> {
  const input = mapInventoryPurchaseExpense(organizationId, schoolId, po, incurredOn);
  if (input === null) return { posted: false, entryId: null };
  return await postExpense(db, input);
}
