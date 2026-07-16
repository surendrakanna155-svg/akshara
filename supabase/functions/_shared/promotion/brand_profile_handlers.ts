// PRC-A Batch 10 — brand profile + poster preview handlers (owner decision #4).
//
// GET  /promotions/brand-profile     read the brand profile   (viewAchievementPromotion)
// PUT  /promotions/brand-profile      configure it            (manageAchievementPromotion)
// POST /promotions/poster/preview     select assets + build the poster brief (dark)  (manage)

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
import { getBrandProfile, upsertBrandProfile } from "./brand_profile_repository.ts";
import { type BrandAsset, selectRelevantAssets } from "./brand_asset_selection.ts";
import { generatePoster } from "./poster_engine.ts";

function requireRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewAchievementPromotion") ?? requireSchoolOperationalScope(claims);
}
function requireWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageAchievementPromotion") ?? requireSchoolOperationalScope(claims);
}

function coerceAssets(raw: unknown): BrandAsset[] {
  if (!Array.isArray(raw)) return [];
  const out: BrandAsset[] = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const o = item as Record<string, unknown>;
    const id = typeof o.id === "string" ? o.id : null;
    const type = typeof o.type === "string" ? o.type : null;
    const url = typeof o.url === "string" ? o.url : null;
    if (!id || !type || !url) continue;
    out.push({
      id,
      type,
      url,
      tags: Array.isArray(o.tags) ? o.tags.filter((t): t is string => typeof t === "string") : [],
      description: typeof o.description === "string" ? o.description : undefined,
    });
  }
  return out;
}

function profileToApi(
  row: Awaited<ReturnType<typeof getBrandProfile>>,
): Record<string, unknown> {
  if (!row) {
    return { configured: false, logoUrl: null, tagline: null, theme: {}, assets: [], isActive: false };
  }
  return {
    configured: true,
    logoUrl: row.logo_url,
    tagline: row.tagline,
    theme: row.theme,
    assets: row.assets,
    isActive: row.is_active,
    updatedAt: row.updated_at,
  };
}

export async function handleGetBrandProfile(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  try {
    const profile = await withTenantContext(config, auth.claims, (db) => getBrandProfile(db, orgId, schoolId));
    return jsonResponse(envelope(profileToApi(profile)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load brand profile", 500);
  }
}

export async function handleUpsertBrandProfile(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireWrite(auth.claims);
  if (denied) return denied;
  if (auth.claims.scope !== "school") {
    return errorEnvelope("VALIDATION_ERROR", "Brand profile requires school scope", 422);
  }

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  const theme = body.theme && typeof body.theme === "object" && !Array.isArray(body.theme)
    ? body.theme as Record<string, unknown>
    : {};

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  try {
    const row = await withTenantContext(config, auth.claims, (db) =>
      upsertBrandProfile(db, {
        organizationId: orgId,
        schoolId,
        logoUrl: typeof body.logoUrl === "string" ? body.logoUrl : (typeof body.logo_url === "string" ? body.logo_url : null),
        tagline: typeof body.tagline === "string" ? body.tagline : null,
        theme,
        assets: coerceAssets(body.assets),
        isActive: typeof body.isActive === "boolean" ? body.isActive : (typeof body.is_active === "boolean" ? body.is_active : true),
        createdBy: auth.claims.sub,
      }));
    return jsonResponse(envelope(profileToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to save brand profile", 500);
  }
}

/**
 * POST /promotions/poster/preview — the internal one-click flow up to (not
 * including) the external render: pick the minimum-relevant assets for the purpose
 * and build the poster brief. The image itself is DARK (provider_not_configured) —
 * honestly not rendered, never fabricated.
 */
export async function handlePosterPreview(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  const purpose = typeof body.purpose === "string" ? body.purpose.trim() : "";
  const title = typeof body.title === "string" ? body.title.trim() : "";
  if (!purpose || !title) {
    return errorEnvelope("VALIDATION_ERROR", "purpose and title are required", 422);
  }
  const keywords = Array.isArray(body.keywords)
    ? body.keywords.filter((k): k is string => typeof k === "string")
    : [];
  const maxAssets = typeof body.maxAssets === "number" ? body.maxAssets : undefined;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const profile = await getBrandProfile(db, orgId, schoolId);
      const assets = profile?.assets ?? [];
      const selected = selectRelevantAssets(assets, { subject: purpose, keywords, maxAssets });
      const poster = generatePoster({
        purpose,
        title,
        details: typeof body.details === "string" ? body.details : null,
        theme: profile?.theme ?? {},
        assets: selected,
      });
      return {
        purpose,
        title,
        theme: profile?.theme ?? {},
        selectedAssets: selected,
        totalAssets: assets.length,
        poster,
        imageGenerationReady: poster.status === "generated",
      };
    });
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to build poster preview", 500);
  }
}
