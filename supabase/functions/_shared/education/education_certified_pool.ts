// Program D · M4.3 / M4.4 integration — deterministic certified-pool builder.
//
// Composes the request-time near-dup FILTER (education_near_dup) and the explainable RANKING
// (education_certified_ranking) — both pure, deterministic, offline WP-D modules — over a bank pool plus
// PRECOMPUTED near-dup vectors. The paper service calls this to shape the pool BEFORE the UNCHANGED
// deterministic solver walks it. No model/network call at request time; every choice is explainable.
//
// Order discipline (so the DEFAULT path stays byte-identical): the near-dup step only REMOVES clones — it
// preserves the incoming pool order (it never reorders). Reordering happens ONLY when ranking is enabled.
// With both flags off the input pool is returned untouched.

import { filterNearDups, type NearDupItem } from "./education_near_dup.ts";
import { rankCertified, type RankItem, type RankWeights } from "./education_certified_ranking.ts";
import type { QuestionBankItemRow } from "./education_types.ts";

export interface CertifiedPoolOptions {
  /** M4.3: drop paraphrase/semantic clones (cosine over precomputed vectors; fingerprint fallback). */
  nearDupFilter?: boolean;
  /** M4.4: reorder by the deterministic explainable ranking. */
  rank?: boolean;
  /** Deterministic "now" (ms) for ranking recency — passed in, never Date.now(). */
  nowMs?: number;
  /** Optional ranking weight overrides. */
  weights?: Partial<RankWeights>;
}

export interface CertifiedPoolResult {
  /** The shaped pool, ready for the solver. */
  pool: QuestionBankItemRow[];
  /** Near-dups removed, each with the kept item it duplicated + score + reason (explainability). */
  dropped: Array<{ id: string; similarTo: string; score: number; reason: string }>;
  /** The ranking trace (empty unless `rank`) — per-item score + contributing terms. */
  order: Array<{ id: string; score: number; trace: Record<string, number> }>;
}

function toNearDupItem(row: QuestionBankItemRow, vectors: Map<string, number[]>): NearDupItem {
  const key = row.fingerprint ?? "";
  return {
    id: row.id,
    contentHash: key,
    questionText: row.question_text,
    nearDupEmbedding: vectors.get(key) ?? null,
  };
}

function toRankItem(row: QuestionBankItemRow): RankItem {
  const lastUsed = typeof row.last_used_at === "string" && row.last_used_at.length > 0
    ? Date.parse(row.last_used_at)
    : null;
  return {
    id: row.id,
    signals: {
      timesUsed: typeof row.times_used === "number" ? row.times_used : 0,
      lastUsedAtMs: lastUsed !== null && !Number.isNaN(lastUsed) ? lastUsed : null,
    },
  };
}

/**
 * Build the certified pool deterministically. `vectors` maps a row's `fingerprint` (= content_hash for
 * certified-platform items) to its precomputed near-dup embedding; a row absent from the map falls back to
 * exact-fingerprint dedup inside filterNearDups. Pure — no DB, no model, no wall-clock.
 */
export function buildCertifiedPool(
  rows: QuestionBankItemRow[],
  vectors: Map<string, number[]>,
  opts: CertifiedPoolOptions = {},
): CertifiedPoolResult {
  let working = rows;
  let dropped: CertifiedPoolResult["dropped"] = [];

  if (opts.nearDupFilter) {
    const res = filterNearDups(working.map((r) => toNearDupItem(r, vectors)));
    const keptIds = new Set(res.kept.map((k) => k.id));
    dropped = res.dropped.map((d) => ({
      id: d.item.id,
      similarTo: d.similarTo,
      score: d.score,
      reason: d.reason,
    }));
    working = working.filter((r) => keptIds.has(r.id)); // REMOVE only — preserve incoming order
  }

  let order: CertifiedPoolResult["order"] = [];
  if (opts.rank) {
    order = rankCertified(working.map(toRankItem), { nowMs: opts.nowMs, weights: opts.weights });
    const byId = new Map(working.map((r) => [r.id, r]));
    working = order
      .map((o) => byId.get(o.id))
      .filter((r): r is QuestionBankItemRow => r !== undefined);
  }

  return { pool: working, dropped, order };
}
