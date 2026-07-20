// P1-PROD-22 SLICE 1 — face_match.ts pure unit tests (DB-free).

import { assertAlmostEquals, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  cosineSimilarity,
  DEFAULT_FACE_MATCH_THRESHOLD,
  faceMatchDecision,
  faceMatchThreshold,
  MAX_SIMILARITY_THRESHOLD,
  MIN_SIMILARITY_THRESHOLD,
} from "./face_match.ts";

Deno.test("cosineSimilarity: identical vectors → 1 (within float epsilon)", () => {
  const v = [0.1, 0.2, 0.3, 0.4];
  assertAlmostEquals(cosineSimilarity(v, v), 1, 1e-12);
});

Deno.test("cosineSimilarity: orthogonal vectors → 0", () => {
  assertEquals(cosineSimilarity([1, 0], [0, 1]), 0);
});

Deno.test("cosineSimilarity: opposite vectors → -1", () => {
  assertEquals(cosineSimilarity([1, 2, 3], [-1, -2, -3]), -1);
});

Deno.test("cosineSimilarity: dimension mismatch → 0, fails closed (never throws)", () => {
  assertEquals(cosineSimilarity([1, 2, 3], [1, 2]), 0);
  assertEquals(cosineSimilarity([1, 2], [1, 2, 3]), 0);
});

Deno.test("cosineSimilarity: empty vectors → 0", () => {
  assertEquals(cosineSimilarity([], []), 0);
});

Deno.test("cosineSimilarity: non-finite values (float4-overflow Infinity readback) → 0, fails closed — NaN must never flow into a threshold comparison", () => {
  assertEquals(cosineSimilarity([Infinity, 0.5], [0.5, 0.5]), 0);
  assertEquals(cosineSimilarity([0.5, 0.5], [-Infinity, 0.5]), 0);
  assertEquals(cosineSimilarity([NaN, 0.5], [0.5, 0.5]), 0);
});

Deno.test("cosineSimilarity: zero (degenerate) vector → 0, fails closed", () => {
  assertEquals(cosineSimilarity([0, 0, 0], [1, 2, 3]), 0);
  assertEquals(cosineSimilarity([1, 2, 3], [0, 0, 0]), 0);
  assertEquals(cosineSimilarity([0, 0], [0, 0]), 0);
});

Deno.test("cosineSimilarity: scale-invariant (same direction, different magnitude) → 1 (within float epsilon)", () => {
  assertAlmostEquals(cosineSimilarity([1, 1, 1], [2, 2, 2]), 1, 1e-12);
});

Deno.test("faceMatchThreshold: no env → conservative default (0.82, the live B4 chain value)", () => {
  Deno.env.delete("FACE_MATCH_MIN_SIMILARITY");
  assertEquals(faceMatchThreshold(), DEFAULT_FACE_MATCH_THRESHOLD);
  assertEquals(faceMatchThreshold(), 0.82);
});

Deno.test("faceMatchThreshold: a valid in-band override is honoured", () => {
  Deno.env.set("FACE_MATCH_MIN_SIMILARITY", "0.9");
  try {
    assertEquals(faceMatchThreshold(), 0.9);
  } finally {
    Deno.env.delete("FACE_MATCH_MIN_SIMILARITY");
  }
});

Deno.test("faceMatchThreshold: an out-of-band override is clamped into [0.5, 0.99]", () => {
  Deno.env.set("FACE_MATCH_MIN_SIMILARITY", "0.01");
  try {
    assertEquals(faceMatchThreshold(), MIN_SIMILARITY_THRESHOLD);
  } finally {
    Deno.env.delete("FACE_MATCH_MIN_SIMILARITY");
  }
  Deno.env.set("FACE_MATCH_MIN_SIMILARITY", "1");
  try {
    assertEquals(faceMatchThreshold(), MAX_SIMILARITY_THRESHOLD);
  } finally {
    Deno.env.delete("FACE_MATCH_MIN_SIMILARITY");
  }
});

Deno.test("faceMatchThreshold: a non-numeric override falls back to the default", () => {
  Deno.env.set("FACE_MATCH_MIN_SIMILARITY", "not-a-number");
  try {
    assertEquals(faceMatchThreshold(), DEFAULT_FACE_MATCH_THRESHOLD);
  } finally {
    Deno.env.delete("FACE_MATCH_MIN_SIMILARITY");
  }
});

Deno.test("faceMatchDecision: at/above threshold → matched", () => {
  assertEquals(faceMatchDecision(0.8, 0.8), { matched: true, similarity: 0.8, threshold: 0.8 });
  assertEquals(faceMatchDecision(0.95, 0.8).matched, true);
});

Deno.test("faceMatchDecision: just below threshold → not matched (boundary)", () => {
  assertEquals(faceMatchDecision(0.7999999, 0.8).matched, false);
});

Deno.test("faceMatchDecision: defaults to the live env-resolved threshold when omitted", () => {
  Deno.env.delete("FACE_MATCH_MIN_SIMILARITY");
  assertEquals(faceMatchDecision(0.85).threshold, DEFAULT_FACE_MATCH_THRESHOLD);
  assertEquals(faceMatchDecision(0.85).matched, true);

  Deno.env.set("FACE_MATCH_MIN_SIMILARITY", "0.9");
  try {
    assertEquals(faceMatchDecision(0.85).matched, false);
    assertEquals(faceMatchDecision(0.85).threshold, 0.9);
  } finally {
    Deno.env.delete("FACE_MATCH_MIN_SIMILARITY");
  }
});

Deno.test("faceMatchDecision: a fail-closed 0 similarity (mismatch/zero vector) never matches", () => {
  assertEquals(faceMatchDecision(0).matched, false);
});
