// SCE-1 — contributor SQL shape (DB-free mockDb): finance reads OPEN accounts
// with outstanding>0; inventory reads only payment_pending distributions;
// library/hostel are honestly not-tracked (no query, no false CLEARED).

import { assert, assertEquals } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  DEFAULT_CLEARANCE_REGISTRY,
  financeContributor,
  hostelContributor,
  inventoryContributor,
  libraryContributor,
} from "./clearance_contributors.ts";

interface Call {
  sql: string;
  args: unknown[];
}

function mockDb(results: unknown[][]): { db: TenantQueryClient; calls: Call[] } {
  const calls: Call[] = [];
  let i = 0;
  const db = {
    queryObject: <T>(sql: string, args: unknown[] = []): Promise<T[]> => {
      calls.push({ sql, args });
      return Promise.resolve((results[i++] ?? []) as T[]);
    },
  } as unknown as TenantQueryClient;
  return { db, calls };
}

const SCOPE = { organizationId: "org-1", schoolId: "school-1" };

Deno.test("finance contributor: reads OPEN accounts with outstanding>0, keyed by student_id", async () => {
  const { db, calls } = mockDb([[
    { id: "acct-2", academic_year: "2025-26", outstanding: "1200" },
    { id: "acct-1", academic_year: "2024-25", outstanding: "300" },
  ]]);
  const items = await financeContributor.contribute(db, SCOPE, "stu-1");
  assertEquals(items.length, 2);
  assertEquals(items[0].amount, 1200);
  assertEquals(items[1].amount, 300);
  const sql = calls[0].sql;
  assert(sql.includes("finance_student_accounts"));
  assert(sql.includes("status = 'open'"));
  assert(sql.includes("outstanding_amount > 0"));
  assertEquals(calls[0].args, ["org-1", "school-1", "stu-1"]);
});

Deno.test("finance contributor: no open dues → no items (cleared)", async () => {
  const { db } = mockDb([[]]);
  const items = await financeContributor.contribute(db, SCOPE, "stu-1");
  assertEquals(items, []);
});

Deno.test("inventory contributor: reads payment_pending distributions with the REAL owed amount from the linked open payment_request", async () => {
  const { db, calls } = mockDb([[
    { id: "dist-1", item_name: "Mathematics Textbook", quantity: 1, amount: "500" },
    { id: "dist-2", item_name: "Uniform Set", quantity: 2, amount: null }, // no live request → 0, still flagged
  ]]);
  const items = await inventoryContributor.contribute(db, SCOPE, "stu-1");
  assertEquals(items.length, 2);
  assertEquals(items[0].amount, 500, "owed rupees come from the linked open payment_request");
  assertEquals(items[1].amount, 0, "no live request → 0, but the obligation still flags");
  assert(items[1].description.includes("×2"));
  const sql = calls[0].sql;
  assert(sql.includes("inv_student_distributions"));
  assert(sql.includes("status = 'payment_pending'"));
  assert(sql.includes("payment_requests"), "must join the payment_requests ledger for the amount");
  assert(
    sql.includes("'pending', 'initiated', 'failed'"),
    "only a still-owed request contributes an amount (captured/cancelled = settled)",
  );
});

Deno.test("library + hostel are honestly not tracked (tracked=false, no query)", () => {
  assertEquals(libraryContributor.tracked, false);
  assertEquals(hostelContributor.tracked, false);
});

Deno.test("default registry order: finance, inventory, library, hostel", () => {
  assertEquals(
    DEFAULT_CLEARANCE_REGISTRY.map((c) => c.module),
    ["finance", "inventory", "library", "hostel"],
  );
});
