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
  requireFeedbackScope,
  schoolIdFromClaims,
} from "../../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../../tenant_handlers.ts";
import {
  type FeedbackAction,
  recordRecommendationFeedback,
} from "../../ai/ai_persona_memory_repository.ts";
import { buildFeed } from "./priority_engine.ts";
import {
  isItemLifecycleState,
  ITEM_LIFECYCLE_STATES,
  type ItemLifecycleState,
} from "./item_lifecycle.ts";
import { recordItemAction, setItemPinned } from "./item_lifecycle_repository.ts";
import { loadPersonaFeedContext } from "./priority_feed_service.ts";
import { actionForItem } from "./recommendation_actions.ts";
import { parseFeedLimit, requirePriorityFeedScope, resolvePersonaParam } from "./priority_handlers.ts";
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

  const url = new URL(req.url);
  const persona = resolvePersonaParam(url.searchParams.get("persona"));
  if (persona instanceof Response) return persona;
  const denied = requirePriorityFeedScope(auth.claims, persona);
  if (denied) return denied;
  const limit = parseFeedLimit(url.searchParams.get("limit"));

  try {
    const nowIso = new Date().toISOString();
    const ctx = await withTenantContext(config, auth.claims, (db) =>
      loadPersonaFeedContext(db, auth.claims, persona, nowIso));
    const feed = buildFeed(ctx.rawItems, persona, nowIso, {
      weights: ctx.weights,
      // See priority_handlers.ts — lifecycle supersedes the legacy hard filter.
      lifecycle: ctx.lifecycle,
      nowIso,
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
  const denied = requireFeedbackScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    itemKey?: string;
    itemType?: string;
    action?: string;
    lifecycle?: {
      state?: string;
      snoozedUntil?: string;
      scoreAtAction?: number;
      dueAtAction?: number;
    };
    /** Set/clear the pin. Independent of `action` and `lifecycle` — a user may
     * pin something they already put away, which is exactly the "actually, keep
     * this in front of me" case. */
    pinned?: boolean;
  }>(req);
  const itemKey = body?.itemKey?.trim() ?? "";
  const itemType = body?.itemType;
  const action = body?.action;
  const lifecycle = body?.lifecycle;
  const pinned = body?.pinned;
  if (!itemKey) return errorEnvelope("VALIDATION_ERROR", "itemKey required", 422);
  if (!isItemType(itemType)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      `itemType must be one of: ${PRIORITY_ITEM_TYPES.join(", ")}`,
      422,
    );
  }
  // `action` teaches the ranker; `lifecycle` manages the user's queue. They are
  // separable on purpose: snoozing is "not now", NOT "this was a bad
  // suggestion", so a snooze must be able to skip the learning signal entirely
  // rather than down-weighting the whole item type.
  if (action === undefined && lifecycle === undefined && pinned === undefined) {
    return errorEnvelope("VALIDATION_ERROR", "action, lifecycle or pinned required", 422);
  }
  if (pinned !== undefined && typeof pinned !== "boolean") {
    return errorEnvelope("VALIDATION_ERROR", "pinned must be a boolean", 422);
  }
  if (action !== undefined && !isFeedbackAction(action)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      `action must be one of: ${FEEDBACK_ACTIONS.join(", ")}`,
      422,
    );
  }
  if (lifecycle !== undefined) {
    if (!isItemLifecycleState(lifecycle.state ?? "")) {
      return errorEnvelope(
        "VALIDATION_ERROR",
        `lifecycle.state must be one of: ${ITEM_LIFECYCLE_STATES.join(", ")}`,
        422,
      );
    }
    if (lifecycle.state === "snoozed") {
      const until = Date.parse(lifecycle.snoozedUntil ?? "");
      if (!Number.isFinite(until)) {
        return errorEnvelope(
          "VALIDATION_ERROR",
          "lifecycle.snoozedUntil must be an ISO timestamp when state is 'snoozed'",
          422,
        );
      }
    }
  }

  try {
    const scope = {
      organizationId: organizationIdFromClaims(auth.claims),
      schoolId: schoolIdFromClaims(auth.claims),
      userId: auth.claims.sub,
    };
    // Both writes share ONE transaction: the ranker's memory and the user's
    // queue must never diverge (an item recorded as dismissed-for-learning but
    // still visible, or hidden with no learning signal).
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const memory = action !== undefined
        ? await recordRecommendationFeedback(db, scope, { itemKey, itemType, action })
        : null;
      const recorded = lifecycle !== undefined
        ? await recordItemAction(db, scope, {
          itemKey,
          itemType,
          state: lifecycle.state as ItemLifecycleState,
          snoozedUntil: lifecycle.snoozedUntil ?? null,
          scoreAtAction: lifecycle.scoreAtAction ?? null,
          dueAtAction: lifecycle.dueAtAction ?? null,
        })
        : null;
      // Applied after the state write so a combined body (e.g. acknowledge +
      // unpin) ends in the caller's intended pin, not the upsert's default.
      if (pinned !== undefined) {
        await setItemPinned(db, scope, itemKey, pinned, itemType);
      }
      return { memory, recorded };
    });
    return jsonResponse(envelope({
      itemType,
      action: action ?? null,
      feedback: result.memory?.recommendationFeedback[itemType] ?? null,
      lifecycle: result.recorded
        ? { state: result.recorded.state, snoozedUntil: result.recorded.snoozedUntil }
        : null,
      pinned: pinned ?? null,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const message = error instanceof Error ? error.message : "Failed to record feedback";
    return errorEnvelope("INTERNAL_ERROR", message, 500);
  }
}
