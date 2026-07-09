// STEP-5 money-path tests for fee reductions (scholarships + discounts).
//
// Proves, without a live DB (MockDb mirrors the finance test harness), that a
// reduction:
//   * reduces the payable by the EXACT amount/percent, and ONLY on approval;
//   * keeps invoice.outstanding ↔ account.outstanding in LOCKSTEP (same delta);
//   * blocks self-approval (SoD, maker != checker);
//   * is idempotent (approving/reversing twice never double-applies);
//   * reverses the EXACT applied amount in lockstep;
//   * never drives the payable (or the invoice total) negative — clamped;
//   * keeps the derived head ledger reconciled (SUM(head_total) == invoice total).

import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  approveFeeReduction,
  clampApplied,
  computeIntendedReduction,
  FeeReductionInvalidStateError,
  FeeReductionSelfApprovalError,
  proposeFeeReduction,
  rejectFeeReduction,
  reverseFeeReduction,
} from "./finance_fee_reductions_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const MAKER = "d1000000-0000-4000-8000-000000000001";
const CHECKER = "d1000000-0000-4000-8000-000000000002";
const REDUCTION = "fr000000-0000-4000-8000-000000000001";
const INVOICE = "inv-1";
const ACCOUNT = "acct-1";
const STUDENT = "stu-1";

type Row = Record<string, unknown>;

function num(v: unknown): number {
  const n = typeof v === "number" ? v : parseFloat(String(v));
  return Number.isFinite(n) ? n : 0;
}

interface MockOpts {
  reduction?: Row | null;
  invoice: Row;
  account: Row;
  heads?: Row[];
  scholarshipExists?: boolean;
  discountRuleExists?: boolean;
}

/**
 * Interprets the exact SQL the repository issues and mutates in-memory rows,
 * so the tests exercise the real money math + guards end to end.
 */
class MockDb {
  reduction: Row | null;
  invoice: Row;
  account: Row;
  heads: Row[];
  scholarshipExists: boolean;
  discountRuleExists: boolean;
  inserted: Row | null = null;
  invoiceUpdates: unknown[][] = [];
  accountUpdates: unknown[][] = [];

  constructor(o: MockOpts) {
    this.reduction = o.reduction ?? null;
    this.invoice = o.invoice;
    this.account = o.account;
    this.heads = o.heads ?? [];
    this.scholarshipExists = o.scholarshipExists ?? true;
    this.discountRuleExists = o.discountRuleExists ?? true;
  }

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    // Load + lock the reduction row.
    if (sql.includes("SELECT * FROM finance_fee_reductions") && sql.includes("FOR UPDATE")) {
      if (!this.reduction || this.reduction.id !== args[0]) return [] as T[];
      return [{ ...this.reduction }] as T[];
    }
    // Load + lock invoice + account.
    if (sql.includes("FROM finance_invoices fi") && sql.includes("FOR UPDATE OF fi")) {
      if (this.invoice.id !== args[0]) return [] as T[];
      return [{ ...this.invoice, student_account_id: this.account.id }] as T[];
    }
    // Source existence probes (propose).
    if (sql.includes("FROM finance_scholarships")) {
      return (this.scholarshipExists ? [{ id: args[0] }] : []) as T[];
    }
    if (sql.includes("FROM finance_discount_rules")) {
      return (this.discountRuleExists ? [{ id: args[0] }] : []) as T[];
    }
    // Insert (propose).
    if (sql.includes("INSERT INTO finance_fee_reductions")) {
      this.inserted = {
        id: REDUCTION,
        organization_id: args[0],
        school_id: args[1],
        source_kind: args[2],
        scholarship_id: args[3],
        discount_rule_id: args[4],
        student_id: args[5],
        invoice_id: args[6],
        student_account_id: args[7],
        reduction_kind: args[8],
        percent: args[9],
        fixed_amount: args[10],
        applied_amount: "0",
        status: "pending",
        reason: args[11],
        created_by: args[12],
        approved_by: null,
        reversed_by: null,
        applied_at: null,
        reversed_at: null,
      };
      return [this.inserted] as T[];
    }
    // Invoice money update.
    if (sql.includes("UPDATE finance_invoices SET") && sql.includes("discount_amount = $1")) {
      this.invoice = {
        ...this.invoice,
        discount_amount: String(args[0]),
        total_amount: String(args[1]),
        outstanding_amount: String(args[2]),
        invoice_status: args[3],
      };
      this.invoiceUpdates.push(args);
      return [] as T[];
    }
    // Account money update — apply (reduce).
    if (
      sql.includes("UPDATE finance_student_accounts SET") &&
      sql.includes("GREATEST(0, total_fee - $1)")
    ) {
      const d = num(args[0]);
      this.account = {
        ...this.account,
        total_fee: String(Math.max(0, num(this.account.total_fee) - d)),
        outstanding_amount: String(Math.max(0, num(this.account.outstanding_amount) - d)),
      };
      this.accountUpdates.push(args);
      return [] as T[];
    }
    // Account money update — reverse (add back).
    if (
      sql.includes("UPDATE finance_student_accounts SET") &&
      sql.includes("total_fee = total_fee + $1")
    ) {
      const d = num(args[0]);
      this.account = {
        ...this.account,
        total_fee: String(num(this.account.total_fee) + d),
        outstanding_amount: String(num(this.account.outstanding_amount) + d),
      };
      this.accountUpdates.push(args);
      return [] as T[];
    }
    // Head ledger select.
    if (sql.includes("SELECT * FROM finance_invoice_head_allocations")) {
      return this.heads.map((h) => ({ ...h })) as T[];
    }
    // Head ledger total update.
    if (
      sql.includes("UPDATE finance_invoice_head_allocations") &&
      sql.includes("head_total_minor = $1")
    ) {
      const head = this.heads.find((h) => h.id === args[1]);
      if (head) head.head_total_minor = String(args[0]);
      return [] as T[];
    }
    // Reduction status flips (guarded on prior status). NB: the `reversed` /
    // `rejected` branches are matched BEFORE `approved`, because the reverse
    // UPDATE's guard (`... AND status = 'approved'`) also contains the substring
    // "status = 'approved'"; the SET verb is the real discriminator.
    if (sql.includes("UPDATE finance_fee_reductions SET") && sql.includes("status = 'reversed'")) {
      if (!this.reduction || this.reduction.status !== "approved") return [] as T[];
      this.reduction = { ...this.reduction, status: "reversed", reversed_by: args[0] };
      return [{ ...this.reduction }] as T[];
    }
    if (sql.includes("UPDATE finance_fee_reductions SET") && sql.includes("status = 'rejected'")) {
      if (!this.reduction || this.reduction.status !== "pending") return [] as T[];
      this.reduction = { ...this.reduction, status: "rejected", approved_by: args[0] };
      return [{ ...this.reduction }] as T[];
    }
    if (sql.includes("UPDATE finance_fee_reductions SET") && sql.includes("status = 'approved'")) {
      if (!this.reduction || this.reduction.status !== "pending") return [] as T[];
      this.reduction = {
        ...this.reduction,
        status: "approved",
        applied_amount: String(args[0]),
        approved_by: args[1],
        student_account_id: args[2],
        applied_at: "now",
      };
      return [{ ...this.reduction }] as T[];
    }
    throw new Error(`Unexpected SQL in MockDb: ${sql}`);
  }
}

function client(db: MockDb): TenantQueryClient {
  return db as unknown as TenantQueryClient;
}

function pendingReduction(overrides: Row = {}): Row {
  return {
    id: REDUCTION,
    organization_id: ORG,
    school_id: SCHOOL,
    source_kind: "scholarship",
    scholarship_id: "sch-1",
    discount_rule_id: null,
    student_id: STUDENT,
    invoice_id: INVOICE,
    student_account_id: ACCOUNT,
    reduction_kind: "fixed",
    percent: null,
    fixed_amount: "5000",
    applied_amount: "0",
    status: "pending",
    reason: "Merit award",
    created_by: MAKER,
    approved_by: null,
    reversed_by: null,
    applied_at: null,
    reversed_at: null,
    ...overrides,
  };
}

function invoiceRow(overrides: Row = {}): Row {
  return {
    id: INVOICE,
    organization_id: ORG,
    school_id: SCHOOL,
    student_id: STUDENT,
    fee_assignment_id: "fa-1",
    subtotal_amount: "50000",
    discount_amount: "0",
    total_amount: "50000",
    outstanding_amount: "50000",
    invoice_status: "issued",
    ...overrides,
  };
}

function accountRow(overrides: Row = {}): Row {
  return {
    id: ACCOUNT,
    total_fee: "50000",
    amount_paid: "0",
    outstanding_amount: "50000",
    ...overrides,
  };
}

function oneHead(total = "50000", paid = "0"): Row {
  return {
    id: "head-1",
    invoice_id: INVOICE,
    fee_head: "tuition:Tuition",
    head_label: "Tuition",
    head_total_minor: total,
    head_paid_minor: paid,
    priority: 0,
    sort_order: 0,
  };
}

// ─── Pure math: intended reduction + clamp ──────────────────────────────────

Deno.test("computeIntendedReduction: fixed returns the amount, percent is % of subtotal", () => {
  assertEquals(
    computeIntendedReduction({ reduction_kind: "fixed", percent: null, fixed_amount: "5000" }, 50000),
    5000,
  );
  assertEquals(
    computeIntendedReduction({ reduction_kind: "percent", percent: "10", fixed_amount: null }, 50000),
    5000,
  );
  assertEquals(
    computeIntendedReduction({ reduction_kind: "percent", percent: "12.5", fixed_amount: null }, 40000),
    5000,
  );
});

Deno.test("clampApplied: never exceeds outstanding or total, never negative", () => {
  assertEquals(clampApplied(5000, 50000, 50000), 5000);
  // fixed larger than outstanding → clamped to outstanding.
  assertEquals(clampApplied(9000, 4000, 50000), 4000);
  // clamped to total (late-fee-inflated outstanding must not push total below 0).
  assertEquals(clampApplied(1100, 1200, 1000), 1000);
  // nothing left to reduce.
  assertEquals(clampApplied(5000, 0, 50000), 0);
  assertEquals(clampApplied(-5, 50000, 50000), 0);
});

// ─── Approve applies the reduction, in lockstep, once ───────────────────────

Deno.test("approve: fixed reduction cuts the payable by the exact amount, invoice ↔ account lockstep", async () => {
  const db = new MockDb({
    reduction: pendingReduction({ fixed_amount: "5000" }),
    invoice: invoiceRow(),
    account: accountRow(),
    heads: [oneHead()],
  });

  const row = await approveFeeReduction(client(db), ORG, SCHOOL, REDUCTION, CHECKER);

  assertEquals(row.status, "approved");
  assertEquals(num(row.applied_amount), 5000);
  // Invoice: discount +5000, total & outstanding -5000.
  assertEquals(num(db.invoice.discount_amount), 5000);
  assertEquals(num(db.invoice.total_amount), 45000);
  assertEquals(num(db.invoice.outstanding_amount), 45000);
  assertEquals(db.invoice.invoice_status, "issued");
  // Account: total_fee & outstanding -5000, in lockstep with the invoice.
  assertEquals(num(db.account.total_fee), 45000);
  assertEquals(num(db.account.outstanding_amount), 45000);
  // The invoice delta and the account delta are the SAME number.
  assertEquals(num(db.accountUpdates[0]![0]), 5000);
  // Head ledger stays reconciled: SUM(head_total) == invoice total.
  assertEquals(num(db.heads[0]!.head_total_minor), 45000);
});

Deno.test("approve: percent reduction cuts percent-of-subtotal, in lockstep", async () => {
  const db = new MockDb({
    reduction: pendingReduction({ reduction_kind: "percent", percent: "20", fixed_amount: null }),
    invoice: invoiceRow(),
    account: accountRow(),
    heads: [oneHead()],
  });

  const row = await approveFeeReduction(client(db), ORG, SCHOOL, REDUCTION, CHECKER);

  assertEquals(num(row.applied_amount), 10000); // 20% of 50000
  assertEquals(num(db.invoice.outstanding_amount), 40000);
  assertEquals(num(db.account.outstanding_amount), 40000);
  assertEquals(num(db.invoice.total_amount), 40000);
  assertEquals(num(db.account.total_fee), 40000);
});

Deno.test("approve: reduction bigger than the outstanding is CLAMPED — payable floored at 0, never negative", async () => {
  // Partly paid: total 50000, paid 47000, outstanding 3000. A 5000 award may
  // only forgive the 3000 still owed.
  const db = new MockDb({
    reduction: pendingReduction({ fixed_amount: "5000" }),
    invoice: invoiceRow({ outstanding_amount: "3000" }),
    account: accountRow({ amount_paid: "47000", outstanding_amount: "3000" }),
    heads: [oneHead("50000", "47000")],
  });

  const row = await approveFeeReduction(client(db), ORG, SCHOOL, REDUCTION, CHECKER);

  assertEquals(num(row.applied_amount), 3000); // clamped to outstanding
  assertEquals(num(db.invoice.outstanding_amount), 0);
  assertEquals(num(db.account.outstanding_amount), 0);
  assertEquals(db.invoice.invoice_status, "paid");
  // total 50000 - 3000 = 47000 == amount_paid → no negative anywhere.
  assertEquals(num(db.invoice.total_amount), 47000);
  assertEquals(num(db.account.total_fee), 47000);
});

Deno.test("approve: SoD — the proposer cannot approve their OWN reduction (403 self-approval)", async () => {
  const db = new MockDb({
    reduction: pendingReduction(),
    invoice: invoiceRow(),
    account: accountRow(),
    heads: [oneHead()],
  });

  await assertRejects(
    () => approveFeeReduction(client(db), ORG, SCHOOL, REDUCTION, MAKER),
    FeeReductionSelfApprovalError,
  );
  // NOTHING moved — the guard runs before any money mutation.
  assertEquals(num(db.invoice.outstanding_amount), 50000);
  assertEquals(num(db.account.outstanding_amount), 50000);
  assertEquals(db.invoiceUpdates.length, 0);
  assertEquals(db.accountUpdates.length, 0);
});

Deno.test("approve: idempotent — approving an already-approved reduction throws and does NOT reduce twice", async () => {
  const db = new MockDb({
    reduction: pendingReduction({ fixed_amount: "5000" }),
    invoice: invoiceRow(),
    account: accountRow(),
    heads: [oneHead()],
  });

  await approveFeeReduction(client(db), ORG, SCHOOL, REDUCTION, CHECKER);
  assertEquals(num(db.invoice.outstanding_amount), 45000);

  await assertRejects(
    () => approveFeeReduction(client(db), ORG, SCHOOL, REDUCTION, CHECKER),
    FeeReductionInvalidStateError,
  );
  // Still reduced only ONCE.
  assertEquals(num(db.invoice.outstanding_amount), 45000);
  assertEquals(num(db.account.outstanding_amount), 45000);
  assertEquals(db.accountUpdates.length, 1);
});

// ─── Reject changes no money ────────────────────────────────────────────────

Deno.test("reject: no money moves; a pending reduction that is rejected reduces NOTHING", async () => {
  const db = new MockDb({
    reduction: pendingReduction(),
    invoice: invoiceRow(),
    account: accountRow(),
    heads: [oneHead()],
  });

  const row = await rejectFeeReduction(client(db), ORG, SCHOOL, REDUCTION, CHECKER);

  assertEquals(row.status, "rejected");
  assertEquals(num(db.invoice.outstanding_amount), 50000);
  assertEquals(num(db.account.outstanding_amount), 50000);
  assertEquals(db.invoiceUpdates.length, 0);
  assertEquals(db.accountUpdates.length, 0);
});

// ─── Reverse restores the exact amount, in lockstep, once ───────────────────

Deno.test("reverse: adds the EXACT applied amount back in lockstep and restores head totals", async () => {
  // Already-approved reduction of 5000 (invoice/account already reduced).
  const db = new MockDb({
    reduction: pendingReduction({ status: "approved", applied_amount: "5000", approved_by: CHECKER }),
    invoice: invoiceRow({ discount_amount: "5000", total_amount: "45000", outstanding_amount: "45000" }),
    account: accountRow({ total_fee: "45000", outstanding_amount: "45000" }),
    heads: [oneHead("45000", "0")],
  });

  const row = await reverseFeeReduction(client(db), ORG, SCHOOL, REDUCTION, CHECKER);

  assertEquals(row.status, "reversed");
  assertEquals(num(db.invoice.outstanding_amount), 50000);
  assertEquals(num(db.invoice.total_amount), 50000);
  assertEquals(num(db.invoice.discount_amount), 0);
  assertEquals(num(db.account.outstanding_amount), 50000);
  assertEquals(num(db.account.total_fee), 50000);
  assertEquals(num(db.accountUpdates[0]![0]), 5000);
  // Head total restored.
  assertEquals(num(db.heads[0]!.head_total_minor), 50000);
});

Deno.test("reverse: idempotent — reversing an already-reversed reduction throws, no double add-back", async () => {
  const db = new MockDb({
    reduction: pendingReduction({ status: "approved", applied_amount: "5000", approved_by: CHECKER }),
    invoice: invoiceRow({ discount_amount: "5000", total_amount: "45000", outstanding_amount: "45000" }),
    account: accountRow({ total_fee: "45000", outstanding_amount: "45000" }),
    heads: [oneHead("45000", "0")],
  });

  await reverseFeeReduction(client(db), ORG, SCHOOL, REDUCTION, CHECKER);
  assertEquals(num(db.invoice.outstanding_amount), 50000);

  await assertRejects(
    () => reverseFeeReduction(client(db), ORG, SCHOOL, REDUCTION, CHECKER),
    FeeReductionInvalidStateError,
  );
  assertEquals(num(db.invoice.outstanding_amount), 50000);
  assertEquals(num(db.account.outstanding_amount), 50000);
  assertEquals(db.accountUpdates.length, 1);
});

Deno.test("reverse: a pending (never-approved) reduction cannot be reversed", async () => {
  const db = new MockDb({
    reduction: pendingReduction(),
    invoice: invoiceRow(),
    account: accountRow(),
    heads: [oneHead()],
  });
  await assertRejects(
    () => reverseFeeReduction(client(db), ORG, SCHOOL, REDUCTION, CHECKER),
    FeeReductionInvalidStateError,
  );
  assertEquals(db.invoiceUpdates.length, 0);
});

// ─── Head reconciliation across multiple heads ──────────────────────────────

Deno.test("approve: multi-head — SUM(head_total) tracks the invoice total after the reduction", async () => {
  const heads: Row[] = [
    { id: "h-tuition", invoice_id: INVOICE, fee_head: "tuition:Tuition", head_label: "Tuition", head_total_minor: "30000", head_paid_minor: "0", priority: 0, sort_order: 0 },
    { id: "h-transport", invoice_id: INVOICE, fee_head: "transport:Transport", head_label: "Transport", head_total_minor: "20000", head_paid_minor: "0", priority: 1, sort_order: 1 },
  ];
  const db = new MockDb({
    reduction: pendingReduction({ fixed_amount: "8000" }),
    invoice: invoiceRow(),
    account: accountRow(),
    heads,
  });

  await approveFeeReduction(client(db), ORG, SCHOOL, REDUCTION, CHECKER);

  const sumHeads = heads.reduce((s, h) => s + num(h.head_total_minor), 0);
  assertEquals(num(db.invoice.total_amount), 42000);
  assertEquals(sumHeads, 42000); // heads reconciled to the reduced invoice total
});

// ─── Propose changes no money ───────────────────────────────────────────────

Deno.test("propose: inserts a PENDING reduction with applied_amount 0 and touches NO money", async () => {
  const db = new MockDb({
    reduction: null,
    invoice: invoiceRow(),
    account: accountRow(),
    heads: [oneHead()],
  });

  const row = await proposeFeeReduction(client(db), ORG, SCHOOL, {
    sourceKind: "scholarship",
    sourceId: "sch-1",
    invoiceId: INVOICE,
    reductionKind: "fixed",
    fixedAmount: 5000,
    reason: "Merit",
    createdBy: MAKER,
  });

  assertEquals(row.status, "pending");
  assertEquals(num(row.applied_amount), 0);
  assertEquals(row.student_id, STUDENT); // resolved from the invoice, not the client
  assertEquals(row.student_account_id, ACCOUNT);
  // No invoice/account money update happened during propose.
  assertEquals(db.invoiceUpdates.length, 0);
  assertEquals(db.accountUpdates.length, 0);
});
