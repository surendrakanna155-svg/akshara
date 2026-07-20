-- PRC-A Batch 2 (caps 136-148) — Certificate Request Desk.
--
-- A parent or staff member RAISES a request for a student certificate
-- (bonafide/study/conduct/transfer/fee). It goes through the existing F2
-- approval framework ("certificateRequest", entity_type "certificate_request"
-- — see approval_types.ts / approval_permissions.ts). On APPROVAL, the
-- decision effect (applyCertificateRequestDecision, in
-- _shared/certificate_desk/) issues the certificate through the ALREADY
-- CERTIFIED SIS issuance engine (sis_certificates_repository.ts —
-- issueCertificate / issueTransferCertificate). This migration never
-- reimplements issuance; it only adds the request/approval-linkage layer in
-- front of it.
--
-- Mirrors 20260885000000_gate_passes.sql exactly for the RLS/RBAC shape (same
-- "parent or staff raises for a student, staff decides" scenario):
--   * requested_by UUID NOT NULL — auth.claims.sub of the raiser, no hard FK
--     (mirrors gate_passes; both staff and parent users live in `users`, but
--     the sibling migration deliberately left this unconstrained).
--   * Parent scope: SELECT + INSERT only, restricted to their own linked
--     children (guardian pattern — mirrors 20260609100000_phase2_rls_scope.sql
--     :247-272). Parents never get UPDATE — approve/reject/cancel all run
--     under a school-scoped staff session (see certificate_desk_handlers.ts
--     for the RBAC gate on cancel, which additionally allows the original
--     requester when that requester is staff).
--   * A partial UNIQUE index blocks a duplicate OPEN (pending/approved)
--     request for the same (student, certificate_type) — the analogue of the
--     gate-pass one-open-slot guard.

CREATE TABLE sis_certificate_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL REFERENCES students (id),
  certificate_type TEXT NOT NULL
    CHECK (certificate_type IN ('bonafide', 'study', 'conduct', 'transfer', 'fee')),
  purpose TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'issued', 'blocked_dues', 'cancelled')),
  requested_by UUID NOT NULL,               -- auth.claims.sub of the raiser (staff or parent)
  requested_by_role TEXT,
  approval_request_id UUID REFERENCES approval_requests (id),
  issued_certificate_id UUID REFERENCES sis_certificate_issues (id),
  issue_note TEXT,
  decided_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- At most one concurrently-open (pending or approved) request per student per
-- certificate type — prevents duplicate raises for the same document.
CREATE UNIQUE INDEX uq_sis_certificate_requests_open
  ON sis_certificate_requests (organization_id, school_id, student_id, certificate_type)
  WHERE status IN ('pending', 'approved');

-- The staff queue: filter by school + status, newest first.
CREATE INDEX idx_sis_certificate_requests_school_queue
  ON sis_certificate_requests (organization_id, school_id, status, created_at DESC);

-- A parent's own raised requests / a student's request history.
CREATE INDEX idx_sis_certificate_requests_student
  ON sis_certificate_requests (organization_id, school_id, student_id, created_at DESC);

ALTER TABLE sis_certificate_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE sis_certificate_requests FORCE ROW LEVEL SECURITY;

-- School staff: full read/write within their own school (INSERT to raise,
-- UPDATE for the approval-effect issue/reject/blocked_dues writes and cancel —
-- all via guarded, status-scoped UPDATEs in the repository, never a free-form
-- write).
CREATE POLICY sis_certificate_requests_school_read ON sis_certificate_requests
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY sis_certificate_requests_school_insert ON sis_certificate_requests
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY sis_certificate_requests_school_update ON sis_certificate_requests
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

-- Parent scope: SELECT + INSERT only, restricted to their own children.
CREATE POLICY sis_certificate_requests_parent_read ON sis_certificate_requests
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
CREATE POLICY sis_certificate_requests_parent_insert ON sis_certificate_requests
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

GRANT SELECT, INSERT, UPDATE ON sis_certificate_requests TO erp_tenant;

CREATE TRIGGER sis_certificate_requests_updated_at
  BEFORE UPDATE ON sis_certificate_requests
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- RBAC — all role slugs below are verified present in role_definitions
-- (20260608100000_rbac_foundation.sql): superAdmin, organizationOwner,
-- organizationAdmin, schoolAdmin, principal, vicePrincipal, management,
-- classTeacher, coordinator, officeStaff, parent.
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('requestStudentCertificate', 'SIS', 'request', 'school', 'Raise a certificate request for a student (bonafide/study/conduct/transfer/fee)'),
  ('approveCertificateRequest', 'SIS', 'approve', 'school', 'Approve/reject a student certificate request (F2 approval type "certificateRequest")')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug)
SELECT rd.slug, 'requestStudentCertificate'
FROM role_definitions rd
WHERE rd.slug IN (
  'parent', 'officeStaff', 'classTeacher', 'coordinator',
  'principal', 'vicePrincipal', 'schoolAdmin'
)
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug)
SELECT rd.slug, 'approveCertificateRequest'
FROM role_definitions rd
WHERE rd.slug IN (
  'principal', 'vicePrincipal', 'schoolAdmin', 'officeStaff', 'management',
  'superAdmin', 'organizationOwner', 'organizationAdmin'
)
ON CONFLICT DO NOTHING;
