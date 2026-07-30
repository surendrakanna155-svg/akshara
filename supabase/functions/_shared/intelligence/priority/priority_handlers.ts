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
import type { AccessTokenClaims } from "../../jwt.ts";
import { envelope, errorEnvelope, jsonResponse } from "../../http.ts";
import {
  authenticateRequest,
  requireParentSelfScope,
  requireSchoolOperationalScope,
  requireStudentSelfScope,
} from "../../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../../tenant_handlers.ts";
import { buildFeed } from "./priority_engine.ts";
import { loadPersonaFeedContext } from "./priority_feed_service.ts";
import { isPersona, type Persona, W2_0_SUPPORTED_PERSONAS } from "./priority_types.ts";

function isSupportedPersona(p: Persona): boolean {
  return W2_0_SUPPORTED_PERSONAS.includes(p);
}

/**
 * Persona-aware RBAC scope gate (doc 10 §4/§5 — "RBAC before context"). Each
 * feed is the caller's OWN feed, so the required session scope is fixed by the
 * persona: parent/student personas demand a genuine parent/student session
 * (children/self resolved from the signed JWT), everything else a school
 * session. This prevents a school-scope caller from pulling a parent/student
 * feed and vice-versa; row-level isolation is then enforced by the loaders
 * (claims.sub / child_ids / student_id) + RLS.
 */
export function requirePriorityFeedScope(
  claims: AccessTokenClaims,
  persona: Persona,
): Response | null {
  if (persona === "parent") return requireParentSelfScope(claims);
  if (persona === "student") return requireStudentSelfScope(claims);
  return requireSchoolOperationalScope(claims);
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

/** GET /intelligence/priorities — the per-persona priority feed. */
export async function handlePriorityFeed(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const url = new URL(req.url);
  // Resolve persona first — it decides which scope the caller must hold.
  const persona = resolvePersonaParam(url.searchParams.get("persona"));
  if (persona instanceof Response) return persona;
  // Any caller in the persona's required scope may request the feed; WHAT they
  // see is bounded per-source by their real read permissions + row scope.
  const denied = requirePriorityFeedScope(auth.claims, persona);
  if (denied) return denied;
  const limit = parseFeedLimit(url.searchParams.get("limit"));

  try {
    const nowIso = new Date().toISOString();
    const ctx = await withTenantContext(config, auth.claims, (db) =>
      loadPersonaFeedContext(db, auth.claims, persona, nowIso));
    const feed = buildFeed(ctx.rawItems, persona, nowIso, {
      weights: ctx.weights,
      // Lifecycle replaces the legacy `dismissedKeys` hard filter: items are
      // scored first and hidden second, so a put-away item can legitimately
      // return when it escalates or its snooze elapses.
      lifecycle: ctx.lifecycle,
      nowIso,
      limit,
    });
    return jsonResponse(envelope({ ...feed, degraded: ctx.degraded }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const message = error instanceof Error ? error.message : "Failed to build priority feed";
    return errorEnvelope("INTERNAL_ERROR", message, 500);
  }
}
