// PRC-A Batch 7 — Tally export repository: the collected-receipts source query
// (off the certified finance_collections ledger) + the per-school ledger map CRUD.

import type { TenantQueryClient } from "../tenant_db.ts";
import type { TallyLedgerMap, TallyReceiptInput } from "./finance_tally_export.ts";
import { DEFAULT_TALLY_LEDGER_MAP } from "./finance_tally_export.ts";

export interface TallyLedgerMapRow {
  id: string;
  organization_id: string;
  school_id: string;
  cash_ledger: string;
  bank_ledger: string;
  fee_income_ledger: string;
  method_ledger_overrides: Record<string, string>;
  company_name: string | null;
  is_active: boolean;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

/**
 * List completed fee receipts for a school within [from, to] (inclusive), off the
 * certified finance_collections ledger. Only status='completed' rows are exported
 * — drafts/cancelled/refunded never post to Tally. Joined to finance_invoices for
 * the invoice number (narration only).
 */
export async function listCollectionsForTallyExport(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  fromDate: string,
  toDate: string,
): Promise<TallyReceiptInput[]> {
  const rows = await db.queryObject<{
    receipt_number: string;
    collection_date: string;
    payment_method: string;
    amount_collected: string;
    reference_number: string | null;
    invoice_number: string | null;
  }>(
    `SELECT fc.receipt_number,
            fc.collection_date::text AS collection_date,
            fc.payment_method,
            fc.amount_collected,
            fc.reference_number,
            fi.invoice_number
       FROM finance_collections fc
       LEFT JOIN finance_invoices fi ON fi.id = fc.invoice_id
      WHERE fc.organization_id = $1
        AND fc.school_id = $2
        AND fc.collection_status = 'completed'
        AND fc.collection_date BETWEEN $3::date AND $4::date
      ORDER BY fc.collection_date, fc.created_at`,
    [orgId, schoolId, fromDate, toDate],
  );
  return rows.map((r) => ({
    receiptNumber: r.receipt_number,
    collectionDate: r.collection_date,
    paymentMethod: r.payment_method,
    amount: r.amount_collected,
    reference: r.reference_number,
    invoiceNumber: r.invoice_number,
  }));
}

/** Project a ledger-map row (or null) to the runtime map used by the generator. */
export function tallyLedgerMapToRuntime(row: TallyLedgerMapRow | null): TallyLedgerMap {
  if (!row || !row.is_active) return DEFAULT_TALLY_LEDGER_MAP;
  const overrides: Record<string, string> = {};
  for (const [k, v] of Object.entries(row.method_ledger_overrides ?? {})) {
    if (typeof v === "string") overrides[k.toLowerCase()] = v;
  }
  return {
    cashLedger: row.cash_ledger,
    bankLedger: row.bank_ledger,
    feeIncomeLedger: row.fee_income_ledger,
    methodLedgerOverrides: overrides,
    companyName: row.company_name,
  };
}

export async function getTallyLedgerMap(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<TallyLedgerMapRow | null> {
  const rows = await db.queryObject<TallyLedgerMapRow>(
    `SELECT * FROM finance_tally_ledger_map
      WHERE organization_id = $1 AND school_id = $2`,
    [orgId, schoolId],
  );
  return rows[0] ?? null;
}

export async function upsertTallyLedgerMap(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string;
    cashLedger: string;
    bankLedger: string;
    feeIncomeLedger: string;
    methodLedgerOverrides: Record<string, string>;
    companyName: string | null;
    isActive: boolean;
    createdBy: string;
  },
): Promise<TallyLedgerMapRow> {
  const rows = await db.queryObject<TallyLedgerMapRow>(
    `INSERT INTO finance_tally_ledger_map (
       organization_id, school_id, cash_ledger, bank_ledger, fee_income_ledger,
       method_ledger_overrides, company_name, is_active, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7, $8, $9)
     ON CONFLICT (organization_id, school_id)
     DO UPDATE SET
       cash_ledger = EXCLUDED.cash_ledger,
       bank_ledger = EXCLUDED.bank_ledger,
       fee_income_ledger = EXCLUDED.fee_income_ledger,
       method_ledger_overrides = EXCLUDED.method_ledger_overrides,
       company_name = EXCLUDED.company_name,
       is_active = EXCLUDED.is_active,
       updated_at = timezone('utc', now())
     RETURNING *`,
    [
      input.organizationId,
      input.schoolId,
      input.cashLedger,
      input.bankLedger,
      input.feeIncomeLedger,
      JSON.stringify(input.methodLedgerOverrides ?? {}),
      input.companyName,
      input.isActive,
      input.createdBy,
    ],
  );
  return rows[0]!;
}
