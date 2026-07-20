import { assert, assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildTallyReceiptVouchersXml,
  DEFAULT_TALLY_LEDGER_MAP,
  escapeXml,
  resolveDebitLedger,
  type TallyLedgerMap,
  type TallyReceiptInput,
} from "./finance_tally_export.ts";

const MAP: TallyLedgerMap = {
  cashLedger: "Cash A/c",
  bankLedger: "HDFC Bank",
  feeIncomeLedger: "Tuition Income",
  methodLedgerOverrides: { upi: "HDFC UPI" },
  companyName: "Green Valley School",
};

const receipt = (over: Partial<TallyReceiptInput> = {}): TallyReceiptInput => ({
  receiptNumber: "RC-001",
  collectionDate: "2026-07-15",
  paymentMethod: "cash",
  amount: "4200.00",
  reference: null,
  invoiceNumber: "INV-77",
  ...over,
});

// ─── resolveDebitLedger ──────────────────────────────────────────────────────

Deno.test("Batch 7: cash routes to the cash ledger, non-cash to bank", () => {
  assertEquals(resolveDebitLedger("cash", MAP), "Cash A/c");
  assertEquals(resolveDebitLedger("CASH", MAP), "Cash A/c");
  assertEquals(resolveDebitLedger("cheque", MAP), "HDFC Bank");
  assertEquals(resolveDebitLedger("card", MAP), "HDFC Bank");
});

Deno.test("Batch 7: an explicit method override wins over the cash/bank default", () => {
  assertEquals(resolveDebitLedger("upi", MAP), "HDFC UPI");
});

// ─── escapeXml ───────────────────────────────────────────────────────────────

Deno.test("Batch 7: ledger names and refs are XML-escaped (injection-safe)", () => {
  assertEquals(escapeXml(`A & B <ledger> "x" 'y'`), "A &amp; B &lt;ledger&gt; &quot;x&quot; &apos;y&apos;");
});

Deno.test("Batch 7: a ledger name with & does not break the XML", () => {
  const xml = buildTallyReceiptVouchersXml([receipt()], {
    ...MAP,
    feeIncomeLedger: "Tuition & Transport",
  });
  assertStringIncludes(xml, "<LEDGERNAME>Tuition &amp; Transport</LEDGERNAME>");
  assert(!xml.includes("Tuition & Transport")); // the raw ampersand never appears
});

// ─── buildTallyReceiptVouchersXml ────────────────────────────────────────────

Deno.test("Batch 7: a receipt becomes a balanced Tally Receipt voucher (Dr cash / Cr income)", () => {
  const xml = buildTallyReceiptVouchersXml([receipt()], MAP);
  assertStringIncludes(xml, "<TALLYREQUEST>Import Data</TALLYREQUEST>");
  assertStringIncludes(xml, "<SVCURRENTCOMPANY>Green Valley School</SVCURRENTCOMPANY>");
  assertStringIncludes(xml, `VCHTYPE="Receipt"`);
  assertStringIncludes(xml, "<DATE>20260715</DATE>");
  assertStringIncludes(xml, "<VOUCHERNUMBER>RC-001</VOUCHERNUMBER>");
  // Debit cash: deemed-positive Yes, negative amount.
  assertStringIncludes(xml, "<LEDGERNAME>Cash A/c</LEDGERNAME>\n       <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>\n       <AMOUNT>-4200.00</AMOUNT>");
  // Credit income: deemed-positive No, positive amount.
  assertStringIncludes(xml, "<LEDGERNAME>Tuition Income</LEDGERNAME>\n       <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>\n       <AMOUNT>4200.00</AMOUNT>");
});

Deno.test("Batch 7: the debit and credit amounts net to zero (double-entry balance)", () => {
  const xml = buildTallyReceiptVouchersXml([receipt({ amount: "1500.50" })], MAP);
  const amounts = [...xml.matchAll(/<AMOUNT>(-?\d+\.\d{2})<\/AMOUNT>/g)].map((m) => Number(m[1]));
  assertEquals(amounts.length, 2);
  assertEquals(amounts[0] + amounts[1], 0);
});

Deno.test("Batch 7: an unconfigured school still yields an importable envelope with defaults", () => {
  const xml = buildTallyReceiptVouchersXml([receipt()], DEFAULT_TALLY_LEDGER_MAP);
  assertStringIncludes(xml, "<LEDGERNAME>Cash</LEDGERNAME>");
  assertStringIncludes(xml, "<LEDGERNAME>Fee Income</LEDGERNAME>");
  assertStringIncludes(xml, "<SVCURRENTCOMPANY></SVCURRENTCOMPANY>");
});

Deno.test("Batch 7: an empty receipt set is still a valid (empty) envelope", () => {
  const xml = buildTallyReceiptVouchersXml([], MAP);
  assertStringIncludes(xml, "<ENVELOPE>");
  assertStringIncludes(xml, "</ENVELOPE>");
  assert(!xml.includes("<VOUCHER "));
});

Deno.test("Batch 7: multiple receipts produce one voucher each", () => {
  const xml = buildTallyReceiptVouchersXml(
    [receipt({ receiptNumber: "RC-1" }), receipt({ receiptNumber: "RC-2", paymentMethod: "upi" })],
    MAP,
  );
  assertEquals([...xml.matchAll(/<VOUCHER /g)].length, 2);
  // second receipt (UPI) debits the override ledger
  assertStringIncludes(xml, "<LEDGERNAME>HDFC UPI</LEDGERNAME>");
});
