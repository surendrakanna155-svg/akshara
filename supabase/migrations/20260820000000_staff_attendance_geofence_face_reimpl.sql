-- B4 — Staff Attendance RE-IMPLEMENTATION (supersedes the O5 device-biometric model).
-- Owner decision docs/ATTENDANCE_AUTH_DESIGN_DECISION.md (FINAL 2026-07-01):
-- attendance auth = GPS geofence -> anti-mock location -> live camera face
-- with AUTOMATED CV FACE MATCH (§7 option a) against a per-staff enrolled
-- reference face. Device biometric is FORBIDDEN as the attendance proof (it stays
-- ONLY on the app-login convenience path).
--
-- This migration:
--   1. Drops the device-biometric hard-block on staff_check_ins and adds the
--      geofence + anti-mock + face-match evidence columns.
--   2. Adds per-school geofence config (center + radius + accuracy policy).
--   3. Adds per-staff face enrollment (reference embedding, privacy-preserving —
--      an embedding vector, NOT a raw image).
--   4. Adds the audited Manual Attendance Request path (GA-2) — the ONLY fallback
--      when geofence/camera cannot complete (no silent bypass).
--   5. Adds the RBAC slugs (approveStaffAttendance, manageSchoolGeofence).

-- 1. staff_check_ins — remove biometric hard-block, add geofence + face-match evidence ----
ALTER TABLE staff_check_ins DROP CONSTRAINT IF EXISTS staff_check_ins_biometric_check;
ALTER TABLE staff_check_ins ALTER COLUMN biometric_verified SET DEFAULT FALSE;
ALTER TABLE staff_check_ins ALTER COLUMN method SET DEFAULT 'face_match';

ALTER TABLE staff_check_ins
  ADD COLUMN IF NOT EXISTS geo_latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS geo_longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS geo_accuracy_m DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS distance_m DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS mock_location_detected BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS location_verified BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS liveness_passed BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS face_match_score DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS face_matched BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS capture_ref TEXT;

-- New row-level hard-block: only a row that passed BOTH location AND face match may
-- persist as an automatic check-in (method='face_match'). Manual (approved) rows are
-- exempt — they carry their own approval audit trail.
ALTER TABLE staff_check_ins
  ADD CONSTRAINT staff_check_ins_verified_check CHECK (
    method = 'manual'
    OR (location_verified = TRUE AND face_matched = TRUE AND mock_location_detected = FALSE)
  );

-- 2. Per-school geofence config -----------------------------------------------------------
CREATE TABLE school_attendance_geofences (
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  center_latitude DOUBLE PRECISION NOT NULL,
  center_longitude DOUBLE PRECISION NOT NULL,
  radius_m INTEGER NOT NULL DEFAULT 100,            -- default 100 m; 50/100/150/200/300
  max_accuracy_m INTEGER NOT NULL DEFAULT 50,       -- reject fixes worse than this
  max_location_age_s INTEGER NOT NULL DEFAULT 60,   -- reject stale/cached fixes
  updated_by UUID,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id),
  CONSTRAINT geofence_radius_check CHECK (radius_m BETWEEN 25 AND 1000),
  CONSTRAINT geofence_accuracy_check CHECK (max_accuracy_m BETWEEN 5 AND 200),
  CONSTRAINT geofence_lat_check CHECK (center_latitude BETWEEN -90 AND 90),
  CONSTRAINT geofence_lng_check CHECK (center_longitude BETWEEN -180 AND 180)
);
ALTER TABLE school_attendance_geofences ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_attendance_geofences FORCE ROW LEVEL SECURITY;

CREATE POLICY school_geofence_read ON school_attendance_geofences
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY school_geofence_write ON school_attendance_geofences
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY school_geofence_update ON school_attendance_geofences
  FOR UPDATE USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
GRANT SELECT, INSERT, UPDATE ON school_attendance_geofences TO erp_tenant;

-- 3. Per-staff face enrollment (reference embedding — privacy-preserving) ------------------
CREATE TABLE staff_face_enrollments (
  id TEXT NOT NULL,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  user_id UUID NOT NULL,                             -- JWT subject; own enrollment only
  embedding JSONB NOT NULL,                          -- float vector (NOT a raw image)
  embedding_dim INTEGER NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  enrolled_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id, id),
  CONSTRAINT face_enrollment_dim_check CHECK (embedding_dim BETWEEN 32 AND 1024)
);
-- One ACTIVE enrollment per user per school.
CREATE UNIQUE INDEX idx_staff_face_active
  ON staff_face_enrollments (organization_id, school_id, user_id)
  WHERE active = TRUE;
ALTER TABLE staff_face_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_face_enrollments FORCE ROW LEVEL SECURITY;

-- A staff member enrolls/replaces only their OWN reference face.
CREATE POLICY face_enroll_self_insert ON staff_face_enrollments
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
    AND user_id = app_current_user_id()
  );
CREATE POLICY face_enroll_self_update ON staff_face_enrollments
  FOR UPDATE USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
    AND user_id = app_current_user_id()
  );
-- Read own enrollment (the server needs the reference embedding to match against).
CREATE POLICY face_enroll_self_read ON staff_face_enrollments
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
    AND user_id = app_current_user_id()
  );
GRANT SELECT, INSERT, UPDATE ON staff_face_enrollments TO erp_tenant;

-- 4. Manual Attendance Request (GA-2) — the ONLY audited fallback (no silent bypass) -------
CREATE TABLE staff_attendance_requests (
  id TEXT NOT NULL,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  user_id UUID NOT NULL,                             -- requester (JWT subject)
  staff_name TEXT NOT NULL DEFAULT '',
  event_type TEXT NOT NULL,
  reason TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending',
  decided_by UUID,
  decided_at TIMESTAMPTZ,
  resulting_check_in_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id, id),
  CONSTRAINT attendance_request_event_check CHECK (event_type IN ('check_in', 'check_out')),
  CONSTRAINT attendance_request_status_check CHECK (status IN ('pending', 'approved', 'rejected'))
);
CREATE INDEX idx_attendance_requests_school_status
  ON staff_attendance_requests (organization_id, school_id, status, created_at DESC);
ALTER TABLE staff_attendance_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_attendance_requests FORCE ROW LEVEL SECURITY;

-- Staff raise their own request; school-scoped principals/HR read + decide the school's queue.
CREATE POLICY attendance_request_self_insert ON staff_attendance_requests
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
    AND user_id = app_current_user_id()
  );
CREATE POLICY attendance_request_school_read ON staff_attendance_requests
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY attendance_request_school_update ON staff_attendance_requests
  FOR UPDATE USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
GRANT SELECT, INSERT, UPDATE ON staff_attendance_requests TO erp_tenant;

-- 5. RBAC — new permission slugs ----------------------------------------------------------
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('approveStaffAttendance', 'HR', 'manage', 'school', 'Approve/reject manual staff attendance requests'),
  ('manageSchoolGeofence', 'HR', 'manage', 'school', 'Configure the school attendance geofence')
ON CONFLICT (slug) DO NOTHING;

-- Approval + geofence config are supervisory: principal / school-admin / HR roles only,
-- NOT every staff role (contrast markStaffAttendance which is universal for self check-in).
INSERT INTO role_permissions (role_slug, permission_slug)
SELECT rd.slug, p.slug
FROM role_definitions rd
CROSS JOIN (VALUES ('approveStaffAttendance'), ('manageSchoolGeofence')) AS p(slug)
WHERE rd.slug IN (
  'principal', 'vicePrincipal', 'schoolAdmin', 'hrManager', 'management',
  'superAdmin', 'organizationOwner', 'organizationAdmin'
)
ON CONFLICT DO NOTHING;
