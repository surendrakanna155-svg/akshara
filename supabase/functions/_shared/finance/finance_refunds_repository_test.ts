import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import {
  InvalidRefundTransitionError,
  RefundAmountError,
  RefundSelfApprovalError,
  approveRefund,
  createRefund,
  getRefund,
  listRefunds,
  rejectRefund,
  type FinanceRefundRow,
} from "./finance_refunds_repository.ts";
import type { FinanceCollectionRow } from "./finance_collections_repository.ts";
import type { FinanceInvoiceRow } from "./finance_invoices_repository.ts";

type Row = Record<string, unknown>;

const ORG = "org-1";
const SCHOOL = "school-1";
const USER = "user-1";
const CHECKER = "user-2";
const COLLECTION_ID = "col-1";
const INVOICE_ID = "inv-1";
const ACCOUNT_ID = "acct-1";

class MockRefundsDb {
  collections: FinanceCollectionRow[] = [{
    id: COLLECTION_ID,
    organization_id: ORG,
    school_id: SCHOOL,
    student_id: "student-1",
    invoice_id: INVOICE_ID,
    student_account_id: ACCOUNT_ID,
    receipt_number: "RCPT-TEST-1",
    collection_date: "2026-06-07",
    payment_method: "cash",
    reference_number: null,
    amount_collected: "5000",
    notes: null,
    collection_status: "completed",
    collected_by: USER,
    created_at: "2026-06-07T00:00:00Z",
    updated_at: "2026-06-07T00:00:00Z",
  }];
  invoices: FinanceInvoiceRow[] = [{
    id: INVOICE_ID,
    organization_id: ORG,
    school_id: SCHOOL,
    student_id: "student-1",
    fee_assignment_id: "fa-1",
    academic_year: "2026-27",
    invoice_number: "INV-1",
    invoice_date: "2026-06-01",
    due_date: "2026-07-01",
    subtotal_amount: "50000",
    discount_amount: "0",
    total_amount: "50000",
    outstanding_amount: "45000",
    invoice_status: "partially_paid",
    created_by: USER,
    created_at: "2026-06-01T00:00:00Z",
    updated_at: "2026-06-01T00:00:00Z",
  }];
  accounts: Row[] = [{
    id: ACCOUNT_ID,
    organization_id: ORG,
    school_id: SCHOOL,
    amount_paid: "5000",
    outstanding_amount: "45000",
  }];
  refunds: FinanceRefundRow[] = [];

  async queryCount(sql: string, args: unknown[] = []): Promise<number> {
    if (sql.includes("FROM finance_refunds") && sql.includes("count")) {
      return this.refunds.filter((r) =>
        r.organization_id === args[0] && r.school_id === args[1]
      ).length;
    }
    if (sql.includes("count") && sql.includes("finance_refunds")) {
      return this.refunds.length;
    }
    return 0;
  }

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("SUM(refund_amount)")) {
      const collectionId = args[0] as string;
      const excludeId = args[3] as string | undefined;
      const total = this.refunds
        .filter((r) =>
          r.collection_id === collectionId &&
          ["pending", "approved", "processed"].includes(r.refund_status) &&
          (!excludeId || r.id !== excludeId)
        )
        .reduce((sum, r) => sum + parseFloat(r.refund_amount), 0);
      return [{ total: String(total) }] as T[];
    }

    if (sql.includes("INSERT INTO finance_refunds")) {
      const row: FinanceRefundRow = {
        id: `refund-${this.refunds.length + 1}`,
        organization_id: args[0] as string,
        school_id: args[1] as string,
        invoice_id: args[2] as string,
        collection_id: args[3] as string,
        student_account_id: args[4] as string,
        refund_amount: String(args[5]),
        refund_reason: args[6] as string,
        refund_status: "pending",
        approved_by: null,
        requested_by: args[7] as string,
        approved_at: null,
        created_at: "2026-06-07T00:00:00Z",
        updated_at: "2026-06-07T00:00:00Z",
      };
      this.refunds.push(row);
      return [row] as T[];
    }

    if (sql.includes("FROM finance_collections") && sql.includes("receipt_number")) {
      const receipt = args[0] as string;
      const accountId = args[1] as string;
      return this.collections.filter((c) =>
        c.receipt_number === receipt && c.student_account_id === accountId
      ) as T[];
    }

    if (sql.includes("FROM finance_collections") && sql.includes("WHERE id = $1")) {
      return this.collections.filter((c) => c.id === args[0]) as T[];
    }

    if (sql.includes("FROM finance_invoices")) {
      return this.invoices.filter((i) => i.id === args[0]) as T[];
    }

    if (sql.includes("UPDATE finance_invoices")) {
      const invoice = this.invoices.find((i) => i.id === args[2]);
      if (invoice) {
        invoice.outstanding_amount = args[0] as string;
        invoice.invoice_status = args[1] as FinanceInvoiceRow["invoice_status"];
      }
      return [] as T[];
    }

    if (sql.includes("UPDATE finance_student_accounts")) {
      const account = this.accounts.find((a) => a.id === args[1]);
      if (account) {
        const delta = parseFloat(String(args[0]));
        account.amount_paid = String(parseFloat(String(account.amount_paid)) - delta);
        account.outstanding_amount = String(
          parseFloat(String(account.outstanding_amount)) + delta,
        );
      }
      return [] as T[];
    }

    if (sql.includes("UPDATE finance_collections SET") && sql.includes("collection_status")) {
      const collection = this.collections.find((c) => c.id === args[1]);
      if (collection) {
        collection.collection_status = args[0] as FinanceCollectionRow["collection_status"];
      }
      return [] as T[];
    }

    if (sql.includes("UPDATE finance_refunds SET") && sql.includes("processed")) {
      const refund = this.refunds.find((r) => r.id === args[1]);
      if (refund) {
        refund.refund_status = "processed";
        refund.approved_by = args[0] as string;
        refund.approved_at = "2026-06-07T01:00:00Z";
      }
      return refund ? [refund] as T[] : [] as T[];
    }

    if (sql.includes("UPDATE finance_refunds SET") && sql.includes("rejected")) {
      const refund = this.refunds.find((r) => r.id === args[0]);
      if (refund) refund.refund_status = "rejected";
      return [] as T[];
    }

    if (sql.includes("FROM finance_refunds fr")) {
      if (args.length >= 4) {
        const orgId = args[0] as string;
        const schoolId = args[1] as string;
        return this.refunds
          .filter((r) => r.organization_id === orgId && r.school_id === schoolId)
          .map((refund) => ({
            ...refund,
            student_name: "Test Student",
            admission_number: "ADM-1",
            class_label: "5",
            receipt_number: "RCPT-TEST-1",
          })) as T[];
      }
      const id = args[0] as string;
      const refund = this.refunds.find((r) => r.id === id);
      if (!refund) return [] as T[];
      const collection = this.collections.find((c) => c.id === refund.collection_id);
      return [{
        ...refund,
        student_name: "Test Student",
        admission_number: "ADM-1",
        class_label: "5",
        receipt_number: collection?.receipt_number,
      }] as T[];
    }

    return [] as T[];
  }
}

function asDb(mock: MockRefundsDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

function schoolClaims(permissions: string[]): AccessTokenClaims {
  return {
    sub: USER,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL,
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

Deno.test("createRefund inserts pending refund by collection id", async () => {
  const db = new MockRefundsDb();
  const refund = await createRefund(asDb(db), ORG, SCHOOL, {
    collectionId: COLLECTION_ID,
    refundAmount: 1000,
    refundReason: "Duplicate payment",
    requestedBy: USER,
  });
  assertEquals(refund.refund_status, "pending");
  assertEquals(refund.refund_amount, "1000");
});

Deno.test("createRefund resolves collection from receipt and account", async () => {
  const db = new MockRefundsDb();
  const refund = await createRefund(asDb(db), ORG, SCHOOL, {
    studentAccountId: ACCOUNT_ID,
    originalReceipt: "RCPT-TEST-1",
    refundAmount: 500,
    refundReason: "Overpayment",
    requestedBy: USER,
  });
  assertEquals(refund.collection_id, COLLECTION_ID);
});

Deno.test("createRefund rejects amount exceeding collection", async () => {
  const db = new MockRefundsDb();
  await assertRejects(
    () => createRefund(asDb(db), ORG, SCHOOL, {
      collectionId: COLLECTION_ID,
      refundAmount: 6000,
      refundReason: "Too much",
      requestedBy: USER,
    }),
    RefundAmountError,
  );
});

Deno.test("sequential refunds cannot exceed collection amount", async () => {
  const db = new MockRefundsDb();
  db.collections[0]!.amount_collected = "10000";
  const first = await createRefund(asDb(db), ORG, SCHOOL, {
    collectionId: COLLECTION_ID,
    refundAmount: 6000,
    refundReason: "First partial",
    requestedBy: USER,
  });
  await approveRefund(asDb(db), ORG, SCHOOL, first.id, CHECKER);
  await assertRejects(
    () => createRefund(asDb(db), ORG, SCHOOL, {
      collectionId: COLLECTION_ID,
      refundAmount: 5000,
      refundReason: "Second exceeds ceiling",
      requestedBy: USER,
    }),
    RefundAmountError,
  );
});

Deno.test("partial refund increases outstanding from current balance not invoice total", async () => {
  const db = new MockRefundsDb();
  db.collections[0]!.amount_collected = "15000";
  db.invoices[0]!.total_amount = "50000";
  db.invoices[0]!.outstanding_amount = "15000";
  db.invoices[0]!.invoice_status = "partially_paid";
  db.accounts[0]!.amount_paid = "35000";
  db.accounts[0]!.outstanding_amount = "15000";

  const created = await createRefund(asDb(db), ORG, SCHOOL, {
    collectionId: COLLECTION_ID,
    refundAmount: 15000,
    refundReason: "Full refund of first collection",
    requestedBy: USER,
  });
  await approveRefund(asDb(db), ORG, SCHOOL, created.id, CHECKER);

  assertEquals(db.invoices[0]!.outstanding_amount, "30000");
  assertEquals(db.accounts[0]!.outstanding_amount, "30000");
  assertEquals(db.accounts[0]!.amount_paid, "20000");
});

Deno.test("approveRefund updates invoice account and collection status", async () => {
  const db = new MockRefundsDb();
  const created = await createRefund(asDb(db), ORG, SCHOOL, {
    collectionId: COLLECTION_ID,
    refundAmount: 2000,
    refundReason: "Partial refund",
    requestedBy: USER,
  });
  const approved = await approveRefund(asDb(db), ORG, SCHOOL, created.id, CHECKER);
  assertEquals(approved.refund_status, "processed");
  assertEquals(db.invoices[0]!.outstanding_amount, "47000");
  assertEquals(db.accounts[0]!.outstanding_amount, "47000");
  assertEquals(db.accounts[0]!.amount_paid, "3000");
  assertEquals(db.collections[0]!.collection_status, "partially_refunded");
});

Deno.test("approveRefund marks collection refunded when full amount", async () => {
  const db = new MockRefundsDb();
  const created = await createRefund(asDb(db), ORG, SCHOOL, {
    collectionId: COLLECTION_ID,
    refundAmount: 5000,
    refundReason: "Full refund",
    requestedBy: USER,
  });
  await approveRefund(asDb(db), ORG, SCHOOL, created.id, CHECKER);
  assertEquals(db.collections[0]!.collection_status, "refunded");
});

Deno.test("rejectRefund sets rejected without balance changes", async () => {
  const db = new MockRefundsDb();
  const created = await createRefund(asDb(db), ORG, SCHOOL, {
    collectionId: COLLECTION_ID,
    refundAmount: 1000,
    refundReason: "Cancel request",
    requestedBy: USER,
  });
  const beforeOutstanding = db.invoices[0]!.outstanding_amount;
  const rejected = await rejectRefund(asDb(db), ORG, SCHOOL, created.id);
  assertEquals(rejected.refund_status, "rejected");
  assertEquals(db.invoices[0]!.outstanding_amount, beforeOutstanding);
});

Deno.test("approveRefund rejects non-pending refund", async () => {
  const db = new MockRefundsDb();
  const created = await createRefund(asDb(db), ORG, SCHOOL, {
    collectionId: COLLECTION_ID,
    refundAmount: 1000,
    refundReason: "Test",
    requestedBy: USER,
  });
  await rejectRefund(asDb(db), ORG, SCHOOL, created.id);
  await assertRejects(
    () => approveRefund(asDb(db), ORG, SCHOOL, created.id, USER),
    InvalidRefundTransitionError,
  );
});

Deno.test("approveRefund rejects self-approval by the requester", async () => {
  const db = new MockRefundsDb();
  const created = await createRefund(asDb(db), ORG, SCHOOL, {
    collectionId: COLLECTION_ID,
    refundAmount: 1000,
    refundReason: "Self approval attempt",
    requestedBy: USER,
  });
  // Approver id equals the requester id -> must be blocked, before mutation.
  await assertRejects(
    () => approveRefund(asDb(db), ORG, SCHOOL, created.id, USER),
    RefundSelfApprovalError,
  );
  // No state mutation occurred: refund still pending, balances untouched.
  assertEquals(db.refunds[0]!.refund_status, "pending");
  assertEquals(db.invoices[0]!.outstanding_amount, "45000");
});

Deno.test("approveRefund succeeds when approver differs from requester", async () => {
  const db = new MockRefundsDb();
  const created = await createRefund(asDb(db), ORG, SCHOOL, {
    collectionId: COLLECTION_ID,
    refundAmount: 1000,
    refundReason: "Maker-checker approval",
    requestedBy: USER,
  });
  const approved = await approveRefund(asDb(db), ORG, SCHOOL, created.id, CHECKER);
  assertEquals(approved.refund_status, "processed");
  assertEquals(approved.approved_by, CHECKER);
});

Deno.test("listRefunds returns paginated items", async () => {
  const db = new MockRefundsDb();
  await createRefund(asDb(db), ORG, SCHOOL, {
    collectionId: COLLECTION_ID,
    refundAmount: 500,
    refundReason: "One",
    requestedBy: USER,
  });
  const result = await listRefunds(asDb(db), ORG, SCHOOL, { page: 1, pageSize: 20 });
  assertEquals(result.items.length, 1);
  assertEquals(result.total, 1);
});

Deno.test("getRefund returns null for missing id", async () => {
  const db = new MockRefundsDb();
  const refund = await getRefund(asDb(db), ORG, SCHOOL, "missing");
  assertEquals(refund, null);
});

Deno.test("viewFinance required for finance read scope", () => {
  assertEquals(requirePermission(schoolClaims([]), "viewFinance")?.status, 403);
  assertEquals(requirePermission(schoolClaims(["viewFinance"]), "viewFinance"), null);
});

Deno.test("manageFinance required for refund creation", () => {
  assertEquals(requirePermission(schoolClaims(["viewFinance"]), "manageFinance")?.status, 403);
  assertEquals(
    requirePermission(schoolClaims(["viewFinance", "manageFinance"]), "manageFinance"),
    null,
  );
});

Deno.test("approveRefunds required for refund approval", () => {
  assertEquals(requirePermission(schoolClaims(["manageFinance"]), "approveRefunds")?.status, 403);
  assertEquals(
    requirePermission(schoolClaims(["approveRefunds"]), "approveRefunds"),
    null,
  );
});

Deno.test("organization scope denied at middleware for finance operations", () => {
  const orgClaims: AccessTokenClaims = {
    ...schoolClaims(["viewFinance", "manageFinance", "approveRefunds"]),
    scope: "organization",
    school_id: null,
  };
  assertEquals(requireSchoolOperationalScope(orgClaims)?.status, 403);
});
