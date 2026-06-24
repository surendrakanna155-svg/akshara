-- B2 — Capability Gating → Entitlement Layer · Step 1 (data model + seed) · 1 of 3
--
-- The plan catalog: the data-driven source of truth for which commercial plans
-- exist and what each plan is *allowed* to use. Everything here is DATA — names,
-- slabs, prices and entitlement rows are edited in these tables, never in code.
--
-- Scope (locked 2026-06-24 by owner): entitlement layer only. NO billing, MRR,
-- renewals, invoicing, payment collection, dedicated DBs, white-label, or addons.
-- `base_price_paise` is DISPLAY-ONLY — B2 never collects payment.
--
-- Plans (locked): Trial · Standard · Professional · Enterprise.
-- Trial: 30-day length + 7-day grace. AI predictions: Enterprise-included (not an addon).
--
-- Resolution rule (enforced in Step 2, not here):
--   effectiveCapability(cap) = planAllows(cap) AND schoolConfigEnabled(cap)
-- A school may narrow within its plan but can never exceed it.
--
-- Catalog tables are platform-global reference data: readable to any authenticated
-- tenant (drives GET /plans), but never tenant-writable. Seeds run BEFORE RLS is
-- enabled so the migration owner can populate them; afterwards FORCE RLS makes the
-- rows read-only to the erp_tenant connection. Additive only.

-- ─── subscription_plans ─────────────────────────────────────────────────────
CREATE TABLE subscription_plans (
  slug                  TEXT PRIMARY KEY,
  name                  TEXT NOT NULL,
  description           TEXT NOT NULL DEFAULT '',
  tier_rank             INTEGER NOT NULL DEFAULT 0,
  -- Limits (data-driven slab). NULL student_slab_max / max_schools = unlimited.
  student_slab_min      INTEGER NOT NULL DEFAULT 0,
  student_slab_max      INTEGER,
  max_schools           INTEGER,
  grace_buffer_percent  NUMERIC NOT NULL DEFAULT 10,   -- slab over-run grace (limit.students)
  -- Trial-only lifecycle knobs (NULL for non-trial plans).
  trial_length_days     INTEGER,
  trial_grace_days      INTEGER,
  -- Display-only commercial reference. NO payment is ever collected in B2.
  base_price_paise      BIGINT NOT NULL DEFAULT 0,
  is_trial              BOOLEAN NOT NULL DEFAULT FALSE,
  is_public             BOOLEAN NOT NULL DEFAULT TRUE,
  is_active             BOOLEAN NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_subscription_plans_tier ON subscription_plans (tier_rank);

CREATE TRIGGER subscription_plans_updated_at
  BEFORE UPDATE ON subscription_plans
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─── plan_entitlements ──────────────────────────────────────────────────────
-- One row per (plan, entitlement slug the plan grants). Slugs follow addendum
-- §6.3 (`module.*`, `feature.*`) and map onto the existing SchoolCapabilities
-- flags so the gating engine is reused, not replaced. Limits live on the plan
-- columns above, not as rows here.
CREATE TABLE plan_entitlements (
  plan_slug         TEXT NOT NULL REFERENCES subscription_plans (slug),
  entitlement_slug  TEXT NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (plan_slug, entitlement_slug)
);

CREATE INDEX idx_plan_entitlements_slug ON plan_entitlements (entitlement_slug);

-- ─── Seed (runs before RLS is enabled) ──────────────────────────────────────
-- Slabs/prices below are the seed proposal from the spec (§3) — all owner-editable
-- data. Trial = Standard-equivalent entitlements, time-boxed 30d + 7d grace.
INSERT INTO subscription_plans
  (slug, name, description, tier_rank,
   student_slab_min, student_slab_max, max_schools, grace_buffer_percent,
   trial_length_days, trial_grace_days, base_price_paise, is_trial, is_public, is_active)
VALUES
  ('trial',        'Trial',        'Time-boxed pilot — Standard-equivalent modules for 30 days.', 0,
     0,  100,    1, 10,   30, 7,        0, TRUE,  TRUE, TRUE),
  ('standard',     'Standard',     'Single school — core academic & operations modules.',         1,
     0,  500,    1, 10,   NULL, NULL,   0, FALSE, TRUE, TRUE),
  ('professional', 'Professional', 'Growing / multi-school — adds operations modules & insights.', 2,
     0, 2000,    5, 10,   NULL, NULL,   0, FALSE, TRUE, TRUE),
  ('enterprise',   'Enterprise',   'Large groups & trusts — all modules, AI predictions, custom slabs.', 3,
     0, NULL, NULL, 10,   NULL, NULL,   0, FALSE, TRUE, TRUE)
ON CONFLICT (slug) DO NOTHING;

-- Entitlement grants per the §4 feature-gating matrix.
--   Core modules → every plan (incl. Trial).
--   Ops modules + parent insights → Professional & Enterprise.
--   Trust org + AI predictions → Enterprise only (AI predictions is Enterprise-included).
INSERT INTO plan_entitlements (plan_slug, entitlement_slug) VALUES
  -- Core (all plans)
  ('trial',        'module.admissions'),
  ('trial',        'module.finance'),
  ('trial',        'module.sis'),
  ('trial',        'module.management'),
  ('trial',        'module.attendance'),
  ('trial',        'module.exams'),
  ('standard',     'module.admissions'),
  ('standard',     'module.finance'),
  ('standard',     'module.sis'),
  ('standard',     'module.management'),
  ('standard',     'module.attendance'),
  ('standard',     'module.exams'),
  ('professional', 'module.admissions'),
  ('professional', 'module.finance'),
  ('professional', 'module.sis'),
  ('professional', 'module.management'),
  ('professional', 'module.attendance'),
  ('professional', 'module.exams'),
  ('enterprise',   'module.admissions'),
  ('enterprise',   'module.finance'),
  ('enterprise',   'module.sis'),
  ('enterprise',   'module.management'),
  ('enterprise',   'module.attendance'),
  ('enterprise',   'module.exams'),
  -- Operations modules + parent insights (Professional & Enterprise)
  ('professional', 'module.transport'),
  ('professional', 'module.hostel'),
  ('professional', 'module.library'),
  ('professional', 'module.inventory'),
  ('professional', 'module.alumni'),
  ('professional', 'module.hr_payroll'),
  ('professional', 'module.multi_branch'),
  ('professional', 'feature.parent_insights'),
  ('enterprise',   'module.transport'),
  ('enterprise',   'module.hostel'),
  ('enterprise',   'module.library'),
  ('enterprise',   'module.inventory'),
  ('enterprise',   'module.alumni'),
  ('enterprise',   'module.hr_payroll'),
  ('enterprise',   'module.multi_branch'),
  ('enterprise',   'feature.parent_insights'),
  -- Enterprise-only
  ('enterprise',   'module.trust_org'),
  ('enterprise',   'feature.ai_predictions')
ON CONFLICT (plan_slug, entitlement_slug) DO NOTHING;

-- ─── RLS: platform-global read-only reference ───────────────────────────────
-- Readable by any authenticated tenant (GET /plans); never tenant-writable.
ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_plans FORCE ROW LEVEL SECURITY;
CREATE POLICY subscription_plans_read ON subscription_plans
  FOR SELECT USING (true);
GRANT SELECT ON subscription_plans TO erp_tenant;

ALTER TABLE plan_entitlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE plan_entitlements FORCE ROW LEVEL SECURITY;
CREATE POLICY plan_entitlements_read ON plan_entitlements
  FOR SELECT USING (true);
GRANT SELECT ON plan_entitlements TO erp_tenant;
