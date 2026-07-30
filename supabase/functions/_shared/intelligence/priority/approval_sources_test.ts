// Living Dashboard Phase 6a — the approval source, and the wait clock that
// finally makes `ageBoost` a live factor. Pure, DB-free.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildApprovalItems, type PendingApprovalBucket } from "./approval_sources.ts";
import { waitingDaysSince } from "./feed_dates.ts";
import { ageBoostFactor, buildFeed, scorePriorityItem } from "./priority_engine.ts";

const NOW = "2026-07-30T06:00:00.000Z"; // 11:30 IST

function bucket(over: Partial<PendingApprovalBucket> = {}): PendingApprovalBucket {
  return { type: "staffLeave", count: 3, oldestWaitingDays: 1, ...over };
}

Deno.test("waitingDaysSince measures the wait on the IST calendar", () => {
  assertEquals(waitingDaysSince(NOW, "2026-07-30T06:00:00.000Z"), 0);
  assertEquals(waitingDaysSince(NOW, "2026-07-28T06:00:00.000Z"), 2);
  assertEquals(waitingDaysSince(NOW, "2026-07-16T06:00:00.000Z"), 14);
});

Deno.test("waitingDaysSince returns undefined for no clock — never a fabricated 0", () => {
  // A `0` would read as "just arrived", a claim we cannot support without a
  // real created_at. Same honest-empty rule the rest of the feed follows.
  assertEquals(waitingDaysSince(NOW, null), undefined);
  assertEquals(waitingDaysSince(NOW, undefined), undefined);
  assertEquals(waitingDaysSince(NOW, ""), undefined);
  assertEquals(waitingDaysSince(NOW, "not-a-date"), undefined);
});

Deno.test("a future timestamp (clock skew) clamps to 0, never negative", () => {
  assertEquals(waitingDaysSince(NOW, "2026-08-05T06:00:00.000Z"), 0);
});

Deno.test("one item per queue, never one per request (feed-flood rule)", () => {
  const items = buildApprovalItems([
    bucket({ type: "staffLeave", count: 40 }),
    bucket({ type: "refund", count: 2 }),
  ]);
  assertEquals(items.length, 2);
  assertEquals(items.map((i) => i.itemKey), [
    "ops:approvals:refund",
    "ops:approvals:staffLeave",
  ]);
  assert(items[1].title.includes("40"), "the count is in the title");
});

Deno.test("an empty queue produces no item at all", () => {
  assertEquals(buildApprovalItems([bucket({ count: 0 })]).length, 0);
});

Deno.test("severity comes from how long the oldest has waited, not from existing", () => {
  const fresh = buildApprovalItems([bucket({ oldestWaitingDays: 0 })])[0];
  const twoDays = buildApprovalItems([bucket({ oldestWaitingDays: 2 })])[0];
  const aWeek = buildApprovalItems([bucket({ oldestWaitingDays: 8 })])[0];

  assertEquals(fresh.factors.impactClass, "routine");
  assertEquals(twoDays.factors.impactClass, "elevated");
  assertEquals(aWeek.factors.impactClass, "serious");
});

Deno.test("an unmeasurable wait stays routine and carries no waitingDays", () => {
  const item = buildApprovalItems([bucket({ oldestWaitingDays: undefined })])[0];
  assertEquals(item.factors.waitingDays, undefined);
  assertEquals(item.factors.impactClass, "routine");
  assert(
    item.detail.includes("awaiting a decision"),
    "wording must not imply a duration we did not measure",
  );
});

Deno.test("approval items are the `approval` type — previously produced by nothing", () => {
  const item = buildApprovalItems([bucket()])[0];
  assertEquals(item.type, "approval");
  assertEquals(item.source, "approval_queue");
});

Deno.test("approvals reach school leadership only", () => {
  const item = buildApprovalItems([bucket()])[0];
  assertEquals(item.personas, ["principal", "admin"]);
  for (const persona of ["teacher", "parent", "student", "director"] as const) {
    assert(!item.personas.includes(persona), `${persona} must not see approvals`);
  }
});

// ---------------------------------------------------------------------------
// The point of Phase 6a: ageBoost stops being dead code.
// ---------------------------------------------------------------------------

Deno.test("ageBoost was inert before a wait clock existed, and now varies", () => {
  assertEquals(ageBoostFactor({}), 1.0, "no waitingDays → the old constant");
  assert(ageBoostFactor({ waitingDays: 7 }) > 1.0);
  assert(
    ageBoostFactor({ waitingDays: 14 }) > ageBoostFactor({ waitingDays: 7 }),
    "longer waits boost more",
  );
});

Deno.test("an old approval outranks a fresh one of the same size", () => {
  const [fresh] = buildApprovalItems([
    bucket({ type: "refund", count: 5, oldestWaitingDays: 0 }),
  ]);
  const [stale] = buildApprovalItems([
    bucket({ type: "staffLeave", count: 5, oldestWaitingDays: 12 }),
  ]);

  const a = scorePriorityItem(fresh);
  const b = scorePriorityItem(stale);
  assert(
    b.rawScore > a.rawScore,
    "doc 04: an approval nobody has touched climbs above a fresh one — "
      + `got stale=${b.rawScore} fresh=${a.rawScore}`,
  );
  assert(b.factorBreakdown.ageBoost > 1.0, "the age factor actually contributed");
});

Deno.test("the feed orders a stale approval above a fresh one end-to-end", () => {
  const items = buildApprovalItems([
    bucket({ type: "refund", count: 5, oldestWaitingDays: 0 }),
    bucket({ type: "staffLeave", count: 5, oldestWaitingDays: 12 }),
  ]);
  const feed = buildFeed(items, "principal", NOW);
  assertEquals(feed.items[0].itemKey, "ops:approvals:staffLeave");
});

Deno.test('"why is this first?" can now say waiting, which was unreachable before', () => {
  const [stale] = buildApprovalItems([bucket({ oldestWaitingDays: 12 })]);
  const scored = scorePriorityItem(stale);
  assertEquals(scored.reason, "waiting 12 days");
});

Deno.test("scoring stays deterministic with the wait clock live", () => {
  const [item] = buildApprovalItems([bucket({ oldestWaitingDays: 5 })]);
  assertEquals(scorePriorityItem(item).rawScore, scorePriorityItem(item).rawScore);
});
