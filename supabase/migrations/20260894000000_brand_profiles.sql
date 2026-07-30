-- PRC-A Batch 10 — Marketing internal work (owner decision #4).
--
-- Owner #4: "build ALL internal work now, isolate only the external activation gate
-- (no faked live publishing)." The internal, buildable-now pieces are: a per-tenant
-- reusable brand profile (logo / assets / campus photos / theme), minimum-relevant-
-- asset selection, and a provider-neutral poster-engine interface. The actual image
-- generation (paid provider) and live Meta/IG publish (App Review) stay external.
--
-- This adds the brand profile. `school_branding` already exists but is app/login UI
-- chrome (display_name/colors/logo for the login screen), NOT a marketing asset kit
-- — overloading it would conflate two concerns, so this is a dedicated table with
-- the same per-school-unique + RLS shape as the promotion family.

CREATE TABLE brand_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  logo_url TEXT,
  tagline TEXT,
  -- Poster theme: {primaryColor, secondaryColor, fontFamily, ...}. Free JSONB so a
  -- new theme knob needs no migration.
  theme JSONB NOT NULL DEFAULT '{}'::jsonb,
  -- Reusable marketing assets: [{id, type, url, tags:[...], description}]. The
  -- minimum-relevant-asset selector scores these by tag/keyword overlap so a poster
  -- request never ships the whole library.
  assets JSONB NOT NULL DEFAULT '[]'::jsonb,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT brand_profiles_assets_is_array CHECK (jsonb_typeof(assets) = 'array'),
  CONSTRAINT brand_profiles_theme_is_object CHECK (jsonb_typeof(theme) = 'object')
);

CREATE UNIQUE INDEX idx_brand_profiles_school
  ON brand_profiles (organization_id, school_id);

CREATE TRIGGER brand_profiles_updated_at
  BEFORE UPDATE ON brand_profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE brand_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE brand_profiles FORCE ROW LEVEL SECURITY;

-- Same school-scoped shape as achievement_promotions.
CREATE POLICY brand_profiles_school_scope ON brand_profiles
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

-- SELECT, INSERT, UPDATE — a brand profile is retired via is_active, not deleted.
GRANT SELECT, INSERT, UPDATE ON brand_profiles TO erp_tenant;

-- RBAC: reuse the EXISTING promotion permissions (viewAchievementPromotion /
-- manageAchievementPromotion) — the brand profile is a promotion-domain marketing
-- asset. No new slug.
