import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { invoiceToApi } from "./finance_mapper.ts";
import {
  DuplicateInvoiceError,
  InvalidInvoiceTransitionError,
  InvoiceNotFoundError,
  cancelInvoice,
  createAnnualInvoice,
  getInvoice,
  issueInvoice,
  listInvoices,
} from "./finance_invoices_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const STAFF = "a3000000-0000-4000-8000-000000000001";
const STUDENT = "a4000000-0000-4000-8000-000000000001";
const ASSIGNMENT = "b8000000-0000-4000-8000-000000000001";

type Row = Record<string, unknown>;

class MockInvoicesDb {
  invoices: Row[] = [];
  /** finance_student_accounts — the STORED aggregate cancelInvoice must keep in lockstep. */
  accounts: Row[] = [];
  /**
   * Models the TOCTOU window: when set, the pre-check SELECT returns this stale
   * status while the stored row has already moved on (a concurrent winner). Lets
   * the loser reach the status-guarded UPDATE, which is the only path that proves
   * the guard — the pre-check alone would mask it.
   */
  staleReadStatus: string | null = null;

  async queryCount(sql: string, args: unknown[] = []): Promise<number> {
    if (sql.includes("FROM finance_invoices")) {
      return this.invoices.filter((i) =>
        i.organization_id === args[0] && i.school_id === args[1]
      ).length;
    }
    return 0;
  }

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("SELECT id FROM finance_invoices") && sql.includes("fee_assignment_id = $1")) {
      const found = this.invoices.find((i) =>
        i.fee_assignment_id === args[0] &&
        i.organization_id === args[1] &&
        i.school_id === args[2]
      );
      return (found ? [{ id: found.id }] : []) as T[];
    }
    if (sql.includes("INSERT INTO finance_invoices")) {
      const row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        school_id: args[1],
        student_id: args[2],
        fee_assignment_id: args[3],
        academic_year: args[4],
        invoice_number: args[5],
        invoice_date: args[6],
        due_date: args[7],
        subtotal_amount: String(args[8]),
        discount_amount: "0",
        total_amount: String(args[8]),
        outstanding_amount: String(args[8]),
        invoice_status: "issued",
        created_by: args[9],
        created_at: "2026-06-12T00:00:00.000Z",
        updated_at: "2026-06-12T00:00:00.000Z",
      };
      this.invoices.push(row);
      return [row as T];
    }
    if (sql.includes("SELECT * FROM finance_invoices") && sql.includes("WHERE id = $1")) {
      const found = this.invoices.find((i) =>
        i.id === args[0] && i.organization_id === args[1] && i.school_id === args[2]
      );
      if (!found) return [] as T[];
      if (this.staleReadStatus !== null) {
        return [{ ...found, invoice_status: this.staleReadStatus }] as T[];
      }
      return [found] as T[];
    }
    if (sql.includes("SELECT * FROM finance_invoices") && sql.includes("ORDER BY invoice_date")) {
      const filtered = this.invoices.filter((i) =>
        i.organization_id === args[0] && i.school_id === args[1]
      );
      return filtered as T[];
    }
    if (sql.includes("UPDATE finance_invoices") && sql.includes("invoice_status = 'issued'")) {
      const row = this.invoices.find((i) => i.id === args[0]);
      if (!row) return [] as T[];
      row.invoice_status = "issued";
      return [row as T];
    }
    if (sql.includes("UPDATE finance_invoices") && sql.includes("invoice_status = 'cancelled'")) {
      const row = this.invoices.find((i) => i.id === args[0]);
      if (!row) return [] as T[];
      // Model the status guard: `AND invoice_status NOT IN ('paid','cancelled')`.
      // A terminal row matches 0 rows, so the caller must throw rather than
      // release the account delta a second time.
      if (row.invoice_status === "paid" || row.invoice_status === "cancelled") {
        return [] as T[];
      }
      row.invoice_status = "cancelled";
      return [row as T];
    }
    if (sql.includes("UPDATE finance_student_accounts")) {
      // args: [released, student_id, academic_year, organization_id, school_id]
      const released = parseFloat(String(args[0]));
      const account = this.accounts.find((a) =>
        a.student_id === args[1] && a.academic_year === args[2] &&
        a.organization_id === args[3] && a.school_id === args[4]
      );
      if (!account) return [] as T[];
      const drop = (value: unknown) =>
        Math.max(0, parseFloat(String(value)) - released).toFixed(2);
      account.total_fee = drop(account.total_fee);
      account.outstanding_amount = drop(account.outstanding_amount);
      return [account as T];
    }
    return [] as T[];
  }
}

function asDb(mock: MockInvoicesDb): TenantQueryClient {
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

Deno.test("createAnnualInvoice creates issued invoice with totals", async () => {
  const db = new MockInvoicesDb();
  const invoice = await createAnnualInvoice(asDb(db), ORG, SCHOOL_A, {
    studentId: STUDENT,
    feeAssignmentId: ASSIGNMENT,
    academicYear: "2026-27",
    totalAmount: 50000,
    createdBy: STAFF,
  });
  assertEquals(invoice.invoice_status, "issued");
  assertEquals(invoice.total_amount, "50000");
  assertEquals(invoice.outstanding_amount, "50000");
  assertEquals(invoice.subtotal_amount, "50000");
  assertEquals(invoice.discount_amount, "0");
  assertEquals(db.invoices.length, 1);
});

Deno.test("createAnnualInvoice prevents duplicate per assignment", async () => {
  const db = new MockInvoicesDb();
  const input = {
    studentId: STUDENT,
    feeAssignmentId: ASSIGNMENT,
    academicYear: "2026-27",
    totalAmount: 50000,
    createdBy: STAFF,
  };
  await createAnnualInvoice(asDb(db), ORG, SCHOOL_A, input);
  await assertRejects(
    () => createAnnualInvoice(asDb(db), ORG, SCHOOL_A, input),
    DuplicateInvoiceError,
  );
});

Deno.test("issueInvoice transitions draft to issued", async () => {
  const db = new MockInvoicesDb();
  db.invoices.push({
    id: "inv-1",
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_id: STUDENT,
    fee_assignment_id: ASSIGNMENT,
    academic_year: "2026-27",
    invoice_number: "INV-2026-TEST",
    invoice_date: "2026-06-01",
    due_date: "2026-07-01",
    subtotal_amount: "1000",
    discount_amount: "0",
    total_amount: "1000",
    outstanding_amount: "1000",
    invoice_status: "draft",
    created_by: STAFF,
    created_at: "2026-06-12T00:00:00.000Z",
    updated_at: "2026-06-12T00:00:00.000Z",
  });
  const issued = await issueInvoice(asDb(db), ORG, SCHOOL_A, "inv-1");
  assertEquals(issued.invoice_status, "issued");
});

Deno.test("issueInvoice rejects non-draft status", async () => {
  const db = new MockInvoicesDb();
  db.invoices.push({
    id: "inv-2",
    organization_id: ORG,
    school_id: SCHOOL_A,
    invoice_status: "issued",
  });
  await assertRejects(
    () => issueInvoice(asDb(db), ORG, SCHOOL_A, "inv-2"),
    InvalidInvoiceTransitionError,
  );
});

Deno.test("cancelInvoice marks issued invoice cancelled", async () => {
  const db = new MockInvoicesDb();
  db.invoices.push({
    id: "inv-3",
    organization_id: ORG,
    school_id: SCHOOL_A,
    invoice_status: "issued",
  });
  const cancelled = await cancelInvoice(asDb(db), ORG, SCHOOL_A, "inv-3");
  assertEquals(cancelled.invoice_status, "cancelled");
});

Deno.test("cancelInvoice rejects paid invoice", async () => {
  const db = new MockInvoicesDb();
  db.invoices.push({
    id: "inv-4",
    organization_id: ORG,
    school_id: SCHOOL_A,
    invoice_status: "paid",
  });
  await assertRejects(
    () => cancelInvoice(asDb(db), ORG, SCHOOL_A, "inv-4"),
    InvalidInvoiceTransitionError,
  );
});

Deno.test("PRC-A: cancelInvoice releases the unpaid remainder from the student account (lockstep)", async () => {
  const db = new MockInvoicesDb();
  // 50,000 billed, 30,000 already collected → 20,000 still owed.
  db.invoices.push({
    id: "inv-lockstep",
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_id: STUDENT,
    academic_year: "2026-27",
    total_amount: "50000",
    outstanding_amount: "20000",
    invoice_status: "partially_paid",
  });
  db.accounts.push({
    id: "acct-lockstep",
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_id: STUDENT,
    academic_year: "2026-27",
    total_fee: "50000",
    amount_paid: "30000",
    outstanding_amount: "20000",
  });

  await cancelInvoice(asDb(db), ORG, SCHOOL_A, "inv-lockstep");

  const account = db.accounts[0]!;
  // Only the STILL-UNPAID 20,000 is released. Before this fix the account kept
  // owing it: a false defaulter, and a blocked no-dues/TC gate.
  assertEquals(account.outstanding_amount, "0.00");
  assertEquals(account.total_fee, "30000.00");
  // The real 30,000 payment is untouched, so outstanding == total_fee - amount_paid.
  assertEquals(account.amount_paid, "30000");
});

Deno.test("PRC-A: the loser of a concurrent double-cancel throws and never releases the account twice", async () => {
  const db = new MockInvoicesDb();
  // A concurrent winner already cancelled the invoice and released the account.
  db.invoices.push({
    id: "inv-race",
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_id: STUDENT,
    academic_year: "2026-27",
    total_amount: "10000",
    outstanding_amount: "10000",
    invoice_status: "cancelled",
  });
  db.accounts.push({
    id: "acct-race",
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_id: STUDENT,
    academic_year: "2026-27",
    total_fee: "0.00",
    amount_paid: "0",
    outstanding_amount: "0.00",
  });
  // ...but this transaction's pre-check read still sees the stale pre-cancel status,
  // so it proceeds to the guarded terminal write.
  db.staleReadStatus = "issued";

  await assertRejects(
    () => cancelInvoice(asDb(db), ORG, SCHOOL_A, "inv-race"),
    InvalidInvoiceTransitionError,
  );

  // The guard matched 0 rows → the release below it never ran a second time.
  assertEquals(db.accounts[0]!.outstanding_amount, "0.00");
  assertEquals(db.accounts[0]!.total_fee, "0.00");
});

Deno.test("getInvoice returns null when missing", async () => {
  const db = new MockInvoicesDb();
  const invoice = await getInvoice(asDb(db), ORG, SCHOOL_A, "missing");
  assertEquals(invoice, null);
});

Deno.test("getInvoice throws not found for issue on missing id", async () => {
  const db = new MockInvoicesDb();
  await assertRejects(
    () => issueInvoice(asDb(db), ORG, SCHOOL_A, "missing"),
    InvoiceNotFoundError,
  );
});

Deno.test("listInvoices returns paginated items", async () => {
  const db = new MockInvoicesDb();
  await createAnnualInvoice(asDb(db), ORG, SCHOOL_A, {
    studentId: STUDENT,
    feeAssignmentId: ASSIGNMENT,
    academicYear: "2026-27",
    totalAmount: 50000,
    createdBy: STAFF,
  });
  const page = await listInvoices(asDb(db), ORG, SCHOOL_A, { page: 1, pageSize: 20 });
  assertEquals(page.items.length, 1);
  assertEquals(page.total, 1);
});

Deno.test("invoiceToApi maps client-compatible fields", () => {
  const api = invoiceToApi({
    id: "inv-5",
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_id: STUDENT,
    fee_assignment_id: ASSIGNMENT,
    academic_year: "2026-27",
    invoice_number: "INV-2026-ABC",
    invoice_date: "2026-06-07",
    due_date: "2026-07-07",
    subtotal_amount: "50000",
    discount_amount: "0",
    total_amount: "50000",
    outstanding_amount: "30000",
    invoice_status: "partially_paid",
    late_fee_amount: "0",
    late_fee_accrued_at: null,
    created_by: STAFF,
    created_at: "2026-06-07T00:00:00.000Z",
    updated_at: "2026-06-07T00:00:00.000Z",
  });
  assertEquals(api.invoiceNumber, "INV-2026-ABC");
  assertEquals(api.paidAmount, "20000");
  assertEquals(api.termLabel, "Annual");
  assertEquals(api.invoiceStatus, "partially_paid");
});

Deno.test("viewFinance required for invoice reads", () => {
  assertEquals(requirePermission(schoolClaims([]), "viewFinance")?.status, 403);
  assertEquals(requirePermission(schoolClaims(["viewFinance"]), "viewFinance"), null);
});

Deno.test("manageFinance required for invoice writes", () => {
  assertEquals(requirePermission(schoolClaims(["viewFinance"]), "manageFinance")?.status, 403);
  assertEquals(
    requirePermission(schoolClaims(["viewFinance", "manageFinance"]), "manageFinance"),
    null,
  );
});

Deno.test("non-school scopes denied for finance invoices", () => {
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
