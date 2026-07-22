import {
  assert,
  assertAlmostEquals,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  cosine,
  filterNearDups,
  NEAR_DUP_THRESHOLD,
  NEAR_DUP_VERSION,
  type NearDupItem,
} from "./education_near_dup.ts";

// ---------------------------------------------------------------------------
// cosine
// ---------------------------------------------------------------------------

Deno.test("cosine: identical vectors -> 1", () => {
  const v = [1, 2, 3, 4];
  assertAlmostEquals(cosine(v, v), 1, 1e-12);
});

Deno.test("cosine: orthogonal vectors -> 0", () => {
  assertEquals(cosine([1, 0], [0, 1]), 0);
  assertEquals(cosine([1, 0, 0], [0, 5, 0]), 0);
});

Deno.test("cosine: L2-normalised inputs equal their dot product", () => {
  // Two unit vectors at 60 degrees -> cosine = 0.5.
  const a = [1, 0];
  const b = [0.5, Math.sqrt(3) / 2];
  assertAlmostEquals(cosine(a, b), 0.5, 1e-12);
});

Deno.test("cosine: zero-magnitude vector -> 0 (no NaN)", () => {
  const r = cosine([0, 0, 0], [1, 2, 3]);
  assertEquals(r, 0);
  assert(!Number.isNaN(r));
});

Deno.test("cosine: deterministic (same inputs -> identical result)", () => {
  const a = [0.11, 0.42, -0.3, 0.9];
  const b = [0.1, 0.44, -0.28, 0.87];
  assertEquals(cosine(a, b), cosine(a, b));
});

Deno.test("cosine: length mismatch throws", () => {
  let threw = false;
  try {
    cosine([1, 2], [1, 2, 3]);
  } catch (_e) {
    threw = true;
  }
  assert(threw);
});

// ---------------------------------------------------------------------------
// filterNearDups — vector path
// ---------------------------------------------------------------------------

Deno.test("filterNearDups: paraphrase pair (cosine >= 0.82) drops one, with explanation", () => {
  // Near-parallel vectors: cosine well above 0.82.
  const a: NearDupItem = {
    id: "a",
    contentHash: "ha",
    questionText: "What is 2 + 2?",
    nearDupEmbedding: [1, 0, 0],
  };
  const b: NearDupItem = {
    id: "b",
    contentHash: "hb",
    questionText: "Compute two plus two.",
    nearDupEmbedding: [0.98, 0.02, 0.03],
  };

  const { kept, dropped } = filterNearDups([a, b]);
  assertEquals(kept.map((k) => k.id), ["a"]);
  assertEquals(dropped.length, 1);
  assertEquals(dropped[0].item.id, "b");
  assertEquals(dropped[0].similarTo, "a");
  assert(dropped[0].score >= NEAR_DUP_THRESHOLD);
  assert(dropped[0].reason.includes(NEAR_DUP_VERSION));
  // Verify the reported score matches cosine of the two vectors.
  assertAlmostEquals(
    dropped[0].score,
    cosine(b.nearDupEmbedding!, a.nearDupEmbedding!),
    1e-12,
  );
});

Deno.test("filterNearDups: distinct pair (cosine < 0.82) keeps both", () => {
  const a: NearDupItem = {
    id: "a",
    contentHash: "ha",
    questionText: "Define photosynthesis.",
    nearDupEmbedding: [1, 0, 0],
  };
  const b: NearDupItem = {
    id: "b",
    contentHash: "hb",
    questionText: "State Newton's second law.",
    nearDupEmbedding: [0, 1, 0], // orthogonal -> cosine 0
  };

  const { kept, dropped } = filterNearDups([a, b]);
  assertEquals(kept.map((k) => k.id), ["a", "b"]);
  assertEquals(dropped.length, 0);
});

// ---------------------------------------------------------------------------
// filterNearDups — fingerprint fallback path
// ---------------------------------------------------------------------------

Deno.test("filterNearDups: no vectors + identical contentHash -> one dropped via fallback", () => {
  const a: NearDupItem = {
    id: "a",
    contentHash: "same-hash",
    questionText: "Anything",
    nearDupEmbedding: null,
  };
  const b: NearDupItem = {
    id: "b",
    contentHash: "same-hash",
    questionText: "Something else entirely",
    nearDupEmbedding: null,
  };

  const { kept, dropped } = filterNearDups([a, b]);
  assertEquals(kept.map((k) => k.id), ["a"]);
  assertEquals(dropped.length, 1);
  assertEquals(dropped[0].item.id, "b");
  assertEquals(dropped[0].similarTo, "a");
  assertEquals(dropped[0].score, 1);
  assert(dropped[0].reason.includes("fingerprint"));
});

Deno.test("filterNearDups: no contentHash falls back to computed fingerprint over questionText", () => {
  const a: NearDupItem = {
    id: "a",
    contentHash: "",
    questionText: "Solve 2x + 3 = 7",
    nearDupEmbedding: null,
  };
  const b: NearDupItem = {
    id: "b",
    contentHash: "",
    questionText: "solve  2x + 3 = 7.", // normalises to the same fingerprint
    nearDupEmbedding: null,
  };

  const { kept, dropped } = filterNearDups([a, b]);
  assertEquals(kept.map((k) => k.id), ["a"]);
  assertEquals(dropped.length, 1);
  assertEquals(dropped[0].similarTo, "a");
});

Deno.test("filterNearDups: one has a vector, other does not -> fingerprint fallback used", () => {
  const a: NearDupItem = {
    id: "a",
    contentHash: "h1",
    questionText: "Q",
    nearDupEmbedding: [1, 0, 0],
  };
  const b: NearDupItem = {
    id: "b",
    contentHash: "h1", // same fingerprint
    questionText: "Q",
    nearDupEmbedding: null, // no vector -> must use fallback vs a
  };

  const { kept, dropped } = filterNearDups([a, b]);
  assertEquals(kept.map((k) => k.id), ["a"]);
  assertEquals(dropped.length, 1);
  assertEquals(dropped[0].similarTo, "a");
  assert(dropped[0].reason.includes("fingerprint"));
});

// ---------------------------------------------------------------------------
// determinism & ordering
// ---------------------------------------------------------------------------

Deno.test("filterNearDups: deterministic order regardless of input order (stable by id)", () => {
  const mk = (id: string, hash: string): NearDupItem => ({
    id,
    contentHash: hash,
    questionText: id,
    nearDupEmbedding: null,
  });

  // c and a share a hash; b is unique.
  const forward = filterNearDups([mk("a", "hx"), mk("b", "hy"), mk("c", "hx")]);
  const reversed = filterNearDups([mk("c", "hx"), mk("b", "hy"), mk("a", "hx")]);

  // Ordered by id: a kept first, c is the dup of a, b kept.
  assertEquals(forward.kept.map((k) => k.id), ["a", "b"]);
  assertEquals(reversed.kept.map((k) => k.id), ["a", "b"]);
  assertEquals(forward.dropped.map((d) => d.item.id), ["c"]);
  assertEquals(reversed.dropped.map((d) => d.item.id), ["c"]);
  assertEquals(forward.dropped[0].similarTo, "a");
  assertEquals(reversed.dropped[0].similarTo, "a");
});
