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
  subject_type: string;
  calendar_event_id: string | null;
  destinations: unknown;
  publish_results: Record<string, unknown>;
}

const PROMO_COLS =
  `id, achievement_type, title, description, status, assets, analytics,
   created_at, published_at, subject_type, calendar_event_id, destinations, publish_results`;

export function generatePromotionAssets(
  title: string,
  opts: { subjectType?: string; description?: string } = {},
): Record<string, unknown> {
  return promotionAssetsToRecord(generatePromotionAssetBundle(title, opts));
}

export async function listPromotions(
  client: TenantQueryClient,
  status?: string,
): Promise<PromotionRow[]> {
  const conditions = status ? "WHERE status = $1" : "";
  const params = status ? [status] : [];
  return await client.queryObject<PromotionRow>(
    `SELECT ${PROMO_COLS} FROM achievement_promotions ${conditions} ORDER BY created_at DESC`,
    params,
  );
}

export async function getPromotion(
  client: TenantQueryClient,
  promotionId: string,
): Promise<PromotionRow | null> {
  const rows = await client.queryObject<PromotionRow>(
    `SELECT ${PROMO_COLS} FROM achievement_promotions WHERE id = $1`,
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
    subjectType?: string;
    calendarEventId?: string | null;
  },
): Promise<PromotionRow> {
  const rows = await client.queryObject<PromotionRow>(
    `INSERT INTO achievement_promotions (
       organization_id, school_id, achievement_type, title, description,
       status, submitted_by, subject_type, calendar_event_id
     ) VALUES ($1, $2, $3, $4, $5, 'draft', $6, $7, $8)
     RETURNING ${PROMO_COLS}`,
    [
      organizationId,
      schoolId,
      input.achievementType,
      input.title,
      input.description ?? null,
      input.submittedBy,
      input.subjectType ?? "achievement",
      input.calendarEventId ?? null,
    ],
  );
  return rows[0]!;
}

export async function generateAndStoreAssets(
  client: TenantQueryClient,
  promotionId: string,
  assets: Record<string, unknown>,
): Promise<PromotionRow> {
  const rows = await client.queryObject<PromotionRow>(
    `UPDATE achievement_promotions
     SET assets = $1::jsonb, status = 'pending_approval'
     WHERE id = $2
     RETURNING ${PROMO_COLS}`,
    [JSON.stringify(assets), promotionId],
  );
  if (!rows[0]) throw new Error("Promotion not found");
  return rows[0];
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
     RETURNING ${PROMO_COLS}`,
    [approvedBy, promotionId],
  );
  if (!rows[0]) throw new Error("Promotion not found");
  return rows[0];
}

export async function markPromotionPublished(
  client: TenantQueryClient,
  promotionId: string,
  destinations: string[],
  publishResults: Record<string, unknown>,
): Promise<PromotionRow> {
  const rows = await client.queryObject<PromotionRow>(
    `UPDATE achievement_promotions
     SET status = 'published', published_at = timezone('utc', now()),
         destinations = $2::jsonb, publish_results = $3::jsonb
     WHERE id = $1 AND status = 'approved'
     RETURNING ${PROMO_COLS}`,
    [promotionId, JSON.stringify(destinations), JSON.stringify(publishResults)],
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
