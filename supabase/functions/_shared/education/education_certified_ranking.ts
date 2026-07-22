// Explainable ranking engine for certified question-bank items.
//
// PURE · DETERMINISTIC · EXPLAINABLE.
//
// Ranks a set of already-certified items by a weighted LINEAR score over four
// signal buckets. Every item returns a per-term numeric `trace`; the item `score`
// is exactly the sum of its trace terms, summed in a fixed order — so the score is
// always reproducible AND auditable ("why did this rank here?").
//
// No randomness. No Date.now(): any notion of "now" is supplied via `ctx.nowMs`.
// Same inputs -> identical order and identical scores.

/** Raw ranking signals for a single item (all optional; sensible neutral defaults). */
export interface RankSignals {
  /** How many times this item has been used/exposed. Lower is preferred. */
  timesUsed?: number;
  /** Epoch-ms of the last use, or null/undefined if never used. Older is preferred. */
  lastUsedAtMs?: number | null;
  /**
   * Calibration status of the item's difficulty. Well-calibrated items are
   * preferred over under/over-exposed or uncalibrated ones. Unknown -> neutral.
   */
  difficultyCalibration?: string;
  /**
   * Remaining rotation-cooldown in days (0 = fully eligible). More days remaining
   * lowers the score so items still cooling down are deprioritised.
   */
  rotationCooldownDays?: number;
  /** Editorial/curriculum importance in [0, 1] (clamped). Higher is preferred. */
  importance?: number;
}

export interface RankItem {
  id: string;
  signals: RankSignals;
}

/** Relative weights for each signal bucket. Default weights sum to 1. */
export interface RankWeights {
  usage: number;
  recency: number;
  difficulty: number;
  rotation: number;
  importance: number;
}

export interface RankContext {
  /**
   * "Now" in epoch-ms, used to age `lastUsedAtMs`. Defaults to 0 (so items with a
   * lastUsedAtMs and no supplied now are treated as freshly used -> min recency).
   * Items that were never used (null) score max recency regardless of now.
   */
  nowMs?: number;
  /** Optional weight overrides; unspecified weights fall back to DEFAULT_WEIGHTS. */
  weights?: Partial<RankWeights>;
}

export interface RankedItem {
  id: string;
  score: number;
  /** Per-term weighted contributions; sums (in fixed order) to `score`. */
  trace: Record<string, number>;
}

export const DEFAULT_WEIGHTS: RankWeights = {
  usage: 0.35,
  recency: 0.20,
  difficulty: 0.15,
  rotation: 0.15,
  importance: 0.15,
};

/** Half-life (days) governing how quickly the recency term climbs toward 1. */
const RECENCY_HALFLIFE_DAYS = 30;
const MS_PER_DAY = 86_400_000;

/**
 * Deterministic calibration-status -> [0,1] score. Unknown/empty maps to a neutral
 * 0.5 so uncategorised items are neither rewarded nor penalised.
 */
const DIFFICULTY_CALIBRATION_SCORE: Readonly<Record<string, number>> = {
  "well-calibrated": 1.0,
  "calibrated": 1.0,
  "under-exposed": 0.75,
  "under-calibrated": 0.5,
  "over-exposed": 0.25,
  "uncalibrated": 0.25,
};
const DIFFICULTY_NEUTRAL = 0.5;

function clamp01(n: number): number {
  if (Number.isNaN(n)) return 0;
  if (n < 0) return 0;
  if (n > 1) return 1;
  return n;
}

/** Prefer-unseen by usage count: timesUsed 0 -> 1, grows down monotonically. */
function usageScore(timesUsed: number): number {
  const t = timesUsed > 0 ? timesUsed : 0;
  return 1 / (1 + t);
}

/**
 * Prefer-older by last-use: never-used -> 1; otherwise climbs from 0 (just used)
 * toward 1 as the item ages, with a fixed half-life. age is clamped >= 0.
 */
function recencyScore(lastUsedAtMs: number | null | undefined, nowMs: number): number {
  if (lastUsedAtMs === null || lastUsedAtMs === undefined) return 1;
  const ageMs = nowMs - lastUsedAtMs;
  const ageDays = ageMs > 0 ? ageMs / MS_PER_DAY : 0;
  return ageDays / (ageDays + RECENCY_HALFLIFE_DAYS);
}

function difficultyScore(calibration: string | undefined): number {
  if (calibration === undefined) return DIFFICULTY_NEUTRAL;
  const key = calibration.trim().toLowerCase();
  const mapped = DIFFICULTY_CALIBRATION_SCORE[key];
  return mapped === undefined ? DIFFICULTY_NEUTRAL : mapped;
}

/** More cooldown days remaining -> lower score. 0 days -> 1 (fully eligible). */
function rotationScore(cooldownDays: number | undefined): number {
  const d = cooldownDays !== undefined && cooldownDays > 0 ? cooldownDays : 0;
  return 1 / (1 + d);
}

function importanceScore(importance: number | undefined): number {
  return importance === undefined ? 0 : clamp01(importance);
}

/**
 * Rank certified items by a deterministic, explainable weighted-linear score.
 *
 * Sorted by `score` descending; ties broken by `id` ascending (stable). Each item
 * carries a `trace` whose weighted terms sum (in the fixed order below) to `score`.
 */
export function rankCertified(items: RankItem[], ctx?: RankContext): RankedItem[] {
  const nowMs = ctx?.nowMs ?? 0;
  const w: RankWeights = { ...DEFAULT_WEIGHTS, ...(ctx?.weights ?? {}) };

  const ranked: RankedItem[] = items.map((item) => {
    const s = item.signals;

    const usage = w.usage * usageScore(s.timesUsed ?? 0);
    const recency = w.recency * recencyScore(s.lastUsedAtMs, nowMs);
    const difficulty = w.difficulty * difficultyScore(s.difficultyCalibration);
    const rotation = w.rotation * rotationScore(s.rotationCooldownDays);
    const importance = w.importance * importanceScore(s.importance);

    // Fixed summation order — keeps `score` bit-for-bit reproducible and exactly
    // equal to the sum of the trace terms.
    const score = usage + recency + difficulty + rotation + importance;

    return {
      id: item.id,
      score,
      trace: { usage, recency, difficulty, rotation, importance },
    };
  });

  ranked.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
  });

  return ranked;
}
