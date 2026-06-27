import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { achievementPromotionAudit, emitMutationAudit } from "../audit/mutation_audit_catalog.ts";
import {
  approvePromotion,
  createPromotion,
  generateAndStoreAssets,
  generatePromotionAssets,
  getPromotion,
  listPromotions,
  markPromotionPublished,
  trackPromotionMetric,
} from "./achievement_promotion_repository.ts";
import { enhanceCaptionsWithAi } from "./publisher_ai_captions.ts";
import { dispatchPublish, PUBLISH_DESTINATIONS } from "./publisher_dispatch.ts";

function requirePromotionRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewAchievementPromotion") ??
    requireSchoolOperationalScope(claims);
}

function requirePromotionWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageAchievementPromotion") ??
    requireSchoolOperationalScope(claims);
}

function requirePromotionApprove(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "approveAchievementPromotion") ??
    requireSchoolOperationalScope(claims);
}

function mapPromotion(row: Awaited<ReturnType<typeof getPromotion>>) {
  if (!row) return null;
  return {
    id: row.id,
    achievementType: row.achievement_type,
    subjectType: row.subject_type,
    calendarEventId: row.calendar_event_id,
    title: row.title,
    description: row.description,
    status: row.status,
    assets: row.assets,
    analytics: row.analytics,
    destinations: row.destinations,
    publishResults: row.publish_results,
    createdAt: row.created_at,
    publishedAt: row.published_at,
  };
}

export async function handleListPromotions(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePromotionRead(auth.claims);
  if (denied) return denied;

  const status = new URL(req.url).searchParams.get("status") ?? undefined;
  try {
    const items = await withTenantContext(config, auth.claims, (db) =>
      listPromotions(db, status)
    );
    return jsonResponse(envelope({
      items: items.map((p) => mapPromotion(p)!),
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("PROMOTION_ERROR", "List promotions failed", 500);
  }
}

export async function handleCreatePromotion(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePromotionWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    achievementType?: string;
    subjectType?: string;
    calendarEventId?: string;
    title?: string;
    description?: string;
  }>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Request body required", 400);
  }
  // subjectType is the general publisher field; achievementType kept for back-compat.
  const subjectType = body.subjectType ?? body.achievementType ?? "achievement";
  if (!body.title) {
    return errorEnvelope("VALIDATION_ERROR", "title is required", 400);
  }

  try {
    const promotion = await withTenantContext(config, auth.claims, async (db) => {
      const created = await createPromotion(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        {
          achievementType: body.achievementType ?? subjectType,
          subjectType,
          calendarEventId: body.calendarEventId ?? null,
          title: body.title!,
          description: body.description,
          submittedBy: auth.claims.sub,
        },
      );
      await emitMutationAudit(
        db,
        auth.claims,
        achievementPromotionAudit.created(created.id),
        req,
      );
      return created;
    });
    return jsonResponse(envelope(mapPromotion(promotion)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("PROMOTION_ERROR", "Create promotion failed", 500);
  }
}

export async function handleGeneratePromotionAssets(
  req: Request,
  config: AppConfig,
  promotionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePromotionWrite(auth.claims);
  if (denied) return denied;

  try {
    // Build subject-aware poster/caption assets, then AI-enhance the captions
    // (safe fallback to the deterministic captions when AI is unavailable).
    const promotion = await withTenantContext(config, auth.claims, async (db) => {
      const current = await getPromotion(db, promotionId);
      if (!current) throw new Error("Promotion not found");
      const baseAssets = generatePromotionAssets(current.title, {
        subjectType: current.subject_type,
        description: current.description ?? undefined,
      });
      const assets = await enhanceCaptionsWithAi(db, auth.claims.tenant_id, baseAssets, {
        subjectType: current.subject_type,
        title: current.title,
        description: current.description,
      });
      const updated = await generateAndStoreAssets(db, promotionId, assets);
      await emitMutationAudit(
        db,
        auth.claims,
        achievementPromotionAudit.generated(promotionId),
        req,
      );
      return updated;
    });
    return jsonResponse(envelope(mapPromotion(promotion)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("PROMOTION_ERROR", "Generate assets failed", 500);
  }
}

export async function handleApprovePromotion(
  req: Request,
  config: AppConfig,
  promotionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePromotionApprove(auth.claims);
  if (denied) return denied;

  try {
    const promotion = await withTenantContext(config, auth.claims, async (db) => {
      const approved = await approvePromotion(db, promotionId, auth.claims.sub);
      await emitMutationAudit(
        db,
        auth.claims,
        achievementPromotionAudit.approved(promotionId),
        req,
      );
      return approved;
    });
    return jsonResponse(envelope(mapPromotion(promotion)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("PROMOTION_ERROR", "Approve promotion failed", 500);
  }
}

export async function handlePublishPromotion(
  req: Request,
  config: AppConfig,
  promotionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePromotionApprove(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ destinations?: string[] }>(req).catch(() => ({} as { destinations?: string[] }));
  const destinations = (body?.destinations ?? []).filter((d) =>
    (PUBLISH_DESTINATIONS as readonly string[]).includes(d)
  );
  if (destinations.length === 0) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      `Select at least one valid destination: ${PUBLISH_DESTINATIONS.join(", ")}`,
      422,
    );
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  if (!schoolId) {
    return errorEnvelope("FORBIDDEN", "Publishing requires school scope", 403);
  }

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const current = await getPromotion(db, promotionId);
      if (!current) return { error: "not_found" as const };
      if (current.status !== "approved") return { error: "not_approved" as const };

      const caption = (() => {
        const card = current.assets?.appCard as Record<string, unknown> | undefined;
        const c = card?.caption;
        return typeof c === "string" && c.trim() ? c.trim() : current.title;
      })();

      const publishResults = await dispatchPublish(db, {
        promotionId,
        title: current.title,
        caption,
        assets: current.assets ?? {},
        destinations,
        orgId,
        schoolId,
        createdBy: auth.claims.sub,
      });
      const published = await markPromotionPublished(db, promotionId, destinations, publishResults);
      await emitMutationAudit(
        db,
        auth.claims,
        achievementPromotionAudit.published(promotionId),
        req,
      );
      return { promotion: published };
    });

    if ("error" in result) {
      if (result.error === "not_found") {
        return errorEnvelope("NOT_FOUND", "Promotion not found", 404);
      }
      return errorEnvelope("PROMOTION_NOT_APPROVED", "Promotion must be approved before publishing", 409);
    }
    return jsonResponse(envelope(mapPromotion(result.promotion)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("PROMOTION_ERROR", "Publish promotion failed", 500);
  }
}

export async function handleTrackPromotion(
  req: Request,
  config: AppConfig,
  promotionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  // RT-22 — tracking a metric is a WRITE; gate it with the manage slug, not the
  // read slug, so a view-only user cannot mutate promotion engagement counts.
  const denied = requirePromotionWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ metric?: string }>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Request body required", 400);
  }
  const metric = body.metric as "views" | "shares" | "downloads" | undefined;
  if (!metric || !["views", "shares", "downloads"].includes(metric)) {
    return errorEnvelope("VALIDATION_ERROR", "metric must be views, shares, or downloads", 400);
  }

  try {
    await withTenantContext(config, auth.claims, async (db) => {
      await trackPromotionMetric(db, promotionId, metric);
      await emitMutationAudit(
        db,
        auth.claims,
        achievementPromotionAudit.metricTracked(promotionId, metric),
        req,
      );
    });
    return jsonResponse(envelope({ tracked: metric }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("PROMOTION_ERROR", "Track metric failed", 500);
  }
}
