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
  getPromotion,
  listPromotions,
  publishPromotion,
  trackPromotionMetric,
} from "./achievement_promotion_repository.ts";

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
    title: row.title,
    description: row.description,
    status: row.status,
    assets: row.assets,
    analytics: row.analytics,
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
    title?: string;
    description?: string;
  }>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Request body required", 400);
  }
  if (!body.achievementType || !body.title) {
    return errorEnvelope("VALIDATION_ERROR", "achievementType and title are required", 400);
  }

  try {
    const promotion = await withTenantContext(config, auth.claims, async (db) => {
      const created = await createPromotion(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        {
          achievementType: body.achievementType!,
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
    const promotion = await withTenantContext(config, auth.claims, async (db) => {
      const updated = await generateAndStoreAssets(db, promotionId);
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

  try {
    const promotion = await withTenantContext(config, auth.claims, async (db) => {
      const published = await publishPromotion(db, promotionId);
      await emitMutationAudit(
        db,
        auth.claims,
        achievementPromotionAudit.published(promotionId),
        req,
      );
      return published;
    });
    return jsonResponse(envelope(mapPromotion(promotion)));
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
  const denied = requirePromotionRead(auth.claims);
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
