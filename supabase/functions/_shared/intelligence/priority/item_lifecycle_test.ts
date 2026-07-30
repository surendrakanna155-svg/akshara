// Living Dashboard — item lifecycle / visibility resolution tests (pure, DB-free).
//
// These pin the behaviours the old destructive dismissal could not express:
// a put-away item comes back when it gets WORSE, when its DEADLINE advances a
// band, or when its SNOOZE elapses — and stays away otherwise. The purity and
// clock-injection assertions at the bottom are load-bearing: they are what keeps
// the feed deterministic and replayable.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  ESCALATION_DELTA,
  isItemLifecycleState,
  type ItemLifecycleRecord,
  lifecycleIndex,
  resolveVisibility,
  urgencyBand,
} from "./item_lifecycle.ts";
import { buildFeed, scorePriorityItem } from "./priority_engine.ts";
import type { RawPriorityItem, ScoredPriorityItem } from "./priority_types.ts";

const NOW = "2026-07-10T06:00:00.000Z"; // 11:30 IST on 2026-07-10

function scored(over: Partial<RawPriorityItem> = {}): ScoredPriorityItem {
  return scorePriorityItem({
    itemKey: "k1",
    type: "exception",
    title: "t",
    detail: "d",
    personas: ["principal"],
    entityTags: [],
    factors: { impactClass: "elevated" },
    source: "test",
    ...over,
  });
}

// A record as a REAL user action writes it: every item is scored before it can
// be acted on, so `scoreAtAction` is always present. Only rows migrated from the
// old `dismissedKeys` array lack one, and those tests null it explicitly.
function record(over: Partial<ItemLifecycleRecord> = {}): ItemLifecycleRecord {
  return {
    itemKey: "k1",
    state: "acknowledged",
    actedAt: NOW,
    scoreAtAction: 50,
    dueAtAction: null,
    ...over,
  };
}

Deno.test("no lifecycle row → the item is visible (the common case)", () => {
  const d = resolveVisibility(scored(), null, NOW);
  assertEquals(d.visible, true);
  assertEquals(d.reason, "visible_new");
});

Deno.test("acknowledged today stays hidden; the same condition returns tomorrow", () => {
  const rec = record({ state: "acknowledged", actedAt: NOW });
  assertEquals(resolveVisibility(scored(), rec, NOW).visible, false);

  // Next IST calendar day — the operations_hub_item_actions precedent.
  const tomorrow = "2026-07-11T06:00:00.000Z";
  const back = resolveVisibility(scored(), rec, tomorrow);
  assertEquals(back.visible, true);
  assertEquals(back.reason, "visible_acknowledge_expired");
});

Deno.test("acknowledge day boundary is IST, not UTC (P2-7 window)", () => {
  // 2026-07-10T19:00Z is already 2026-07-11 00:30 IST — a new school day.
  const rec = record({ state: "acknowledged", actedAt: "2026-07-10T06:00:00.000Z" });
  const d = resolveVisibility(scored(), rec, "2026-07-10T19:00:00.000Z");
  assertEquals(d.visible, true, "IST midnight must end the acknowledge, not UTC midnight");
});

Deno.test("severity increase breaks through an acknowledgement", () => {
  const low = scored({ factors: { impactClass: "routine" } });
  const rec = record({ state: "acknowledged", scoreAtAction: low.score });

  // Same severity → still hidden.
  assertEquals(resolveVisibility(low, rec, NOW).visible, false);

  // Materially worse → comes back, same day, with the honest reason.
  const worse = scored({ factors: { impactClass: "critical", dueInDays: 0 } });
  assert(worse.score >= low.score + ESCALATION_DELTA, "fixture must clear the delta");
  const d = resolveVisibility(worse, rec, NOW);
  assertEquals(d.visible, true);
  assertEquals(d.reason, "visible_severity_increased");
});

Deno.test("severity increase breaks through a live snooze", () => {
  const rec = record({
    state: "snoozed",
    snoozedUntil: "2026-07-20T00:00:00.000Z", // far in the future
    scoreAtAction: 10,
  });
  const worse = scored({ factors: { impactClass: "critical", dueInDays: 0 } });
  const d = resolveVisibility(worse, rec, NOW);
  assertEquals(d.visible, true, "a genuine worsening must outrank a snooze");
  assertEquals(d.reason, "visible_severity_increased");
});

Deno.test("a legacy row (no watermark) never fabricates an escalation", () => {
  // Dismissals migrated out of the old `dismissedKeys` array carry no baseline
  // for EITHER dimension. Claiming "it got worse" or "the deadline advanced"
  // against an unknown baseline would be inventing a comparison, so both
  // escalation rules must stay silent — even for a maximally severe item.
  const rec = record({ state: "acknowledged", scoreAtAction: null, dueAtAction: null });
  const worst = scored({ factors: { impactClass: "critical", dueInDays: 0 } });
  assertEquals(resolveVisibility(worst, rec, NOW).visible, false);

  // It is not buried forever, though: the ordinary day boundary still returns it.
  const tomorrow = "2026-07-11T06:00:00.000Z";
  assertEquals(resolveVisibility(worst, rec, tomorrow).visible, true);
});

Deno.test("a real row with a watermark DOES resurface on a newly-acquired deadline", () => {
  // Contrast with the legacy case: here we know the item had no clock when the
  // user acted, so gaining one is a genuine change worth surfacing.
  const rec = record({ state: "acknowledged", scoreAtAction: 20, dueAtAction: null });
  const nowDue = scored({ factors: { dueInDays: 1, impactClass: "routine" } });
  const d = resolveVisibility(nowDue, rec, NOW);
  assertEquals(d.visible, true);
  assertEquals(d.reason, "visible_deadline_advanced");
});

Deno.test("deadline advancing a band resurfaces; ticking within a band does not", () => {
  const rec = record({ state: "acknowledged", dueAtAction: 10 }); // band 1 (<=14)

  // 8 days out is still band 1 — no re-nag.
  const sameBand = scored({ factors: { dueInDays: 8, impactClass: "elevated" } });
  assertEquals(resolveVisibility(sameBand, rec, NOW).visible, false);

  // 5 days out crosses into band 2 (<=7) — comes back once.
  const nextBand = scored({ factors: { dueInDays: 5, impactClass: "elevated" } });
  const d = resolveVisibility(nextBand, rec, NOW);
  assertEquals(d.visible, true);
  assertEquals(d.reason, "visible_deadline_advanced");
});

Deno.test("snooze hides until the window closes, then returns with no scheduler", () => {
  const rec = record({
    state: "snoozed",
    snoozedUntil: "2026-07-10T08:00:00.000Z",
    scoreAtAction: 50,
  });
  const it = scored({ factors: { impactClass: "elevated" } });

  // Before the window closes.
  assertEquals(resolveVisibility(it, rec, "2026-07-10T07:00:00.000Z").visible, false);

  // At/after — read-time resolution, nothing ticked.
  const d = resolveVisibility(it, rec, "2026-07-10T08:00:00.000Z");
  assertEquals(d.visible, true);
  assertEquals(d.reason, "visible_snooze_elapsed");
});

Deno.test("a corrupt snoozedUntil fails OPEN (shows the item), never buries it", () => {
  const rec = record({ state: "snoozed", snoozedUntil: "not-a-date", scoreAtAction: 50 });
  assertEquals(resolveVisibility(scored(), rec, NOW).visible, true);

  const missing = record({ state: "snoozed", snoozedUntil: null, scoreAtAction: 50 });
  assertEquals(resolveVisibility(scored(), missing, NOW).visible, true);
});

Deno.test("terminal states never resurface, however bad it gets", () => {
  for (const state of ["completed", "resolved"] as const) {
    const rec = record({ state, scoreAtAction: 0 });
    const worst = scored({ factors: { impactClass: "critical", dueInDays: -5 } });
    const d = resolveVisibility(worst, rec, "2026-08-01T00:00:00.000Z");
    assertEquals(d.visible, false, `${state} must stay done`);
    assertEquals(d.reason, "hidden_terminal");
  }
});

Deno.test("urgencyBand collapses days onto the scorer's tiers", () => {
  assertEquals(urgencyBand(undefined), 0);
  assertEquals(urgencyBand(null), 0);
  assertEquals(urgencyBand(30), 0);
  assertEquals(urgencyBand(14), 1);
  assertEquals(urgencyBand(7), 2);
  assertEquals(urgencyBand(2), 3);
  assertEquals(urgencyBand(0), 4);
  assertEquals(urgencyBand(-3), 4, "overdue is the top band, not a new one");
});

Deno.test("resolveVisibility is pure and deterministic (same inputs → same answer)", () => {
  const it = scored({ factors: { dueInDays: 3, impactClass: "serious" } });
  const rec = record({ state: "snoozed", snoozedUntil: "2026-07-11T00:00:00.000Z" });
  const a = resolveVisibility(it, rec, NOW);
  const b = resolveVisibility(it, rec, NOW);
  assertEquals(a, b);
});

Deno.test("the clock is injected — a different now yields a different answer", () => {
  const rec = record({ state: "snoozed", snoozedUntil: "2026-07-10T08:00:00.000Z" });
  const it = scored();
  assertEquals(resolveVisibility(it, rec, "2026-07-10T07:59:59.000Z").visible, false);
  assertEquals(resolveVisibility(it, rec, "2026-07-10T08:00:01.000Z").visible, true);
});

Deno.test("lifecycleIndex keys by itemKey; state guard rejects junk", () => {
  const idx = lifecycleIndex([record({ itemKey: "a" }), record({ itemKey: "b" })]);
  assertEquals(idx.size, 2);
  assertEquals(idx.get("a")?.itemKey, "a");

  assert(isItemLifecycleState("snoozed"));
  assert(isItemLifecycleState("escalated"));
  assert(!isItemLifecycleState("dismissed"), "legacy vocabulary must not leak in");
  assert(!isItemLifecycleState(""));
});

// ---------------------------------------------------------------------------
// buildFeed integration — the overlay as the engine applies it.
// ---------------------------------------------------------------------------

function raw(over: Partial<RawPriorityItem> = {}): RawPriorityItem {
  return {
    itemKey: "k1",
    type: "exception",
    title: "t",
    detail: "d",
    personas: ["principal"],
    entityTags: [],
    factors: { impactClass: "elevated" },
    source: "test",
    ...over,
  };
}

Deno.test("buildFeed without lifecycle is byte-identical to before (no new fields)", () => {
  const feed = buildFeed([raw()], "principal", NOW);
  assertEquals(feed.items.length, 1);
  assertEquals(feed.items[0].lifecycleState, undefined);
  assertEquals(feed.items[0].visibilityReason, undefined);
  assertEquals(feed.hidden, undefined);
});

Deno.test("buildFeed hides a snoozed item and annotates the survivors", () => {
  const items = [raw({ itemKey: "a" }), raw({ itemKey: "b" })];
  const lifecycle = lifecycleIndex([
    record({ itemKey: "a", state: "snoozed", snoozedUntil: "2026-07-20T00:00:00.000Z" }),
  ]);
  const feed = buildFeed(items, "principal", NOW, { lifecycle });

  assertEquals(feed.items.map((i) => i.itemKey), ["b"]);
  assertEquals(feed.items[0].visibilityReason, "visible_new");
  assertEquals(feed.counts.total, 1);
});

Deno.test("the limit counts VISIBLE items — hidden ones never eat the budget", () => {
  // 5 items, the top 3 by score are all snoozed. With a limit of 2 the user must
  // still get 2 REAL items, not an empty feed with work silently missing.
  const items = [
    raw({ itemKey: "hi-1", factors: { impactClass: "critical", dueInDays: 0 } }),
    raw({ itemKey: "hi-2", factors: { impactClass: "critical", dueInDays: 0 } }),
    raw({ itemKey: "hi-3", factors: { impactClass: "critical", dueInDays: 0 } }),
    raw({ itemKey: "lo-1", factors: { impactClass: "routine" } }),
    raw({ itemKey: "lo-2", factors: { impactClass: "routine" } }),
  ];
  // Snoozed while ALREADY at this urgency: score is at the 100 ceiling and the
  // deadline is already in the top band, so neither escalation rule can fire and
  // the snooze genuinely holds. (Watermarks must mirror the item's state at
  // action time — otherwise the item legitimately resurfaces, as it should.)
  const snoozedFar = (k: string) =>
    record({
      itemKey: k,
      state: "snoozed",
      snoozedUntil: "2026-07-20T00:00:00.000Z",
      scoreAtAction: 100,
      dueAtAction: 0,
    });
  const lifecycle = lifecycleIndex([snoozedFar("hi-1"), snoozedFar("hi-2"), snoozedFar("hi-3")]);

  const feed = buildFeed(items, "principal", NOW, { lifecycle, limit: 2 });
  assertEquals(feed.items.length, 2);
  assertEquals(feed.items.map((i) => i.itemKey), ["lo-1", "lo-2"]);
});

Deno.test("includeHidden exposes put-away items for Copilot rehydration", () => {
  const items = [raw({ itemKey: "a" }), raw({ itemKey: "b" })];
  const lifecycle = lifecycleIndex([
    record({
      itemKey: "a",
      state: "snoozed",
      snoozedUntil: "2026-07-20T00:00:00.000Z",
      scoreAtAction: 100,
    }),
  ]);

  const withHidden = buildFeed(items, "principal", NOW, { lifecycle, includeHidden: true });
  assertEquals(withHidden.items.map((i) => i.itemKey), ["b"]);
  assertEquals(withHidden.hidden?.map((i) => i.itemKey), ["a"]);
  assertEquals(withHidden.hidden?.[0].lifecycleState, "snoozed");
  assertEquals(withHidden.hidden?.[0].visibilityReason, "hidden_snoozed");

  // The dismissed item is still SCORED — that is what makes restore possible.
  assert((withHidden.hidden?.[0].score ?? 0) > 0);
});

Deno.test("an escalating item climbs back into the feed on its own", () => {
  const lifecycle = lifecycleIndex([
    record({ itemKey: "a", state: "acknowledged", scoreAtAction: 10, dueAtAction: null }),
  ]);

  const calm = buildFeed([raw({ itemKey: "a", factors: { impactClass: "routine" } })], "principal", NOW, { lifecycle });
  assertEquals(calm.items.length, 0, "quiet item stays put away");

  const worse = buildFeed(
    [raw({ itemKey: "a", factors: { impactClass: "critical", dueInDays: 0 } })],
    "principal",
    NOW,
    { lifecycle },
  );
  assertEquals(worse.items.length, 1, "the same item returns once it gets worse");
  assertEquals(worse.items[0].visibilityReason, "visible_severity_increased");
});

Deno.test("the deprecated dismissedKeys hard filter still erases, unchanged", () => {
  const feed = buildFeed([raw({ itemKey: "a" }), raw({ itemKey: "b" })], "principal", NOW, {
    dismissedKeys: new Set(["a"]),
  });
  assertEquals(feed.items.map((i) => i.itemKey), ["b"]);
});

// ---------------------------------------------------------------------------
// Phase 4 — pins. Doc 04 §5: "user pins always win". A self-reordering feed is
// only tolerable if the user can nail down what they are working on.
// ---------------------------------------------------------------------------

Deno.test("a pin outranks an acknowledgement", () => {
  const rec = record({ state: "acknowledged", pinned: true });
  const d = resolveVisibility(scored(), rec, NOW);
  assertEquals(d.visible, true);
  assertEquals(d.reason, "visible_pinned");
});

Deno.test("a pin outranks a live snooze", () => {
  const rec = record({
    state: "snoozed",
    snoozedUntil: "2026-07-20T00:00:00.000Z",
    pinned: true,
  });
  assertEquals(resolveVisibility(scored(), rec, NOW).visible, true);
});

Deno.test("a pin outranks even a terminal state", () => {
  // Pinning after completing is the later, more deliberate signal. Swallowing
  // it would read as the app ignoring the user.
  const rec = record({ state: "completed", pinned: true });
  const d = resolveVisibility(scored(), rec, NOW);
  assertEquals(d.visible, true);
  assertEquals(d.reason, "visible_pinned");
});

Deno.test("pinned:false behaves exactly as no pin at all", () => {
  const rec = record({ state: "completed", pinned: false });
  assertEquals(resolveVisibility(scored(), rec, NOW).visible, false);
});

Deno.test("pins float to the top of the feed, above higher-scoring items", () => {
  const items = [
    raw({ itemKey: "urgent", factors: { impactClass: "critical", dueInDays: 0 } }),
    raw({ itemKey: "quiet", factors: { impactClass: "routine" } }),
  ];
  const lifecycle = lifecycleIndex([
    record({ itemKey: "quiet", state: "new", pinned: true }),
  ]);
  const feed = buildFeed(items, "principal", NOW, { lifecycle });

  assertEquals(feed.items.map((i) => i.itemKey), ["quiet", "urgent"]);
  assertEquals(feed.items[0].pinned, true);
});

Deno.test("score order is preserved WITHIN the pinned and unpinned groups", () => {
  const items = [
    raw({ itemKey: "p-low", factors: { impactClass: "routine" } }),
    raw({ itemKey: "p-high", factors: { impactClass: "critical", dueInDays: 0 } }),
    raw({ itemKey: "u-low", factors: { impactClass: "routine" } }),
    raw({ itemKey: "u-high", factors: { impactClass: "critical", dueInDays: 0 } }),
  ];
  const lifecycle = lifecycleIndex([
    record({ itemKey: "p-low", state: "new", pinned: true }),
    record({ itemKey: "p-high", state: "new", pinned: true }),
  ]);
  const feed = buildFeed(items, "principal", NOW, { lifecycle });

  assertEquals(
    feed.items.map((i) => i.itemKey),
    ["p-high", "p-low", "u-high", "u-low"],
    "pins first, but each group still ordered by score",
  );
});

Deno.test("a pinned item consumes a limit slot — it is shown, not extra", () => {
  const items = [
    raw({ itemKey: "a", factors: { impactClass: "critical", dueInDays: 0 } }),
    raw({ itemKey: "b", factors: { impactClass: "serious" } }),
    raw({ itemKey: "z", factors: { impactClass: "routine" } }),
  ];
  const lifecycle = lifecycleIndex([record({ itemKey: "z", state: "new", pinned: true })]);
  const feed = buildFeed(items, "principal", NOW, { lifecycle, limit: 2 });
  assertEquals(feed.items.map((i) => i.itemKey), ["z", "a"]);
});
