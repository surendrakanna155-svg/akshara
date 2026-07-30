-- PRC-A Batch 9 — Upload malware-scan infrastructure (owner-future-idea 29).
--
-- The audit found: validateUpload enforces extension/MIME/size, but there is NO
-- content (malware) scanning of uploaded files. This adds the scan-result ledger
-- + integration points so an AV engine can be plugged in later, following owner
-- decision #4's media-prep policy (which names a "malware pipeline" step).
--
-- DESIGN — honest ship-dark (mirrors the wallet / storage-quota pattern):
--   * A freshly-confirmed upload is recorded with an HONEST status. With no AV
--     configured it is 'skipped' ("we did not scan this") — NEVER a fabricated
--     'clean'. Only a real AV verdict sets 'clean' / 'infected'.
--   * Serving is gated by resolveScanDisposition() behind MALWARE_SCAN_ENFORCEMENT
--     (default OFF): today every object resolves to allow, so there is no behaviour
--     change on deploy. Flipping enforcement on (once an AV runs) blocks 'infected'
--     and holds 'pending' — without an AV, 'skipped' still passes (nothing scanned,
--     nothing to enforce), so enforcement can't take uploads offline by itself.
--   * A verdict is an UPDATE (a later AV callback flips pending→clean/infected);
--     the row is never deleted (auditable). No DELETE grant.

CREATE TABLE upload_scan_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  bucket TEXT NOT NULL,
  object_key TEXT NOT NULL,
  -- Which upload surface this came from (memories / admissions_document / complaint).
  module TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'clean', 'infected', 'skipped', 'error')),
  engine TEXT NOT NULL DEFAULT 'none',
  detail TEXT,
  scanned_at TIMESTAMPTZ,
  requested_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- One scan record per stored object; the confirm recorder upserts on this.
CREATE UNIQUE INDEX idx_upload_scan_results_object
  ON upload_scan_results (organization_id, object_key);

CREATE TRIGGER upload_scan_results_updated_at
  BEFORE UPDATE ON upload_scan_results FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE upload_scan_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE upload_scan_results FORCE ROW LEVEL SECURITY;

-- School-scoped: a school session records/reads only its own school's scan rows;
-- cross-school/cross-tenant rows are invisible.
CREATE POLICY upload_scan_results_school_scope ON upload_scan_results
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

-- SELECT, INSERT, UPDATE (for the AV verdict) — deliberately NO DELETE.
GRANT SELECT, INSERT, UPDATE ON upload_scan_results TO erp_tenant;

-- RBAC: no new slug — the scan record is written/read on the SAME upload paths
-- (memories/admissions/complaint) that already gate on their module permissions.
