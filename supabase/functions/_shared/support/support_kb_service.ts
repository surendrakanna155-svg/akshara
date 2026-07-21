// ASIP — Phase 2 / ASIP-8: Continuous Learning. Turns a resolved incident/cluster
// into a knowledge-base article and recalls prior resolutions for a new incident.
// DETERMINISTIC-FIRST: the article is keyed by the SAME cluster fingerprint the
// clustering engine uses, so recall-by-fingerprint needs no embeddings. A
// governed embedding (support_kb_embedding) adds an OPTIONAL similarity layer
// that stays dormant when unconfigured — never a dependency of learning or
// deterministic recall.

import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { withTenantContext } from "../tenant_db.ts";
import { embeddingsConfigured, embedText } from "../ai/embeddings_client.ts";
import {
  clusterFingerprint,
  clusterTitle,
  deterministicInvestigation,
  diagnosticsFromMirrorEvidence,
  errorSignature,
  type MirrorDiagnostics,
} from "./support_platform_service.ts";
import type { PlatformEvidenceRow, PlatformIncidentRow } from "./support_platform_repository.ts";
import {
  findKbByFingerprint,
  findNearestKbArticles,
  findRelatedKb,
  kbEmbeddingAvailable,
  type KbArticleRow,
  storeKbEmbedding,
  upsertKbArticle,
} from "./support_kb_repository.ts";

export type KbMatchType = "exact" | "related" | "semantic";

/** A prior resolution surfaced for a live incident (console + investigation). */
export interface KbMatch {
  id: string;
  fingerprint: string;
  category: string;
  moduleKey: string | null;
  title: string;
  rootCause: string;
  resolution: string;
  resolvedCount: number;
  schoolsSeen: number;
  matchType: KbMatchType;
  distance: number | null;
  updatedAt: string;
}

const MAX_MATCHES = 3;
/** Cosine ceiling for a semantic KB hit — conservative so false recalls are rare
 * (mirrors the semantic-cache default; tunable via env at pilot). */
function kbSemanticMaxDistance(): number {
  const raw = Number(Deno.env.get("SUPPORT_KB_SEMANTIC_MAX_DISTANCE") ?? "");
  return Number.isFinite(raw) && raw > 0 && raw <= 1 ? raw : 0.2;
}

export function toKbMatch(row: KbArticleRow, matchType: KbMatchType, distance: number | null = null): KbMatch {
  return {
    id: row.id,
    fingerprint: row.fingerprint,
    category: row.category,
    moduleKey: row.module_key,
    title: row.title,
    rootCause: row.root_cause,
    resolution: row.resolution,
    resolvedCount: row.resolved_count,
    schoolsSeen: row.schools_seen,
    matchType,
    distance,
    updatedAt: row.updated_at,
  };
}

/** The text embedded for an ARTICLE (learning). */
export function articleEmbedText(a: {
  category: string;
  moduleKey: string | null;
  title: string;
  rootCause: string;
  resolution: string;
}): string {
  return [
    `category: ${a.category}`,
    a.moduleKey ? `module: ${a.moduleKey}` : "",
    a.title,
    a.rootCause,
    a.resolution,
  ].filter(Boolean).join("\n");
}

/** The text embedded for a live INCIDENT (semantic recall query). */
export function incidentQueryText(incident: PlatformIncidentRow, diag: MirrorDiagnostics): string {
  return [
    `category: ${incident.category}`,
    incident.module_key ? `module: ${incident.module_key}` : "",
    incident.title,
    incident.description,
    diag.signals.length ? `signals: ${diag.signals.join("; ")}` : "",
  ].filter(Boolean).join("\n");
}

// ─── Learn from a resolution ───────────────────────────────────────────────────

export interface LearnInput {
  incident: PlatformIncidentRow;
  evidence: PlatformEvidenceRow[];
  resolution: string;
  /** cluster root cause if the whole cluster was resolved (preferred narrative) */
  clusterRootCause: string;
  /** how many schools this resolution covered (cluster breadth) */
  schoolsSeen: number;
}

/**
 * Distil a resolution into a KB article (deterministic; no network, no model).
 * Keyed by the incident's cluster fingerprint so a future incident with the same
 * signature recalls it by exact key. Idempotent: re-resolving the same signature
 * bumps counts and refreshes the narrative. Runs inside the caller's support
 * transaction. Returns the article, or null when there is no resolution text.
 */
export async function learnFromResolution(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  input: LearnInput,
): Promise<KbArticleRow | null> {
  const resolution = input.resolution.trim();
  if (!resolution) return null;

  const { incident, evidence } = input;
  const diag = diagnosticsFromMirrorEvidence(evidence);
  const fingerprint = clusterFingerprint(incident.category, incident.module_key, diag);
  const sig = errorSignature(diag);
  const rootCause = input.clusterRootCause.trim() ||
    deterministicInvestigation(incident, diag, Math.max(1, input.schoolsSeen)).likelyRootCause;

  return await upsertKbArticle(db, claims, {
    fingerprint,
    category: incident.category,
    moduleKey: incident.module_key,
    errorSignature: sig,
    title: clusterTitle(incident.category, incident.module_key, diag),
    rootCause: rootCause.slice(0, 2000),
    resolution: resolution.slice(0, 4000),
    sourceIncidentRef: incident.public_ref,
    sourceClusterId: incident.cluster_id,
    schoolsSeen: Math.max(1, input.schoolsSeen),
  });
}

/**
 * Best-effort: embed a freshly-learned article and store the vector for future
 * semantic recall. Runs in its OWN transaction (a network embed call must never
 * hold the resolve transaction open) and never throws. No-op when embeddings are
 * unconfigured or the pgvector substrate is dormant.
 */
export async function embedArticleBestEffort(
  config: AppConfig,
  claims: AccessTokenClaims,
  article: KbArticleRow,
): Promise<void> {
  if (!embeddingsConfigured()) return;
  try {
    const vector = await embedText(articleEmbedText({
      category: article.category,
      moduleKey: article.module_key,
      title: article.title,
      rootCause: article.root_cause,
      resolution: article.resolution,
    }));
    if (!vector) return;
    await withTenantContext(config, claims, async (db) => {
      if (!(await kbEmbeddingAvailable(db))) return;
      await storeKbEmbedding(db, claims, article.id, vector);
    });
  } catch (_err) {
    // Semantic layer is best-effort; deterministic recall is unaffected.
  }
}

// ─── Recall prior resolutions for a live incident ──────────────────────────────

/**
 * Deterministic recall (no network): the exact-fingerprint article first, then
 * related same-category+module articles. Always safe to call; returns [] when
 * the KB is empty. This is the primary "we've seen this before" path.
 */
export async function recallForIncident(
  db: TenantQueryClient,
  incident: PlatformIncidentRow,
  evidence: PlatformEvidenceRow[],
): Promise<KbMatch[]> {
  const diag = diagnosticsFromMirrorEvidence(evidence);
  const fingerprint = clusterFingerprint(incident.category, incident.module_key, diag);
  const out: KbMatch[] = [];

  const exact = await findKbByFingerprint(db, fingerprint);
  if (exact) out.push(toKbMatch(exact, "exact"));

  if (out.length < MAX_MATCHES) {
    const related = await findRelatedKb(db, {
      category: incident.category,
      moduleKey: incident.module_key,
      excludeFingerprint: fingerprint,
      limit: MAX_MATCHES - out.length,
    });
    for (const r of related) out.push(toKbMatch(r, "related"));
  }
  return out.slice(0, MAX_MATCHES);
}

/**
 * Optional semantic augmentation. Embeds the incident and adds nearest articles
 * not already recalled deterministically. Best-effort, own transaction, never
 * throws; a no-op when embeddings/pgvector are absent. Merges into (and never
 * drops) the deterministic matches.
 */
export async function augmentRecallSemantic(
  config: AppConfig,
  claims: AccessTokenClaims,
  incident: PlatformIncidentRow,
  evidence: PlatformEvidenceRow[],
  deterministic: KbMatch[],
): Promise<KbMatch[]> {
  if (!embeddingsConfigured() || deterministic.length >= MAX_MATCHES) return deterministic;
  try {
    const diag = diagnosticsFromMirrorEvidence(evidence);
    const vector = await embedText(incidentQueryText(incident, diag));
    if (!vector) return deterministic;
    const seen = new Set(deterministic.map((m) => m.id));
    const merged = [...deterministic];
    await withTenantContext(config, claims, async (db) => {
      if (!(await kbEmbeddingAvailable(db))) return;
      const hits = await findNearestKbArticles(db, {
        embedding: vector,
        maxDistance: kbSemanticMaxDistance(),
        limit: MAX_MATCHES,
      });
      for (const h of hits) {
        if (merged.length >= MAX_MATCHES) break;
        if (seen.has(h.article.id)) continue;
        seen.add(h.article.id);
        merged.push(toKbMatch(h.article, "semantic", h.distance));
      }
    });
    return merged;
  } catch (_err) {
    return deterministic;
  }
}
