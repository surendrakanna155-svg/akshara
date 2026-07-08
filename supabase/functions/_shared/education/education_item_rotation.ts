// CI-C8 — Item exposure / rotation helper (spec v3.0 §10.1 / Phase-1 item 1.9).
// ADDITIVE + policy-gated. Pure, deterministic, ZERO runtime AI, ZERO DB access.
//
// The E1a dormant seed (migration 20260853000000) records item EXPOSURE —
// `edu_item_exposures` (a usage log) + `times_used` / `last_used_at` counters on
// the bank. This module turns those signals into a rotation DECISION under a
// governed `RotationPolicy` (mirrors the dormant `edu_item_rotation_policies`
// table): it rests recently-used items (hard cooldown), caps over-reused items,
// and soft-deprioritises the rest so the certified solver's bank-first walk
// naturally rotates through the bank instead of always re-picking the same items.
//
// Same seam shape as CI-C7's `orderBankForProfile`: this returns a re-ordered /
// filtered COPY of the bank that the caller passes straight to the certified
// `solveBlueprint` / `solveTemplateBlueprint`. The solver itself is UNTOUCHED
// (invariant I1). Two ways behaviour stays byte-identical to the certified path:
//   1. The helper is never called (no policy) — the raw bank goes to the solver.
//   2. The helper is called but no exposure data exists (every item times_used=0,
//      last_used_at=null) and no hard cooldown fires — the canonical (chapter,
//      marks, id) tiebreak reproduces the certified `sortBank` order exactly.
//
// Determinism discipline (mirrors the solver): NO `Date.now()`, NO randomness.
// The cooldown reference instant is an EXPLICIT input (`RotationContext.referenceAt`),
// so the same inputs always yield the same output — testable and auditable.

import type { QuestionBankItemRow } from "./education_types.ts";

// ═════════════════════════════════════════════════════════════════════════════
// Policy config entity (mirrors the dormant `edu_item_rotation_policies` table).
// ═════════════════════════════════════════════════════════════════════════════

/** A rotation-cooldown policy. Every knob is optional — an empty policy is a no-op. */
export interface RotationPolicy {
  /** e.g. 'default' | 'formal_exam' | 'practice' | 'competitive'. */
  code?: string;
  title?: string;
  /**
   * HARD exclusion — an item last used within this many days of the reference
   * instant is skipped (rested). 0 / undefined ⇒ no time cooldown.
   */
  cooldownDays?: number;
  /**
   * HARD exclusion — an item whose exposure count has reached this cap is
   * skipped. 0 / undefined ⇒ uncapped reuse.
   */
  maxTimesUsed?: number;
  /**
   * SOFT rotation — order remaining eligible items least-used / least-recently-
   * used first. Defaults to TRUE (the natural rotation behaviour); set false to
   * keep canonical order and apply only the hard cooldowns above.
   */
  deprioritizeRecent?: boolean;
}

/** Context for the cooldown math — the reference instant, supplied explicitly. */
export interface RotationContext {
  /**
   * The reference instant (ISO-8601) cooldowns are measured against — normally
   * "now" at generation time, passed IN so the helper stays pure/deterministic.
   * Omit and cooldownDays is inert (nothing can be "within N days" of nothing).
   */
  referenceAt?: string;
}

/** Normalised exposure signal for one item (missing counters ⇒ never used). */
export interface ItemExposure {
  timesUsed: number;
  lastUsedAt: string | null;
}

/** Why an item was hard-excluded from selection by the rotation policy. */
export type RotationExclusionReason = "cooldown_days" | "max_times_used";

export interface RotationExclusion {
  itemId: string;
  reason: RotationExclusionReason;
  detail: Record<string, unknown>;
}

const MS_PER_DAY = 86_400_000;

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers.
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Canonical bank comparator — IDENTICAL to `sortBank` in the paper service
 * (chapter, then marks, then id). The deterministic tiebreak so an EMPTY policy
 * (or no exposure) reproduces the certified ordering exactly.
 */
function canonicalCompare(a: QuestionBankItemRow, b: QuestionBankItemRow): number {
  if (a.chapter !== b.chapter) return a.chapter.localeCompare(b.chapter);
  if (a.marks !== b.marks) return a.marks - b.marks;
  return a.id.localeCompare(b.id);
}

/** Read the dormant exposure counters off a bank row; absent ⇒ never used. */
export function itemExposure(item: QuestionBankItemRow): ItemExposure {
  const timesUsed = typeof item.times_used === "number" && item.times_used > 0
    ? item.times_used
    : 0;
  const lastUsedAt = typeof item.last_used_at === "string" && item.last_used_at.length > 0
    ? item.last_used_at
    : null;
  return { timesUsed, lastUsedAt };
}

/** Parse an ISO timestamp to epoch ms, or null when absent/unparseable. Pure. */
function epochMs(iso: string | null | undefined): number | null {
  if (!iso) return null;
  const t = Date.parse(iso);
  return Number.isNaN(t) ? null : t;
}

/**
 * Whether an item is HARD-excluded by the policy at the reference instant.
 * Returns the reason (+ detail) or null when the item stays selectable. Pure.
 */
export function rotationExclusion(
  policy: RotationPolicy,
  item: QuestionBankItemRow,
  ctx: RotationContext = {},
): RotationExclusion | null {
  const { timesUsed, lastUsedAt } = itemExposure(item);

  // Reuse cap — deterministic, needs no reference instant.
  if (typeof policy.maxTimesUsed === "number" && policy.maxTimesUsed > 0) {
    if (timesUsed >= policy.maxTimesUsed) {
      return {
        itemId: item.id,
        reason: "max_times_used",
        detail: { timesUsed, maxTimesUsed: policy.maxTimesUsed },
      };
    }
  }

  // Time cooldown — only meaningful with BOTH a reference instant and a last-use.
  if (typeof policy.cooldownDays === "number" && policy.cooldownDays > 0) {
    const ref = epochMs(ctx.referenceAt);
    const used = epochMs(lastUsedAt);
    if (ref !== null && used !== null) {
      const ageDays = (ref - used) / MS_PER_DAY;
      // Used in the future relative to ref (clock skew) counts as "just used".
      if (ageDays < policy.cooldownDays) {
        return {
          itemId: item.id,
          reason: "cooldown_days",
          detail: { lastUsedAt, referenceAt: ctx.referenceAt, ageDays, cooldownDays: policy.cooldownDays },
        };
      }
    }
  }

  return null;
}

/** Every item the policy hard-excludes, in input order (for explainability). */
export function rotationExclusions(
  policy: RotationPolicy,
  bank: QuestionBankItemRow[],
  ctx: RotationContext = {},
): RotationExclusion[] {
  const out: RotationExclusion[] = [];
  for (const item of bank) {
    const ex = rotationExclusion(policy, item, ctx);
    if (ex) out.push(ex);
  }
  return out;
}

/**
 * Rotation ordering key comparator (soft deprioritisation): least-used first,
 * then least-recently-used first (never-used = most eligible), then canonical.
 * A "never used" item (lastUsedAt null) sorts BEFORE any dated one at equal use
 * count, because resting the recently-used spreads exposure.
 */
function rotationCompare(a: QuestionBankItemRow, b: QuestionBankItemRow): number {
  const ea = itemExposure(a);
  const eb = itemExposure(b);
  if (ea.timesUsed !== eb.timesUsed) return ea.timesUsed - eb.timesUsed;

  const ta = epochMs(ea.lastUsedAt);
  const tb = epochMs(eb.lastUsedAt);
  // null (never used) is the freshest → treat as -Infinity so it sorts first.
  const na = ta === null ? Number.NEGATIVE_INFINITY : ta;
  const nb = tb === null ? Number.NEGATIVE_INFINITY : tb;
  if (na !== nb) return na - nb;

  return canonicalCompare(a, b);
}

/**
 * The CI-C8 rotation seam — drop-in for `orderBankForProfile`. Returns a COPY of
 * the bank with hard-cooled-down items REMOVED and the remainder ordered for
 * rotation (least-used / least-recently-used first) when the policy asks for it.
 * Pure — never mutates the input. Pass the result straight to `solveBlueprint`
 * / `solveTemplateBlueprint`; nothing else in the pipeline changes.
 *
 * Byte-identity guarantee: with no hard cooldown firing and no exposure data,
 * `rotationCompare` collapses to `canonicalCompare`, so the solver picks
 * IDENTICALLY to the certified path (invariant I1).
 */
export function orderBankForRotation(
  policy: RotationPolicy,
  bank: QuestionBankItemRow[],
  ctx: RotationContext = {},
): QuestionBankItemRow[] {
  const excluded = new Set(rotationExclusions(policy, bank, ctx).map((e) => e.itemId));
  const eligible = bank.filter((item) => !excluded.has(item.id));

  // deprioritizeRecent defaults to TRUE; only an explicit `false` opts out.
  const soft = policy.deprioritizeRecent !== false;
  return [...eligible].sort(soft ? rotationCompare : canonicalCompare);
}

export interface RotationResult {
  /** Rotation-ordered, cooldown-filtered bank — ready for the solver. */
  bank: QuestionBankItemRow[];
  /** Items removed by a hard cooldown, with the reason (explainability). */
  excluded: RotationExclusion[];
}

/**
 * Convenience wrapper returning BOTH the solver-ready bank and the exclusion
 * report in one pass, so a caller can surface "N items rested for rotation"
 * alongside the generated paper. Pure.
 */
export function applyRotation(
  policy: RotationPolicy,
  bank: QuestionBankItemRow[],
  ctx: RotationContext = {},
): RotationResult {
  return {
    bank: orderBankForRotation(policy, bank, ctx),
    excluded: rotationExclusions(policy, bank, ctx),
  };
}
