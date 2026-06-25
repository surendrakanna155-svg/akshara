-- B6 — Marketing Engine MVP completion.
--
-- 1. Round-trip the campaign acquisition fields the Flutter client already sends
--    (audience segment + scheduled send time). The v11 foundation schema dropped
--    them silently (no columns); persist them so create/list/update is lossless.
--
-- 2. Gate the Marketing / Growth engine behind a plan entitlement
--    (`module.marketing`), consistent with every other module (B2). Granted to
--    Professional & Enterprise; Trial/Standard receive `402 PLAN_UPGRADE_REQUIRED`.
--    The pilot org is assigned the Professional plan, so it inherits the grant —
--    no per-org seed needed.

ALTER TABLE growth_campaigns
  ADD COLUMN IF NOT EXISTS audience TEXT NOT NULL DEFAULT 'all',
  ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ;

INSERT INTO plan_entitlements (plan_slug, entitlement_slug) VALUES
  ('professional', 'module.marketing'),
  ('enterprise',   'module.marketing')
ON CONFLICT (plan_slug, entitlement_slug) DO NOTHING;
