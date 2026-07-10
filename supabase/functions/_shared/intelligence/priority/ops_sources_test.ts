// W2.7 ops-module worklist generators — pure unit tests (DB-free).

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildFeed } from "./priority_engine.ts";
import { actionForItem } from "./recommendation_actions.ts";
import {
  collectOpsRawItems,
  opsHrDocumentItems,
  opsInventoryItems,
  opsLibraryItems,
  opsProbationItems,
  opsPtpItems,
  opsRecoveryItems,
  opsTransportItems,
} from "./ops_sources.ts";

Deno.test("recovery: actionable entries summarize into one bounded item", () => {
  const items = opsRecoveryItems([
    { studentName: "Aarav", outstandingMinor: 500_000, priority: 2, reason: "Not yet contacted" },
    { studentName: "Diya", outstandingMinor: 1_200_000, priority: 0, reason: "Promise broken — follow up" },
    // Future promise (priority 5) — deliberately left alone.
    { studentName: "Kabir", outstandingMinor: 900_000, priority: 5, reason: "Promised — awaiting date" },
  ]);
  assertEquals(items.length, 1);
  const item = items[0]!;
  assertEquals(item.itemKey, "ops:finance:call_queue");
  assertEquals(item.type, "follow_up");
  // Only the 2 actionable entries count; the top is the broken promise.
  assertEquals(item.factors.peopleAffected, 2);
  assertEquals(item.factors.moneyAtStakeMinor, 1_700_000);
  assert(item.detail.includes("Diya"));
  assert(!item.detail.includes("Kabir"));
});

Deno.test("recovery: fully future-promised queue yields no item (honest empty)", () => {
  assertEquals(
    opsRecoveryItems([
      { studentName: "Kabir", outstandingMinor: 900_000, priority: 5, reason: "Promised" },
    ]).length,
    0,
  );
});

Deno.test("PTP: broken promises are an exception, due promises a deadline", () => {
  const items = opsPtpItems({ brokenPromises: 2, promisesDueToday: 1, promisesOverdue: 3 });
  assertEquals(items.length, 2);
  assertEquals(items[0]!.itemKey, "ops:finance:ptp_broken");
  assertEquals(items[0]!.type, "exception");
  assertEquals(items[1]!.itemKey, "ops:finance:ptp_due");
  assertEquals(items[1]!.type, "deadline");
  assertEquals(items[1]!.factors.dueInDays, 0);
  assertEquals(items[1]!.factors.peopleAffected, 4);
});

Deno.test("PTP: zero counts produce nothing", () => {
  assertEquals(
    opsPtpItems({ brokenPromises: 0, promisesDueToday: 0, promisesOverdue: 0 }).length,
    0,
  );
});

Deno.test("inventory: low-stock rows summarize with the largest-gap item on top", () => {
  const items = opsInventoryItems([
    { itemName: "Chalk boxes", quantityOnHand: 2, reorderLevel: 20 },
    { itemName: "Dusters", quantityOnHand: 5, reorderLevel: 10 },
  ]);
  assertEquals(items.length, 1);
  assertEquals(items[0]!.itemKey, "ops:inventory:reorder");
  assertEquals(items[0]!.type, "exception");
  assert(items[0]!.title.startsWith("2 items"));
  assert(items[0]!.detail.includes("Chalk boxes"));
  assertEquals(items[0]!.factors.impactClass, "elevated");
});

Deno.test("inventory: 10+ low-stock rows escalate to serious", () => {
  const rows = Array.from({ length: 10 }, (_, i) => ({
    itemName: `Item ${i}`,
    quantityOnHand: 1,
    reorderLevel: 5,
  }));
  assertEquals(opsInventoryItems(rows)[0]!.factors.impactClass, "serious");
});

Deno.test("transport: expired documents escalate and drive the headline", () => {
  const items = opsTransportItems([
    { subject: "Vehicle KA-01-AB-1234", document: "insurance", inDays: -3 },
    { subject: "Driver Ramesh", document: "licence", inDays: 12 },
  ]);
  assertEquals(items.length, 1);
  const item = items[0]!;
  assertEquals(item.type, "deadline");
  assert(item.title.includes("expired"));
  assertEquals(item.factors.dueInDays, -3);
  assertEquals(item.factors.impactClass, "serious");
  assert(item.detail.includes("expired 3 days ago"));
});

Deno.test("transport: only-upcoming expiries stay elevated with soonest dueInDays", () => {
  const items = opsTransportItems([
    { subject: "Vehicle KA-01", document: "fitness", inDays: 21 },
    { subject: "Vehicle KA-02", document: "permit", inDays: 7 },
  ]);
  assertEquals(items[0]!.factors.dueInDays, 7);
  assertEquals(items[0]!.factors.impactClass, "elevated");
  assert(items[0]!.title.includes("expiring soon"));
});

Deno.test("hr: document expiries + probation reviews are separate items", () => {
  const docs = opsHrDocumentItems([
    { subject: "Sunita Rao", document: "contract", inDays: 10 },
  ]);
  const probation = opsProbationItems([
    { employee: "Vikram Singh", daysToEnd: -2 },
    { employee: "Meena Iyer", daysToEnd: 9 },
  ]);
  assertEquals(docs.length, 1);
  assertEquals(docs[0]!.itemKey, "ops:hr:doc_expiry");
  assertEquals(docs[0]!.type, "deadline");
  assertEquals(probation.length, 1);
  assertEquals(probation[0]!.itemKey, "ops:hr:probation");
  // Lapsed probation is the soonest and is never hidden.
  assert(probation[0]!.detail.includes("Vikram Singh"));
  assert(probation[0]!.detail.includes("ended 2 days ago"));
  assertEquals(probation[0]!.factors.peopleAffected, 2);
});

Deno.test("library: overdue loans summarize with fines in paise", () => {
  const items = opsLibraryItems([
    { daysOverdue: 4, fineRupees: 20 },
    { daysOverdue: 10, fineRupees: 50 },
  ]);
  assertEquals(items.length, 1);
  const item = items[0]!;
  assertEquals(item.itemKey, "ops:library:overdue");
  assertEquals(item.factors.moneyAtStakeMinor, 7_000);
  assertEquals(item.factors.peopleAffected, 2);
  assert(item.detail.includes("longest overdue 10 days"));
});

Deno.test("ops items are school-persona scoped: never surface to teacher/parent/student/director", () => {
  const raw = collectOpsRawItems({
    callQueue: [{ studentName: "A", outstandingMinor: 100_000, priority: 0, reason: "r" }],
    ptp: { brokenPromises: 1, promisesDueToday: 0, promisesOverdue: 0 },
    lowStock: [{ itemName: "Chalk", quantityOnHand: 1, reorderLevel: 5 }],
    transportExpiries: [{ subject: "Vehicle X", document: "puc", inDays: 3 }],
    hrDocuments: [{ subject: "S", document: "medical", inDays: 3 }],
    probation: [{ employee: "E", daysToEnd: 3 }],
    libraryOverdue: [{ daysOverdue: 2, fineRupees: 10 }],
  });
  assertEquals(raw.length, 7);

  const nowIso = "2026-07-10T00:00:00Z";
  assert(buildFeed(raw, "principal", nowIso).items.length === 7);
  assert(buildFeed(raw, "admin", nowIso).items.length === 7);
  // Finance persona sees only the finance worklists (call queue + broken PTP;
  // no due-PTP item since due counts are 0 in this fixture).
  assertEquals(buildFeed(raw, "finance", nowIso).items.length, 2);
  for (const persona of ["teacher", "parent", "student", "director"] as const) {
    assertEquals(buildFeed(raw, persona, nowIso).items.length, 0, persona);
  }
});

Deno.test("every ops item carries a pre-staged confirm-only action", () => {
  const raw = collectOpsRawItems({
    callQueue: [{ studentName: "A", outstandingMinor: 100_000, priority: 2, reason: "r" }],
    ptp: { brokenPromises: 1, promisesDueToday: 1, promisesOverdue: 0 },
    lowStock: [{ itemName: "Chalk", quantityOnHand: 1, reorderLevel: 5 }],
    transportExpiries: [{ subject: "Vehicle X", document: "puc", inDays: 3 }],
    hrDocuments: [{ subject: "S", document: "medical", inDays: 3 }],
    probation: [{ employee: "E", daysToEnd: 3 }],
    libraryOverdue: [{ daysOverdue: 2, fineRupees: 10 }],
  });
  for (const item of raw) {
    const action = actionForItem(item);
    assert(action, `action missing for ${item.source}`);
    assertEquals(action!.requiresConfirmation, true);
    assert(action!.deepLink.startsWith("/"), item.source);
  }
});

Deno.test("collectOpsRawItems tolerates absent sources", () => {
  assertEquals(collectOpsRawItems({}).length, 0);
});
