// PRA-P1-10 (S1) — proves that APPROVING a discount rule / scholarship FOR A
// STUDENT actually reduces the payable, and only through the certified
// fee-reduction maker-checker (finance_fee_reductions), never a parallel path.
//
// It proves, without a live DB (MockDb interprets the exact SQL the repos issue,
// mirroring finance_fee_reductions_repository_test), that:
//   * applyDiscountRuleToInvoice / awardScholarshipToInvoice emit a PENDING
//     fee-reduction bound to the source, with the amount taken from the RULE /
//     scholarship (authoritative) — and touch NO money by themselves;
//   * a rule that is not governance-approved (pending) cannot be applied;
//   * a scholarship whose max_discount carries no machine amount is rejected;
//   * the EMITTED reduction is genuinely guarded: the proposer cannot approve
//     their own reduction (SoD), while a DIFFERENT approver's approval reduces
//     the invoice + account payable in lockstep.

import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  applyDiscountRuleToInvoice,
  DiscountRuleNotApplicableError,
  DiscountRuleNotFoundError,
} from "./finance_discounts_repository.ts";
import {
  awardScholarshipToInvoice,
  parseMaxDiscount,
  ScholarshipNotApplicableError,
} from "./finance_scholarships_repository.ts";
import {
  approveFeeReduction,
  FeeReductionSelfApprovalError,
} from "./finance_fee_reductions_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const MAKER = "d1000000-0000-4000-8000-000000000001";
const CHECKER = "d1000000-0000-4000-8000-000000000002";
const REDUCTION = "fr000000-0000-4000-8000-000000000001";
const RULE = "dr000000-0000-4000-8000-000000000001";
const SCH = "sc000000-0000-4000-8000-000000000001";
const INVOICE = "inv-1";
const ACCOUNT = "acct-1";
const STUDENT = "stu-1";

type Row = Record<string, unknown>;

function num(v: unknown): number {
  const n = typeof v === "number" ? v : parseFloat(String(v));
  return Number.isFinite(n) ? n : 0;
}

interface MockOpts {
  rule?: Row | null;
  scholarship?: Row | null;
  invoice: Row;
  account: Row;
  heads?: Row[];
}

/**
 * Interprets the exact SQL the repositories issue and mutates in-memory rows, so
 * the tests exercise the real binding + money math + guards end to end.
 */
class MockDb {
  rule: Row | null;
  scholarship: Row | null;
  invoice: Row;
  account: Row;
  heads: Row[];
  reduction: Row | null = null;
  inserted: Row | null = null;
  invoiceUpdates: unknown[][] = [];
  accountUpdates: unknown[][] = [];

  constructor(o: MockOpts) {
    this.rule = o.rule ?? null;
    this.scholarship = o.scholarship ?? null;
    this.invoice = o.invoice;
    this.account = o.account;
    this.heads = o.heads ?? [];
  }

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    // getDiscountRule — full row (checked BEFORE the `SELECT id` existence probe).
    if (sql.includes("SELECT * FROM finance_discount_rules")) {
      if (!this.rule || this.rule.id !== args[0]) return [] as T[];
      return [{ ...this.rule }] as T[];
    }
    // getScholarship — full row (checked BEFORE the `SELECT id` existence probe).
    if (sql.includes("SELECT * FROM finance_scholarships")) {
      if (!this.scholarship || this.scholarship.id !== args[0]) return [] as T[];
      return [{ ...this.scholarship }] as T[];
    }
    // Load + lock the reduction row (approve step).
    if (sql.includes("SELECT * FROM finance_fee_reductions") && sql.includes("FOR UPDATE")) {
      if (!this.reduction || this.reduction.id !== args[0]) return [] as T[];
      return [{ ...this.reduction }] as T[];
    }
    // Load + lock invoice + account.
    if (sql.includes("FROM finance_invoices fi") && sql.includes("FOR UPDATE OF fi")) {
      if (this.invoice.id !== args[0]) return [] as T[];
      return [{ ...this.invoice, student_account_id: this.account.id }] as T[];
    }
    // proposeFeeReduction source existence probes (`SELECT id FROM ...`).
    if (sql.includes("FROM finance_scholarships")) {
      return (this.scholarship ? [{ id: args[0] }] : []) as T[];
    }
    if (sql.includes("FROM finance_discount_rules")) {
      return (this.rule ? [{ id: args[0] }] : []) as T[];
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
      // Make the emitted reduction loadable by the approve step.
      this.reduction = { ...this.inserted };
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
    // Reduction status flip → approved (guarded on pending).
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

function ruleRow(overrides: Row = {}): Row {
  return {
    id: RULE,
    organization_id: ORG,
    school_id: SCHOOL,
    name: "Sibling discount",
    discount_percent: "25",
    applies_to: "all",
    status: "approved",
    created_by: MAKER,
    ...overrides,
  };
}

function scholarshipRow(overrides: Row = {}): Row {
  return {
    id: SCH,
    organization_id: ORG,
    school_id: SCHOOL,
    name: "Merit scholarship",
    type: "merit",
    max_discount: "5000",
    eligibility: "Top 3 rank",
    active_assignments: 0,
    status: "active",
    created_by: MAKER,
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

// ─── parseMaxDiscount: authoritative amount from free text ───────────────────

Deno.test("parseMaxDiscount: percent, fixed, and unusable inputs", () => {
  assertEquals(parseMaxDiscount("25%"), { reductionKind: "percent", percent: 25 });
  assertEquals(parseMaxDiscount("12.5 %"), { reductionKind: "percent", percent: 12.5 });
  assertEquals(parseMaxDiscount("5000"), { reductionKind: "fixed", fixedAmount: 5000 });
  assertEquals(parseMaxDiscount("₹5,000"), { reductionKind: "fixed", fixedAmount: 5000 });
  // Unusable → null (must not silently mis-reduce a payable).
  assertEquals(parseMaxDiscount(""), null);
  assertEquals(parseMaxDiscount("Full tuition"), null);
  assertEquals(parseMaxDiscount("150%"), null); // percent out of range
  assertEquals(parseMaxDiscount("0"), null);
});

// ─── Discount rule → guarded fee-reduction ───────────────────────────────────

Deno.test("applyDiscountRuleToInvoice: emits a PENDING reduction bound to the rule, percent FROM the rule, no money moved", async () => {
  const db = new MockDb({
    rule: ruleRow({ discount_percent: "25" }),
    invoice: invoiceRow(),
    account: accountRow(),
    heads: [oneHead()],
  });

  const row = await applyDiscountRuleToInvoice(client(db), ORG, SCHOOL, {
    ruleId: RULE,
    invoiceId: INVOICE,
    createdBy: MAKER,
  });

  assertEquals(row.status, "pending");
  assertEquals(row.source_kind, "discount");
  assertEquals(row.discount_rule_id, RULE);
  assertEquals(row.scholarship_id, null);
  assertEquals(row.reduction_kind, "percent");
  assertEquals(num(row.percent), 25); // taken from the RULE, not the client
  assertEquals(num(row.applied_amount), 0);
  assertEquals(row.student_id, STUDENT); // resolved from the invoice
  assertEquals(row.created_by, MAKER);
  // Proposing changes NO money.
  assertEquals(db.invoiceUpdates.length, 0);
  assertEquals(db.accountUpdates.length, 0);
});

Deno.test("applyDiscountRuleToInvoice: a NON-approved (pending) rule cannot reduce a payable", async () => {
  const db = new MockDb({
    rule: ruleRow({ status: "pending" }),
    invoice: invoiceRow(),
    account: accountRow(),
  });
  await assertRejects(
    () =>
      applyDiscountRuleToInvoice(client(db), ORG, SCHOOL, {
        ruleId: RULE,
        invoiceId: INVOICE,
        createdBy: MAKER,
      }),
    DiscountRuleNotApplicableError,
  );
  assertEquals(db.inserted, null); // nothing emitted
});

Deno.test("applyDiscountRuleToInvoice: an unknown rule 404s (not-found), emits nothing", async () => {
  const db = new MockDb({ rule: null, invoice: invoiceRow(), account: accountRow() });
  await assertRejects(
    () =>
      applyDiscountRuleToInvoice(client(db), ORG, SCHOOL, {
        ruleId: RULE,
        invoiceId: INVOICE,
        createdBy: MAKER,
      }),
    DiscountRuleNotFoundError,
  );
  assertEquals(db.inserted, null);
});

// ─── Scholarship → guarded fee-reduction ─────────────────────────────────────

Deno.test("awardScholarshipToInvoice: fixed max_discount → PENDING fixed reduction bound to the scholarship", async () => {
  const db = new MockDb({
    scholarship: scholarshipRow({ max_discount: "5000" }),
    invoice: invoiceRow(),
    account: accountRow(),
    heads: [oneHead()],
  });

  const row = await awardScholarshipToInvoice(client(db), ORG, SCHOOL, {
    scholarshipId: SCH,
    invoiceId: INVOICE,
    createdBy: MAKER,
  });

  assertEquals(row.status, "pending");
  assertEquals(row.source_kind, "scholarship");
  assertEquals(row.scholarship_id, SCH);
  assertEquals(row.discount_rule_id, null);
  assertEquals(row.reduction_kind, "fixed");
  assertEquals(num(row.fixed_amount), 5000);
  assertEquals(db.invoiceUpdates.length, 0);
  assertEquals(db.accountUpdates.length, 0);
});

Deno.test("awardScholarshipToInvoice: percent max_discount → PENDING percent reduction", async () => {
  const db = new MockDb({
    scholarship: scholarshipRow({ max_discount: "20%" }),
    invoice: invoiceRow(),
    account: accountRow(),
    heads: [oneHead()],
  });

  const row = await awardScholarshipToInvoice(client(db), ORG, SCHOOL, {
    scholarshipId: SCH,
    invoiceId: INVOICE,
    createdBy: MAKER,
  });

  assertEquals(row.reduction_kind, "percent");
  assertEquals(num(row.percent), 20);
});

Deno.test("awardScholarshipToInvoice: unusable free-text max_discount is rejected — no silent mis-reduction", async () => {
  const db = new MockDb({
    scholarship: scholarshipRow({ max_discount: "Full tuition" }),
    invoice: invoiceRow(),
    account: accountRow(),
  });
  await assertRejects(
    () =>
      awardScholarshipToInvoice(client(db), ORG, SCHOOL, {
        scholarshipId: SCH,
        invoiceId: INVOICE,
        createdBy: MAKER,
      }),
    ScholarshipNotApplicableError,
  );
  assertEquals(db.inserted, null);
});

// ─── The emitted reduction is genuinely maker-checked ────────────────────────

Deno.test("emitted reduction: the PROPOSER cannot approve their own reduction (SoD, self-approval blocked)", async () => {
  const db = new MockDb({
    rule: ruleRow({ discount_percent: "25" }),
    invoice: invoiceRow(),
    account: accountRow(),
    heads: [oneHead()],
  });

  // MAKER applies the rule → pending reduction.
  const proposed = await applyDiscountRuleToInvoice(client(db), ORG, SCHOOL, {
    ruleId: RULE,
    invoiceId: INVOICE,
    createdBy: MAKER,
  });

  // The same MAKER tries to approve it → blocked before any money moves.
  await assertRejects(
    () => approveFeeReduction(client(db), ORG, SCHOOL, proposed.id, MAKER),
    FeeReductionSelfApprovalError,
  );
  assertEquals(num(db.invoice.outstanding_amount), 50000);
  assertEquals(num(db.account.outstanding_amount), 50000);
  assertEquals(db.invoiceUpdates.length, 0);
  assertEquals(db.accountUpdates.length, 0);
});

Deno.test("emitted reduction: a DIFFERENT approver's approval reduces the invoice + account payable in lockstep (25% of 50000)", async () => {
  const db = new MockDb({
    rule: ruleRow({ discount_percent: "25" }),
    invoice: invoiceRow(),
    account: accountRow(),
    heads: [oneHead()],
  });

  const proposed = await applyDiscountRuleToInvoice(client(db), ORG, SCHOOL, {
    ruleId: RULE,
    invoiceId: INVOICE,
    createdBy: MAKER,
  });

  const approved = await approveFeeReduction(client(db), ORG, SCHOOL, proposed.id, CHECKER);

  assertEquals(approved.status, "approved");
  assertEquals(num(approved.applied_amount), 12500); // 25% of 50000
  // Invoice + account reduced by the SAME delta, in lockstep.
  assertEquals(num(db.invoice.outstanding_amount), 37500);
  assertEquals(num(db.invoice.total_amount), 37500);
  assertEquals(num(db.invoice.discount_amount), 12500);
  assertEquals(num(db.account.outstanding_amount), 37500);
  assertEquals(num(db.account.total_fee), 37500);
  assertEquals(num(db.accountUpdates[0]![0]), 12500);
  // Head ledger stays reconciled with the reduced invoice total.
  assertEquals(num(db.heads[0]!.head_total_minor), 37500);
});
