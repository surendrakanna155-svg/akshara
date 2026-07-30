// PRA-P1-09 + P1-08 (S1) — direct behaviour tests for the two owner-approved
// decisions: (1) createCollection rejects direct cheque/DD/PDC entry; (2) when a
// school enables `receipts.receipt_sequencing`, a collection gets a gapless
// per-school, per-financial-year number `{prefix}/{FY}/{NNNNNN}`.
import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  createCollection,
  InstrumentPaymentNotAllowedError,
} from "./finance_collections_repository.ts";

const ORG = "org-1";
const SCHOOL = "school-1";

// --- PRA-P1-09: direct cheque/DD/PDC entry is rejected (pure guard, no DB) ---

class NoopDb {
  // deno-lint-ignore require-await
  async queryObject<T>(): Promise<T[]> {
    throw new Error("createCollection must reject the instrument BEFORE any query");
  }
  get client(): TenantQueryClient {
    return this as unknown as TenantQueryClient;
  }
}

for (const method of ["cheque", "dd", "pdc", "CHEQUE", " Dd "]) {
  Deno.test(`PRA-P1-09: createCollection rejects direct '${method}' entry`, async () => {
    const db = new NoopDb();
    await assertRejects(
      () =>
        createCollection(db.client, ORG, SCHOOL, {
          invoiceId: "inv-1",
          amountCollected: 5000,
          paymentMethod: method,
          collectedBy: "staff-1",
        }),
      InstrumentPaymentNotAllowedError,
    );
  });
}

Deno.test("PRA-P1-09: allowInstrument bypasses the block (register post path)", async () => {
  // With allowInstrument set (as reconcileOfflinePayment does), a cheque is
  // allowed and reaches the DB — proven by the invoice-load query firing.
  let reachedDb = false;
  const db = {
    // deno-lint-ignore require-await
    async queryObject<T>(sql: string): Promise<T[]> {
      reachedDb = true;
      // Fail the invoice load fast; we only assert the guard was passed.
      if (sql.includes("FROM finance_invoices fi")) return [] as T[];
      return [] as T[];
    },
  };
  await assertRejects(() =>
    createCollection(db as unknown as TenantQueryClient, ORG, SCHOOL, {
      invoiceId: "inv-1",
      amountCollected: 5000,
      paymentMethod: "cheque",
      collectedBy: "staff-1",
      allowInstrument: true,
    })
  );
  assertEquals(reachedDb, true, "allowInstrument must let a cheque reach the DB");
});

// --- PRA-P1-08: sequenced receipt number when the per-school flag is on ---

class SequencingMockDb {
  capturedReceiptNumber: string | null = null;

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    const s = sql.replace(/\s+/g, " ").trim();

    // getSettingsRow → sequencing ON, prefix RCP.
    if (s.includes("SELECT * FROM finance_settings")) {
      return [{
        organization_id: ORG,
        school_id: SCHOOL,
        academic_year: "",
        settings: {
          "receipts.receipt_sequencing": "true",
          "receipts.receipt_prefix": "RCP",
        },
      } as T];
    }
    // Atomic sequence allocation → the 42nd receipt this FY.
    if (s.includes("INSERT INTO finance_receipt_sequences")) {
      return [{ next_number: "42" } as T];
    }
    // loadInvoiceForCollection.
    if (s.includes("FROM finance_invoices fi") && s.includes("JOIN finance_student_accounts")) {
      return [{
        id: String(args[0]),
        organization_id: ORG,
        school_id: SCHOOL,
        student_id: "stu-1",
        student_account_id: "acct-1",
        fee_assignment_id: "fa-1",
        total_amount: "100000",
        outstanding_amount: "100000",
        invoice_status: "issued",
      } as T];
    }
    // Capture the receipt number chosen for the collection.
    if (s.startsWith("INSERT INTO finance_collections")) {
      this.capturedReceiptNumber = String(args[5]);
      return [{
        id: "coll-1",
        receipt_number: String(args[5]),
        amount_collected: String(args[9]),
        collection_status: "completed",
      } as T];
    }
    if (s.startsWith("INSERT INTO finance_receipts")) {
      return [{ id: "rcpt-1", receipt_number: String(args[3]) } as T];
    }
    // day-lock, invoice/account updates, head allocations → inert.
    return [] as T[];
  }
  get client(): TenantQueryClient {
    return this as unknown as TenantQueryClient;
  }
}

Deno.test("PRA-P1-08: sequenced receipt number is {prefix}/{FY-Apr-Mar}/{padded}", async () => {
  const db = new SequencingMockDb();
  await createCollection(db.client, ORG, SCHOOL, {
    invoiceId: "inv-1",
    amountCollected: 5000,
    paymentMethod: "cash",
    collectedBy: "staff-1",
    collectionDate: "2026-07-01", // FY 2026-27 (April–March)
  });
  assertEquals(db.capturedReceiptNumber, "RCP/2026-27/000042");
});

Deno.test("PRA-P1-08: a January date belongs to the previous fiscal year", async () => {
  const db = new SequencingMockDb();
  await createCollection(db.client, ORG, SCHOOL, {
    invoiceId: "inv-1",
    amountCollected: 5000,
    paymentMethod: "cash",
    collectedBy: "staff-1",
    collectionDate: "2027-01-15", // Jan 2027 → still FY 2026-27
  });
  assertEquals(db.capturedReceiptNumber, "RCP/2026-27/000042");
});
