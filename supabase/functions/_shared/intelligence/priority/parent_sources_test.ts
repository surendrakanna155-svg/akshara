// Adaptive AI — P3-AI-2 / W2 parent rollout: pure generator tests (DB-free).

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  collectParentRawItems,
  parentAttendanceItems,
  parentFeeItems,
} from "./parent_sources.ts";
import { buildFeed } from "./priority_engine.ts";

Deno.test("parent attendance: only below-threshold children with real data surface", () => {
  const items = parentAttendanceItems([
    { studentId: "s1", childName: "Asha", attendancePercent: 68, absentDays: 6 },
    { studentId: "s2", childName: "Ravi", attendancePercent: 92, absentDays: 1 }, // healthy → no item
    { studentId: "s3", childName: "Meena", attendancePercent: null, absentDays: 0 }, // no data → no item
    { studentId: "s4", childName: "Kiran", attendancePercent: 55, absentDays: 12 }, // serious
  ]);
  assertEquals(items.map((i) => i.itemKey), [
    "parent:attendance:s1",
    "parent:attendance:s4",
  ]);
  assertEquals(items[0]!.type, "exception");
  assertEquals(items[0]!.factors.impactClass, "elevated"); // 68% → elevated
  assertEquals(items[1]!.factors.impactClass, "serious"); // 55% → serious
  assert(items[0]!.entityTags.includes("student:s1:attendance"));
  assertEquals(items[0]!.personas, ["parent"]);
});

Deno.test("parent fees: only outstanding balances surface, sized by amount + due date", () => {
  const items = parentFeeItems([
    { studentId: "s1", childName: "Asha", totalDueMinor: 1_250_000, nearestDueInDays: 3 }, // ₹12,500
    { studentId: "s2", childName: "Ravi", totalDueMinor: 0 }, // paid up → no item
  ]);
  assertEquals(items.length, 1);
  const it = items[0]!;
  assertEquals(it.itemKey, "parent:fees:s1");
  assertEquals(it.type, "follow_up");
  assertEquals(it.factors.moneyAtStakeMinor, 1_250_000);
  assertEquals(it.factors.dueInDays, 3);
  assert(it.detail.includes("12,500"));
  assert(it.entityTags.includes("student:s1:fees"));
});

Deno.test("parent fees: a balance with no known due date carries no fabricated clock", () => {
  const items = parentFeeItems([{ studentId: "s1", childName: "Asha", totalDueMinor: 50000 }]);
  assertEquals(items[0]!.factors.dueInDays, undefined);
  assertEquals(items[0]!.factors.moneyAtStakeMinor, 50000);
});

Deno.test("parent items are persona-isolated (never surface to teacher/principal)", () => {
  const raw = collectParentRawItems({
    attendance: [{ studentId: "s1", childName: "Asha", attendancePercent: 60, absentDays: 8 }],
    fees: [{ studentId: "s1", childName: "Asha", totalDueMinor: 500000, nearestDueInDays: 1 }],
  });
  assertEquals(raw.length, 2);
  assert(buildFeed(raw, "parent", "2026-07-10T00:00:00Z").items.length === 2);
  assertEquals(buildFeed(raw, "teacher", "2026-07-10T00:00:00Z").items.length, 0);
  assertEquals(buildFeed(raw, "principal", "2026-07-10T00:00:00Z").items.length, 0);
});

Deno.test("collectParentRawItems tolerates absent sources", () => {
  assertEquals(collectParentRawItems({}).length, 0);
});
