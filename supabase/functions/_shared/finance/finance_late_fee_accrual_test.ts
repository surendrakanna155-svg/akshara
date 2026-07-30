// RT-11-2 — accrueLateFees set-based accrual (replaces the per-invoice FOR-UPDATE
// loop). Proves the batched delta writes produce the SAME fees + counts and update
// invoice + account outstanding by a delta, and that the `late_fee_amount = 0` guard
// prevents double-accrual.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { accrueLateFees } from "./finance_late_fee_repository.ts";

const ORG = "org-1";
const SCHOOL = "school-1";

interface Inv {
  id: string;
  fee_assignment_id: string;
  total_amount: string;
  outstanding_amount: string;
  late_fee_amount: string;
  invoice_status: string;
  student_account_id: string;
}
interface Acct {
  id: string;
  outstanding_amount: string;
}

class FakeLateFeeDb {
  accounts: Map<string, Acct>;
  constructor(public invoices: Inv[], accounts: Acct[]) {
    this.accounts = new Map(accounts.map((a) => [a.id, a]));
  }
  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    if (sql.includes("FROM finance_settings")) {
      return Promise.resolve([{
        settings: {
          "payments.grace_days": 0,
          "payments.late_fee_percent": 5,
          "payments.late_fee_flat": 0,
          "payments.late_fee_cap": 0,
        },
      }] as unknown as T[]);
    }
    // Non-locking candidates read (eligible = not yet accrued).
    if (sql.includes("SELECT fi.*") && sql.includes("student_account_id")) {
      return Promise.resolve(
        this.invoices.filter((i) => Number(i.late_fee_amount) === 0) as unknown as T[],
      );
    }
    // Set-based invoice write: DELTA + `late_fee_amount = 0` guard, RETURNING applied ids.
    if (sql.includes("UPDATE finance_invoices fi SET") && sql.includes("unnest")) {
      const ids = args[2] as string[];
      const fees = (args[3] as string[]).map(Number);
      const applied: { id: string }[] = [];
      ids.forEach((id, k) => {
        const inv = this.invoices.find((i) => i.id === id);
        if (inv && Number(inv.late_fee_amount) === 0) {
          inv.late_fee_amount = String(fees[k]);
          inv.outstanding_amount = String(Number(inv.outstanding_amount) + fees[k]);
          applied.push({ id });
        }
      });
      return Promise.resolve(applied as unknown as T[]);
    }
    // Set-based account write: DELTA per account.
    if (sql.includes("UPDATE finance_student_accounts fsa SET") && sql.includes("unnest")) {
      const ids = args[2] as string[];
      const fees = (args[3] as string[]).map(Number);
      ids.forEach((id, k) => {
        const acct = this.accounts.get(id);
        if (acct) acct.outstanding_amount = String(Number(acct.outstanding_amount) + fees[k]);
      });
      return Promise.resolve([] as T[]);
    }
    return Promise.resolve([] as T[]);
  }
}

function inv(overrides: Partial<Inv>): Inv {
  return {
    id: "inv",
    fee_assignment_id: "fa",
    total_amount: "10000",
    outstanding_amount: "10000",
    late_fee_amount: "0",
    invoice_status: "issued",
    student_account_id: "acct",
    ...overrides,
  };
}

Deno.test("RT-11-2: accrueLateFees applies the correct fee per invoice + delta per account (set-based)", async () => {
  const invoices = [
    inv({ id: "inv-1", total_amount: "10000", outstanding_amount: "4000", student_account_id: "acct-1" }),
    inv({ id: "inv-2", total_amount: "20000", outstanding_amount: "20000", student_account_id: "acct-2" }),
  ];
  const db = new FakeLateFeeDb(invoices, [
    { id: "acct-1", outstanding_amount: "4000" },
    { id: "acct-2", outstanding_amount: "20000" },
  ]);
  const result = await accrueLateFees(db as unknown as TenantQueryClient, ORG, SCHOOL);
  // 5% of total: inv-1 = 500, inv-2 = 1000.
  assertEquals(result.accruedCount, 2);
  assertEquals(result.totalLateFee, 1500);
  // Invoice outstanding moved by the DELTA (preserves any prior collection reduction).
  assertEquals(invoices[0].outstanding_amount, "4500");
  assertEquals(invoices[0].late_fee_amount, "500");
  assertEquals(invoices[1].outstanding_amount, "21000");
  // Account outstanding moved by the DELTA.
  assertEquals(db.accounts.get("acct-1")!.outstanding_amount, "4500");
  assertEquals(db.accounts.get("acct-2")!.outstanding_amount, "21000");
});

Deno.test("RT-11-2: two invoices on the SAME account roll up into one account delta", async () => {
  const invoices = [
    inv({ id: "inv-1", total_amount: "10000", outstanding_amount: "10000", student_account_id: "acct-1" }),
    inv({ id: "inv-2", total_amount: "10000", outstanding_amount: "10000", student_account_id: "acct-1" }),
  ];
  const db = new FakeLateFeeDb(invoices, [{ id: "acct-1", outstanding_amount: "20000" }]);
  const result = await accrueLateFees(db as unknown as TenantQueryClient, ORG, SCHOOL);
  assertEquals(result.accruedCount, 2);
  assertEquals(result.totalLateFee, 1000); // 500 + 500
  // The account delta is the SUM of both invoices' fees, applied once.
  assertEquals(db.accounts.get("acct-1")!.outstanding_amount, "21000");
});

Deno.test("RT-11-2: an already-accrued invoice is skipped (guard) — no double fee", async () => {
  const invoices = [
    inv({ id: "inv-1", outstanding_amount: "10500", late_fee_amount: "500", student_account_id: "acct-1" }),
  ];
  const db = new FakeLateFeeDb(invoices, [{ id: "acct-1", outstanding_amount: "10500" }]);
  const result = await accrueLateFees(db as unknown as TenantQueryClient, ORG, SCHOOL);
  assertEquals(result.accruedCount, 0);
  assertEquals(result.totalLateFee, 0);
  assertEquals(db.accounts.get("acct-1")!.outstanding_amount, "10500");
});
