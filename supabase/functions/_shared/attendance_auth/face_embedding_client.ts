// Server-side face embedding derivation — the client seam to the internal
// inference service (deploy/akshara-vps/face-inference).
//
// WHY THIS EXISTS. Until now the CLIENT computed the embedding and posted it.
// That made template forgery possible: a tampered client could enrol vector E
// and replay E forever, and the server had no way to tell — it only ever saw a
// number array. Deriving the embedding here, from a crop the server received,
// removes that capability entirely.
//
// This module only DERIVES. The match decision and threshold stay in
// face_match.ts, so there is exactly one place that answers "is this the
// enrolled person".

/** Raised when an embedding cannot be derived. Never carries the crop. */
export class FaceEmbeddingUnavailableError extends Error {
  constructor(readonly code: string, message: string) {
    super(message);
    this.name = "FaceEmbeddingUnavailableError";
  }
}

export interface DerivedEmbedding {
  embedding: number[];
  modelTag: string;
}

const DEFAULT_ENDPOINT = "http://akshara-face-inference:8080";
/** Inference measured ~74-250ms; this bounds a hung service without cutting
 * off a legitimately slow one. Attendance fails closed to the manual request
 * rather than hanging a staff member at the gate. */
const DEFAULT_TIMEOUT_MS = 4000;

export function faceInferenceEndpoint(): string {
  const raw = Deno.env.get("FACE_INFERENCE_URL");
  return raw && raw.trim() !== "" ? raw.trim().replace(/\/+$/, "") : DEFAULT_ENDPOINT;
}

function timeoutMs(): number {
  const raw = Number(Deno.env.get("FACE_INFERENCE_TIMEOUT_MS"));
  return Number.isFinite(raw) && raw > 0 ? raw : DEFAULT_TIMEOUT_MS;
}

/**
 * Derives a 512-d embedding from a base64 aligned 112x112 crop.
 *
 * FAILS CLOSED on every path: a missing service, a timeout, a non-2xx, a
 * malformed body, a wrong dimension count or a non-finite value all throw.
 * There is no fallback that returns a usable vector, because any such fallback
 * would be a way to check in without a verified face.
 */
export async function deriveFaceEmbedding(
  cropBase64: string,
  fetchImpl: typeof fetch = fetch,
): Promise<DerivedEmbedding> {
  if (!cropBase64 || cropBase64.trim() === "") {
    throw new FaceEmbeddingUnavailableError("FACE_CROP_REQUIRED", "No face crop supplied");
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs());
  let res: Response;
  try {
    res = await fetchImpl(`${faceInferenceEndpoint()}/embed`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ crop: cropBase64 }),
      signal: controller.signal,
    });
  } catch (_e) {
    // Covers abort (timeout) and connection failure alike. The distinction does
    // not change what the staff member should do: use the manual request.
    throw new FaceEmbeddingUnavailableError(
      "FACE_SERVICE_UNAVAILABLE",
      "Face verification is temporarily unavailable — use the manual attendance request",
    );
  } finally {
    clearTimeout(timer);
  }

  if (res.status === 422 || res.status === 413) {
    // The service rejected the crop itself (not an image, wrong size, oversize).
    throw new FaceEmbeddingUnavailableError(
      "FACE_CROP_INVALID",
      "The captured face image was not usable — please capture again",
    );
  }
  if (!res.ok) {
    throw new FaceEmbeddingUnavailableError(
      "FACE_SERVICE_UNAVAILABLE",
      "Face verification is temporarily unavailable — use the manual attendance request",
    );
  }

  let body: { embedding?: unknown; modelTag?: unknown };
  try {
    body = await res.json();
  } catch (_e) {
    throw new FaceEmbeddingUnavailableError(
      "FACE_SERVICE_UNAVAILABLE",
      "Face verification returned an unreadable response",
    );
  }

  const raw = body?.embedding;
  if (!Array.isArray(raw) || raw.length === 0) {
    throw new FaceEmbeddingUnavailableError(
      "FACE_SERVICE_UNAVAILABLE",
      "Face verification returned no embedding",
    );
  }

  const embedding: number[] = [];
  for (const v of raw) {
    // Strict `typeof`, NOT `Number(v)`. JSON has no NaN or Infinity literal, so
    // a service that produced one serialises it as `null` — and `Number(null)`
    // is 0, which IS finite. Coercing would therefore accept a corrupted
    // component as a silent zero, quietly distorting the embedding rather than
    // rejecting it.
    const n = typeof v === "number" ? v : Number.NaN;
    // A non-finite component would make the cosine NaN downstream. face_match
    // already fails closed on that, but emitting it at all would mean storing a
    // meaningless enrolment — reject at the source.
    if (!Number.isFinite(n)) {
      throw new FaceEmbeddingUnavailableError(
        "FACE_SERVICE_UNAVAILABLE",
        "Face verification returned a non-finite embedding",
      );
    }
    embedding.push(n);
  }

  const modelTag = typeof body?.modelTag === "string" ? body.modelTag.trim() : "";
  if (modelTag === "") {
    // Without a tag the server cannot detect a cross-model comparison, which is
    // the guard that stops embeddings from two different spaces being scored.
    throw new FaceEmbeddingUnavailableError(
      "FACE_SERVICE_UNAVAILABLE",
      "Face verification returned no model tag",
    );
  }

  return { embedding, modelTag };
}
