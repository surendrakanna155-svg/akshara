// Adaptive AI — P3-AI-2 / W2.0b: the Recommendation Engine route handlers.
//
// A recommendation = a scored priority item + a pre-staged one-click action
// (doc 04 §4). Two routes, both deterministic + Tier-1 (ZERO model calls):
//
//   GET  /intelligence/recommendations?persona=…   → scored feed + actions
//   POST /intelligence/recommendations/feedback     → accept/dismiss/suppress learning
//
// Governance rails honoured: AI NEVER executes (actions carry
// requiresConfirmation; the human confirms on the normal ERP route). RBAC is the
// real wall (shared feed service). Learning is per-user Persona Memory (W1.2
// schema, activated here) — deterministic weight math, no model output stored.

import type { AppConfig } from "../../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../../tenant_handlers.ts";
import {
  type FeedbackAction,
  recordRecommendationFeedback,
} from "../../ai/ai_persona_memory_repository.ts";
import { buildFeed } from "./priority_engine.ts";
import { loadPersonaFeedContext } from "./priority_feed_service.ts";
import { actionForItem } from "./recommendation_actions.ts";
import { parseFeedLimit, resolvePersonaParam } from "./priority_handlers.ts";
import { PRIORITY_ITEM_TYPES, type PriorityItemType } from "./priority_types.ts";

const FEEDBACK_ACTIONS: readonly FeedbackAction[] = ["accept", "dismiss", "suppress"] as const;

function isItemType(v: unknown): v is PriorityItemType {
  return typeof v === "string" && (PRIORITY_ITEM_TYPES as readonly string[]).includes(v);
}

function isFeedbackAction(v: unknown): v is FeedbackAction {
  return typeof v === "string" && (FEEDBACK_ACTIONS as readonly string[]).includes(v);
}

/** GET /intelligence/recommendations — the priority feed enriched with
 * pre-staged one-click actions (the actionable half of W2.0). */
export async function handleRecommendationFeed(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
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
    // Attach the pre-staged action to each item (undefined = informational only).
    const items = feed.items.map((it) => ({ ...it, action: actionForItem(it) }));
    return jsonResponse(envelope({ ...feed, items, degraded: ctx.degraded }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const message = error instanceof Error ? error.message : "Failed to build recommendations";
    return errorEnvelope("INTERNAL_ERROR", message, 500);
  }
}

/** POST /intelligence/recommendations/feedback — the accept/dismiss/suppress
 * learning loop (P12). Body: { itemKey, itemType, action }. Idempotent-ish
 * upsert into the caller's own Persona Memory row (RLS-scoped to the user). */
export async function handleRecommendationFeedback(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ itemKey?: string; itemType?: string; action?: string }>(req);
  const itemKey = body?.itemKey?.trim() ?? "";
  const itemType = body?.itemType;
  const action = body?.action;
  if (!itemKey) return errorEnvelope("VALIDATION_ERROR", "itemKey required", 422);
  if (!isItemType(itemType)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      `itemType must be one of: ${PRIORITY_ITEM_TYPES.join(", ")}`,
      422,
    );
  }
  if (!isFeedbackAction(action)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      `action must be one of: ${FEEDBACK_ACTIONS.join(", ")}`,
      422,
    );
  }

  try {
    const memory = await withTenantContext(config, auth.claims, (db) =>
      recordRecommendationFeedback(db, {
        organizationId: organizationIdFromClaims(auth.claims),
        schoolId: schoolIdFromClaims(auth.claims),
        userId: auth.claims.sub,
      }, { itemKey, itemType, action }));
    return jsonResponse(envelope({
      itemType,
      action,
      feedback: memory.recommendationFeedback[itemType] ?? null,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const message = error instanceof Error ? error.message : "Failed to record feedback";
    return errorEnvelope("INTERNAL_ERROR", message, 500);
  }
}
