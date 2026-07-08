// FIX 2 (P1-PROD gap sweep) — `waiveLateFee` must reverse the SAME delta on
// the invoice AND the student account. Previously the invoice was floored
// (`Math.max(0, outstanding - lateFee)`) while the account subtracted the
// FULL `lateFee` unconditionally — if a payment landed between accrual and
// waive, the invoice forgave only what was left owed, but the account was
// over-reduced by the difference, permanently understating the family's
// aggregate dues.

import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { NoLateFeeError, waiveLateFee } from "./finance_late_fee_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const INVOICE = "inv-1";
const ACCOUNT = "acct-1";

type Row = Record<string, unknown>;

class MockLateFeeDb {
  invoice: Row;
  account: Row;
  accountUpdateArgs: unknown[] | null = null;

  constructor(invoice: Row, account: Row) {
    this.invoice = invoice;
    this.account = account;
  }

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("FROM finance_invoices fi") && sql.includes("FOR UPDATE OF fi")) {
      if (this.invoice.id !== args[0]) return [] as T[];
      return [{ ...this.invoice, student_account_id: this.account.id }] as T[];
    }
    if (sql.includes("UPDATE finance_invoices SET") && sql.includes("late_fee_amount = 0")) {
      this.invoice = {
        ...this.invoice,
        late_fee_amount: "0",
        late_fee_accrued_at: null,
        outstanding_amount: String(args[0]),
      };
      return [this.invoice] as T[];
    }
    if (
      sql.includes("UPDATE finance_student_accounts SET") &&
      sql.includes("GREATEST(0, outstanding_amount - $1)")
    ) {
      this.accountUpdateArgs = args;
      const before = Number(this.account.outstanding_amount);
      const delta = Number(args[0]);
      this.account = {
        ...this.account,
        outstanding_amount: String(Math.max(0, before - delta)),
      };
      return [] as T[];
    }
    throw new Error(`Unexpected query in MockLateFeeDb: ${sql}`);
  }
}

function mockClient(db: MockLateFeeDb): TenantQueryClient {
  return db as unknown as TenantQueryClient;
}

Deno.test("FIX 2: no intervening payment — full late fee reversed in lockstep on invoice + account", async () => {
  const invoice: Row = {
    id: INVOICE,
    organization_id: ORG,
    school_id: SCHOOL,
    total_amount: "100",
    outstanding_amount: "120", // 100 base + 20 accrued late fee, nothing paid
    late_fee_amount: "20",
  };
  const account: Row = { id: ACCOUNT, outstanding_amount: "120" };
  const db = new MockLateFeeDb(invoice, account);

  const result = await waiveLateFee(mockClient(db), ORG, SCHOOL, INVOICE);

  assertEquals(result.waivedAmount, 20);
  assertEquals(db.invoice.outstanding_amount, "100");
  assertEquals(db.account.outstanding_amount, "100");
  // Invoice delta (120 -> 100 = 20) equals the account delta (120 -> 100 = 20).
  assertEquals(db.accountUpdateArgs?.[0], "20");
});

Deno.test("FIX 2: accrue ₹20 → pay ₹110 (past the fee) → waive only forgives the still-outstanding portion, on BOTH sides", async () => {
  // total 100, late fee 20 accrued (outstanding 100 -> 120), then a 110
  // payment lands (outstanding 120 -> 10) BEFORE the waive — the payment
  // covers the entire late fee plus 90 of the base amount.
  const invoice: Row = {
    id: INVOICE,
    organization_id: ORG,
    school_id: SCHOOL,
    total_amount: "100",
    outstanding_amount: "10",
    late_fee_amount: "20",
  };
  const account: Row = { id: ACCOUNT, outstanding_amount: "10" };
  const db = new MockLateFeeDb(invoice, account);

  const result = await waiveLateFee(mockClient(db), ORG, SCHOOL, INVOICE);

  // Only the ₹10 still genuinely outstanding is forgiven — NOT the full ₹20
  // accrued fee (the other ₹10 was already effectively covered by the
  // payment).
  const invoiceDelta = 10 - Number(db.invoice.outstanding_amount);
  const accountDelta = 10 - Number(db.account.outstanding_amount);
  assertEquals(invoiceDelta, 10);
  assertEquals(accountDelta, 10);
  assertEquals(invoiceDelta, accountDelta);
  assertEquals(result.waivedAmount, 10);

  assertEquals(db.invoice.outstanding_amount, "0");
  assertEquals(db.account.outstanding_amount, "0");
  // The account update must have used the CAPPED delta (10), not the raw
  // accrued late fee (20) — this is the regression this fix closes.
  assertEquals(db.accountUpdateArgs?.[0], "10");
});

Deno.test("FIX 2: fully paid before waive (outstanding already 0) — nothing left to forgive on either side", async () => {
  const invoice: Row = {
    id: INVOICE,
    organization_id: ORG,
    school_id: SCHOOL,
    total_amount: "100",
    outstanding_amount: "0",
    late_fee_amount: "20",
  };
  const account: Row = { id: ACCOUNT, outstanding_amount: "0" };
  const db = new MockLateFeeDb(invoice, account);

  const result = await waiveLateFee(mockClient(db), ORG, SCHOOL, INVOICE);

  assertEquals(result.waivedAmount, 0);
  assertEquals(db.invoice.outstanding_amount, "0");
  assertEquals(db.account.outstanding_amount, "0");
  assertEquals(db.accountUpdateArgs?.[0], "0");
});

Deno.test("FIX 2: no accrued late fee — waiveLateFee still rejects (unchanged behaviour)", async () => {
  const invoice: Row = {
    id: INVOICE,
    organization_id: ORG,
    school_id: SCHOOL,
    total_amount: "100",
    outstanding_amount: "100",
    late_fee_amount: "0",
  };
  const account: Row = { id: ACCOUNT, outstanding_amount: "100" };
  const db = new MockLateFeeDb(invoice, account);

  await assertRejects(
    () => waiveLateFee(mockClient(db), ORG, SCHOOL, INVOICE),
    NoLateFeeError,
  );
});
