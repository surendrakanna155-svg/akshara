// Adaptive AI — P3-AI-3 / W2.8: Stage-2 semantic cache repository.
//
// Embedding rows key back to ai_response_cache entries by cache_key; the
// nearest-match read joins on it so Stage-2 can only ever serve an answer
// Stage-1 could have served (same table, same TTL, same RLS wall). Every
// function degrades to "miss" when the substrate is absent — the migration
// is defensive (pgvector may not be provisioned) and the runtime must be too.

import type { TenantQueryClient } from "../tenant_db.ts";
import type { AiTenantScope } from "./ai_call_log_repository.ts";
import { logAiDegradation } from "./ai_telemetry.ts";

/** Cosine-distance ceiling for a semantic hit (doc 03 §3.2: tuned at pilot).
 * 0 = identical direction; conservative default keeps false-serves rare. */
export function semanticMaxDistance(): number {
  const raw = Number(Deno.env.get("AI_SEMANTIC_CACHE_MAX_DISTANCE") ?? "");
  return Number.isFinite(raw) && raw > 0 && raw <= 1 ? raw : 0.12;
}

/** SHA-256 hex of the normalized question — the embedding-call cache key. */
export async function questionHash(text: string): Promise<string> {
  const normalized = text.trim().toLowerCase().replace(/\s+/g, " ");
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(normalized),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** pgvector literal: '[0.1,0.2,...]'. Values are provider floats, never user
 * text — but they are still passed as a bound parameter, not interpolated. */
export function vectorLiteral(embedding: number[]): string {
  return `[${embedding.map((v) => (Number.isFinite(v) ? v : 0)).join(",")}]`;
}

/** True when the (conditionally-created) substrate exists in this database.
 * Cheap catalog probe; callers treat false as "Stage-2 dormant". */
export async function semanticCacheAvailable(db: TenantQueryClient): Promise<boolean> {
  try {
    const rows = await db.queryObject<{ reg: string | null }>(
      `SELECT to_regclass('ai_semantic_cache_embeddings')::text AS reg`,
    );
    return rows[0]?.reg != null;
  } catch (err) {
    logAiDegradation("semantic_cache.probe", err);
    return false;
  }
}

/** Look up a previously-stored embedding for this question (the "embedding
 * calls are themselves cached by text hash" rule). Returns the vector literal
 * so the caller can reuse it without a provider round-trip. */
export async function findStoredEmbedding(
  db: TenantQueryClient,
  scope: AiTenantScope,
  hash: string,
): Promise<string | null> {
  const rows = await db.queryObject<{ embedding: string }>(
    `SELECT embedding::text AS embedding
       FROM ai_semantic_cache_embeddings
      WHERE organization_id = $1 AND school_id = $2 AND question_hash = $3
      LIMIT 1`,
    [scope.organizationId, scope.schoolId, hash],
  );
  return rows[0]?.embedding ?? null;
}

/** Store the question's embedding keyed to its ai_response_cache entry.
 * Idempotent per (school, question_hash). Best-effort — callers wrap. */
export async function storeSemanticEmbedding(
  db: TenantQueryClient,
  scope: AiTenantScope,
  input: {
    cacheKey: string;
    surface: string;
    language: string;
    questionHash: string;
    embedding: string; // vectorLiteral() output
  },
): Promise<void> {
  await db.queryObject(
    `INSERT INTO ai_semantic_cache_embeddings (
       organization_id, school_id, cache_key, surface, language,
       question_hash, embedding
     ) VALUES ($1,$2,$3,$4,$5,$6,$7::vector)
     ON CONFLICT (organization_id, school_id, question_hash) DO UPDATE SET
       cache_key = EXCLUDED.cache_key,
       surface = EXCLUDED.surface,
       language = EXCLUDED.language,
       embedding = EXCLUDED.embedding,
       created_at = timezone('utc', now())`,
    [
      scope.organizationId,
      scope.schoolId,
      input.cacheKey,
      input.surface,
      input.language,
      input.questionHash,
      input.embedding,
    ],
  );
}

export interface SemanticHit {
  payload: string;
  model: string;
  distance: number;
}

/** The Stage-2 read: nearest cached answer for this school+surface+language
 * within the distance ceiling, joined to a LIVE (unexpired) ai_response_cache
 * entry. Bumps the underlying entry's hit_count like the exact-key path. */
export async function findNearestCachedResponse(
  db: TenantQueryClient,
  scope: AiTenantScope,
  args: { surface: string; language: string; embedding: string; maxDistance: number },
): Promise<SemanticHit | null> {
  const rows = await db.queryObject<{
    id: string;
    payload: string;
    model: string;
    distance: number;
  }>(
    `SELECT c.id, c.payload, c.model,
            (e.embedding <=> $5::vector)::float8 AS distance
       FROM ai_semantic_cache_embeddings e
       JOIN ai_response_cache c
         ON c.organization_id = e.organization_id
        AND c.school_id = e.school_id
        AND c.cache_key = e.cache_key
      WHERE e.organization_id = $1 AND e.school_id = $2
        AND e.surface = $3 AND e.language = $4
        AND (c.expires_at IS NULL OR c.expires_at > timezone('utc', now()))
      ORDER BY e.embedding <=> $5::vector
      LIMIT 1`,
    [scope.organizationId, scope.schoolId, args.surface, args.language, args.embedding],
  );
  const row = rows[0];
  if (!row || Number(row.distance) > args.maxDistance) return null;
  await db.queryObject(
    `UPDATE ai_response_cache SET hit_count = hit_count + 1 WHERE id = $1`,
    [row.id],
  );
  return { payload: row.payload, model: row.model, distance: Number(row.distance) };
}
