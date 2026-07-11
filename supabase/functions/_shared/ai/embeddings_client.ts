// Adaptive AI — P3-AI-3 / W2.8: the (gated) embeddings client.
//
// The Anthropic API has no embeddings endpoint, so Stage-2 semantic caching
// rides a separate embeddings provider (default wire shape: Voyage AI's
// POST /v1/embeddings — Anthropic's documented companion for embeddings).
// EVERYTHING is env-gated and fails soft:
//   AI_EMBEDDINGS_API_KEY   — unset ⇒ embeddings disabled ⇒ Stage-2 dormant
//   AI_EMBEDDINGS_URL       — default https://api.voyageai.com/v1/embeddings
//   AI_EMBEDDINGS_MODEL     — default voyage-3.5-lite (1024 dims, matching
//                             the ai_semantic_cache_embeddings column)
// A failure here can never break the user path: callers get null and fall
// through to the live governed model call, exactly like a cache miss.

import { logAiDegradation } from "./ai_telemetry.ts";

export const EMBEDDING_DIMENSIONS = 1024;
const DEFAULT_URL = "https://api.voyageai.com/v1/embeddings";
const DEFAULT_MODEL = "voyage-3.5-lite";
const EMBED_TIMEOUT_MS = 5_000;

/** True when an embeddings provider is configured for this deployment. */
export function embeddingsConfigured(): boolean {
  return !!Deno.env.get("AI_EMBEDDINGS_API_KEY");
}

/** Injectable fetch seam for tests. */
export type FetchLike = typeof fetch;

/**
 * Embed one text. Returns the vector, or null on ANY failure mode
 * (unconfigured, timeout, non-2xx, wrong dimensionality) — never throws.
 */
export async function embedText(
  text: string,
  fetchImpl: FetchLike = fetch,
): Promise<number[] | null> {
  const apiKey = Deno.env.get("AI_EMBEDDINGS_API_KEY");
  if (!apiKey || text.trim().length === 0) return null;

  const url = Deno.env.get("AI_EMBEDDINGS_URL") ?? DEFAULT_URL;
  const model = Deno.env.get("AI_EMBEDDINGS_MODEL") ?? DEFAULT_MODEL;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), EMBED_TIMEOUT_MS);
  try {
    const response = await fetchImpl(url, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({ model, input: [text] }),
      signal: controller.signal,
    });
    if (!response.ok) {
      logAiDegradation("embeddings.http", `status ${response.status}`);
      return null;
    }
    const payload = await response.json() as {
      data?: Array<{ embedding?: number[] }>;
    };
    const embedding = payload.data?.[0]?.embedding;
    if (!Array.isArray(embedding) || embedding.length !== EMBEDDING_DIMENSIONS) {
      logAiDegradation("embeddings.shape", `got ${embedding?.length ?? "none"} dims`);
      return null;
    }
    return embedding;
  } catch (err) {
    logAiDegradation("embeddings.call", err);
    return null;
  } finally {
    clearTimeout(timer);
  }
}
