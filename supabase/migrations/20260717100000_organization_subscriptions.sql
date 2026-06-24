-- B2 — Capability Gating → Entitlement Layer · Step 1 (data model + seed) · 2 of 3
--
-- Binds each organization to exactly one plan from the catalog. This is the
-- assignment + status layer — NOT billing. No payment, invoice, renewal or MRR
-- field exists here by design.
--
-- Default-to-Trial (locked pilot posture):
--   * every existing org is back-filled with a `trial` subscription below;
--   * every NEW org gets one via an AFTER INSERT trigger (SECURITY DEFINER, since
--     org provisioning may run under a scope that RLS would otherwise block);
--   * a missing row is still treated as Trial by the Step-2 resolver (fail-safe).
--
-- RLS: an org's own tokens (organization OR school scope) may READ its row;
-- only organization-scope tokens may WRITE (the route additionally gates on the
-- managePlatformSubscriptions permission — superAdmin — in Step 2). No DELETE
-- (status flips only), per the erp_tenant-no-DELETE rule. Additive only.

-- ─── organization_subscriptions ─────────────────────────────────────────────
CREATE TABLE organization_subscriptions (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id       UUID NOT NULL UNIQUE REFERENCES organizations (id),
  plan_slug             TEXT NOT NULL REFERENCES subscription_plans (slug),
  status                TEXT NOT NULL DEFAULT 'trial'
                          CHECK (status IN ('trial', 'active', 'grace', 'suspended')),
  -- Per-org slab/school overrides (NULL = inherit the plan's value).
  student_slab_max      INTEGER,
  max_schools_override  INTEGER,
  -- Trial lifecycle (set for trial rows; NULL once on a paid plan).
  trial_ends_at         TIMESTAMPTZ,
  grace_ends_at         TIMESTAMPTZ,
  -- Cached usage for fast limit checks (refreshed by Step-2 count paths).
  student_count_cached  INTEGER NOT NULL DEFAULT 0,
  school_count_cached   INTEGER NOT NULL DEFAULT 0,
  -- Enterprise per-deal entitlement overrides, e.g. {"grant": ["feature.ai_predictions"]}.
  overrides             JSONB NOT NULL DEFAULT '{}'::jsonb,
  started_at            TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  assigned_by           UUID REFERENCES users (id),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_organization_subscriptions_plan
  ON organization_subscriptions (plan_slug);

CREATE TRIGGER organization_subscriptions_updated_at
  BEFORE UPDATE ON organization_subscriptions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─── Back-fill every existing org with a Trial subscription ──────────────────
-- Runs before RLS is enabled. Uses the trial plan's own length/grace knobs so the
-- dates stay data-driven (30d + 7d as seeded), not hard-coded here.
INSERT INTO organization_subscriptions
  (organization_id, plan_slug, status, trial_ends_at, grace_ends_at, started_at)
SELECT
  o.id,
  'trial',
  'trial',
  timezone('utc', now()) + make_interval(days => COALESCE(p.trial_length_days, 30)),
  timezone('utc', now()) + make_interval(days => COALESCE(p.trial_length_days, 30)
                                              + COALESCE(p.trial_grace_days, 0)),
  timezone('utc', now())
FROM organizations o
CROSS JOIN subscription_plans p
WHERE p.slug = 'trial'
  AND o.deleted_at IS NULL
ON CONFLICT (organization_id) DO NOTHING;

-- ─── Forward default-to-Trial: new orgs get a Trial row on creation ─────────
-- SECURITY DEFINER so it inserts regardless of the creating connection's scope
-- (org provisioning is privileged). Idempotent via the UNIQUE org constraint.
CREATE OR REPLACE FUNCTION ensure_default_subscription()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
AS $$
DECLARE
  v_len  INTEGER;
  v_grc  INTEGER;
BEGIN
  SELECT COALESCE(trial_length_days, 30), COALESCE(trial_grace_days, 0)
    INTO v_len, v_grc
  FROM subscription_plans
  WHERE slug = 'trial';

  INSERT INTO organization_subscriptions
    (organization_id, plan_slug, status, trial_ends_at, grace_ends_at, started_at)
  VALUES
    (NEW.id,
     'trial',
     'trial',
     timezone('utc', now()) + make_interval(days => COALESCE(v_len, 30)),
     timezone('utc', now()) + make_interval(days => COALESCE(v_len, 30) + COALESCE(v_grc, 0)),
     timezone('utc', now()))
  ON CONFLICT (organization_id) DO NOTHING;

  RETURN NEW;
END;
$$;

CREATE TRIGGER organizations_default_subscription
  AFTER INSERT ON organizations
  FOR EACH ROW EXECUTE FUNCTION ensure_default_subscription();

-- ─── RLS: own-org read (org OR school scope); org-scope write only ───────────
ALTER TABLE organization_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_subscriptions FORCE ROW LEVEL SECURITY;

CREATE POLICY organization_subscriptions_read ON organization_subscriptions
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school')
  );

CREATE POLICY organization_subscriptions_insert ON organization_subscriptions
  FOR INSERT
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'organization'
  );

CREATE POLICY organization_subscriptions_update ON organization_subscriptions
  FOR UPDATE
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'organization'
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'organization'
  );

GRANT SELECT, INSERT, UPDATE ON organization_subscriptions TO erp_tenant;
