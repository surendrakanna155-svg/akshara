import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleApprovePromotion,
  handleCreatePromotion,
  handleGeneratePromotionAssets,
  handleListPromotions,
  handlePublishPromotion,
  handleTrackPromotion,
} from "./achievement_promotion_handlers.ts";
import {
  handleGetBrandProfile,
  handlePosterPreview,
  handleUpsertBrandProfile,
} from "./brand_profile_handlers.ts";

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function routePromotion(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/promotions")) return null;

  if (path === "/promotions" && method === "GET") {
    return await handleListPromotions(req, config);
  }
  if (path === "/promotions" && method === "POST") {
    return await handleCreatePromotion(req, config);
  }

  // Batch 10 — marketing internal (owner #4): brand profile + poster preview.
  // Registered BEFORE the UUID :id match so these named segments aren't shadowed.
  if (path === "/promotions/brand-profile" && method === "GET") {
    return await handleGetBrandProfile(req, config);
  }
  if (path === "/promotions/brand-profile" && method === "PUT") {
    return await handleUpsertBrandProfile(req, config);
  }
  if (path === "/promotions/poster/preview" && method === "POST") {
    return await handlePosterPreview(req, config);
  }

  const match = path.match(/^\/promotions\/([^/]+)(?:\/(generate|approve|publish|track))?$/);
  if (match && UUID.test(match[1]!)) {
    const id = match[1]!;
    const action = match[2];
    if (method === "POST" && action === "generate") {
      return await handleGeneratePromotionAssets(req, config, id);
    }
    if (method === "POST" && action === "approve") {
      return await handleApprovePromotion(req, config, id);
    }
    if (method === "POST" && action === "publish") {
      return await handlePublishPromotion(req, config, id);
    }
    if (method === "POST" && action === "track") {
      return await handleTrackPromotion(req, config, id);
    }
  }

  return null;
}
