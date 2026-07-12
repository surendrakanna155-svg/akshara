-- SCE-1 slice 3 — Student Clearance dues-WAIVER ledger (two-person maker-checker).
--
-- The design-sanctioned override: schools DO waive a (usually small) remaining
-- due at exit so a Transfer Certificate can issue. Per the owner decision the
-- override is maker-checker with separation of duties (approver != requester),
-- mirroring FIN-D4 fee concessions and the HR-3 leave SoD. A maker raises a
-- waiver for a student+lifecycle, snapshotting the blocking amount as it stands;
-- a DIFFERENT checker approves it; only an APPROVED (un-consumed) waiver that
-- still covers the current dues lets the clearance gate pass. The waiver is
-- CONSUMED (single-use) when the lifecycle event (e.g. the TC) is issued, and
-- the decision is snapshotted onto the certificate row so the exit stays
-- auditable forever.

CREATE TABLE student_clearance_waivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL,
  lifecycle TEXT NOT NULL,
  reason TEXT NOT NULL DEFAULT '',
  -- The blocking dues total as it stood when the maker raised the waiver — what
  -- the checker is approving. A waiver only clears the gate if the CURRENT
  -- blocking amount has not grown beyond this (else dues accrued post-approval
  -- and a fresh waiver is required — no open-ended "waive all future dues").
  blocking_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'consumed')),
  maker_id UUID NOT NULL,                          -- who raised it (JWT subject)
  checker_id UUID,                                 -- who decided it (!= maker)
  decided_at TIMESTAMPTZ,
  consumed_by_issue_id UUID REFERENCES sis_certificate_issues (id),
  consumed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT clearance_waiver_lifecycle_check CHECK (
    lifecycle IN (
      'transfer_certificate', 'transfer', 'alumni_conversion',
      'promotion', 'year_close'
    )
  ),
  CONSTRAINT clearance_waiver_amount_check CHECK (blocking_amount >= 0)
);

-- The approver queue (pending, newest first) + the maker's own history.
CREATE INDEX idx_clearance_waivers_school_status
  ON student_clearance_waivers (organization_id, school_id, status, created_at DESC);
CREATE INDEX idx_clearance_waivers_maker
  ON student_clearance_waivers (organization_id, school_id, maker_id, created_at DESC);

-- The gate lookup: at most ONE approved, un-consumed waiver per
-- (org, school, student, lifecycle) at a time — the partial unique index makes
-- a second concurrent approval impossible, so the gate reads a single row.
CREATE UNIQUE INDEX uq_clearance_waivers_active
  ON student_clearance_waivers (organization_id, school_id, student_id, lifecycle)
  WHERE status = 'approved';

ALTER TABLE student_clearance_waivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_clearance_waivers FORCE ROW LEVEL SECURITY;

-- Maker raises within their school; supervisory principals/HR read + decide the
-- school's queue. All school-scoped (finance-sensitive — never org-wide).
CREATE POLICY clearance_waivers_school_read ON student_clearance_waivers
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY clearance_waivers_school_insert ON student_clearance_waivers
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY clearance_waivers_school_update ON student_clearance_waivers
  FOR UPDATE USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
GRANT SELECT, INSERT, UPDATE ON student_clearance_waivers TO erp_tenant;

-- TC-record SNAPSHOT (idempotent, immutable audit): what the clearance state was
-- when the certificate issued — the dues present, and the waiver that cleared
-- them (if any). Additive nullable columns on the existing issue register.
ALTER TABLE sis_certificate_issues
  ADD COLUMN IF NOT EXISTS clearance_snapshot_amount NUMERIC(12, 2),
  ADD COLUMN IF NOT EXISTS clearance_waiver_id UUID
    REFERENCES student_clearance_waivers (id);

-- RBAC — the CHECKER permission. The maker raises with the existing manageSis
-- (raising a waiver is part of SIS student management); the checker needs this
-- distinct supervisory slug so approve != raise is enforceable and auditable.
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('approveClearanceWaiver', 'SIS', 'manage', 'school', 'Approve/reject a student clearance dues-waiver (maker-checker)')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug)
SELECT rd.slug, 'approveClearanceWaiver'
FROM role_definitions rd
WHERE rd.slug IN (
  'principal', 'vicePrincipal', 'schoolAdmin', 'management',
  'superAdmin', 'organizationOwner', 'organizationAdmin'
)
ON CONFLICT DO NOTHING;
