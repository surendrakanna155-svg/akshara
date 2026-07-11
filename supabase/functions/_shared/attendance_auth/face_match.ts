// P1-PROD-22 SLICE 1 — server-authoritative face-match decision (pure, DB-free).
//
// docs/ATTENDANCE_AUTH_DESIGN_DECISION.md §7: "Match is server-authoritative: the
// client extracts a live face embedding on-device and sends it; the SERVER
// computes cosine similarity vs the enrolled reference and decides pass/fail.
// The client cannot simply assert matched=true." This module is that decision —
// exported for the SLICE 2 check-in verification chain (geofence -> anti-mock ->
// liveness -> THIS match -> check-in); that chain is NOT wired here.

/** Cosine similarity is only ever meaningful below this floor (a school could
 * otherwise be configured to accept a near-random match) and above this
 * ceiling (would reject all legitimate re-captures — lighting/angle noise is
 * real) — the env override is clamped into this band so a misconfiguration can
 * never disable matching (0) or demand impossible exactness (1). */
export const MIN_SIMILARITY_THRESHOLD = 0.5;
export const MAX_SIMILARITY_THRESHOLD = 0.99;

/** Conservative default acceptance threshold (cosine similarity). Tunable per
 * deployment via FACE_MATCH_MIN_SIMILARITY, always clamped to
 * [MIN_SIMILARITY_THRESHOLD, MAX_SIMILARITY_THRESHOLD]. */
export const DEFAULT_FACE_MATCH_THRESHOLD = 0.8;

/**
 * Cosine similarity of two equal-length vectors, in [-1, 1] for well-formed
 * inputs. FAILS CLOSED — returns 0 (never throws) on a dimension mismatch or a
 * degenerate (zero-magnitude) vector: an inconclusive comparison must never be
 * read as a match by a caller that only checks `similarity >= threshold`.
 */
export function cosineSimilarity(a: number[], b: number[]): number {
  if (a.length === 0 || a.length !== b.length) return 0;
  let dot = 0;
  let na = 0;
  let nb = 0;
  for (let i = 0; i < a.length; i++) {
    const av = a[i]!;
    const bv = b[i]!;
    dot += av * bv;
    na += av * av;
    nb += bv * bv;
  }
  if (na === 0 || nb === 0) return 0;
  // Cosine similarity is mathematically bounded to [-1, 1]; clamp away the
  // occasional floating-point overshoot (e.g. 1.0000000000000002 for
  // identical/parallel vectors) so callers can rely on the bound holding exactly.
  const raw = dot / (Math.sqrt(na) * Math.sqrt(nb));
  return Math.min(1, Math.max(-1, raw));
}

/**
 * Resolves the live acceptance threshold: FACE_MATCH_MIN_SIMILARITY when set to
 * a finite number, clamped into [0.5, 0.99]; otherwise the conservative default
 * (0.80). Never throws.
 */
export function faceMatchThreshold(): number {
  const envVal = Deno.env.get("FACE_MATCH_MIN_SIMILARITY");
  // Number("") is 0 (finite!), so an unset/blank env var must be filtered out
  // BEFORE the numeric conversion — otherwise "no override" would silently
  // resolve to the clamp floor instead of the conservative default.
  if (envVal === undefined || envVal.trim() === "") return DEFAULT_FACE_MATCH_THRESHOLD;
  const raw = Number(envVal);
  if (!Number.isFinite(raw)) return DEFAULT_FACE_MATCH_THRESHOLD;
  return Math.min(MAX_SIMILARITY_THRESHOLD, Math.max(MIN_SIMILARITY_THRESHOLD, raw));
}

export interface FaceMatchDecision {
  matched: boolean;
  similarity: number;
  threshold: number;
}

/**
 * The server-authoritative pass/fail verdict for a precomputed similarity score
 * against a threshold (defaults to the live env-resolved {@link faceMatchThreshold}).
 * Pure — callers compute `similarity` via {@link cosineSimilarity} first.
 */
export function faceMatchDecision(
  similarity: number,
  threshold: number = faceMatchThreshold(),
): FaceMatchDecision {
  return { matched: similarity >= threshold, similarity, threshold };
}
