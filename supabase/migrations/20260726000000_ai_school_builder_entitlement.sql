-- B7 — AI School Builder (Phase 1)
-- Adds the `feature.ai_school_builder` entitlement and grants it to Professional
-- & Enterprise plans (the AI pre-fill of school structure/config sits on the
-- certified onboarding foundation; Trial/Standard get the manual wizard only).
-- The pilot org is on the Professional plan, so it gains access here.

INSERT INTO plan_entitlements (plan_slug, entitlement_slug) VALUES
  ('professional', 'feature.ai_school_builder'),
  ('enterprise',   'feature.ai_school_builder')
ON CONFLICT (plan_slug, entitlement_slug) DO NOTHING;
