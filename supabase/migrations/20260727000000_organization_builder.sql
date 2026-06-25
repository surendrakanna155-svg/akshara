-- B10 — Organization Builder (P3, Platform Expansion). Backend foundation.
--
-- The Organization Builder is the chain/trust owner's no-touch path to stand up a
-- new vertical organization: pick a vertical pack → a guided interview → a
-- generated configuration preview (modules / roles / widgets / workflows) →
-- provisioning. The entire Flutter UI (hub, 7-step interview, preview,
-- provisioning) already ships against a frozen contract; this migration + the
-- `_shared/organization_builder/` module give it a real backend.
--
-- Three real tables back the contract:
--   • org_builder_packs            — vertical pack CATALOG (reference data, seeded
--                                     here; org-agnostic, read-only to tenants).
--   • org_builder_interview_drafts — one row per in-flight interview; id is the
--                                     CLIENT-SUPPLIED draft id (e.g. "draft_173…"),
--                                     so the PK is TEXT, not a UUID. answers and AI
--                                     recommendations are persisted as JSONB.
--   • org_builder_provisioning_jobs — one row per provisioning run. Provisioning is
--                                     REAL, synchronous, audited work: it resolves
--                                     the configuration, persists it, marks the
--                                     draft provisioned, and records each step's
--                                     actual outcome (no simulated timers).
--
-- Security: Organization Builder is ORGANIZATION scope (chains/trusts only). Two
-- new permissions gate it (view / manage), granted to org/group leadership +
-- platform super admin. The two stateful tables enforce org-scope RLS exactly like
-- the Director portal; the catalog is readable by any org-scope caller. Access is
-- additionally entitlement-gated by `feature.organization_builder` (Enterprise),
-- enforced in the router.

-- ─── Permissions ────────────────────────────────────────────────────────────

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewOrganizationBuilder',   'OrganizationBuilder', 'view',   'organization', 'View organization builder'),
  ('manageOrganizationBuilder', 'OrganizationBuilder', 'manage', 'organization', 'Manage organization builder')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('organizationOwner',   'viewOrganizationBuilder'),
  ('organizationOwner',   'manageOrganizationBuilder'),
  ('organizationAdmin',   'viewOrganizationBuilder'),
  ('organizationAdmin',   'manageOrganizationBuilder'),
  ('schoolGroupDirector', 'viewOrganizationBuilder'),
  ('schoolGroupDirector', 'manageOrganizationBuilder'),
  ('superAdmin',          'viewOrganizationBuilder'),
  ('superAdmin',          'manageOrganizationBuilder')
ON CONFLICT DO NOTHING;

-- ─── Entitlement (Enterprise-only; per-deal override-grantable) ──────────────
-- Chains/trusts are the Enterprise tier. Mirrors module.trust_org / feature.ai_predictions.

INSERT INTO plan_entitlements (plan_slug, entitlement_slug) VALUES
  ('enterprise', 'feature.organization_builder')
ON CONFLICT (plan_slug, entitlement_slug) DO NOTHING;

-- ─── Vertical pack catalog (reference data) ─────────────────────────────────

CREATE TABLE org_builder_packs (
  id               TEXT PRIMARY KEY,
  type             TEXT NOT NULL
    CHECK (type IN ('school', 'salon', 'hospital', 'restaurant')),
  name             TEXT NOT NULL,
  description      TEXT NOT NULL DEFAULT '',
  primary_entities TEXT[] NOT NULL DEFAULT '{}',
  module_seeds     TEXT[] NOT NULL DEFAULT '{}',
  dashboard_focus  TEXT NOT NULL DEFAULT '',
  brand_label      TEXT,
  sort_order       INTEGER NOT NULL DEFAULT 0,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TRIGGER org_builder_packs_updated_at
  BEFORE UPDATE ON org_builder_packs
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

INSERT INTO org_builder_packs
  (id, type, name, description, primary_entities, module_seeds, dashboard_focus, brand_label, sort_order)
VALUES
  ('pack_school', 'school', 'Education',
   'Students, classes, academic year — SIS, Finance, Education Suite.',
   ARRAY['Students', 'Classes', 'Academic year'],
   ARRAY['SIS', 'Finance', 'Education Suite', 'Transport', 'Hostel'],
   'Attendance, fees, risk, memories', NULL, 0),
  ('pack_salon', 'salon', 'Salon (Velora)',
   'Clients, stylists, services — appointments, retail, staff scheduling.',
   ARRAY['Clients', 'Stylists', 'Services'],
   ARRAY['Appointments', 'Retail inventory', 'Staff', 'Loyalty'],
   'Chair utilization, revenue, loyalty', 'Velora', 1),
  ('pack_hospital', 'hospital', 'Hospital',
   'Patients, departments, practitioners — billing, pharmacy, lab.',
   ARRAY['Patients', 'Departments', 'Practitioners'],
   ARRAY['Appointments', 'Billing', 'Pharmacy', 'Lab', 'Supply'],
   'Bed/OPD load, collections, inventory', NULL, 2),
  ('pack_restaurant', 'restaurant', 'Restaurant',
   'Tables, menu, kitchen stations — orders, inventory, staff shifts.',
   ARRAY['Tables', 'Menu', 'Kitchen stations'],
   ARRAY['Orders', 'Inventory', 'Staff shifts', 'POS'],
   'Covers, ticket time, waste', NULL, 3)
ON CONFLICT (id) DO NOTHING;

-- ─── Interview drafts (org-scoped; client-supplied TEXT id) ─────────────────

CREATE TABLE org_builder_interview_drafts (
  id                TEXT PRIMARY KEY,
  organization_id   UUID NOT NULL REFERENCES organizations (id),
  pack_id           TEXT NOT NULL REFERENCES org_builder_packs (id),
  organization_name TEXT NOT NULL DEFAULT '',
  current_step      INTEGER NOT NULL DEFAULT 0,
  answers           JSONB NOT NULL DEFAULT '{}'::jsonb,
  recommendations   JSONB NOT NULL DEFAULT '[]'::jsonb,
  status            TEXT NOT NULL DEFAULT 'in_progress'
    CHECK (status IN ('in_progress', 'ready_for_preview', 'provisioned')),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_org_builder_drafts_org
  ON org_builder_interview_drafts (organization_id, updated_at DESC);

CREATE TRIGGER org_builder_interview_drafts_updated_at
  BEFORE UPDATE ON org_builder_interview_drafts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─── Provisioning jobs (org-scoped) ─────────────────────────────────────────

CREATE TABLE org_builder_provisioning_jobs (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id   UUID NOT NULL REFERENCES organizations (id),
  draft_id          TEXT NOT NULL REFERENCES org_builder_interview_drafts (id),
  organization_name TEXT NOT NULL DEFAULT '',
  status            TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'running', 'completed', 'failed')),
  steps             JSONB NOT NULL DEFAULT '[]'::jsonb,
  resolved_config   JSONB NOT NULL DEFAULT '{}'::jsonb,
  started_at        TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  completed_at      TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_org_builder_jobs_org
  ON org_builder_provisioning_jobs (organization_id, started_at DESC);

CREATE INDEX idx_org_builder_jobs_draft
  ON org_builder_provisioning_jobs (draft_id);

CREATE TRIGGER org_builder_provisioning_jobs_updated_at
  BEFORE UPDATE ON org_builder_provisioning_jobs
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─── RLS ────────────────────────────────────────────────────────────────────
-- Catalog: any org-scope caller may read. Stateful tables: hard org-scope, both
-- directions (mirrors the Director portal). A school/parent/student token (scope
-- not in the org set) matches none of these.

ALTER TABLE org_builder_packs ENABLE ROW LEVEL SECURITY;
ALTER TABLE org_builder_packs FORCE ROW LEVEL SECURITY;
ALTER TABLE org_builder_interview_drafts ENABLE ROW LEVEL SECURITY;
ALTER TABLE org_builder_interview_drafts FORCE ROW LEVEL SECURITY;
ALTER TABLE org_builder_provisioning_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE org_builder_provisioning_jobs FORCE ROW LEVEL SECURITY;

CREATE POLICY org_builder_packs_org_read ON org_builder_packs
  FOR SELECT USING (
    app_current_scope() IN ('organization', 'school_group', 'platform')
  );

CREATE POLICY org_builder_drafts_org_scope ON org_builder_interview_drafts
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school_group', 'platform')
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school_group', 'platform')
  );

CREATE POLICY org_builder_jobs_org_scope ON org_builder_provisioning_jobs
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school_group', 'platform')
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() IN ('organization', 'school_group', 'platform')
  );

GRANT SELECT ON org_builder_packs TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON org_builder_interview_drafts TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON org_builder_provisioning_jobs TO erp_tenant;
