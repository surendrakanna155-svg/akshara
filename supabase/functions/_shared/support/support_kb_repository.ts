// ASIP — Phase 2 / ASIP-8: knowledge-base data access. Every query runs under a
// PLATFORM_ORG (support) session, so the KB RLS
// (app_current_tenant_id() = PLATFORM_ORG) scopes rows automatically — a school
// session can never touch the KB. Deterministic recall (by fingerprint /
// category+module) is always available; the semantic layer (support_kb_embedding,
// pgvector) is probed for and degrades to "dormant" when absent, exactly like the
// W2.8 semantic cache.

import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { logAiDegradation } from "../ai/ai_telemetry.ts";
import { vectorLiteral } from "../ai/ai_semantic_cache_repository.ts";
import { SUPPORT_PLATFORM_ORG } from "./support_platform_repository.ts";

export interface KbArticleRow {
  id: string;
  fingerprint: string;
  category: string;
  module_key: string | null;
  error_signature: string;
  title: string;
  root_cause: string;
  resolution: string;
  source_incident_ref: string | null;
  source_cluster_id: string | null;
  resolved_count: number;
  schools_seen: number;
  status: string;
  created_at: string;
  updated_at: string;
}

const KB_COLS = `
  id, fingerprint, category, module_key, error_signature, title, root_cause,
  resolution, source_incident_ref, source_cluster_id, resolved_count,
  schools_seen, status, created_at, updated_at
`;

export interface KbUpsertInput {
  fingerprint: string;
  category: string;
  moduleKey: string | null;
  errorSignature: string;
  title: string;
  rootCause: string;
  resolution: string;
  sourceIncidentRef: string | null;
  sourceClusterId: string | null;
  schoolsSeen: number;
}

/** Idempotent learn: one active article per (platform_org, fingerprint). A
 * repeat resolution of the same signature bumps resolved_count, widens
 * schools_seen, and refreshes the narrative to the latest resolution. */
export async function upsertKbArticle(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  input: KbUpsertInput,
): Promise<KbArticleRow> {
  const rows = await db.queryObject<KbArticleRow>(
    `INSERT INTO support_kb_article (
       platform_org_id, fingerprint, category, module_key, error_signature,
       title, root_cause, resolution, source_incident_ref, source_cluster_id,
       schools_seen
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
     ON CONFLICT (platform_org_id, fingerprint) DO UPDATE SET
       category = EXCLUDED.category,
       module_key = EXCLUDED.module_key,
       error_signature = EXCLUDED.error_signature,
       title = EXCLUDED.title,
       root_cause = EXCLUDED.root_cause,
       resolution = EXCLUDED.resolution,
       source_incident_ref = EXCLUDED.source_incident_ref,
       source_cluster_id = EXCLUDED.source_cluster_id,
       resolved_count = support_kb_article.resolved_count + 1,
       schools_seen = GREATEST(support_kb_article.schools_seen, EXCLUDED.schools_seen),
       status = 'active',
       updated_at = timezone('utc', now())
     RETURNING ${KB_COLS}`,
    [
      claims.tenant_id,
      input.fingerprint,
      input.category,
      input.moduleKey,
      input.errorSignature,
      input.title,
      input.rootCause,
      input.resolution,
      input.sourceIncidentRef,
      input.sourceClusterId,
      Math.max(1, Math.trunc(input.schoolsSeen || 1)),
    ],
  );
  return rows[0];
}

/** Exact deterministic recall: the article whose fingerprint matches this
 * incident's signature (the strongest "we've seen this before" hit). */
export async function findKbByFingerprint(
  db: TenantQueryClient,
  fingerprint: string,
): Promise<KbArticleRow | null> {
  const rows = await db.queryObject<KbArticleRow>(
    `SELECT ${KB_COLS} FROM support_kb_article
      WHERE platform_org_id = $1 AND status = 'active' AND fingerprint = $2
      LIMIT 1`,
    [SUPPORT_PLATFORM_ORG, fingerprint],
  );
  return rows[0] ?? null;
}

/** Related deterministic recall: other resolved articles in the same
 * category+module, most-resolved / most-recent first, excluding the exact hit. */
export async function findRelatedKb(
  db: TenantQueryClient,
  args: { category: string; moduleKey: string | null; excludeFingerprint: string; limit: number },
): Promise<KbArticleRow[]> {
  const limit = Math.min(Math.max(args.limit, 1), 10);
  return await db.queryObject<KbArticleRow>(
    `SELECT ${KB_COLS} FROM support_kb_article
      WHERE platform_org_id = $1 AND status = 'active'
        AND category = $2
        AND module_key IS NOT DISTINCT FROM $3
        AND fingerprint <> $4
      ORDER BY resolved_count DESC, updated_at DESC
      LIMIT $5`,
    [SUPPORT_PLATFORM_ORG, args.category, args.moduleKey, args.excludeFingerprint, limit],
  );
}

export interface Page<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}

/** Console KB browser: newest-first, optional free-text filter over the
 * title/root-cause/resolution/category/module. */
export async function listKbArticles(
  db: TenantQueryClient,
  filter: { q?: string; page: number; pageSize: number },
): Promise<Page<KbArticleRow>> {
  const limit = Math.min(Math.max(filter.pageSize, 1), 100);
  const offset = (Math.max(filter.page, 1) - 1) * limit;
  const where: string[] = ["platform_org_id = $1", "status = 'active'"];
  const args: unknown[] = [SUPPORT_PLATFORM_ORG];
  const q = (filter.q ?? "").trim();
  if (q) {
    args.push(`%${q}%`);
    const p = `$${args.length}`;
    where.push(
      `(title ILIKE ${p} OR root_cause ILIKE ${p} OR resolution ILIKE ${p} OR category ILIKE ${p} OR coalesce(module_key,'') ILIKE ${p})`,
    );
  }
  const whereSql = where.join(" AND ");
  const total = await db.queryCount(
    `SELECT count(*)::text AS count FROM support_kb_article WHERE ${whereSql}`,
    args,
  );
  const items = await db.queryObject<KbArticleRow>(
    `SELECT ${KB_COLS} FROM support_kb_article WHERE ${whereSql}
      ORDER BY updated_at DESC
      LIMIT $${args.length + 1} OFFSET $${args.length + 2}`,
    [...args, limit, offset],
  );
  return { items, total, page: Math.max(filter.page, 1), pageSize: limit, hasMore: offset + items.length < total };
}

export async function getKbArticle(
  db: TenantQueryClient,
  articleId: string,
): Promise<KbArticleRow | null> {
  const rows = await db.queryObject<KbArticleRow>(
    `SELECT ${KB_COLS} FROM support_kb_article
      WHERE platform_org_id = $1 AND id = $2::uuid`,
    [SUPPORT_PLATFORM_ORG, articleId],
  );
  return rows[0] ?? null;
}

// ─── Optional semantic layer (dormant without pgvector) ────────────────────────

/** True when the (conditionally-created) embedding substrate exists. Cheap
 * catalog probe; callers treat false as "semantic recall dormant". */
export async function kbEmbeddingAvailable(db: TenantQueryClient): Promise<boolean> {
  try {
    const rows = await db.queryObject<{ reg: string | null }>(
      `SELECT to_regclass('support_kb_embedding')::text AS reg`,
    );
    return rows[0]?.reg != null;
  } catch (err) {
    logAiDegradation("support_kb.probe", err);
    return false;
  }
}

/** Store/refresh the article's embedding. Best-effort — callers wrap. No-op
 * (throws caught by caller) when the substrate is dormant. */
export async function storeKbEmbedding(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  articleId: string,
  embedding: number[],
): Promise<void> {
  await db.queryObject(
    `INSERT INTO support_kb_embedding (article_id, platform_org_id, embedding)
     VALUES ($1::uuid, $2, $3::vector)
     ON CONFLICT (article_id) DO UPDATE SET
       embedding = EXCLUDED.embedding,
       created_at = timezone('utc', now())`,
    [articleId, claims.tenant_id, vectorLiteral(embedding)],
  );
}

export interface KbSemanticHit {
  article: KbArticleRow;
  distance: number;
}

/** Nearest active articles by cosine distance within a ceiling. Returns [] when
 * the substrate is dormant or nothing is within range. */
export async function findNearestKbArticles(
  db: TenantQueryClient,
  args: { embedding: number[]; maxDistance: number; limit: number },
): Promise<KbSemanticHit[]> {
  const limit = Math.min(Math.max(args.limit, 1), 10);
  const rows = await db.queryObject<KbArticleRow & { distance: number }>(
    `SELECT ${KB_COLS.split(",").map((c) => `a.${c.trim()}`).join(", ")},
            (e.embedding <=> $2::vector)::float8 AS distance
       FROM support_kb_embedding e
       JOIN support_kb_article a ON a.id = e.article_id
      WHERE e.platform_org_id = $1 AND a.status = 'active'
      ORDER BY e.embedding <=> $2::vector
      LIMIT $3`,
    [SUPPORT_PLATFORM_ORG, vectorLiteral(args.embedding), limit],
  );
  const out: KbSemanticHit[] = [];
  for (const r of rows) {
    const { distance, ...article } = r;
    if (Number(distance) <= args.maxDistance) out.push({ article, distance: Number(distance) });
  }
  return out;
}
