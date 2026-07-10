// Adaptive AI — P3-AI-1 / W1.2: Tier-2 response cache (design doc 03 §3.1).
//
// Exact-key, write-through cache for validated model outputs. Every entry is
// org+school scoped (in the key AND the row scope + RLS) so a cached generation
// can never serve another tenant even on an identical key (doc 03 §6). The
// cache key is a SHA-256 of the full prompt signature, so any change to the
// injected facts, model, surface, or language yields a different key — a hit
// therefore only occurs when the exact same request would produce the same
// answer. TTL is the backstop; entity-tag invalidation (W1.4) is the primary.

import type { TenantQueryClient } from "../tenant_db.ts";
import type { AiTenantScope } from "./ai_call_log_repository.ts";

export interface CacheKeyParts {
  surface: string;
  schoolId: string;
  language: string;
  model: string;
  system: string;
  messages: Array<{ role: string; content: string }>;
}

export interface CacheHit {
  payload: string;
  model: string;
}

export interface CacheWriteInput {
  cacheKey: string;
  surface: string;
  language: string;
  payload: string;
  entityTags: string[];
  model: string;
  tokensSaved: number;
  /** 0/undefined → no expiry (relies on entity-tag invalidation + profile bump). */
  ttlSeconds?: number;
}

function toHex(buffer: ArrayBuffer): string {
  return Array.from(new Uint8Array(buffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** Deterministic SHA-256 cache key over the full prompt signature. Identical
 * state twice → identical key (doc 09 W1.3 done-when); any fact/model/surface/
 * language change → different key → cache miss → fresh answer. */
export async function mintCacheKey(parts: CacheKeyParts): Promise<string> {
  const canonical = JSON.stringify([
    parts.surface,
    parts.schoolId,
    parts.language,
    parts.model,
    parts.system,
    parts.messages.map((m) => [m.role, m.content]),
  ]);
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(canonical),
  );
  return toHex(digest);
}

/** Look up a non-expired cache entry; increments hit_count on a hit. Returns
 * null on miss. */
export async function lookupResponseCache(
  db: TenantQueryClient,
  scope: AiTenantScope,
  cacheKey: string,
): Promise<CacheHit | null> {
  const rows = await db.queryObject<{ id: string; payload: string; model: string }>(
    `SELECT id, payload, model
       FROM ai_response_cache
      WHERE organization_id = $1 AND school_id = $2 AND cache_key = $3
        AND (expires_at IS NULL OR expires_at > timezone('utc', now()))
      LIMIT 1`,
    [scope.organizationId, scope.schoolId, cacheKey],
  );
  const row = rows[0];
  if (!row) return null;
  await db.queryObject(
    `UPDATE ai_response_cache SET hit_count = hit_count + 1 WHERE id = $1`,
    [row.id],
  );
  return { payload: row.payload, model: row.model };
}

/** Write-through: upsert a validated output under its key. */
export async function writeResponseCache(
  db: TenantQueryClient,
  scope: AiTenantScope,
  input: CacheWriteInput,
): Promise<void> {
  const ttl = Math.trunc(input.ttlSeconds ?? 0);
  await db.queryObject(
    `INSERT INTO ai_response_cache (
       organization_id, school_id, cache_key, surface, language, payload,
       entity_tags, model, tokens_saved, expires_at
     ) VALUES (
       $1,$2,$3,$4,$5,$6,$7,$8,$9,
       CASE WHEN $10 > 0 THEN timezone('utc', now()) + ($10 * interval '1 second') ELSE NULL END
     )
     ON CONFLICT (organization_id, school_id, cache_key) DO UPDATE SET
       surface = EXCLUDED.surface,
       language = EXCLUDED.language,
       payload = EXCLUDED.payload,
       entity_tags = EXCLUDED.entity_tags,
       model = EXCLUDED.model,
       tokens_saved = EXCLUDED.tokens_saved,
       expires_at = EXCLUDED.expires_at,
       created_at = timezone('utc', now())`,
    [
      scope.organizationId,
      scope.schoolId,
      input.cacheKey,
      input.surface,
      input.language,
      input.payload,
      input.entityTags,
      input.model,
      Math.trunc(input.tokensSaved),
      ttl,
    ],
  );
}

/** Invalidate every cache entry tagged with any of `tags` (Signal Refinery,
 * W1.4). No-op on an empty tag list. Returns the number of rows removed. */
export async function invalidateCacheByEntityTags(
  db: TenantQueryClient,
  scope: AiTenantScope,
  tags: string[],
): Promise<number> {
  if (tags.length === 0) return 0;
  const rows = await db.queryObject<{ id: string }>(
    `DELETE FROM ai_response_cache
      WHERE organization_id = $1 AND school_id = $2 AND entity_tags && $3::text[]
      RETURNING id`,
    [scope.organizationId, scope.schoolId, tags],
  );
  return rows.length;
}
