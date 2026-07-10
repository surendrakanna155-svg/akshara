// Adaptive AI — P3-AI-2 / W2.0a: Priority Engine scorer tests (pure, DB-free).

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  ageBoostFactor,
  buildFeed,
  clampLearnedWeight,
  DEFAULT_LEARNED_WEIGHT,
  impactFactor,
  MAX_LEARNED_WEIGHT,
  MIN_LEARNED_WEIGHT,
  normalizeScore,
  scorePriorityItem,
  urgencyFactor,
} from "./priority_engine.ts";
import type { RawPriorityItem } from "./priority_types.ts";

const NOW = "2026-07-10T00:00:00.000Z";

function item(over: Partial<RawPriorityItem> = {}): RawPriorityItem {
  return {
    itemKey: "k1",
    type: "exception",
    title: "t",
    detail: "d",
    personas: ["principal"],
    entityTags: [],
    factors: {},
    source: "test",
    ...over,
  };
}

// ─── factor functions ────────────────────────────────────────────────────────

Deno.test("urgency: an overdue deadline is maximally urgent; a distant one is minimal", () => {
  assertEquals(urgencyFactor({ dueInDays: -3 }), 3.0);
  assertEquals(urgencyFactor({ dueInDays: 0 }), 3.0);
  assertEquals(urgencyFactor({ dueInDays: 2 }), 2.4);
  assertEquals(urgencyFactor({ dueInDays: 7 }), 1.8);
  assertEquals(urgencyFactor({ dueInDays: 30 }), 1.0);
});

Deno.test("urgency: with no clock, severity stands in for urgency", () => {
  assertEquals(urgencyFactor({ impactClass: "critical" }), 3.0);
  assertEquals(urgencyFactor({ impactClass: "routine" }), 1.2);
  assertEquals(urgencyFactor({}), 1.0);
});

Deno.test("impact: takes the largest of money, people, and compliance class", () => {
  assertEquals(impactFactor({ moneyAtStakeMinor: 100_000_00 }), 3.0); // ≥₹1L
  assertEquals(impactFactor({ moneyAtStakeMinor: 5_000_00 }), 1.8); // ₹5k
  assertEquals(impactFactor({ peopleAffected: 50 }), 3.0);
  assertEquals(impactFactor({ peopleAffected: 1 }), 1.4);
  // money (1.4) vs compliance serious (2.4) → 2.4 wins
  assertEquals(impactFactor({ moneyAtStakeMinor: 1_00, impactClass: "serious" }), 2.4);
  assertEquals(impactFactor({}), 1.0);
});

Deno.test("ageBoost: ramps from 1.0 to a 1.5 cap over 14 days", () => {
  assertEquals(ageBoostFactor({}), 1.0);
  assertEquals(ageBoostFactor({ waitingDays: 0 }), 1.0);
  assertEquals(ageBoostFactor({ waitingDays: 7 }), 1.25);
  assertEquals(ageBoostFactor({ waitingDays: 14 }), 1.5);
  assertEquals(ageBoostFactor({ waitingDays: 100 }), 1.5); // capped
});

Deno.test("learned weight is clamped and defaults to neutral", () => {
  assertEquals(clampLearnedWeight(undefined), DEFAULT_LEARNED_WEIGHT);
  assertEquals(clampLearnedWeight(5), MAX_LEARNED_WEIGHT);
  assertEquals(clampLearnedWeight(0.01), MIN_LEARNED_WEIGHT);
  assertEquals(clampLearnedWeight(Number.NaN), DEFAULT_LEARNED_WEIGHT);
});

Deno.test("normalizeScore maps onto a 0–100 scale calibrated to the reachable neutral band", () => {
  assertEquals(normalizeScore(1.0), 0); // RAW_MIN
  assertEquals(normalizeScore(9.0), 100); // reachable RAW_MAX (max urgency × max impact)
  assertEquals(normalizeScore(0.5), 0); // below-neutral (down-weighted) clamps to 0
  assertEquals(normalizeScore(13.5), 100); // age-boosted/up-weighted amplifier → clamps to 100
  assert(normalizeScore(5) > 0 && normalizeScore(5) < 100);
});

Deno.test("P1-4: a maximally-severe item reaches the critical band WITHOUT waitingDays", () => {
  // Regression guard: previously ageBoost was pinned at 1.0 (no generator sets
  // waitingDays) so the ceiling was 64 and counts.critical was always 0.
  const overdueCritical = scorePriorityItem(
    item({ factors: { dueInDays: -1, impactClass: "critical" } }),
  );
  assert(overdueCritical.score >= 75, `expected >=75, got ${overdueCritical.score}`);
  // A high-impact due-soon item is also critical.
  const dueSoonBig = scorePriorityItem(
    item({ factors: { dueInDays: 0, moneyAtStakeMinor: 100_000_00 } }),
  );
  assert(dueSoonBig.score >= 75, `expected >=75, got ${dueSoonBig.score}`);
});

// ─── scorePriorityItem ───────────────────────────────────────────────────────

Deno.test("scorePriorityItem is deterministic and exposes every factor", () => {
  const a = scorePriorityItem(item({ factors: { dueInDays: 1, moneyAtStakeMinor: 100_000_00 } }));
  const b = scorePriorityItem(item({ factors: { dueInDays: 1, moneyAtStakeMinor: 100_000_00 } }));
  assertEquals(a.rawScore, b.rawScore);
  assertEquals(a.factorBreakdown.urgency, 2.4);
  assertEquals(a.factorBreakdown.impact, 3.0);
  assertEquals(a.factorBreakdown.ageBoost, 1.0);
  assertEquals(a.factorBreakdown.learnedWeight, 1.0);
  assertEquals(a.rawScore, 7.2);
  // rawScore is exactly the product of the four exposed factors (explainable).
  assertEquals(
    a.rawScore,
    Math.round(
      a.factorBreakdown.urgency * a.factorBreakdown.impact *
        a.factorBreakdown.ageBoost * a.factorBreakdown.learnedWeight * 100,
    ) / 100,
  );
});

Deno.test("learned weight tilts the score without changing the other factors", () => {
  const base = scorePriorityItem(item({ type: "follow_up", factors: { impactClass: "serious" } }));
  const up = scorePriorityItem(
    item({ type: "follow_up", factors: { impactClass: "serious" } }),
    { follow_up: 2.0 },
  );
  assertEquals(up.factorBreakdown.impact, base.factorBreakdown.impact);
  assertEquals(up.rawScore, base.rawScore * 2);
});

Deno.test("reason names the dominant driver", () => {
  assertEquals(scorePriorityItem(item({ factors: { dueInDays: -1 } })).reason, "overdue");
  assertEquals(scorePriorityItem(item({ factors: { dueInDays: 1 } })).reason, "due tomorrow");
  assertEquals(
    scorePriorityItem(item({ factors: { waitingDays: 10 } })).reason,
    "waiting 10 days",
  );
  assertEquals(
    scorePriorityItem(item({ factors: { impactClass: "critical" } })).reason,
    "critical severity",
  );
});

// ─── buildFeed ───────────────────────────────────────────────────────────────

Deno.test("buildFeed filters by persona relevance", () => {
  const items = [
    item({ itemKey: "a", personas: ["principal"] }),
    item({ itemKey: "b", personas: ["finance"] }),
  ];
  const feed = buildFeed(items, "finance", NOW);
  assertEquals(feed.items.map((i) => i.itemKey), ["b"]);
});

Deno.test("buildFeed dedupes by itemKey (deterministic first-wins)", () => {
  const items = [
    item({ itemKey: "dup", detail: "x" }),
    item({ itemKey: "dup", detail: "y" }),
  ];
  const feed = buildFeed(items, "principal", NOW);
  assertEquals(feed.items.length, 1);
});

Deno.test("buildFeed drops dismissed keys", () => {
  const items = [item({ itemKey: "keep" }), item({ itemKey: "gone" })];
  const feed = buildFeed(items, "principal", NOW, { dismissedKeys: new Set(["gone"]) });
  assertEquals(feed.items.map((i) => i.itemKey), ["keep"]);
});

Deno.test("buildFeed sorts by score desc with a stable itemKey tie-break", () => {
  const items = [
    item({ itemKey: "low", factors: { impactClass: "routine" } }),
    item({ itemKey: "high", factors: { dueInDays: -1, impactClass: "critical" } }),
    // two identical-score items → tie-break by itemKey ascending
    item({ itemKey: "z-tie", factors: { impactClass: "elevated" } }),
    item({ itemKey: "a-tie", factors: { impactClass: "elevated" } }),
  ];
  const feed = buildFeed(items, "principal", NOW);
  assertEquals(feed.items[0].itemKey, "high");
  const ties = feed.items.filter((i) => i.itemKey.endsWith("-tie")).map((i) => i.itemKey);
  assertEquals(ties, ["a-tie", "z-tie"]);
});

Deno.test("buildFeed honours the limit and reports counts", () => {
  const items = Array.from({ length: 30 }, (_, i) =>
    item({ itemKey: `k${i}`, type: i % 2 ? "exception" : "follow_up" }));
  const feed = buildFeed(items, "principal", NOW, { limit: 5 });
  assertEquals(feed.items.length, 5);
  assertEquals(feed.counts.total, 5);
  assertEquals(
    (feed.counts.byType.exception ?? 0) + (feed.counts.byType.follow_up ?? 0),
    5,
  );
});

Deno.test("buildFeed counts a >=75 score as critical", () => {
  const items = [
    // Severity alone reaches critical (no waitingDays crutch) after P1-4.
    item({ itemKey: "crit", factors: { dueInDays: -1, impactClass: "critical" } }),
    item({ itemKey: "calm", factors: { impactClass: "routine" } }),
  ];
  const feed = buildFeed(items, "principal", NOW);
  const crit = feed.items.find((i) => i.itemKey === "crit")!;
  assert(crit.score >= 75);
  assertEquals(feed.counts.critical, 1);
});
