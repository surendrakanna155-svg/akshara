// PRC-A Batch 10 — brand profile repository (owner decision #4).

import type { TenantQueryClient } from "../tenant_db.ts";
import type { BrandAsset } from "./brand_asset_selection.ts";

export interface BrandProfileRow {
  id: string;
  organization_id: string;
  school_id: string;
  logo_url: string | null;
  tagline: string | null;
  theme: Record<string, unknown>;
  assets: BrandAsset[];
  is_active: boolean;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export async function getBrandProfile(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<BrandProfileRow | null> {
  const rows = await db.queryObject<BrandProfileRow>(
    `SELECT * FROM brand_profiles WHERE organization_id = $1 AND school_id = $2`,
    [orgId, schoolId],
  );
  return rows[0] ?? null;
}

export async function upsertBrandProfile(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string;
    logoUrl: string | null;
    tagline: string | null;
    theme: Record<string, unknown>;
    assets: BrandAsset[];
    isActive: boolean;
    createdBy: string;
  },
): Promise<BrandProfileRow> {
  const rows = await db.queryObject<BrandProfileRow>(
    `INSERT INTO brand_profiles (
       organization_id, school_id, logo_url, tagline, theme, assets, is_active, created_by
     ) VALUES ($1, $2, $3, $4, $5::jsonb, $6::jsonb, $7, $8)
     ON CONFLICT (organization_id, school_id)
     DO UPDATE SET
       logo_url = EXCLUDED.logo_url,
       tagline = EXCLUDED.tagline,
       theme = EXCLUDED.theme,
       assets = EXCLUDED.assets,
       is_active = EXCLUDED.is_active,
       updated_at = timezone('utc', now())
     RETURNING *`,
    [
      input.organizationId,
      input.schoolId,
      input.logoUrl,
      input.tagline,
      JSON.stringify(input.theme ?? {}),
      JSON.stringify(input.assets ?? []),
      input.isActive,
      input.createdBy,
    ],
  );
  return rows[0]!;
}
