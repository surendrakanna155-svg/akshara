-- Staff Face ID attendance (O5 — Must-Before-GA, parallel to QW8).
-- Device-biometric (Face ID / fingerprint) gated STAFF self check-in/out.
-- HARD-BLOCK: a check-in only lands after a real device biometric — there is NO
-- device-credential (PIN) fallback (owner decision 2026-06-30). NO computer-vision
-- face matching (Future Vision), NO GPS (Phase 2). Student attendance stays
-- teacher-entered (O4). Records BOTH check_in and check_out events (no pairing
-- enforcement in v1; no late/grace rules).
--
-- Two parts: (1) RBAC seed so the staff JWT carries `markStaffAttendance`;
-- (2) an append-only `staff_check_ins` ledger, school-scoped + JWT-subject-pinned.

-- 1. Permission catalog + role grants -------------------------------------------------
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('markStaffAttendance', 'HR', 'manage', 'school', 'Record own staff check-in/out (biometric)')
ON CONFLICT (slug) DO NOTHING;

-- Granted to EVERY staff role definition (all roles except parent/student). Staff
-- self-check-in is universal across personas; the biometric gate + the
-- JWT-derived actor identity (not role scarcity) are what prevent buddy-punching.
INSERT INTO role_permissions (role_slug, permission_slug)
SELECT rd.slug, 'markStaffAttendance'
FROM role_definitions rd
WHERE rd.slug NOT IN ('parent', 'student')
ON CONFLICT DO NOTHING;

-- 2. Append-only staff check-in ledger ------------------------------------------------
CREATE TABLE staff_check_ins (
  id TEXT NOT NULL,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  user_id UUID NOT NULL,                         -- the authenticated staff member (JWT sub)
  employee_ref TEXT,                             -- optional employee_code / display ref
  staff_name TEXT NOT NULL DEFAULT '',
  staff_role TEXT NOT NULL DEFAULT '',
  event_type TEXT NOT NULL,
  event_time TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  method TEXT NOT NULL DEFAULT 'biometric',      -- face_id | fingerprint | iris | biometric
  biometric_verified BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id, id),
  CONSTRAINT staff_check_ins_event_type_check CHECK (event_type IN ('check_in', 'check_out')),
  -- Hard-block at the row level too: only a biometric-verified event may persist.
  CONSTRAINT staff_check_ins_biometric_check CHECK (biometric_verified = TRUE)
);

CREATE INDEX idx_staff_check_ins_school_user
  ON staff_check_ins (organization_id, school_id, user_id, event_time DESC);

ALTER TABLE staff_check_ins ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_check_ins FORCE ROW LEVEL SECURITY;

-- INSERT is pinned to the caller's OWN JWT subject so no one can record a
-- check-in as another user (row-level buddy-punching prevention); reads are
-- school-scoped (HR/principal can see the school's ledger).
CREATE POLICY staff_check_ins_self_insert ON staff_check_ins
  FOR INSERT
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
    AND user_id = app_current_user_id()
  );

CREATE POLICY staff_check_ins_school_read ON staff_check_ins
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

-- Append-only: no UPDATE/DELETE grant (a check-in is an immutable record of fact).
GRANT SELECT, INSERT ON staff_check_ins TO erp_tenant;
