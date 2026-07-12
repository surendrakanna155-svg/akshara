// SCE-1 slice 2 — gate-mode semantics. The load-bearing difference from the
// read-only report: a BLOCKING dues source that can't be read FAILS CLOSED (the
// gate's transaction rolls back) rather than degrading to not_tracked. Advisory
// sources still degrade — their outage must never block a lifecycle event.

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  buildClearanceReport,
  type ClearanceContributor,
  type ClearanceItem,
} from "./clearance_engine.ts";
import { evaluateClearanceGate } from "./clearance_gate.ts";

const SCOPE = { organizationId: "org-1", schoolId: "school-1" };

function fake(
  module: string,
  opts: { tracked: boolean; items?: ClearanceItem[]; throws?: boolean },
): ClearanceContributor {
  return {
    module,
    tracked: opts.tracked,
    contribute() {
      if (opts.throws) throw new Error(`${module} read failed`);
      return Promise.resolve(opts.items ?? []);
    },
  };
}

const dues = (amount: number): ClearanceItem[] => [
  { reference: "r", description: "owed", amount },
];

// The finance contributor is `blocking` on transfer_certificate.
Deno.test("gate mode: a BLOCKING contributor that throws FAILS CLOSED (re-throws), never issues un-gated", async () => {
  const db = {} as unknown as TenantQueryClient;
  await assertRejects(
    () =>
      buildClearanceReport(db, SCOPE, "stu-1", "transfer_certificate", [
        fake("finance", { tracked: true, throws: true }),
      ], { failClosedOnBlocking: true }),
    Error,
    "finance read failed",
  );
});

Deno.test("gate mode: an ADVISORY contributor that throws still DEGRADES (does not block the event)", async () => {
  const db = {} as unknown as TenantQueryClient;
  // inventory is advisory on transfer_certificate; its outage must not block a TC.
  const report = await buildClearanceReport(db, SCOPE, "stu-1", "transfer_certificate", [
    fake("finance", { tracked: true, items: [] }),
    fake("inventory", { tracked: true, throws: true }),
  ], { failClosedOnBlocking: true });
  assert(!report.blocked, "an advisory source outage must not block");
  assertEquals(report.contributions[1].status, "not_tracked");
});

Deno.test("gate mode blockingContributorsOnly: an advisory contributor is NEVER QUERIED (audit slice-2 P2 — a throwing advisory query can't run to poison the txn)", async () => {
  const db = {} as unknown as TenantQueryClient;
  let inventoryQueried = false;
  const spyInventory: ClearanceContributor = {
    module: "inventory",
    tracked: true,
    contribute() {
      inventoryQueried = true; // would flip if the gate ran it
      throw new Error("inventory must not be queried in blocking-only gate mode");
    },
  };
  const report = await buildClearanceReport(db, SCOPE, "stu-1", "transfer_certificate", [
    fake("finance", { tracked: true, items: dues(700) }),
    spyInventory,
  ], { failClosedOnBlocking: true, blockingContributorsOnly: true });
  assertEquals(inventoryQueried, false, "advisory inventory must be skipped, not queried");
  assert(report.blocked, "finance still blocks");
  assertEquals(report.blockingAmount, 700);
  // only the blocking contributor appears in a gate-mode report
  assertEquals(report.contributions.length, 1);
  assertEquals(report.contributions[0].module, "finance");
});

Deno.test("evaluateClearanceGate uses blocking-only mode: a broken inventory query does NOT run / does NOT affect the gate", async () => {
  const db = {
    // deno-lint-ignore require-await
    queryObject: async <T>(sql: string): Promise<T[]> => {
      if (sql.includes("SUM(outstanding_amount)")) return [{ outstanding: "0" }] as T[];
      // If the gate ever ran the inventory JOIN, this would throw and surface.
      throw new Error("inventory query must not run in the gate");
    },
  } as unknown as TenantQueryClient;
  const report = await evaluateClearanceGate(db, SCOPE, "stu-1", "transfer_certificate");
  assert(!report.blocked, "no finance dues → cleared, and inventory never ran");
});

Deno.test("report mode (default): a BLOCKING contributor that throws degrades to not_tracked (fail-SAFE, never a fabricated block)", async () => {
  const db = {} as unknown as TenantQueryClient;
  const report = await buildClearanceReport(db, SCOPE, "stu-1", "transfer_certificate", [
    fake("finance", { tracked: true, throws: true }),
  ]);
  assertEquals(report.contributions[0].status, "not_tracked");
  assert(!report.blocked);
});

Deno.test("evaluateClearanceGate runs the real default registry in gate mode: finance dues block, and a finance read error fails closed", async () => {
  // Finance query present (net 900) → blocked; inventory/library/hostel no-op.
  const okDb = {
    // deno-lint-ignore require-await
    queryObject: async <T>(sql: string): Promise<T[]> => {
      if (sql.includes("SUM(outstanding_amount)")) {
        return [{ outstanding: "900" }] as T[];
      }
      return [] as T[]; // inventory join → no rows
    },
  } as unknown as TenantQueryClient;
  const report = await evaluateClearanceGate(okDb, SCOPE, "stu-1", "transfer_certificate");
  assert(report.blocked);
  assertEquals(report.blockingAmount, 900);

  // Finance read throws → the gate must fail closed (reject), not clear.
  const badDb = {
    queryObject: <T>(sql: string): Promise<T[]> => {
      if (sql.includes("SUM(outstanding_amount)")) throw new Error("db down");
      return Promise.resolve([] as T[]);
    },
  } as unknown as TenantQueryClient;
  await assertRejects(
    () => evaluateClearanceGate(badDb, SCOPE, "stu-1", "transfer_certificate"),
    Error,
    "db down",
  );
});
