-- PRC-A Batch 4 — Storage quota (caps 31–36).
--
-- The audit found: uploads are validated PER FILE (storage_service.validateUpload
-- mirrors the bucket's size/MIME cap) but there is NO cumulative tracking, NO
-- storage_quota table, and NO plan storage column — so an org can accumulate
-- unlimited storage one acceptable file at a time. This adds the cumulative half.
--
-- DESIGN — deliberately mirrors the Batch 3 AI-credit-wallet that was live-certified:
--   * usage is a PROJECTION over an append-only signed ledger
--     (storage_usage_entries), never a mutable counter that could drift or lose an
--     update under concurrency;
--   * the limit lives in the EXISTING plan-limit system (subscription_plans +
--     resolveSubscription), alongside the student/school slabs — NOT a second
--     limit system;
--   * enforcement follows the SOFT check-then-act model of enforceStudentLimit /
--     enforceSchoolLimit (a small transient over-quota is acceptable for a soft
--     resource; the next upload is blocked), NOT the wallet's atomic admit — money
--     needs atomicity, bytes do not.
--
-- BYTES, integer BIGINT throughout — no floats, so no rounding drift over millions
-- of files.

-- ─── Plan storage limit: a new column on the EXISTING plan catalog ────────────
-- NULL = unlimited (same convention as max_schools). Left NULL on all existing
-- plans so NOTHING changes on deploy — enforcement is additionally gated by the
-- STORAGE_QUOTA_ENFORCEMENT master switch (default OFF). Two independent brakes,
-- exactly like the wallet shipped dark.
ALTER TABLE subscription_plans
  ADD COLUMN IF NOT EXISTS max_storage_bytes BIGINT
    CHECK (max_storage_bytes IS NULL OR max_storage_bytes >= 0);

-- ─── Usage ledger: append-only + signed ──────────────────────────────────────
-- An upload writes a positive delta (bytes stored); a delete writes a negative
-- one (bytes freed). Usage = SUM(delta_bytes). There is no UPDATE/DELETE grant —
-- a usage ledger that can be silently rewritten cannot be trusted, exactly as for
-- ai_credit_entries. Correcting a mistake means a compensating row.
CREATE TABLE storage_usage_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  -- Storage is bought by the ORGANISATION (the plan is org-scoped), but we keep
  -- the school_id when known so a future per-school breakdown is possible without
  -- a migration. The quota itself is summed org-wide.
  school_id UUID,
  delta_bytes BIGINT NOT NULL,
  -- Which upload surface this came from (memories / admissions_document /
  -- complaint_photo / …) — free text so a new upload site needs no migration.
  category TEXT NOT NULL DEFAULT '',
  -- The storage object this delta accounts for — provenance for reconciliation.
  object_key TEXT NOT NULL DEFAULT '',
  actor_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  -- A no-op ledger row is noise; a delta must move the needle one way or the other.
  CONSTRAINT storage_usage_entries_delta_nonzero CHECK (delta_bytes <> 0)
);

-- The usage projection sums every row for an org; this is the covering index.
CREATE INDEX idx_storage_usage_entries_org
  ON storage_usage_entries (organization_id, created_at DESC);

ALTER TABLE storage_usage_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage_usage_entries FORCE ROW LEVEL SECURITY;

-- Org-wall read: usage is an org-level fact; a school-scoped session still needs
-- to read its own org's total for the presign quota gate to work.
CREATE POLICY storage_usage_entries_tenant_read ON storage_usage_entries
  FOR SELECT
  USING (organization_id = app_current_tenant_id());

-- INSERT through the normal tenant path (the upload handler runs on
-- withTenantContext); the tenant WITH CHECK is the backstop, the app-layer
-- recorder is the real writer.
CREATE POLICY storage_usage_entries_tenant_insert ON storage_usage_entries
  FOR INSERT
  WITH CHECK (organization_id = app_current_tenant_id());

-- SELECT, INSERT only — deliberately no UPDATE/DELETE (append-only ledger).
GRANT SELECT, INSERT ON storage_usage_entries TO erp_tenant;

-- ─── RBAC ────────────────────────────────────────────────────────────────────
-- Viewing the org's storage usage/limit is an org concern (they need to know how
-- much of what they bought is left). There is deliberately NO manage permission:
-- the limit is set by the PLAN, not granted ad hoc — routing a manual storage
-- top-up would be the "second limit system" the plan model already forbids.
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewStorageQuota', 'Storage', 'view', 'organization', 'View the organisation''s storage usage and plan limit')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug)
SELECT rd.slug, 'viewStorageQuota'
FROM role_definitions rd
WHERE rd.slug IN (
  'superAdmin', 'organizationOwner', 'organizationAdmin', 'management'
)
ON CONFLICT DO NOTHING;
