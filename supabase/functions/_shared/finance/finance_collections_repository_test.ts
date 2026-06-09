import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  CollectionAmountError,
  DuplicateReceiptError,
  InvoiceNotCollectibleError,
  InvalidCollectionTransitionError,
  cancelCollection,
  computeInvoiceStatus,
  createCollection,
  getDailySummary,
  getReceipt,
} from "./finance_collections_repository.ts";
import {
  collectionDetailToApi,
  collectionPaymentToApi,
  dailySummaryToApi,
} from "./finance_mapper.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const STAFF = "a3000000-0000-4000-8000-000000000001";
const STUDENT = "a4000000-0000-4000-8000-000000000001";
const INVOICE = "inv-1";
const ACCOUNT = "acct-1";

type Row = Record<string, unknown>;

class MockCollectionsDb {
  invoices = [{
    id: INVOICE,
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_id: STUDENT,
    fee_assignment_id: "asg-1",
    outstanding_amount: "50000",
    total_amount: "50000",
    invoice_status: "issued",
    due_date: "2026-07-07",
  }];
  accounts = [{
    id: ACCOUNT,
    fee_assignment_id: "asg-1",
    organization_id: ORG,
    school_id: SCHOOL_A,
    amount_paid: "0",
    outstanding_amount: "50000",
  }];
  collections: Row[] = [];
  receipts: Row[] = [];
  failReceiptInsert = false;

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("FROM finance_invoices fi") && sql.includes("JOIN finance_student_accounts")) {
      const inv = this.invoices.find((i) => i.id === args[0]);
      if (!inv) return [] as T[];
      const acct = this.accounts.find((a) => a.fee_assignment_id === inv.fee_assignment_id);
      return [{ ...inv, student_account_id: acct?.id }] as T[];
    }
    if (sql.includes("INSERT INTO finance_collections")) {
      const row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        school_id: args[1],
        student_id: args[2],
        invoice_id: args[3],
        student_account_id: args[4],
        receipt_number: args[5],
        collection_date: args[6],
        payment_method: args[7],
        reference_number: args[8],
        amount_collected: String(args[9]),
        notes: args[10],
        collection_status: "completed",
        collected_by: args[11],
        created_at: "2026-06-09T00:00:00.000Z",
        updated_at: "2026-06-09T00:00:00.000Z",
      };
      this.collections.push(row);
      return [row as T];
    }
    if (sql.includes("INSERT INTO finance_receipts")) {
      if (this.failReceiptInsert) {
        throw new Error('duplicate key value violates unique constraint "finance_receipts_receipt_number_key"');
      }
      const row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        school_id: args[1],
        collection_id: args[2],
        receipt_number: args[3],
        receipt_date: args[4],
        amount: String(args[5]),
        generated_by: args[6],
        created_at: "2026-06-09T00:00:00.000Z",
      };
      this.receipts.push(row);
      return [row as T];
    }
    if (sql.includes("UPDATE finance_invoices SET") && sql.includes("outstanding_amount")) {
      const inv = this.invoices.find((i) => i.id === args[2]);
      if (inv) {
        inv.outstanding_amount = String(args[0]);
        inv.invoice_status = String(args[1]);
      }
      return [] as T[];
    }
    if (sql.includes("UPDATE finance_student_accounts SET") && sql.includes("amount_paid +")) {
      const acct = this.accounts.find((a) => a.id === args[1]);
      if (acct) {
        acct.amount_paid = String(parseFloat(String(acct.amount_paid)) + Number(args[0]));
        acct.outstanding_amount = String(parseFloat(String(acct.outstanding_amount)) - Number(args[0]));
      }
      return [] as T[];
    }
    if (sql.includes("SELECT * FROM finance_invoices WHERE id = $1 AND organization_id = $2")) {
      return this.invoices.filter((i) =>
        i.id === args[0] && i.organization_id === args[1] && i.school_id === args[2]
      ) as T[];
    }
    if (sql.includes("SELECT * FROM finance_invoices WHERE id = $1") && !sql.includes("organization_id")) {
      return this.invoices.filter((i) => i.id === args[0]) as T[];
    }
    if (sql.includes("SELECT * FROM finance_collections") && sql.includes("WHERE id = $1") && !sql.includes("fc.id")) {
      return this.collections.filter((c) =>
        c.id === args[0] && c.organization_id === args[1] && c.school_id === args[2]
      ) as T[];
    }
    if (sql.includes("SELECT * FROM finance_receipts") && sql.includes("collection_id = $1")) {
      return this.receipts.filter((r) => r.collection_id === args[0]) as T[];
    }
    if (sql.includes("SELECT * FROM finance_receipts") && sql.includes("WHERE id = $1")) {
      return this.receipts.filter((r) => r.id === args[0]) as T[];
    }
    if (sql.includes("UPDATE finance_collections SET") && sql.includes("cancelled")) {
      const row = this.collections.find((c) => c.id === args[0]);
      if (row) row.collection_status = "cancelled";
      return (row ? [row] : []) as T[];
    }
    if (sql.includes("UPDATE finance_invoices SET") && sql.includes("outstanding_amount = $1") && sql.includes("cancel")) {
      const inv = this.invoices.find((i) => i.id === args[2]);
      if (inv) {
        inv.outstanding_amount = String(args[0]);
        inv.invoice_status = String(args[1]);
      }
      return [] as T[];
    }
    if (sql.includes("UPDATE finance_student_accounts SET") && sql.includes("amount_paid -")) {
      const acct = this.accounts.find((a) => a.id === args[1]);
      if (acct) {
        acct.amount_paid = String(parseFloat(String(acct.amount_paid)) - Number(args[0]));
        acct.outstanding_amount = String(parseFloat(String(acct.outstanding_amount)) + Number(args[0]));
      }
      return [] as T[];
    }
    if (sql.includes("FROM finance_collections fc") && sql.includes("WHERE fc.id = $1")) {
      const row = this.collections.find((c) =>
        c.id === args[0] && c.organization_id === args[1] && c.school_id === args[2]
      );
      if (!row) return [] as T[];
      return [{ ...row, student_name: "Probe Student", admission_number: "ADM-1", class_label: "5" }] as T[];
    }
    return [] as T[];
  }

  async queryCount(): Promise<number> {
    return this.collections.length;
  }

  async queryObjectDailySummary(sql: string): Promise<unknown[]> {
    if (sql.includes("FROM finance_collections") && sql.includes("collection_date = CURRENT_DATE")) {
      const completed = this.collections.filter((c) => c.collection_status === "completed");
      const cash = completed.filter((c) => String(c.payment_method).toLowerCase() === "cash");
      const upi = completed.filter((c) => String(c.payment_method).toLowerCase() === "upi");
      const sum = (rows: Row[]) => rows.reduce((t, r) => t + parseFloat(String(r.amount_collected)), 0);
      return [{
        total: String(sum(completed)),
        count: String(completed.length),
        cash: String(sum(cash)),
        upi: String(sum(upi)),
        drafts: "0",
      }];
    }
    if (sql.includes("FROM finance_invoices") && sql.includes("invoice_status")) {
      const active = this.invoices.filter((i) => !["cancelled", "draft"].includes(String(i.invoice_status)));
      return [{
        pending: String(active.filter((i) => i.invoice_status === "issued").length),
        paid: String(active.filter((i) => i.invoice_status === "paid").length),
        partial: String(active.filter((i) => i.invoice_status === "partially_paid").length),
        outstanding: String(active.reduce((t, i) =>
          ["issued", "partially_paid"].includes(String(i.invoice_status))
            ? t + parseFloat(String(i.outstanding_amount))
            : t, 0)),
      }];
    }
    return [];
  }
}

class MockDailySummaryDb extends MockCollectionsDb {
  override async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("collection_date = CURRENT_DATE") || (sql.includes("FROM finance_invoices") && sql.includes("invoice_status"))) {
      return await this.queryObjectDailySummary(sql) as T[];
    }
    return await super.queryObject(sql, args);
  }
}

function asDb(mock: MockCollectionsDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

function schoolClaims(permissions: string[]): AccessTokenClaims {
  return {
    sub: STAFF,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL_A,
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions,
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "test",
  };
}

Deno.test("computeInvoiceStatus derives issued/partial/paid", () => {
  assertEquals(computeInvoiceStatus(50000, 50000), "issued");
  assertEquals(computeInvoiceStatus(25000, 50000), "partially_paid");
  assertEquals(computeInvoiceStatus(0, 50000), "paid");
});

Deno.test("createCollection creates collection and receipt", async () => {
  const db = new MockCollectionsDb();
  const result = await createCollection(asDb(db), ORG, SCHOOL_A, {
    invoiceId: INVOICE,
    amountCollected: 10000,
    paymentMethod: "cash",
    collectedBy: STAFF,
  });
  assertEquals(result.collection.collection_status, "completed");
  assertEquals(result.receipt.receipt_number, result.collection.receipt_number);
  assertEquals(db.collections.length, 1);
  assertEquals(db.receipts.length, 1);
});

Deno.test("createCollection updates invoice and account balances", async () => {
  const db = new MockCollectionsDb();
  await createCollection(asDb(db), ORG, SCHOOL_A, {
    invoiceId: INVOICE,
    amountCollected: 20000,
    paymentMethod: "upi",
    collectedBy: STAFF,
  });
  assertEquals(db.invoices[0]!.outstanding_amount, "30000");
  assertEquals(db.invoices[0]!.invoice_status, "partially_paid");
  assertEquals(db.accounts[0]!.amount_paid, "20000");
  assertEquals(db.accounts[0]!.outstanding_amount, "30000");
});

Deno.test("createCollection full payment marks invoice paid", async () => {
  const db = new MockCollectionsDb();
  await createCollection(asDb(db), ORG, SCHOOL_A, {
    invoiceId: INVOICE,
    amountCollected: 50000,
    paymentMethod: "cash",
    collectedBy: STAFF,
  });
  assertEquals(db.invoices[0]!.invoice_status, "paid");
  assertEquals(db.invoices[0]!.outstanding_amount, "0");
});

Deno.test("createCollection rejects amount over outstanding", async () => {
  const db = new MockCollectionsDb();
  await assertRejects(
    () => createCollection(asDb(db), ORG, SCHOOL_A, {
      invoiceId: INVOICE,
      amountCollected: 50001,
      paymentMethod: "cash",
      collectedBy: STAFF,
    }),
    CollectionAmountError,
  );
});

Deno.test("createCollection rejects cancelled invoice", async () => {
  const db = new MockCollectionsDb();
  db.invoices[0]!.invoice_status = "cancelled";
  await assertRejects(
    () => createCollection(asDb(db), ORG, SCHOOL_A, {
      invoiceId: INVOICE,
      amountCollected: 1000,
      paymentMethod: "cash",
      collectedBy: STAFF,
    }),
    InvoiceNotCollectibleError,
  );
});

Deno.test("createCollection duplicate receipt surfaces DuplicateReceiptError", async () => {
  const db = new MockCollectionsDb();
  db.failReceiptInsert = true;
  await assertRejects(
    () => createCollection(asDb(db), ORG, SCHOOL_A, {
      invoiceId: INVOICE,
      amountCollected: 1000,
      paymentMethod: "cash",
      collectedBy: STAFF,
    }),
    DuplicateReceiptError,
  );
});

Deno.test("cancelCollection reverses balances for completed collection", async () => {
  const db = new MockCollectionsDb();
  const created = await createCollection(asDb(db), ORG, SCHOOL_A, {
    invoiceId: INVOICE,
    amountCollected: 15000,
    paymentMethod: "cash",
    collectedBy: STAFF,
  });
  await cancelCollection(asDb(db), ORG, SCHOOL_A, created.collection.id);
  assertEquals(db.invoices[0]!.outstanding_amount, "50000");
  assertEquals(db.invoices[0]!.invoice_status, "issued");
  assertEquals(db.accounts[0]!.amount_paid, "0");
});

Deno.test("cancelCollection rejects already cancelled", async () => {
  const db = new MockCollectionsDb();
  const created = await createCollection(asDb(db), ORG, SCHOOL_A, {
    invoiceId: INVOICE,
    amountCollected: 5000,
    paymentMethod: "cash",
    collectedBy: STAFF,
  });
  await cancelCollection(asDb(db), ORG, SCHOOL_A, created.collection.id);
  await assertRejects(
    () => cancelCollection(asDb(db), ORG, SCHOOL_A, created.collection.id),
    InvalidCollectionTransitionError,
  );
});

Deno.test("getReceipt returns receipt and collection", async () => {
  const db = new MockCollectionsDb();
  const created = await createCollection(asDb(db), ORG, SCHOOL_A, {
    invoiceId: INVOICE,
    amountCollected: 5000,
    paymentMethod: "cash",
    collectedBy: STAFF,
  });
  const receiptId = created.receipt.id as string;
  const found = await getReceipt(asDb(db), ORG, SCHOOL_A, receiptId);
  assertEquals(found?.receipt.id, receiptId);
  assertEquals(found?.collection.id, created.collection.id);
});

Deno.test("collectionPaymentToApi maps client status field", () => {
  const api = collectionPaymentToApi({
    id: "c1",
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_id: STUDENT,
    invoice_id: INVOICE,
    student_account_id: ACCOUNT,
    receipt_number: "RCPT-2026-TEST",
    collection_date: "2026-06-09",
    payment_method: "cash",
    reference_number: null,
    amount_collected: "5000",
    notes: null,
    collection_status: "completed",
    collected_by: STAFF,
    created_at: "2026-06-09T00:00:00.000Z",
    updated_at: "2026-06-09T00:00:00.000Z",
    student_name: "Probe",
    admission_number: "ADM-1",
    class_label: "5",
  });
  assertEquals(api.status, "completed");
  assertEquals(api.mode, "cash");
});

Deno.test("viewFinance required for collection reads", () => {
  assertEquals(requirePermission(schoolClaims([]), "viewFinance")?.status, 403);
  assertEquals(requirePermission(schoolClaims(["viewFinance"]), "viewFinance"), null);
});

Deno.test("manageFinance required for collection writes", () => {
  assertEquals(requirePermission(schoolClaims(["viewFinance"]), "manageFinance")?.status, 403);
});

Deno.test("non-school scopes denied for finance collections", () => {
  const orgClaims: AccessTokenClaims = {
    ...schoolClaims(["viewFinance", "manageFinance"]),
    scope: "organization",
    school_id: null,
    role: "organizationAdmin",
    role_slugs: ["organizationAdmin"],
    primary_role: "organizationAdmin",
  };
  assertEquals(requireSchoolOperationalScope(orgClaims)?.status, 403);
});

Deno.test("getDailySummary aggregates collections and invoices", async () => {
  const db = new MockDailySummaryDb();
  await createCollection(asDb(db), ORG, SCHOOL_A, {
    invoiceId: INVOICE,
    amountCollected: 10000,
    paymentMethod: "cash",
    collectedBy: STAFF,
  });
  const summary = await getDailySummary(asDb(db), ORG, SCHOOL_A);
  assertEquals(summary.todayCollectionCount, 1);
  assertEquals(summary.todayCollections, 10000);
  assertEquals(summary.partiallyPaidInvoices, 1);
  const api = dailySummaryToApi(summary);
  assertEquals(api.totalCollected, "10000");
  assertEquals(api.transactionCount, 1);
});

Deno.test("collectionDetailToApi builds timeline and receipt links from db rows", () => {
  const collection = {
    id: "c1",
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_id: STUDENT,
    invoice_id: INVOICE,
    student_account_id: ACCOUNT,
    receipt_number: "RCPT-1",
    collection_date: "2026-06-09",
    payment_method: "cash",
    reference_number: null,
    amount_collected: "5000",
    notes: null,
    collection_status: "completed",
    collected_by: STAFF,
    created_at: "2026-06-09T00:00:00.000Z",
    updated_at: "2026-06-09T00:00:00.000Z",
    student_name: "Probe",
    admission_number: "ADM-1",
    class_label: "5",
  };
  const invoice = {
    id: INVOICE,
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_id: STUDENT,
    fee_assignment_id: "asg-1",
    academic_year: "2026-27",
    invoice_number: "INV-1",
    invoice_date: "2026-06-01",
    due_date: "2026-07-01",
    subtotal_amount: "50000",
    discount_amount: "0",
    total_amount: "50000",
    outstanding_amount: "45000",
    invoice_status: "partially_paid",
    created_by: STAFF,
    created_at: "2026-06-01T00:00:00.000Z",
    updated_at: "2026-06-09T00:00:00.000Z",
  };
  const account = {
    id: ACCOUNT,
    total_fee: "50000",
    amount_paid: "5000",
    outstanding_amount: "45000",
    status: "open",
  };
  const detail = collectionDetailToApi(
    collection as import("./finance_collections_repository.ts").CollectionListRow,
    invoice as import("./finance_invoices_repository.ts").FinanceInvoiceRow,
    account,
    [collection as import("./finance_collections_repository.ts").FinanceCollectionRow],
    [{
      id: "r1",
      organization_id: ORG,
      school_id: SCHOOL_A,
      collection_id: "c1",
      receipt_number: "RCPT-1",
      receipt_date: "2026-06-09",
      amount: "5000",
      generated_by: STAFF,
      created_at: "2026-06-09T00:00:00.000Z",
    }],
  );
  const timeline = detail.paymentTimeline as Array<Record<string, unknown>>;
  const links = detail.receiptLinks as Array<Record<string, unknown>>;
  const history = detail.installmentHistory as Array<Record<string, unknown>>;
  assertEquals(timeline.length, 1);
  assertEquals(timeline[0]!.status, "completed");
  assertEquals(links.length, 1);
  assertEquals(links[0]!.receiptNumber, "RCPT-1");
  assertEquals(history[0]!.paidAmount, "5000");
  assertEquals((detail.summaryKpis as Array<Record<string, unknown>>).length, 5);
});
