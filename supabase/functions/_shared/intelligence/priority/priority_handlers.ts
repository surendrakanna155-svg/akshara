// Adaptive AI — P3-AI-2 / W2.0a: the per-persona Priority Feed route handler.
//
// GET /intelligence/priorities?persona=<principal|finance|director|admin>&limit=N
//
// Deterministic, Tier-1, ZERO model calls (doc 04 §3.3). It loads the existing
// analytics + student-risk intelligence the caller is PERMITTED to read (via the
// shared feed service — RBAC is the real wall, doc 02 §5), scores it through the
// pure engine, and applies the caller's learned weights + dismissed items from
// Persona Memory (W2.0b). No new table for the feed itself; no clock in scoring.

import type { AppConfig } from "../../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../../http.ts";
import {
  authenticateRequest,
  requireSchoolOperationalScope,
} from "../../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../../tenant_handlers.ts";
import { buildFeed } from "./priority_engine.ts";
import { loadPersonaFeedContext } from "./priority_feed_service.ts";
import { isPersona, type Persona, W2_0_SUPPORTED_PERSONAS } from "./priority_types.ts";

function isSupportedPersona(p: Persona): boolean {
  return W2_0_SUPPORTED_PERSONAS.includes(p);
}

/** Validate the ?persona= param → the resolved persona, or an error Response. */
export function resolvePersonaParam(raw: string | null): Persona | Response {
  const value = (raw ?? "principal").toLowerCase();
  if (!isPersona(value) || !isSupportedPersona(value)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      `persona must be one of: ${W2_0_SUPPORTED_PERSONAS.join(", ")} ` +
        `(per-user personas ship in their rollout wave)`,
      422,
    );
  }
  return value;
}

export function parseFeedLimit(raw: string | null): number {
  const n = Number.parseInt(raw ?? "", 10);
  if (!Number.isFinite(n) || n <= 0) return 20;
  return Math.min(50, n);
}

/** GET /intelligence/priorities — the W2.0 per-persona priority feed. */
export async function handlePriorityFeed(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  // Any authenticated user with a school operational scope may request a feed;
  // WHAT they see is bounded per-source by their real read permissions.
  const denied = requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const persona = resolvePersonaParam(url.searchParams.get("persona"));
  if (persona instanceof Response) return persona;
  const limit = parseFeedLimit(url.searchParams.get("limit"));

  try {
    const ctx = await withTenantContext(config, auth.claims, (db) =>
      loadPersonaFeedContext(db, auth.claims, persona));
    const feed = buildFeed(ctx.rawItems, persona, new Date().toISOString(), {
      weights: ctx.weights,
      dismissedKeys: ctx.dismissedKeys,
      limit,
    });
    return jsonResponse(envelope({ ...feed, degraded: ctx.degraded }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const message = error instanceof Error ? error.message : "Failed to build priority feed";
    return errorEnvelope("INTERNAL_ERROR", message, 500);
  }
}
