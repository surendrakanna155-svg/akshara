import type { TenantQueryClient } from "../tenant_db.ts";
import {
  generatePromotionAssetBundle,
  promotionAssetsToRecord,
} from "./promotion_asset_service.ts";

export interface PromotionRow {
  id: string;
  achievement_type: string;
  title: string;
  description: string | null;
  status: string;
  assets: Record<string, unknown>;
  analytics: { views: number; shares: number; downloads: number };
  created_at: string;
  published_at: string | null;
}

export function generatePromotionAssets(title: string): Record<string, unknown> {
  return promotionAssetsToRecord(generatePromotionAssetBundle(title));
}

export async function listPromotions(
  client: TenantQueryClient,
  status?: string,
): Promise<PromotionRow[]> {
  const conditions = status ? "WHERE status = $1" : "";
  const params = status ? [status] : [];
  return await client.queryObject<PromotionRow>(
    `SELECT id, achievement_type, title, description, status, assets, analytics,
            created_at, published_at
     FROM achievement_promotions ${conditions}
     ORDER BY created_at DESC`,
    params,
  );
}

export async function getPromotion(
  client: TenantQueryClient,
  promotionId: string,
): Promise<PromotionRow | null> {
  const rows = await client.queryObject<PromotionRow>(
    `SELECT id, achievement_type, title, description, status, assets, analytics,
            created_at, published_at
     FROM achievement_promotions WHERE id = $1`,
    [promotionId],
  );
  return rows[0] ?? null;
}

export async function createPromotion(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: {
    achievementType: string;
    title: string;
    description?: string;
    submittedBy: string;
  },
): Promise<PromotionRow> {
  const rows = await client.queryObject<PromotionRow>(
    `INSERT INTO achievement_promotions (
       organization_id, school_id, achievement_type, title, description,
       status, submitted_by
     ) VALUES ($1, $2, $3, $4, $5, 'draft', $6)
     RETURNING id, achievement_type, title, description, status, assets, analytics,
               created_at, published_at`,
    [
      organizationId,
      schoolId,
      input.achievementType,
      input.title,
      input.description ?? null,
      input.submittedBy,
    ],
  );
  return rows[0]!;
}

export async function generateAndStoreAssets(
  client: TenantQueryClient,
  promotionId: string,
): Promise<PromotionRow> {
  const current = await getPromotion(client, promotionId);
  if (!current) throw new Error("Promotion not found");
  const assets = generatePromotionAssets(current.title);
  const rows = await client.queryObject<PromotionRow>(
    `UPDATE achievement_promotions
     SET assets = $1::jsonb, status = 'pending_approval'
     WHERE id = $2
     RETURNING id, achievement_type, title, description, status, assets, analytics,
               created_at, published_at`,
    [JSON.stringify(assets), promotionId],
  );
  return rows[0]!;
}

export async function approvePromotion(
  client: TenantQueryClient,
  promotionId: string,
  approvedBy: string,
): Promise<PromotionRow> {
  const rows = await client.queryObject<PromotionRow>(
    `UPDATE achievement_promotions
     SET status = 'approved', approved_by = $1
     WHERE id = $2
     RETURNING id, achievement_type, title, description, status, assets, analytics,
               created_at, published_at`,
    [approvedBy, promotionId],
  );
  if (!rows[0]) throw new Error("Promotion not found");
  return rows[0];
}

export async function publishPromotion(
  client: TenantQueryClient,
  promotionId: string,
): Promise<PromotionRow> {
  const rows = await client.queryObject<PromotionRow>(
    `UPDATE achievement_promotions
     SET status = 'published', published_at = timezone('utc', now())
     WHERE id = $1 AND status = 'approved'
     RETURNING id, achievement_type, title, description, status, assets, analytics,
               created_at, published_at`,
    [promotionId],
  );
  if (!rows[0]) throw new Error("Promotion not found or not approved");
  return rows[0];
}

export async function trackPromotionMetric(
  client: TenantQueryClient,
  promotionId: string,
  metric: "views" | "shares" | "downloads",
): Promise<void> {
  await client.queryObject(
    `UPDATE achievement_promotions
     SET analytics = jsonb_set(
       analytics,
       '{${metric}}',
       to_jsonb(coalesce((analytics->>'${metric}')::int, 0) + 1)
     )
     WHERE id = $1`,
    [promotionId],
  );
}

export async function getPromotionWithAssetUrls(
  client: TenantQueryClient,
  promotionId: string,
): Promise<PromotionRow | null> {
  return await getPromotion(client, promotionId);
}
