// FIN-D2 — per-head payment allocation (self-reconciling derived ledger).
//
// A DERIVED ledger layered ON TOP of the existing single-outstanding money path.
// It NEVER changes how the invoice / student-account outstanding is computed or
// updated. It splits the ONE invoice's paid amount across fee heads in priority
// order (tuition first, then structure sort_order) as collections happen.
//
// INVARIANT (asserted by the reconciliation test): after any collection or
// cancellation, SUM(head_paid_minor) for an invoice == the invoice's amount_paid
// (= total_amount - outstanding_amount). Because allocation on collect adds
// exactly `amountCollected` (never exceeding each head's remaining, and the heads
// sum to the invoice total) and reversal on cancel subtracts exactly the same
// amount in reverse order, the head ledger tracks amount_paid exactly.
//
// MONEY UNIT: NUMERIC(12,2) major rupees — the SAME scale as finance_invoices,
// so reconciliation is exact with no conversion. Column names retain the
// spec's `_minor` suffix; the stored values are the finance-standard NUMERIC
// scale (see migration 20260827000000 header).

import type { TenantQueryClient } from "../tenant_db.ts";
import { decodeFeeHead } from "./finance_mapper.ts";
import { getFinanceSettingValue } from "./finance_settings_repository.ts";

export interface FinanceInvoiceHeadAllocationRow {
  id: string;
  organization_id: string;
  school_id: string;
  invoice_id: string;
  fee_head: string;
  head_label: string;
  head_total_minor: string;
  head_paid_minor: string;
  sort_order: number;
  priority: number;
  created_at: string;
  updated_at: string;
}

interface StructureItemRow {
  fee_head: string;
  amount: string;
  sort_order: number;
}

function parseAmount(value: string | number): number {
  const num = typeof value === "number" ? value : parseFloat(value);
  return Number.isFinite(num) ? num : 0;
}

function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

function formatNumeric(value: number): string {
  return Number.isInteger(value) ? String(value) : value.toFixed(2);
}

/**
 * tuition_first priority: any head whose category is "tuition" (case-insensitive)
 * gets priority 0; everything else priority 1. Within a priority band, ties break
 * on the structure's sort_order (ascending) — deterministic ordering for
 * allocation + reversal. `head_allocation_priority` is a hook; only tuition_first
 * is implemented today.
 */
function priorityForHead(feeHead: string, mode: string): number {
  // Only "tuition_first" is implemented; `mode` is the documented hook for
  // future strategies. Any other value falls back to tuition_first.
  void mode;
  const { category } = decodeFeeHead(feeHead);
  return category.trim().toLowerCase() === "tuition" ? 0 : 1;
}

/**
 * Seed the head-allocation ledger for a freshly created invoice from the fee
 * structure items linked via the assignment. If the breakdown isn't reachable
 * (no items), seeds a single "general:General" head equal to the total so the
 * ledger still reconciles (SUM(head_total) == invoice total).
 *
 * Called with the SAME db transaction as invoice creation, so the seed is atomic
 * with the invoice INSERT.
 */
export async function seedHeadAllocations(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  invoiceId: string,
  feeAssignmentId: string,
  total: number,
): Promise<void> {
  const priorityMode = await getFinanceSettingValue(
    db,
    organizationId,
    schoolId,
    "payments",
    "head_allocation_priority",
    "tuition_first",
  );

  const items = await db.queryObject<StructureItemRow>(
    `SELECT fsi.fee_head, fsi.amount, fsi.sort_order
       FROM finance_fee_structure_items fsi
       JOIN finance_fee_assignments ffa
         ON ffa.fee_structure_id = fsi.fee_structure_id
        AND ffa.organization_id = fsi.organization_id
        AND ffa.school_id = fsi.school_id
      WHERE ffa.id = $1 AND ffa.organization_id = $2 AND ffa.school_id = $3
      ORDER BY fsi.sort_order ASC, fsi.created_at ASC`,
    [feeAssignmentId, organizationId, schoolId],
  );

  // Build the head rows. If items sum to the invoice total we use them verbatim;
  // otherwise (empty / mismatched breakdown) we fall back to a single General
  // head = total so the ledger always reconciles against the invoice.
  const itemsSum = round2(items.reduce((s, it) => s + parseAmount(it.amount), 0));
  const useItems = items.length > 0 && itemsSum === round2(total);

  interface HeadSeed {
    feeHead: string;
    label: string;
    headTotal: number;
    sortOrder: number;
    priority: number;
  }
  const seeds: HeadSeed[] = [];
  if (useItems) {
    for (const it of items) {
      const { label } = decodeFeeHead(it.fee_head);
      seeds.push({
        feeHead: it.fee_head,
        label,
        headTotal: round2(parseAmount(it.amount)),
        sortOrder: it.sort_order,
        priority: priorityForHead(it.fee_head, priorityMode),
      });
    }
  } else {
    seeds.push({
      feeHead: "general:General",
      label: "General",
      headTotal: round2(total),
      sortOrder: 0,
      priority: 1,
    });
  }

  for (const s of seeds) {
    await db.queryObject(
      `INSERT INTO finance_invoice_head_allocations (
        organization_id, school_id, invoice_id, fee_head, head_label,
        head_total_minor, head_paid_minor, sort_order, priority
      ) VALUES ($1, $2, $3, $4, $5, $6, 0, $7, $8)
      ON CONFLICT (invoice_id, fee_head) DO NOTHING`,
      [
        organizationId,
        schoolId,
        invoiceId,
        s.feeHead,
        s.label,
        formatNumeric(s.headTotal),
        s.sortOrder,
        s.priority,
      ],
    );
  }
}

/**
 * Allocate `amountCollected` across the invoice's heads in priority order
 * (priority asc, then sort_order asc), filling each head up to its remaining
 * (head_total - head_paid) until the collected amount is exhausted. Called AFTER
 * the existing outstanding reduction — it does not read or write outstanding.
 *
 * Returns the amount actually allocated (== amountCollected when the heads have
 * enough remaining, which they always do because SUM(head_total) == invoice
 * total and amountCollected <= outstanding <= remaining total).
 */
export async function allocateCollectionToHeads(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  invoiceId: string,
  amountCollected: number,
): Promise<number> {
  const heads = await db.queryObject<FinanceInvoiceHeadAllocationRow>(
    `SELECT * FROM finance_invoice_head_allocations
     WHERE invoice_id = $1 AND organization_id = $2 AND school_id = $3
     ORDER BY priority ASC, sort_order ASC, created_at ASC`,
    [invoiceId, organizationId, schoolId],
  );

  let remaining = round2(amountCollected);
  let allocated = 0;
  for (const head of heads) {
    if (remaining <= 0) break;
    const headTotal = parseAmount(head.head_total_minor);
    const headPaid = parseAmount(head.head_paid_minor);
    const headRemaining = round2(headTotal - headPaid);
    if (headRemaining <= 0) continue;
    const toApply = round2(Math.min(headRemaining, remaining));
    const newPaid = round2(headPaid + toApply);
    await db.queryObject(
      `UPDATE finance_invoice_head_allocations
        SET head_paid_minor = $1, updated_at = timezone('utc', now())
      WHERE id = $2 AND organization_id = $3 AND school_id = $4`,
      [formatNumeric(newPaid), head.id, organizationId, schoolId],
    );
    remaining = round2(remaining - toApply);
    allocated = round2(allocated + toApply);
  }
  return allocated;
}

/**
 * Reverse `amount` from the invoice's heads in REVERSE priority order (priority
 * desc, then sort_order desc), subtracting from each head's head_paid down to 0
 * until the amount is exhausted. Called on cancellation AFTER the existing
 * outstanding reversal. Exactly undoes a prior allocateCollectionToHeads of the
 * same amount, preserving the reconciliation invariant.
 */
export async function reverseCollectionFromHeads(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  invoiceId: string,
  amount: number,
): Promise<number> {
  const heads = await db.queryObject<FinanceInvoiceHeadAllocationRow>(
    `SELECT * FROM finance_invoice_head_allocations
     WHERE invoice_id = $1 AND organization_id = $2 AND school_id = $3
     ORDER BY priority DESC, sort_order DESC, created_at DESC`,
    [invoiceId, organizationId, schoolId],
  );

  let remaining = round2(amount);
  let reversed = 0;
  for (const head of heads) {
    if (remaining <= 0) break;
    const headPaid = parseAmount(head.head_paid_minor);
    if (headPaid <= 0) continue;
    const toReverse = round2(Math.min(headPaid, remaining));
    const newPaid = round2(headPaid - toReverse);
    await db.queryObject(
      `UPDATE finance_invoice_head_allocations
        SET head_paid_minor = $1, updated_at = timezone('utc', now())
      WHERE id = $2 AND organization_id = $3 AND school_id = $4`,
      [formatNumeric(newPaid), head.id, organizationId, schoolId],
    );
    remaining = round2(remaining - toReverse);
    reversed = round2(reversed + toReverse);
  }
  return reversed;
}

export async function listHeadAllocationsForInvoice(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  invoiceId: string,
): Promise<FinanceInvoiceHeadAllocationRow[]> {
  return await db.queryObject<FinanceInvoiceHeadAllocationRow>(
    `SELECT * FROM finance_invoice_head_allocations
     WHERE invoice_id = $1 AND organization_id = $2 AND school_id = $3
     ORDER BY priority ASC, sort_order ASC, created_at ASC`,
    [invoiceId, organizationId, schoolId],
  );
}

/**
 * FIN-9 — head-wise dues: per fee_head, SUM(head_total - head_paid) across OPEN
 * invoices for the school (issued / partially_paid; excludes paid / cancelled /
 * draft). Grouped by fee_head so the same head across many students rolls up.
 */
export interface HeadWiseDueRow {
  fee_head: string;
  head_label: string;
  dues: string;
}

export async function headWiseDues(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<HeadWiseDueRow[]> {
  return await db.queryObject<HeadWiseDueRow>(
    `SELECT ha.fee_head AS fee_head,
            MAX(ha.head_label) AS head_label,
            COALESCE(SUM(ha.head_total_minor - ha.head_paid_minor), 0)::text AS dues
       FROM finance_invoice_head_allocations ha
       JOIN finance_invoices fi ON fi.id = ha.invoice_id
      WHERE ha.organization_id = $1 AND ha.school_id = $2
        AND fi.invoice_status IN ('issued', 'partially_paid')
      GROUP BY ha.fee_head
      HAVING COALESCE(SUM(ha.head_total_minor - ha.head_paid_minor), 0) > 0
      ORDER BY dues DESC`,
    [organizationId, schoolId],
  );
}
