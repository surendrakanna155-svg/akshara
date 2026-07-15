-- PRC-A Batch 2 (caps 109-118) — Gate Pass / Early Pickup.
--
-- A parent or staff member RAISES a gate pass request for a student (early
-- pickup / late arrival / authorized exit). It goes through the existing F2
-- approval framework ("gatePass", entity_type "gate_pass") — see
-- approval_types.ts / approval_permissions.ts. On APPROVAL, the decision
-- handler (applyGatePassDecision, in _shared/gate_pass/) mints a single-use
-- credential (a 6-digit OTP + a QR token): ONLY their SHA-256 hashes are ever
-- persisted here — the plaintext is dispatched to the parent via the
-- communication service and never stored, logged, or returned in any API
-- response or approval-effect payload. At the gate, office staff present the
-- credential via POST /gate-passes/:id/verify; a guarded terminal UPDATE
-- (status='approved' -> 'used') makes a concurrent double-verify impossible —
-- this is a child-safety control (see the recurring money-integrity race
-- pattern this project has hardened elsewhere; the same discipline applies to
-- "who may collect this child" as to "who may collect this money").
--
-- Expiry is LAZY: `credential_expires_at` is compared at verify time (a
-- time-expired approved pass fails verification) and the API mapper computes
-- a display-only "expired" status for an approved-but-time-expired pass
-- rather than showing a misleading "approved" (see gate_pass_repository.ts).

CREATE TABLE gate_passes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL,
  pass_type TEXT NOT NULL
    CHECK (pass_type IN ('early_pickup', 'late_arrival', 'authorized_exit')),
  reason TEXT NOT NULL DEFAULT '',
  requested_by UUID NOT NULL,               -- auth.claims.sub of the raiser (staff or parent)
  pickup_person_name TEXT NOT NULL DEFAULT '',
  pickup_person_relation TEXT NOT NULL DEFAULT '',
  pickup_person_phone TEXT NOT NULL DEFAULT '',
  scheduled_at TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'used', 'expired', 'cancelled')),
  approval_request_id UUID REFERENCES approval_requests (id),
  -- Single-use credential — hashes ONLY (SHA-256 hex via the same hashToken()
  -- helper the OTP-login flow uses). The plaintext OTP/QR token is NEVER
  -- written to this table, any log, or an approval_domain_effects payload.
  otp_hash TEXT,
  qr_token_hash TEXT,
  credential_expires_at TIMESTAMPTZ,
  verified_by UUID,
  verified_at TIMESTAMPTZ,
  verification_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- At most one concurrently-open (pending or approved) gate pass per student
-- per scheduled slot — prevents a duplicate raise for the same pickup window.
CREATE UNIQUE INDEX uq_gate_passes_open_slot
  ON gate_passes (organization_id, school_id, student_id, scheduled_at)
  WHERE status IN ('pending', 'approved');

-- The staff queue: filter by school + status, newest-scheduled first.
CREATE INDEX idx_gate_passes_school_status
  ON gate_passes (organization_id, school_id, status, scheduled_at DESC);

-- A parent's own raised passes / a student's history.
CREATE INDEX idx_gate_passes_student
  ON gate_passes (organization_id, school_id, student_id, created_at DESC);

ALTER TABLE gate_passes ENABLE ROW LEVEL SECURITY;
ALTER TABLE gate_passes FORCE ROW LEVEL SECURITY;

-- School staff: full read/write within their own school (INSERT to raise,
-- UPDATE for approve/reject-effect, verify, and cancel — all via guarded,
-- status-scoped UPDATEs in the repository, never a free-form write).
CREATE POLICY gate_passes_school_read ON gate_passes
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY gate_passes_school_insert ON gate_passes
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY gate_passes_school_update ON gate_passes
  FOR UPDATE USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

-- Parent scope: SELECT + INSERT only, restricted to their own children (the
-- guardian pattern — mirrors 20260609100000_phase2_rls_scope.sql:247-272).
-- Parents never get UPDATE here — approve/reject/verify/cancel all run under
-- a school-scoped staff session (see gate_pass_handlers.ts for the RBAC gate
-- on cancel, which additionally allows the original requester).
CREATE POLICY gate_passes_parent_read ON gate_passes
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'parent'
    AND school_id = app_current_school_id()
    AND student_id IN (
      SELECT sg.student_id FROM student_guardians sg
      WHERE sg.guardian_user_id = app_current_parent_user_id()
        AND sg.status = 'active'
    )
  );
CREATE POLICY gate_passes_parent_insert ON gate_passes
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'parent'
    AND school_id = app_current_school_id()
    AND student_id IN (
      SELECT sg.student_id FROM student_guardians sg
      WHERE sg.guardian_user_id = app_current_parent_user_id()
        AND sg.status = 'active'
    )
  );

GRANT SELECT, INSERT, UPDATE ON gate_passes TO erp_tenant;

CREATE TRIGGER gate_passes_updated_at
  BEFORE UPDATE ON gate_passes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- RBAC — all three role slugs below are verified present in role_definitions
-- (20260608100000_rbac_foundation.sql): superAdmin, organizationOwner,
-- organizationAdmin, schoolAdmin, principal, vicePrincipal, management,
-- classTeacher, coordinator, officeStaff, parent. There is no
-- security-guard role in this project (per the PRC-A audit) — gate
-- verification reuses officeStaff.
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('requestGatePass', 'GatePass', 'create', 'school', 'Raise a gate pass / early pickup request for a student'),
  ('approveGatePass', 'GatePass', 'manage', 'school', 'Approve/reject a gate pass request (F2 approval type "gatePass")'),
  ('verifyGatePass', 'GatePass', 'manage', 'school', 'Verify the single-use OTP/QR credential at the gate and release the student')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug)
SELECT rd.slug, 'requestGatePass'
FROM role_definitions rd
WHERE rd.slug IN (
  'parent', 'classTeacher', 'coordinator', 'officeStaff',
  'principal', 'vicePrincipal', 'schoolAdmin'
)
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug)
SELECT rd.slug, 'approveGatePass'
FROM role_definitions rd
WHERE rd.slug IN (
  'classTeacher', 'coordinator', 'principal', 'vicePrincipal', 'schoolAdmin',
  'management', 'superAdmin', 'organizationOwner', 'organizationAdmin', 'officeStaff'
)
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug)
SELECT rd.slug, 'verifyGatePass'
FROM role_definitions rd
WHERE rd.slug IN ('officeStaff', 'principal', 'vicePrincipal', 'schoolAdmin')
ON CONFLICT DO NOTHING;
