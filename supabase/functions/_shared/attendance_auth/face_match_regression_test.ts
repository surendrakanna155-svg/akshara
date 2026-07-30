// Face-match regression battery for the AuraFace (ArcFace-family, 512-d) space.
//
// Covers the four cases the attendance decision actually has to get right:
// genuine match, impostor rejection, threshold boundaries, and replay.
//
// These are DECISION-LOGIC tests over controlled vectors, deliberately. The
// model's real genuine/impostor separation can only be measured with real face
// pairs, which is an owner/data gate (see
// docs/engineering/FACE_VERIFICATION_DEPLOYMENT_PLAN.md §"Threshold calibration").
// What is pinned here is that the decision behaves correctly GIVEN a similarity
// — which is the part this module owns.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  cosineSimilarity,
  DEFAULT_FACE_MATCH_THRESHOLD,
  faceMatchDecision,
  FACE_MATCH_EMBEDDING_SPACE,
  MAX_SIMILARITY_THRESHOLD,
  MIN_SIMILARITY_THRESHOLD,
} from "./face_match.ts";

const DIMS = 512;

/** A unit vector in the 512-d space, deterministic per seed. */
function vec(seed: number): number[] {
  let s = seed;
  const rand = () => {
    s = (s * 1103515245 + 12345) & 0x7fffffff;
    return s / 0x7fffffff - 0.5;
  };
  const v = Array.from({ length: DIMS }, rand);
  const n = Math.sqrt(v.reduce((a, x) => a + x * x, 0));
  return v.map((x) => x / n);
}

/** A unit vector at EXACTLY cosine `target` from `base`.
 *
 * Gram-Schmidt: orthogonalise `other` against `base`, then combine as
 * `target*base + sqrt(1-target^2)*perp`. Simply mixing and renormalising does
 * NOT give the target cosine — it lands high, which silently weakens any test
 * built on it. */
function atSimilarity(base: number[], other: number[], target: number): number[] {
  const dot = base.reduce((a, x, i) => a + x * other[i]!, 0);
  const perp = other.map((x, i) => x - dot * base[i]!);
  const pn = Math.sqrt(perp.reduce((a, x) => a + x * x, 0));
  const unit = perp.map((x) => x / pn);
  const k = Math.sqrt(Math.max(0, 1 - target * target));
  return base.map((x, i) => target * x + k * unit[i]!);
}

Deno.test("the calibrated space is named, so a model swap cannot silently reuse a stale threshold", () => {
  assertEquals(FACE_MATCH_EMBEDDING_SPACE, "auraface-v1");
});

Deno.test("GENUINE: a staff member's own re-capture is accepted", () => {
  const enrolled = vec(1);
  // A re-capture of the same face differs only by lighting/angle/sensor noise.
  // Measured on the real int8 model, that noise moves the embedding very
  // little: same-input-plus-noise pairs scored 0.865-0.913 cosine.
  const recapture = atSimilarity(enrolled, vec(999), 0.88);
  const sim = cosineSimilarity(enrolled, recapture);
  assertEquals(sim > DEFAULT_FACE_MATCH_THRESHOLD, true);
  assertEquals(faceMatchDecision(sim).matched, true);
});

Deno.test("IMPOSTOR: an unrelated person is rejected", () => {
  const enrolled = vec(2);
  const impostor = vec(3);
  const sim = cosineSimilarity(enrolled, impostor);
  assertEquals(sim < DEFAULT_FACE_MATCH_THRESHOLD, true);
  assertEquals(faceMatchDecision(sim).matched, false);
});

Deno.test("IMPOSTOR: a near-miss just under the threshold is still rejected", () => {
  // The dangerous case: a lookalike, or a degraded capture of a real face that
  // lands just short. It must fail closed to the manual-request path.
  const enrolled = vec(4);
  const nearMiss = atSimilarity(enrolled, vec(5), DEFAULT_FACE_MATCH_THRESHOLD - 0.05);
  assertEquals(faceMatchDecision(cosineSimilarity(enrolled, nearMiss)).matched, false);
});

Deno.test("BOUNDARY: the threshold is inclusive, and one ulp below is a reject", () => {
  const t = DEFAULT_FACE_MATCH_THRESHOLD;
  assertEquals(faceMatchDecision(t, t).matched, true);
  assertEquals(faceMatchDecision(t - Number.EPSILON, t).matched, false);
  assertEquals(faceMatchDecision(t + Number.EPSILON, t).matched, true);
});

Deno.test("BOUNDARY: the clamp band brackets the ArcFace-family operating range", () => {
  // 0.3-0.4 is where ArcFace-family 1:1 verification operates (OpenCV's SFace
  // ships 0.363). The band must be able to EXPRESS that range — the previous
  // [0.5, 0.99] band could not, which is the defect this replaced.
  assertEquals(MIN_SIMILARITY_THRESHOLD < 0.363, true);
  assertEquals(MAX_SIMILARITY_THRESHOLD > 0.40, true);
  // ...but must not permit accepting a near-stranger.
  assertEquals(MIN_SIMILARITY_THRESHOLD >= 0.25, true);
});

Deno.test("BOUNDARY: no configuration can disable matching entirely", () => {
  // A 0 or negative threshold would accept every face, including an orthogonal
  // one. The clamp floor is what prevents that being reachable by config.
  const enrolled = vec(6);
  const stranger = vec(7);
  const sim = cosineSimilarity(enrolled, stranger);
  assertEquals(faceMatchDecision(sim, MIN_SIMILARITY_THRESHOLD).matched, false);
});

Deno.test("REPLAY: an identical embedding scores 1.0 — so freshness, not the matcher, is the defence", () => {
  // A replayed capture is INDISTINGUISHABLE to the matcher: identical vectors
  // score a perfect 1.0 and match. That is correct and unavoidable — a matcher
  // compares faces, it cannot know when a face was captured.
  //
  // Replay is therefore defended EARLIER in the chain, and this test exists to
  // pin that reasoning in place so nobody later "hardens" the matcher instead:
  //   - the crop is derived server-side from a live capture, so a tampered
  //     client can no longer post a stored embedding at all;
  //   - the liveness challenge must pass for the capture to be produced;
  //   - the location fix carries an anti-stale window.
  const enrolled = vec(8);
  assertEquals(cosineSimilarity(enrolled, enrolled) > 0.999, true);
  assertEquals(faceMatchDecision(cosineSimilarity(enrolled, enrolled)).matched, true);
});

Deno.test("REPLAY: a zeroed or malformed embedding cannot force a match", () => {
  // The other half of replay defence: garbage must fail closed rather than
  // land somewhere permissive.
  const enrolled = vec(9);
  assertEquals(faceMatchDecision(cosineSimilarity(enrolled, new Array(DIMS).fill(0))).matched, false);
  assertEquals(faceMatchDecision(cosineSimilarity(enrolled, [])).matched, false);
  assertEquals(faceMatchDecision(cosineSimilarity(enrolled, vec(10).slice(0, 192))).matched, false);
});

Deno.test("a 192-d embedding from the retired model cannot be scored against a 512-d enrolment", () => {
  // Defence in depth behind the model-tag check: even if a stale client posted
  // an old-space vector, the dimension mismatch fails closed to 0.
  assertEquals(cosineSimilarity(vec(11), vec(12).slice(0, 192)), 0);
});
