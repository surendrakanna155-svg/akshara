// Server-side embedding derivation — every failure path must fail CLOSED.
//
// This seam replaced client-computed embeddings. If any path here returned a
// usable vector on failure, it would be a way to check in without a verified
// face — i.e. the exact forgery hole the change was made to close.

import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  deriveFaceEmbedding,
  FaceEmbeddingUnavailableError,
  faceInferenceEndpoint,
} from "./face_embedding_client.ts";

const CROP = "aGVsbG8=";

function respond(status: number, body: unknown, ok = true): typeof fetch {
  return ((_url: string | URL | Request, _init?: RequestInit) =>
    Promise.resolve(
      new Response(typeof body === "string" ? body : JSON.stringify(body), {
        status,
        headers: { "content-type": "application/json" },
      }),
    )) as unknown as typeof fetch;
}

function rejects(): typeof fetch {
  return (() => Promise.reject(new TypeError("connection refused"))) as unknown as typeof fetch;
}

async function codeOf(fn: () => Promise<unknown>): Promise<string> {
  try {
    await fn();
    return "NO_THROW";
  } catch (e) {
    return e instanceof FaceEmbeddingUnavailableError ? e.code : `WRONG_TYPE:${e}`;
  }
}

Deno.test("happy path: returns the embedding and the model tag", async () => {
  const vec = Array.from({ length: 512 }, (_, i) => (i % 7) / 10);
  const out = await deriveFaceEmbedding(CROP, respond(200, { embedding: vec, modelTag: "auraface-v1" }));
  assertEquals(out.embedding.length, 512);
  assertEquals(out.modelTag, "auraface-v1");
});

Deno.test("an empty crop is refused before any network call", async () => {
  const never = (() => {
    throw new Error("must not be called");
  }) as unknown as typeof fetch;
  assertEquals(await codeOf(() => deriveFaceEmbedding("", never)), "FACE_CROP_REQUIRED");
  assertEquals(await codeOf(() => deriveFaceEmbedding("   ", never)), "FACE_CROP_REQUIRED");
});

Deno.test("service unreachable → FACE_SERVICE_UNAVAILABLE, never a vector", async () => {
  assertEquals(await codeOf(() => deriveFaceEmbedding(CROP, rejects())), "FACE_SERVICE_UNAVAILABLE");
});

Deno.test("422/413 from the service → the capture is at fault, not the service", async () => {
  // Distinct code so the client can say "capture again" rather than
  // "try later" — a wrong-size or non-image crop will never succeed on retry.
  assertEquals(await codeOf(() => deriveFaceEmbedding(CROP, respond(422, {}))), "FACE_CROP_INVALID");
  assertEquals(await codeOf(() => deriveFaceEmbedding(CROP, respond(413, {}))), "FACE_CROP_INVALID");
});

Deno.test("5xx → FACE_SERVICE_UNAVAILABLE", async () => {
  assertEquals(await codeOf(() => deriveFaceEmbedding(CROP, respond(500, {}))), "FACE_SERVICE_UNAVAILABLE");
  assertEquals(await codeOf(() => deriveFaceEmbedding(CROP, respond(503, {}))), "FACE_SERVICE_UNAVAILABLE");
});

Deno.test("unreadable body → fails closed", async () => {
  assertEquals(
    await codeOf(() => deriveFaceEmbedding(CROP, respond(200, "not json at all"))),
    "FACE_SERVICE_UNAVAILABLE",
  );
});

Deno.test("missing or empty embedding → fails closed", async () => {
  assertEquals(await codeOf(() => deriveFaceEmbedding(CROP, respond(200, { modelTag: "x" }))), "FACE_SERVICE_UNAVAILABLE");
  assertEquals(
    await codeOf(() => deriveFaceEmbedding(CROP, respond(200, { embedding: [], modelTag: "x" }))),
    "FACE_SERVICE_UNAVAILABLE",
  );
});

Deno.test("a non-finite component is rejected at the source", async () => {
  // face_match already fails closed on NaN, but emitting one here would mean an
  // enrolment could be STORED as meaningless. Reject where it originates.
  for (const bad of [NaN, Infinity, -Infinity, "abc", null]) {
    const vec: unknown[] = Array.from({ length: 512 }, () => 0.1);
    vec[7] = bad;
    assertEquals(
      await codeOf(() => deriveFaceEmbedding(CROP, respond(200, { embedding: vec, modelTag: "auraface-v1" }))),
      "FACE_SERVICE_UNAVAILABLE",
      `component ${String(bad)} must not be accepted`,
    );
  }
});

Deno.test("a missing model tag is refused — it is what prevents cross-model scoring", async () => {
  const vec = Array.from({ length: 512 }, () => 0.1);
  assertEquals(await codeOf(() => deriveFaceEmbedding(CROP, respond(200, { embedding: vec }))), "FACE_SERVICE_UNAVAILABLE");
  assertEquals(
    await codeOf(() => deriveFaceEmbedding(CROP, respond(200, { embedding: vec, modelTag: "  " }))),
    "FACE_SERVICE_UNAVAILABLE",
  );
});

Deno.test("endpoint resolves from env and tolerates a trailing slash", () => {
  Deno.env.delete("FACE_INFERENCE_URL");
  assertEquals(faceInferenceEndpoint(), "http://akshara-face-inference:8080");
  Deno.env.set("FACE_INFERENCE_URL", "http://127.0.0.1:9000/");
  try {
    assertEquals(faceInferenceEndpoint(), "http://127.0.0.1:9000");
  } finally {
    Deno.env.delete("FACE_INFERENCE_URL");
  }
});

Deno.test("the crop is sent in the body and never in the URL", async () => {
  // A crop in a query string would land in access logs and proxy logs —
  // biometric data written to disk by accident.
  let seenUrl = "";
  let seenBody = "";
  const spy = ((url: string | URL | Request, init?: RequestInit) => {
    seenUrl = String(url);
    seenBody = String(init?.body ?? "");
    const vec = Array.from({ length: 512 }, () => 0.1);
    return Promise.resolve(
      new Response(JSON.stringify({ embedding: vec, modelTag: "auraface-v1" }), { status: 200 }),
    );
  }) as unknown as typeof fetch;

  await deriveFaceEmbedding("SECRETCROPDATA", spy);
  assertEquals(seenUrl.includes("SECRETCROPDATA"), false);
  assertEquals(seenBody.includes("SECRETCROPDATA"), true);
});
