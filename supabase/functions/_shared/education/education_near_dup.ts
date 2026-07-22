// Request-time semantic near-duplicate filter for the certified question bank.
//
// PURE · DETERMINISTIC · EXPLAINABLE · OFFLINE-ONLY.
//
// This module NEVER computes an embedding and NEVER calls a model or the network.
// It operates strictly over PRECOMPUTED near-dup vectors (number[128], produced
// offline by the AI/indexing pipeline) using cosine similarity, and falls back to
// an exact content fingerprint (via the shared education_fingerprint module) when
// either item in a pair lacks a vector.
//
// Contract (Program-D Contract-1 §1.3):
//   - near-dup vector = number[128]
//   - request-time near-dup = cosine similarity >= 0.82
//   - threshold version   = "cosine-0.82-v1"
//   - items without a vector fall back to exact fingerprint equality
//
// The type below is intentionally MINIMAL and self-contained so this filter stays
// decoupled from any repository row shape.

import { computeQuestionFingerprint } from "./education_fingerprint.ts";

/** Versioned request-time near-dup threshold (cosine similarity, inclusive). */
export const NEAR_DUP_THRESHOLD = 0.82;

/** Version tag recorded alongside every near-dup verdict for auditability. */
export const NEAR_DUP_VERSION = "cosine-0.82-v1";

/** Minimal, decoupled input shape for the near-dup filter. */
export interface NearDupItem {
  /** Stable identity used for deterministic ordering and tie-breaks. */
  id: string;
  /** Precomputed exact-content hash (fingerprint) for the fallback path. */
  contentHash: string;
  /** Raw question text — used to recompute a fingerprint when contentHash is absent. */
  questionText: string;
  /** Precomputed offline near-dup embedding (number[128]) or null when unavailable. */
  nearDupEmbedding: number[] | null;
}

export interface FilterNearDupsOptions {
  /**
   * Override the cosine threshold (defaults to {@link NEAR_DUP_THRESHOLD}).
   * Provided for testing / calibrated re-runs; production uses the versioned const.
   */
  threshold?: number;
}

export interface DroppedNearDup {
  /** The item that was removed from the kept set. */
  item: NearDupItem;
  /** The id of the already-kept item this was a near-dup of. */
  similarTo: string;
  /** Cosine score (vector path) or 1 for an exact fingerprint match. */
  score: number;
  /** Human-readable, auditable explanation of why it was dropped. */
  reason: string;
}

export interface FilterNearDupsResult {
  kept: NearDupItem[];
  dropped: DroppedNearDup[];
}

/**
 * Deterministic cosine similarity of two equal-length numeric vectors.
 *
 * - identical vectors     -> 1
 * - orthogonal vectors    -> 0
 * - zero-magnitude input  -> 0 (avoids NaN; a vector with no magnitude carries
 *   no directional signal and is treated as maximally dissimilar)
 *
 * Operations run in a fixed order so the same inputs always yield the same
 * floating-point result.
 */
export function cosine(a: number[], b: number[]): number {
  if (a.length !== b.length) {
    throw new Error(
      `cosine: vector length mismatch (${a.length} !== ${b.length})`,
    );
  }
  let dot = 0;
  let normA = 0;
  let normB = 0;
  for (let i = 0; i < a.length; i++) {
    const x = a[i];
    const y = b[i];
    dot += x * y;
    normA += x * x;
    normB += y * y;
  }
  if (normA === 0 || normB === 0) return 0;
  return dot / (Math.sqrt(normA) * Math.sqrt(normB));
}

/**
 * Deterministic exact-match key for the fingerprint fallback path.
 *
 * Prefers the precomputed `contentHash` when present; otherwise recomputes a
 * stable fingerprint from the question text via the shared education_fingerprint
 * module (import-only; never mutated here).
 */
function fallbackFingerprint(item: NearDupItem): string {
  if (typeof item.contentHash === "string" && item.contentHash.length > 0) {
    return item.contentHash;
  }
  return computeQuestionFingerprint({
    subjectName: "",
    chapter: "",
    questionType: "",
    questionText: item.questionText,
  });
}

function hasVector(item: NearDupItem): boolean {
  return Array.isArray(item.nearDupEmbedding) && item.nearDupEmbedding.length > 0;
}

/**
 * Filter near-duplicates out of a pool, at request time, with zero model calls.
 *
 * Algorithm (fully deterministic):
 *   1. Order the pool by `id` (ascending, stable) so the verdict never depends on
 *      input ordering.
 *   2. Greedily keep items. For each candidate, compare against every already-kept
 *      item in kept-order:
 *        - If BOTH have precomputed vectors: cosine >= threshold => near-dup.
 *        - Otherwise (either lacks a vector): exact fingerprint equality => dup.
 *      The FIRST matching kept item (in id order) wins, making `similarTo`
 *      deterministic. A candidate with no match is kept.
 *
 * Every dropped item carries its `similarTo` id, the numeric `score`, and a
 * versioned `reason` string — the explanation required by the contract.
 */
export function filterNearDups(
  pool: NearDupItem[],
  opts?: FilterNearDupsOptions,
): FilterNearDupsResult {
  const threshold = opts?.threshold ?? NEAR_DUP_THRESHOLD;

  const ordered = [...pool].sort((x, y) => (x.id < y.id ? -1 : x.id > y.id ? 1 : 0));

  const kept: NearDupItem[] = [];
  const dropped: DroppedNearDup[] = [];

  for (const candidate of ordered) {
    let matched: DroppedNearDup | null = null;

    for (const keeper of kept) {
      if (hasVector(candidate) && hasVector(keeper)) {
        const score = cosine(
          candidate.nearDupEmbedding as number[],
          keeper.nearDupEmbedding as number[],
        );
        if (score >= threshold) {
          matched = {
            item: candidate,
            similarTo: keeper.id,
            score,
            reason:
              `near-dup: cosine ${score.toFixed(4)} >= ${threshold} (${NEAR_DUP_VERSION})`,
          };
          break;
        }
      } else if (fallbackFingerprint(candidate) === fallbackFingerprint(keeper)) {
        matched = {
          item: candidate,
          similarTo: keeper.id,
          score: 1,
          reason:
            `exact-fingerprint fallback (missing vector) (${NEAR_DUP_VERSION})`,
        };
        break;
      }
    }

    if (matched) {
      dropped.push(matched);
    } else {
      kept.push(candidate);
    }
  }

  return { kept, dropped };
}
