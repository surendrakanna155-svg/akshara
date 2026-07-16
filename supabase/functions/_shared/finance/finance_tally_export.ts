// PRC-A Batch 7 — Tally accounting export (owner-future-idea 11).
//
// Pure, deterministic Tally XML generation, kept free of DB/IO so it can be
// unit-tested exhaustively. Emits the standard Tally "Import Data" ENVELOPE with
// one Receipt voucher per completed fee collection.
//
// Tally sign convention (do not "fix"): in an ALLLEDGERENTRIES.LIST, a DEBIT
// entry carries ISDEEMEDPOSITIVE=Yes and a NEGATIVE amount; a CREDIT entry
// carries ISDEEMEDPOSITIVE=No and a POSITIVE amount. A Receipt debits cash/bank
// (money in) and credits the income ledger.

/** Per-school ledger mapping (finance_tally_ledger_map projected to runtime). */
export interface TallyLedgerMap {
  cashLedger: string;
  bankLedger: string;
  feeIncomeLedger: string;
  /** lowercased payment_method → explicit Tally ledger name. */
  methodLedgerOverrides: Record<string, string>;
  companyName: string | null;
}

/** The default map for a school that has not configured one — conventional Tally
 * ledger names, so an unconfigured school still gets an importable file. */
export const DEFAULT_TALLY_LEDGER_MAP: TallyLedgerMap = {
  cashLedger: "Cash",
  bankLedger: "Bank",
  feeIncomeLedger: "Fee Income",
  methodLedgerOverrides: {},
  companyName: null,
};

/** One collected receipt to export (subset of finance_collections + invoice). */
export interface TallyReceiptInput {
  receiptNumber: string;
  collectionDate: string; // YYYY-MM-DD
  paymentMethod: string;
  amount: string; // NUMERIC(12,2) as text, e.g. "4200.00"
  reference: string | null;
  invoiceNumber: string | null;
}

/** XML-escape text for element content and attribute values. */
export function escapeXml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

/**
 * Resolve the Tally DEBIT ledger (where the money landed) for a collection's
 * payment method. An explicit override wins; otherwise cash methods route to the
 * cash ledger and every other method to the bank ledger.
 */
export function resolveDebitLedger(paymentMethod: string, map: TallyLedgerMap): string {
  const method = (paymentMethod ?? "").trim().toLowerCase();
  const override = map.methodLedgerOverrides[method];
  if (override && override.trim().length > 0) return override.trim();
  return method === "cash" ? map.cashLedger : map.bankLedger;
}

/** YYYY-MM-DD → YYYYMMDD (Tally's voucher DATE format). Falls back to the raw
 * digits if the input is unexpected, never throwing. */
function tallyDate(isoDate: string): string {
  return (isoDate ?? "").slice(0, 10).replaceAll("-", "");
}

/** Normalise a NUMERIC text amount to a fixed 2-decimal string (Tally amounts). */
function amount2(raw: string): string {
  const n = Number(raw);
  if (!Number.isFinite(n)) return "0.00";
  return n.toFixed(2);
}

function voucherXml(r: TallyReceiptInput, map: TallyLedgerMap): string {
  const debitLedger = resolveDebitLedger(r.paymentMethod, map);
  const amt = amount2(r.amount);
  const narrationParts = [
    r.invoiceNumber ? `Invoice ${r.invoiceNumber}` : null,
    r.reference ? `Ref ${r.reference}` : null,
    `Fee receipt ${r.receiptNumber}`,
  ].filter((p): p is string => !!p);
  const narration = escapeXml(narrationParts.join(" · "));
  return [
    `    <TALLYMESSAGE xmlns:UDF="TallyUDF">`,
    `     <VOUCHER VCHTYPE="Receipt" ACTION="Create" OBJVIEW="Accounting Voucher View">`,
    `      <DATE>${tallyDate(r.collectionDate)}</DATE>`,
    `      <VOUCHERTYPENAME>Receipt</VOUCHERTYPENAME>`,
    `      <VOUCHERNUMBER>${escapeXml(r.receiptNumber)}</VOUCHERNUMBER>`,
    `      <NARRATION>${narration}</NARRATION>`,
    // Debit: cash/bank ledger receives the money (negative + deemed-positive).
    `      <ALLLEDGERENTRIES.LIST>`,
    `       <LEDGERNAME>${escapeXml(debitLedger)}</LEDGERNAME>`,
    `       <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>`,
    `       <AMOUNT>-${amt}</AMOUNT>`,
    `      </ALLLEDGERENTRIES.LIST>`,
    // Credit: fee income ledger (positive).
    `      <ALLLEDGERENTRIES.LIST>`,
    `       <LEDGERNAME>${escapeXml(map.feeIncomeLedger)}</LEDGERNAME>`,
    `       <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>`,
    `       <AMOUNT>${amt}</AMOUNT>`,
    `      </ALLLEDGERENTRIES.LIST>`,
    `     </VOUCHER>`,
    `    </TALLYMESSAGE>`,
  ].join("\n");
}

/**
 * Build the full Tally "Import Data" ENVELOPE for a set of completed receipts.
 * An empty set still produces a valid, importable (empty) envelope.
 */
export function buildTallyReceiptVouchersXml(
  receipts: TallyReceiptInput[],
  map: TallyLedgerMap,
): string {
  const company = escapeXml((map.companyName ?? "").trim());
  const vouchers = receipts.map((r) => voucherXml(r, map)).join("\n");
  return [
    `<?xml version="1.0" encoding="UTF-8"?>`,
    `<ENVELOPE>`,
    ` <HEADER>`,
    `  <TALLYREQUEST>Import Data</TALLYREQUEST>`,
    ` </HEADER>`,
    ` <BODY>`,
    `  <IMPORTDATA>`,
    `   <REQUESTDESC>`,
    `    <REPORTNAME>Vouchers</REPORTNAME>`,
    `    <STATICVARIABLES>`,
    `     <SVCURRENTCOMPANY>${company}</SVCURRENTCOMPANY>`,
    `    </STATICVARIABLES>`,
    `   </REQUESTDESC>`,
    `   <REQUESTDATA>`,
    vouchers,
    `   </REQUESTDATA>`,
    `  </IMPORTDATA>`,
    ` </BODY>`,
    `</ENVELOPE>`,
  ].filter((line) => line.length > 0).join("\n");
}
