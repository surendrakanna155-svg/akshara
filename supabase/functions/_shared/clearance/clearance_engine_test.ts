// SCE-1 — clearance engine: registry aggregation, per-lifecycle policy, the
// honesty law (not_tracked is never CLEARED and never blocks), and fail-safe
// (a throwing contributor degrades to not_tracked, never a silent pass).

import { assert, assertEquals } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  buildClearanceReport,
  type ClearanceContributor,
  type ClearanceItem,
} from "./clearance_engine.ts";

const db = {} as unknown as TenantQueryClient; // contributors here are pure fakes
const SCOPE = { organizationId: "org-1", schoolId: "school-1" };

function fake(
  module: string,
  opts: { tracked: boolean; items?: ClearanceItem[]; throws?: boolean },
): ClearanceContributor {
  return {
    module,
    tracked: opts.tracked,
    contribute() {
      if (opts.throws) throw new Error("read failed");
      return Promise.resolve(opts.items ?? []);
    },
  };
}

const dues = (amount: number): ClearanceItem[] => [
  { reference: "r1", description: "owed", amount },
];

Deno.test("blocking finance dues on an exit lifecycle → blocked, amount summed", async () => {
  const report = await buildClearanceReport(db, SCOPE, "stu-1", "transfer_certificate", [
    fake("finance", { tracked: true, items: dues(1500) }),
  ]);
  assert(report.blocked);
  assertEquals(report.blockingAmount, 1500);
  assertEquals(report.totalOutstanding, 1500);
  assertEquals(report.contributions[0].status, "pending");
});

Deno.test("the SAME finance dues on promotion are ADVISORY → not blocked (never held back a grade)", async () => {
  const report = await buildClearanceReport(db, SCOPE, "stu-1", "promotion", [
    fake("finance", { tracked: true, items: dues(1500) }),
  ]);
  assert(!report.blocked);
  assertEquals(report.blockingAmount, 0);
  // still surfaced as owed (advisory), just non-blocking.
  assertEquals(report.totalOutstanding, 1500);
  assertEquals(report.contributions[0].policy, "advisory");
});

Deno.test("no dues → cleared, not blocked", async () => {
  const report = await buildClearanceReport(db, SCOPE, "stu-1", "transfer_certificate", [
    fake("finance", { tracked: true, items: [] }),
  ]);
  assert(!report.blocked);
  assertEquals(report.contributions[0].status, "cleared");
  assertEquals(report.totalOutstanding, 0);
});

Deno.test("HONESTY: a not_tracked module is neither CLEARED nor blocking, and is listed", async () => {
  const report = await buildClearanceReport(db, SCOPE, "stu-1", "transfer_certificate", [
    fake("library", { tracked: false }),
    fake("hostel", { tracked: false }),
  ]);
  assert(!report.blocked, "an untracked module must never block");
  assertEquals(report.contributions[0].status, "not_tracked");
  assertEquals(report.contributions[0].coverage, "not_tracked");
  assertEquals(report.notTracked, ["library", "hostel"]);
});

Deno.test("FAIL-SAFE: a throwing tracked contributor degrades to not_tracked, never a silent CLEARED", async () => {
  const report = await buildClearanceReport(db, SCOPE, "stu-1", "transfer_certificate", [
    fake("finance", { tracked: true, throws: true }),
  ]);
  assertEquals(report.contributions[0].status, "not_tracked");
  assert(!report.blocked, "a failed read is inconclusive, not a block");
  // and crucially NOT reported as cleared
  assert(report.contributions[0].status !== "cleared");
});

Deno.test("mixed: finance blocks on exit, inventory dues are advisory (counted, non-blocking), library not_tracked", async () => {
  const report = await buildClearanceReport(db, SCOPE, "stu-1", "transfer_certificate", [
    fake("finance", { tracked: true, items: dues(2000) }), // blocking on exit
    fake("inventory", { tracked: true, items: dues(500) }), // advisory on exit (owner opt-in to block)
    fake("library", { tracked: false }), // advisory + not tracked
  ]);
  assert(report.blocked, "finance dues block the exit");
  assertEquals(report.blockingAmount, 2000, "only finance is blocking; inventory is advisory");
  assertEquals(report.totalOutstanding, 2500, "inventory dues ARE summed into the total");
  assertEquals(report.contributions[1].policy, "advisory");
  assertEquals(report.contributions[1].status, "pending");
  assertEquals(report.notTracked, ["library"]);
});

Deno.test("inventory dues alone do NOT block a TC today (preserves SIS-D1 finance-only gate)", async () => {
  const report = await buildClearanceReport(db, SCOPE, "stu-1", "transfer_certificate", [
    fake("finance", { tracked: true, items: [] }),
    fake("inventory", { tracked: true, items: dues(500) }),
  ]);
  assert(!report.blocked, "unpaid inventory alone must not block the TC by default");
  assertEquals(report.blockingAmount, 0);
  assertEquals(report.totalOutstanding, 500);
});

Deno.test("unknown lifecycle → the engine fails STRICT (blocking), never permissive", async () => {
  const report = await buildClearanceReport(db, SCOPE, "stu-1", "made_up_event", [
    fake("finance", { tracked: true, items: dues(500) }),
  ]);
  // An unrecognized lifecycle is treated as an exit event: finance dues BLOCK.
  assertEquals(report.contributions[0].policy, "blocking");
  assert(report.blocked);
});

Deno.test("SECURITY: a prototype key as the lifecycle cannot downgrade a gate to advisory", async () => {
  for (const evil of ["constructor", "valueOf", "toString", "hasOwnProperty", "__proto__"]) {
    const report = await buildClearanceReport(db, SCOPE, "stu-1", evil, [
      fake("finance", { tracked: true, items: dues(500) }),
    ]);
    assertEquals(report.contributions[0].policy, "blocking", `lifecycle=${evil} must fail strict`);
    assert(report.blocked, `lifecycle=${evil} must still block a duesful exit`);
  }
});

Deno.test("SECURITY: a prototype key as the MODULE name resolves to the safe default, not an inherited value", async () => {
  const report = await buildClearanceReport(db, SCOPE, "stu-1", "transfer_certificate", [
    fake("constructor", { tracked: true, items: dues(100) }),
    fake("toString", { tracked: true, items: dues(50) }),
  ]);
  // Unknown modules on a known lifecycle default to advisory (not blocking, not
  // a thrown inherited function) — no crash, no false block, no false clear.
  assertEquals(report.contributions[0].policy, "advisory");
  assertEquals(report.contributions[1].policy, "advisory");
  assert(!report.blocked);
});
