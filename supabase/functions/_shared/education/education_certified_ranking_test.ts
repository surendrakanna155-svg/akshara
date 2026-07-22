import {
  assert,
  assertAlmostEquals,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  DEFAULT_WEIGHTS,
  rankCertified,
  type RankItem,
} from "./education_certified_ranking.ts";

function sumTrace(trace: Record<string, number>): number {
  // Fixed order matching the module's summation.
  return (
    trace.usage +
    trace.recency +
    trace.difficulty +
    trace.rotation +
    trace.importance
  );
}

Deno.test("rankCertified: reproducible order and scores (same inputs)", () => {
  const items: RankItem[] = [
    { id: "q1", signals: { timesUsed: 3, importance: 0.5 } },
    { id: "q2", signals: { timesUsed: 0, importance: 0.9 } },
    { id: "q3", signals: { timesUsed: 1, importance: 0.2 } },
  ];
  const a = rankCertified(items);
  const b = rankCertified(items);
  assertEquals(a, b);
});

Deno.test("rankCertified: prefer-unseen — lower timesUsed ranks higher", () => {
  const items: RankItem[] = [
    { id: "used", signals: { timesUsed: 10 } },
    { id: "fresh", signals: { timesUsed: 0 } },
  ];
  const ranked = rankCertified(items);
  assertEquals(ranked[0].id, "fresh");
  assertEquals(ranked[1].id, "used");
  assert(ranked[0].score > ranked[1].score);
});

Deno.test("rankCertified: prefer-older — older lastUsed ranks higher", () => {
  const now = 1_000 * 86_400_000; // day 1000 in ms
  const items: RankItem[] = [
    { id: "recent", signals: { timesUsed: 1, lastUsedAtMs: now - 1 * 86_400_000 } },
    { id: "old", signals: { timesUsed: 1, lastUsedAtMs: now - 365 * 86_400_000 } },
  ];
  const ranked = rankCertified(items, { nowMs: now });
  assertEquals(ranked[0].id, "old");
  assertEquals(ranked[1].id, "recent");
});

Deno.test("rankCertified: never-used item scores max recency", () => {
  const now = 500 * 86_400_000;
  const items: RankItem[] = [
    { id: "never", signals: { timesUsed: 1, lastUsedAtMs: null } },
    { id: "aged", signals: { timesUsed: 1, lastUsedAtMs: now - 10 * 86_400_000 } },
  ];
  const ranked = rankCertified(items, { nowMs: now });
  const never = ranked.find((r) => r.id === "never")!;
  const aged = ranked.find((r) => r.id === "aged")!;
  assertAlmostEquals(never.trace.recency, DEFAULT_WEIGHTS.recency, 1e-12);
  assert(never.trace.recency > aged.trace.recency);
});

Deno.test("rankCertified: trace terms sum exactly to score", () => {
  const items: RankItem[] = [
    {
      id: "q1",
      signals: {
        timesUsed: 2,
        lastUsedAtMs: 5 * 86_400_000,
        difficultyCalibration: "well-calibrated",
        rotationCooldownDays: 3,
        importance: 0.7,
      },
    },
    {
      id: "q2",
      signals: {
        timesUsed: 0,
        lastUsedAtMs: null,
        difficultyCalibration: "unknown-label",
        rotationCooldownDays: 0,
        importance: 0.3,
      },
    },
  ];
  const ranked = rankCertified(items, { nowMs: 30 * 86_400_000 });
  for (const r of ranked) {
    assertEquals(sumTrace(r.trace), r.score);
    assert(r.score >= 0 && r.score <= 1);
  }
});

Deno.test("rankCertified: difficulty calibration is explainable and ordered", () => {
  const items: RankItem[] = [
    { id: "good", signals: { difficultyCalibration: "well-calibrated" } },
    { id: "bad", signals: { difficultyCalibration: "over-exposed" } },
  ];
  const ranked = rankCertified(items);
  const good = ranked.find((r) => r.id === "good")!;
  const bad = ranked.find((r) => r.id === "bad")!;
  assert(good.trace.difficulty > bad.trace.difficulty);
  assertEquals(ranked[0].id, "good");
});

Deno.test("rankCertified: rotation cooldown deprioritises items still cooling down", () => {
  const items: RankItem[] = [
    { id: "eligible", signals: { rotationCooldownDays: 0 } },
    { id: "cooling", signals: { rotationCooldownDays: 14 } },
  ];
  const ranked = rankCertified(items);
  assertEquals(ranked[0].id, "eligible");
  const eligible = ranked.find((r) => r.id === "eligible")!;
  const cooling = ranked.find((r) => r.id === "cooling")!;
  assert(eligible.trace.rotation > cooling.trace.rotation);
});

Deno.test("rankCertified: tie-break by id ascending (stable)", () => {
  // Identical signals -> identical score -> deterministic id order.
  const items: RankItem[] = [
    { id: "zebra", signals: { timesUsed: 1, importance: 0.5 } },
    { id: "alpha", signals: { timesUsed: 1, importance: 0.5 } },
    { id: "mango", signals: { timesUsed: 1, importance: 0.5 } },
  ];
  const ranked = rankCertified(items);
  assertEquals(ranked.map((r) => r.id), ["alpha", "mango", "zebra"]);
  assertEquals(ranked[0].score, ranked[1].score);
  assertEquals(ranked[1].score, ranked[2].score);
});

Deno.test("rankCertified: no Date.now — now supplied via ctx changes recency deterministically", () => {
  const item: RankItem[] = [
    { id: "q", signals: { timesUsed: 1, lastUsedAtMs: 0 } },
  ];
  const early = rankCertified(item, { nowMs: 1 * 86_400_000 });
  const late = rankCertified(item, { nowMs: 400 * 86_400_000 });
  // Older relative to a later "now" -> higher recency contribution.
  assert(late[0].trace.recency > early[0].trace.recency);
  // And each call is itself reproducible.
  assertEquals(rankCertified(item, { nowMs: 400 * 86_400_000 }), late);
});

Deno.test("rankCertified: weight overrides via ctx are honoured", () => {
  const items: RankItem[] = [{ id: "q", signals: { timesUsed: 0 } }];
  const base = rankCertified(items)[0];
  const boosted = rankCertified(items, { weights: { usage: 1 } })[0];
  // usageScore(0) = 1, so usage term equals the weight.
  assertAlmostEquals(base.trace.usage, DEFAULT_WEIGHTS.usage, 1e-12);
  assertAlmostEquals(boosted.trace.usage, 1, 1e-12);
});

Deno.test("rankCertified: empty input -> empty output", () => {
  assertEquals(rankCertified([]), []);
});
