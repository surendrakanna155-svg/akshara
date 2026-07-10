// Adaptive AI — P3-AI-2 / W2.0a: the Priority Engine scorer (design doc 04 §3.2).
//
// PURE + deterministic + clock-free: it takes measured PriorityFactors and
// learned weights and produces an explainable score. No DB, no model calls, no
// `Date` — generators do all clock work and hand the engine plain numbers, so
// scoring is trivially unit-testable and idempotent (same inputs → same feed).
//
// Formula (doc 04 §3.2): score = urgency × impact × age_boost × learned_weight.
// Every factor is returned in the breakdown so the UI can always answer
// "why is this first?" (explainability rail, doc 01 §6).

import type {
  ImpactClass,
  LearnedWeights,
  Persona,
  PriorityFactorBreakdown,
  PriorityFactors,
  PriorityItemType,
  RawPriorityItem,
  ScoredPriorityItem,
} from "./priority_types.ts";

/** Neutral weight for an item type with no learned signal yet. */
export const DEFAULT_LEARNED_WEIGHT = 1.0;
/** Learned weight is clamped so accept/dismiss can tune but never fully
 * suppress or explode an item type (bounded adaptivity, doc 04 §5). */
export const MIN_LEARNED_WEIGHT = 0.5;
export const MAX_LEARNED_WEIGHT = 2.0;

// Factor ranges (kept as named constants so the normalization below stays exact).
const URGENCY_MIN = 1.0;
const URGENCY_MAX = 3.0;
const IMPACT_MIN = 1.0;
const IMPACT_MAX = 3.0;
const AGE_MIN = 1.0;
const AGE_MAX = 1.5;

// The 0–100 display scale is calibrated to the NEUTRAL (default-weight) band so
// an un-learned feed still spans the full range and the ≥75 "critical" band is
// reachable. Learning (weight 0.5–2.0) then pushes items past these bounds and
// clamps — i.e. a down-weighted item sinks toward 0, an up-weighted one pins 100.
const RAW_MIN = URGENCY_MIN * IMPACT_MIN * AGE_MIN * DEFAULT_LEARNED_WEIGHT; // 1.0
const RAW_MAX = URGENCY_MAX * IMPACT_MAX * AGE_MAX * DEFAULT_LEARNED_WEIGHT; // 13.5

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

function clamp(n: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, n));
}

const IMPACT_CLASS_SCORE: Record<ImpactClass, number> = {
  routine: 1.2,
  elevated: 1.8,
  serious: 2.4,
  critical: 3.0,
};

/** Urgency (1..3): a deadline dominates; absent a due date, severity carries it. */
export function urgencyFactor(f: PriorityFactors): number {
  if (typeof f.dueInDays === "number") {
    if (f.dueInDays <= 0) return URGENCY_MAX; // due / overdue
    if (f.dueInDays <= 2) return 2.4;
    if (f.dueInDays <= 7) return 1.8;
    if (f.dueInDays <= 14) return 1.4;
    return URGENCY_MIN;
  }
  if (f.impactClass) {
    // No clock — let severity stand in for urgency (a critical exception is
    // urgent by nature). Half the compliance scale, floored at URGENCY_MIN.
    return clamp(IMPACT_CLASS_SCORE[f.impactClass], URGENCY_MIN, URGENCY_MAX);
  }
  return URGENCY_MIN;
}

/** Impact (1..3): the largest of money, people-affected, and compliance class. */
export function impactFactor(f: PriorityFactors): number {
  let impact = IMPACT_MIN;

  if (typeof f.moneyAtStakeMinor === "number" && f.moneyAtStakeMinor > 0) {
    // ₹ tiers (paise): ≥₹1L → 3, ≥₹25k → 2.4, ≥₹5k → 1.8, else 1.4.
    const rupees = f.moneyAtStakeMinor / 100;
    const moneyImpact = rupees >= 100_000
      ? 3.0
      : rupees >= 25_000
      ? 2.4
      : rupees >= 5_000
      ? 1.8
      : 1.4;
    impact = Math.max(impact, moneyImpact);
  }

  if (typeof f.peopleAffected === "number" && f.peopleAffected > 0) {
    const p = f.peopleAffected;
    const peopleImpact = p >= 50 ? 3.0 : p >= 15 ? 2.4 : p >= 5 ? 1.8 : 1.4;
    impact = Math.max(impact, peopleImpact);
  }

  if (f.impactClass) {
    impact = Math.max(impact, IMPACT_CLASS_SCORE[f.impactClass]);
  }

  return clamp(impact, IMPACT_MIN, IMPACT_MAX);
}

/** Age boost (1..1.5): the longer something waits unresolved, the more it rises
 * (an approval nobody has touched in two weeks climbs above a fresh one). */
export function ageBoostFactor(f: PriorityFactors): number {
  const waited = typeof f.waitingDays === "number" ? Math.max(0, f.waitingDays) : 0;
  if (waited <= 0) return AGE_MIN;
  // Linear ramp: +0.5 across 14 days, capped.
  return clamp(AGE_MIN + (waited / 14) * (AGE_MAX - AGE_MIN), AGE_MIN, AGE_MAX);
}

export function clampLearnedWeight(w: number | undefined): number {
  if (typeof w !== "number" || !Number.isFinite(w)) return DEFAULT_LEARNED_WEIGHT;
  return clamp(w, MIN_LEARNED_WEIGHT, MAX_LEARNED_WEIGHT);
}

/** Map the raw multiplicative score onto a stable 0–100 display scale. */
export function normalizeScore(rawScore: number): number {
  const pct = ((rawScore - RAW_MIN) / (RAW_MAX - RAW_MIN)) * 100;
  return Math.round(clamp(pct, 0, 100));
}

/** The dominant driver, for the "why is this first?" reason line. */
function dominantFactorReason(
  item: RawPriorityItem,
  b: PriorityFactorBreakdown,
): string {
  const f = item.factors;
  // Deadline first: it is the most actionable explanation when present.
  if (typeof f.dueInDays === "number") {
    if (f.dueInDays <= 0) return "overdue";
    if (f.dueInDays === 1) return "due tomorrow";
    if (f.dueInDays <= 7) return `due in ${f.dueInDays} days`;
  }
  if (typeof f.waitingDays === "number" && f.waitingDays >= 2 && b.ageBoost >= 1.2) {
    return `waiting ${Math.round(f.waitingDays)} days`;
  }
  if (typeof f.moneyAtStakeMinor === "number" && f.moneyAtStakeMinor > 0 && b.impact >= 2.4) {
    return `₹${Math.round(f.moneyAtStakeMinor / 100).toLocaleString("en-IN")} at stake`;
  }
  if (typeof f.peopleAffected === "number" && f.peopleAffected >= 5 && b.impact >= 1.8) {
    return `${f.peopleAffected} affected`;
  }
  if (f.impactClass === "critical") return "critical severity";
  if (f.impactClass === "serious") return "high severity";
  return "elevated priority";
}

/** Score one item; returns the item enriched with its factor breakdown, a
 * normalized 0–100 score, and a human reason. Deterministic. */
export function scorePriorityItem(
  item: RawPriorityItem,
  weights: LearnedWeights = {},
): ScoredPriorityItem {
  const breakdown: PriorityFactorBreakdown = {
    urgency: round2(urgencyFactor(item.factors)),
    impact: round2(impactFactor(item.factors)),
    ageBoost: round2(ageBoostFactor(item.factors)),
    learnedWeight: round2(clampLearnedWeight(weights[item.type])),
  };
  const rawScore = round2(
    breakdown.urgency * breakdown.impact * breakdown.ageBoost * breakdown.learnedWeight,
  );
  return {
    ...item,
    factorBreakdown: breakdown,
    rawScore,
    score: normalizeScore(rawScore),
    reason: dominantFactorReason(item, breakdown),
  };
}

export interface BuildFeedOptions {
  /** Per-item-type learned multipliers for this (school, persona). */
  weights?: LearnedWeights;
  /** itemKeys the user dismissed/snoozed — filtered out of the feed. */
  dismissedKeys?: Set<string>;
  /** Max items returned (default 20). */
  limit?: number;
}

/** Turn raw items into a scored, persona-filtered, sorted, deduped feed.
 * Deterministic ordering: score desc, then itemKey asc as a stable tie-break. */
export function buildFeed(
  rawItems: RawPriorityItem[],
  persona: Persona,
  generatedAt: string,
  options: BuildFeedOptions = {},
): {
  persona: Persona;
  generatedAt: string;
  items: ScoredPriorityItem[];
  counts: {
    total: number;
    byType: Partial<Record<PriorityItemType, number>>;
    critical: number;
  };
} {
  const limit = Math.min(100, Math.max(1, Math.trunc(options.limit ?? 20)));
  const dismissed = options.dismissedKeys ?? new Set<string>();

  // 1) persona relevance + dismissed filter
  const relevant = rawItems.filter(
    (it) => it.personas.includes(persona) && !dismissed.has(it.itemKey),
  );

  // 2) dedupe by itemKey (first occurrence wins — generators share keys for the
  // same real-world item; a stable pre-sort by key makes "first" deterministic).
  const byKey = new Map<string, RawPriorityItem>();
  for (const it of [...relevant].sort((a, b) => a.itemKey.localeCompare(b.itemKey))) {
    if (!byKey.has(it.itemKey)) byKey.set(it.itemKey, it);
  }

  // 3) score + sort (score desc, itemKey asc tie-break)
  const scored = [...byKey.values()]
    .map((it) => scorePriorityItem(it, options.weights))
    .sort((a, b) => (b.rawScore - a.rawScore) || a.itemKey.localeCompare(b.itemKey))
    .slice(0, limit);

  const byType: Partial<Record<PriorityItemType, number>> = {};
  let critical = 0;
  for (const it of scored) {
    byType[it.type] = (byType[it.type] ?? 0) + 1;
    if (it.score >= 75) critical++;
  }

  return {
    persona,
    generatedAt,
    items: scored,
    counts: { total: scored.length, byType, critical },
  };
}
