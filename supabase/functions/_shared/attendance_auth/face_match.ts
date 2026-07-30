// P1-PROD-22 SLICE 1 — server-authoritative face-match decision (pure, DB-free).
//
// docs/ATTENDANCE_AUTH_DESIGN_DECISION.md §7: "Match is server-authoritative: the
// client extracts a live face embedding on-device and sends it; the SERVER
// computes cosine similarity vs the enrolled reference and decides pass/fail.
// The client cannot simply assert matched=true." This module is that decision —
// exported for the SLICE 2 check-in verification chain (geofence -> anti-mock ->
// liveness -> THIS match -> check-in); that chain is NOT wired here.

/** The embedding space these thresholds are calibrated for.
 *
 * Thresholds are NOT portable across embedding spaces — a cosine value means
 * something different in each. Changing the model REQUIRES revisiting the three
 * constants below, so the space is named here rather than left implicit. The
 * server refuses to compare embeddings across differing model tags
 * (FACE_EMBEDDING_MISMATCH), which is what stops a stale enrolment being
 * scored against a threshold meant for a different model. */
export const FACE_MATCH_EMBEDDING_SPACE = "auraface-v1";

/** Clamp band for the env override.
 *
 * The floor stops a deployment being configured to accept a near-random match;
 * the ceiling stops it demanding impossible exactness, which would reject every
 * legitimate re-capture (lighting and angle noise are real).
 *
 * ⚠️ These were `[0.5, 0.99]`, calibrated for the retired 192-d MobileFaceNet
 * space. ArcFace-family 512-d embeddings — which AuraFace is — operate FAR
 * lower: impostor pairs cluster near 0.0-0.15 and genuine pairs sit around
 * 0.4-0.7. A 0.5 floor made the correct operating point unreachable by
 * configuration, and the old 0.82 default would have rejected essentially every
 * genuine staff member.
 *
 * 0.25 is deliberately just above the impostor cluster: low enough to permit
 * field tuning if the false-reject rate proves too high, high enough that no
 * configuration can accept a stranger. */
export const MIN_SIMILARITY_THRESHOLD = 0.25;
export const MAX_SIMILARITY_THRESHOLD = 0.99;

/** Default acceptance threshold (cosine similarity) for the space named in
 * {@link FACE_MATCH_EMBEDDING_SPACE}. Tunable per deployment via
 * FACE_MATCH_MIN_SIMILARITY, always clamped into the band above.
 *
 * 0.40 is chosen conservatively for 1:1 staff attendance. Reference points:
 * OpenCV's SFace ships 0.363, and ArcFace-family verification thresholds are
 * commonly quoted at 0.3-0.4. Sitting at the top of that range biases towards
 * FALSE REJECT over FALSE ACCEPT, which is the correct direction here — a false
 * accept is one staff member checking in as another, i.e. payroll fraud, while
 * a false reject sends them to the audited manual-attendance request with
 * maker-checker approval. The geofence, anti-mock and liveness checks have
 * already gated the attempt before this decision is reached.
 *
 * This value must be re-tuned against real enrolment pairs before wide rollout;
 * it is a defensible starting point, not a measured operating point. */
export const DEFAULT_FACE_MATCH_THRESHOLD = 0.40;

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
  // Non-finite input values (e.g. a float4-overflowed Infinity read back from
  // the DB) make `raw` NaN — and Math.min/Math.max propagate NaN instead of
  // clamping it, so `NaN < threshold` comparisons downstream would fail OPEN.
  // An inconclusive comparison is a non-match: fail closed.
  if (!Number.isFinite(raw)) return 0;
  return Math.min(1, Math.max(-1, raw));
}

/**
 * Resolves the live acceptance threshold: FACE_MATCH_MIN_SIMILARITY when set to
 * a finite number, clamped into
 * [{@link MIN_SIMILARITY_THRESHOLD}, {@link MAX_SIMILARITY_THRESHOLD}];
 * otherwise {@link DEFAULT_FACE_MATCH_THRESHOLD}. Never throws.
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
