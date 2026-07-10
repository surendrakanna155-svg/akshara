// Adaptive AI — P3-AI-2 / W2.0b: Persona Memory repository (design doc 03 §2.2).
//
// Activates the dormant `ai_persona_memory` schema (migration 20260868) as the
// accept/dismiss learning + preference substrate for the Recommendation Engine
// (doc 04 §4 learning loop P12). One row per (org, school, user); RLS scopes it
// to the current user (user_id = app_current_user_id()). Holds ONLY facts and
// preferences — never model output. The learning math is PURE (fully unit-tested
// below); the DB layer is a thin read-modify-write upsert (single-user row, no
// contention). Deterministic, zero model calls.

import type { TenantQueryClient } from "../tenant_db.ts";
import {
  clampLearnedWeight,
  DEFAULT_LEARNED_WEIGHT,
} from "../intelligence/priority/priority_engine.ts";
import type { LearnedWeights, PriorityItemType } from "../intelligence/priority/priority_types.ts";

export interface PersonaMemoryScope {
  organizationId: string;
  schoolId: string;
  userId: string;
}

/** Per-item-type accept/dismiss/suppress tallies — the learning signal. */
export interface FeedbackCounters {
  accepted: number;
  dismissed: number;
  suppressed: number;
}

export interface PersonaMemory {
  /** UI preferences; W2.0b uses `dismissedKeys` (item keys hidden by the user). */
  preferences: { dismissedKeys?: string[] } & Record<string, unknown>;
  /** Per-item-type feedback tallies → learned weights. */
  recommendationFeedback: Partial<Record<PriorityItemType, FeedbackCounters>>;
  /** Reserved for usage-frequency learning (dashboard reorder, doc 04 §5). */
  usageStats: Record<string, unknown>;
}

export type FeedbackAction = "accept" | "dismiss" | "suppress";

export interface FeedbackInput {
  itemKey: string;
  itemType: PriorityItemType;
  action: FeedbackAction;
}

// ─── Pure logic (DB-free, unit-tested) ───────────────────────────────────────

export function emptyPersonaMemory(): PersonaMemory {
  return { preferences: {}, recommendationFeedback: {}, usageStats: {} };
}

function counters(m: PersonaMemory, type: PriorityItemType): FeedbackCounters {
  return m.recommendationFeedback[type] ?? { accepted: 0, dismissed: 0, suppressed: 0 };
}

/** Apply one feedback event, returning a NEW memory (pure, idempotent shape).
 * - accept  → the item type is more welcome (weight ↑)
 * - dismiss → this item hidden + the type slightly less welcome (weight ↓)
 * - suppress ("don't show again") → the type strongly down-weighted (class sink)
 */
export function applyFeedback(memory: PersonaMemory, input: FeedbackInput): PersonaMemory {
  const c = { ...counters(memory, input.itemType) };
  if (input.action === "accept") c.accepted += 1;
  else if (input.action === "dismiss") c.dismissed += 1;
  else c.suppressed += 1;

  const dismissedKeys = new Set(memory.preferences.dismissedKeys ?? []);
  // dismiss/suppress hide THIS item; accept clears any prior hide of it.
  if (input.action === "accept") dismissedKeys.delete(input.itemKey);
  else dismissedKeys.add(input.itemKey);

  return {
    preferences: { ...memory.preferences, dismissedKeys: [...dismissedKeys].sort() },
    recommendationFeedback: { ...memory.recommendationFeedback, [input.itemType]: c },
    usageStats: memory.usageStats,
  };
}

/** Item keys the user has hidden (dismissed/suppressed). */
export function dismissedKeysOf(memory: PersonaMemory): Set<string> {
  return new Set(memory.preferences.dismissedKeys ?? []);
}

/** Derive a bounded per-item-type learned weight from the feedback tallies.
 * net = accepted − dismissed − 2·suppressed; weight = clamp(1 + 0.1·net, 0.5, 2).
 * Deterministic and explainable: every weight is a function of counted events. */
export function deriveLearnedWeights(memory: PersonaMemory): LearnedWeights {
  const weights: LearnedWeights = {};
  for (const [type, c] of Object.entries(memory.recommendationFeedback)) {
    if (!c) continue;
    const net = c.accepted - c.dismissed - 2 * c.suppressed;
    const w = clampLearnedWeight(DEFAULT_LEARNED_WEIGHT + 0.1 * net);
    if (w !== DEFAULT_LEARNED_WEIGHT) weights[type as PriorityItemType] = w;
  }
  return weights;
}

// ─── DB layer (thin read-modify-write) ───────────────────────────────────────

interface PersonaMemoryRow {
  preferences: PersonaMemory["preferences"];
  recommendation_feedback: PersonaMemory["recommendationFeedback"];
  usage_stats: Record<string, unknown>;
}

/** Read the current user's persona memory (RLS-scoped); empty default if none. */
export async function getPersonaMemory(
  db: TenantQueryClient,
  scope: PersonaMemoryScope,
): Promise<PersonaMemory> {
  const rows = await db.queryObject<PersonaMemoryRow>(
    `SELECT preferences, recommendation_feedback, usage_stats
       FROM ai_persona_memory
      WHERE organization_id = $1 AND school_id = $2 AND user_id = $3
      LIMIT 1`,
    [scope.organizationId, scope.schoolId, scope.userId],
  );
  const row = rows[0];
  if (!row) return emptyPersonaMemory();
  return {
    preferences: row.preferences ?? {},
    recommendationFeedback: row.recommendation_feedback ?? {},
    usageStats: row.usage_stats ?? {},
  };
}

/** Record one feedback event: read → apply (pure) → upsert. Returns the new
 * memory so the caller can echo the resulting learned weight. */
export async function recordRecommendationFeedback(
  db: TenantQueryClient,
  scope: PersonaMemoryScope,
  input: FeedbackInput,
): Promise<PersonaMemory> {
  const current = await getPersonaMemory(db, scope);
  const next = applyFeedback(current, input);
  await db.queryObject(
    `INSERT INTO ai_persona_memory (
       organization_id, school_id, user_id,
       preferences, recommendation_feedback, usage_stats, updated_at
     ) VALUES ($1,$2,$3,$4::jsonb,$5::jsonb,$6::jsonb, timezone('utc', now()))
     ON CONFLICT (organization_id, school_id, user_id) DO UPDATE SET
       preferences = EXCLUDED.preferences,
       recommendation_feedback = EXCLUDED.recommendation_feedback,
       usage_stats = EXCLUDED.usage_stats,
       updated_at = timezone('utc', now())`,
    [
      scope.organizationId,
      scope.schoolId,
      scope.userId,
      JSON.stringify(next.preferences),
      JSON.stringify(next.recommendationFeedback),
      JSON.stringify(next.usageStats),
    ],
  );
  return next;
}
