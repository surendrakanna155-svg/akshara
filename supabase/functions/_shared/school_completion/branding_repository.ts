import type { TenantQueryClient } from "../tenant_db.ts";

// ── Tenant-isolation probes (QA-R-004 — per-school branding isolation) ────────
// Branding is school-scoped (RLS: organization_id = tenant AND school_id =
// current_school). School A must read only its own branding row and never
// School B's.
export const SCHOOL_BRANDING_PROBE_SCHOOL_A = "e1000000-0000-4000-8000-000000000001";
export const SCHOOL_BRANDING_PROBE_SCHOOL_B = "e1000000-0000-4000-8000-000000000002";
export const SCHOOL_BRANDING_PROBE_SQL = `
  SELECT count(*)::text AS count FROM school_branding WHERE id = $1::uuid
`;

export interface BrandingRow {
  id: string;
  organization_id: string;
  school_id: string;
  display_name: string | null;
  tagline: string | null;
  primary_color: string;
  secondary_color: string;
  logo_url: string | null;
  favicon_url: string | null;
  login_background_url: string | null;
}

export interface BrandingInput {
  displayName?: string;
  tagline?: string;
  primaryColor?: string;
  secondaryColor?: string;
  logoUrl?: string;
  faviconUrl?: string;
  loginBackgroundUrl?: string;
}

const DEFAULT_BRANDING = {
  displayName: "NIKSHA School",
  tagline: "Learning with purpose",
  primaryColor: "#1B4D89",
  secondaryColor: "#F5A623",
  logoUrl: null as string | null,
  faviconUrl: null as string | null,
  loginBackgroundUrl: null as string | null,
};

export async function getSchoolBranding(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<BrandingRow | null> {
  const rows = await db.queryObject<BrandingRow>(
    `SELECT * FROM school_branding WHERE organization_id = $1 AND school_id = $2`,
    [orgId, schoolId],
  );
  return rows[0] ?? null;
}

export async function upsertSchoolBranding(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  input: BrandingInput,
): Promise<BrandingRow> {
  const rows = await db.queryObject<BrandingRow>(
    `INSERT INTO school_branding (
       organization_id, school_id, display_name, tagline,
       primary_color, secondary_color, logo_url, favicon_url, login_background_url
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
     ON CONFLICT (organization_id, school_id)
     DO UPDATE SET
       display_name = coalesce(EXCLUDED.display_name, school_branding.display_name),
       tagline = coalesce(EXCLUDED.tagline, school_branding.tagline),
       primary_color = coalesce(EXCLUDED.primary_color, school_branding.primary_color),
       secondary_color = coalesce(EXCLUDED.secondary_color, school_branding.secondary_color),
       logo_url = coalesce(EXCLUDED.logo_url, school_branding.logo_url),
       favicon_url = coalesce(EXCLUDED.favicon_url, school_branding.favicon_url),
       login_background_url = coalesce(EXCLUDED.login_background_url, school_branding.login_background_url),
       updated_at = timezone('utc', now())
     RETURNING *`,
    [
      orgId,
      schoolId,
      input.displayName ?? DEFAULT_BRANDING.displayName,
      input.tagline ?? DEFAULT_BRANDING.tagline,
      input.primaryColor ?? DEFAULT_BRANDING.primaryColor,
      input.secondaryColor ?? DEFAULT_BRANDING.secondaryColor,
      input.logoUrl ?? null,
      input.faviconUrl ?? null,
      input.loginBackgroundUrl ?? null,
    ],
  );
  return rows[0]!;
}

export function brandingToApi(row: BrandingRow | null) {
  const base = row ?? {
    display_name: DEFAULT_BRANDING.displayName,
    tagline: DEFAULT_BRANDING.tagline,
    primary_color: DEFAULT_BRANDING.primaryColor,
    secondary_color: DEFAULT_BRANDING.secondaryColor,
    logo_url: DEFAULT_BRANDING.logoUrl,
    favicon_url: DEFAULT_BRANDING.faviconUrl,
    login_background_url: DEFAULT_BRANDING.loginBackgroundUrl,
  };
  return {
    displayName: base.display_name,
    tagline: base.tagline,
    primaryColor: base.primary_color,
    secondaryColor: base.secondary_color,
    logoUrl: base.logo_url,
    faviconUrl: base.favicon_url,
    loginBackgroundUrl: base.login_background_url,
  };
}
