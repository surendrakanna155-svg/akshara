-- PRC-A Batch 2 (caps 101-108) — Complaint / Internal Issue (ticket) module.
--
-- School-internal issue/complaint capability: a parent reports a broken
-- classroom fan or a bus grievance; a staff member reports a facilities/
-- maintenance issue; it is assigned, tracked against an SLA, and resolved,
-- optionally attributed to a vendor with a repair cost. This is NOT a public/
-- platform support desk and NOT a disciplinary system, and deliberately has
-- NO F2 approval type — assign -> SLA -> resolve, not maker-checker.
--
-- Two tables:
--   complaints        — the ticket itself (mutable state machine).
--   complaint_events  — APPEND-ONLY timeline (raised/assigned/commented/
--                        status_changed/resolved/closed/reopened).
--
-- RLS: school staff scope reads/writes their school's complaints; parent scope
-- may SELECT + INSERT only complaints THEY raised (never another parent's).

CREATE TABLE complaints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  category TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  severity TEXT NOT NULL DEFAULT 'medium',
  status TEXT NOT NULL DEFAULT 'open',
  raised_by UUID NOT NULL,
  raised_by_role TEXT NOT NULL DEFAULT '',
  related_student_id UUID REFERENCES students (id),
  assigned_to UUID,
  assigned_at TIMESTAMPTZ,
  assigned_by UUID,
  -- Computed deterministically at raise time from the SLA policy table
  -- (complaints_sla.ts) — never a scattered magic number.
  sla_due_at TIMESTAMPTZ NOT NULL,
  first_response_at TIMESTAMPTZ,
  resolved_at TIMESTAMPTZ,
  resolved_by UUID,
  resolution_note TEXT,
  reopened_count INT NOT NULL DEFAULT 0,
  vendor_id UUID REFERENCES inventory_vendors (id),
  repair_cost NUMERIC(12, 2),
  photo_path TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT complaints_category_check CHECK (
    category IN (
      'facilities', 'transport', 'academics', 'hostel',
      'finance', 'safety', 'staff', 'other'
    )
  ),
  CONSTRAINT complaints_severity_check CHECK (
    severity IN ('low', 'medium', 'high', 'critical')
  ),
  CONSTRAINT complaints_status_check CHECK (
    status IN ('open', 'assigned', 'in_progress', 'resolved', 'closed', 'reopened')
  ),
  CONSTRAINT complaints_repair_cost_check CHECK (repair_cost IS NULL OR repair_cost >= 0)
);

-- Assignee queue (a staff member's open workload).
CREATE INDEX idx_complaints_assignee
  ON complaints (organization_id, school_id, assigned_to, status);
-- School-wide triage queue (newest first).
CREATE INDEX idx_complaints_school_queue
  ON complaints (organization_id, school_id, status, created_at DESC);
-- SLA breach scan — only over complaints still in flight.
CREATE INDEX idx_complaints_sla_breach
  ON complaints (organization_id, school_id, sla_due_at)
  WHERE status NOT IN ('resolved', 'closed');
-- A raiser's / parent's own list ("sees only their own").
CREATE INDEX idx_complaints_raised_by
  ON complaints (organization_id, school_id, raised_by, created_at DESC);

CREATE TRIGGER complaints_updated_at
  BEFORE UPDATE ON complaints
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE complaint_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  complaint_id UUID NOT NULL REFERENCES complaints (id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  actor_id UUID NOT NULL,
  actor_name TEXT NOT NULL DEFAULT '',
  note TEXT,
  metadata JSONB NOT NULL DEFAULT '{}',
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT complaint_events_type_check CHECK (
    event_type IN (
      'raised', 'assigned', 'commented', 'status_changed',
      'resolved', 'closed', 'reopened'
    )
  )
);

CREATE INDEX idx_complaint_events_complaint
  ON complaint_events (complaint_id, occurred_at);

-- ─── RLS: complaints ────────────────────────────────────────────────────────

ALTER TABLE complaints ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaints FORCE ROW LEVEL SECURITY;

-- School staff: full read of the school's queue. Permission-level narrowing
-- (raiser-only vs manage-all) happens in the application layer (a raiser who
-- only holds raiseComplaint gets `raised_by = $self` folded into the SQL
-- WHERE by the repository) — RLS enforces tenant + school isolation only,
-- matching the established pattern (students_scope_access et al.).
CREATE POLICY complaints_school_select ON complaints
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

-- Parent: SELECT only complaints THEY raised — never another parent's.
CREATE POLICY complaints_parent_select ON complaints
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'parent'
    AND school_id = app_current_school_id()
    AND raised_by = app_current_user_id()
  );

CREATE POLICY complaints_school_insert ON complaints
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

-- Parent: INSERT only with themselves as the raiser.
CREATE POLICY complaints_parent_insert ON complaints
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'parent'
    AND school_id = app_current_school_id()
    AND raised_by = app_current_user_id()
  );

-- Parent has NO update policy: a parent may SELECT + INSERT only (raise,
-- read). Assign/transition/comment(staff-side)/vendor are staff-only writes.
CREATE POLICY complaints_school_update ON complaints
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

GRANT SELECT, INSERT, UPDATE ON complaints TO erp_tenant;

-- ─── RLS: complaint_events (append-only) ───────────────────────────────────

ALTER TABLE complaint_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaint_events FORCE ROW LEVEL SECURITY;

CREATE POLICY complaint_events_school_select ON complaint_events
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

-- Parent: only the timeline of a complaint THEY raised.
CREATE POLICY complaint_events_parent_select ON complaint_events
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'parent'
    AND school_id = app_current_school_id()
    AND EXISTS (
      SELECT 1 FROM complaints c
      WHERE c.id = complaint_events.complaint_id
        AND c.raised_by = app_current_user_id()
    )
  );

CREATE POLICY complaint_events_school_insert ON complaint_events
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

-- Parent: may only append (comment) onto a complaint THEY raised.
CREATE POLICY complaint_events_parent_insert ON complaint_events
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'parent'
    AND school_id = app_current_school_id()
    AND EXISTS (
      SELECT 1 FROM complaints c
      WHERE c.id = complaint_events.complaint_id
        AND c.raised_by = app_current_user_id()
    )
  );

-- Append-only: SELECT + INSERT only, NO UPDATE/DELETE grant.
GRANT SELECT, INSERT ON complaint_events TO erp_tenant;

-- ─── Storage: complaint photo attachments ──────────────────────────────────
-- Mirrors the admissions-documents bucket pattern (20260806000020): a
-- dedicated, private, tenant-isolated bucket; path layout
-- {organization_id}/{school_id}/{complaint_id}/{uuid}_{filename}. Presigning
-- always goes through the service-role client (_shared/complaints/
-- complaints_storage.ts, reusing _shared/storage/storage_service.ts's
-- validateUpload) — these object policies are defense-in-depth for any
-- direct-client Storage API path.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'complaint-photos',
  'complaint-photos',
  false,
  10485760, -- 10 MiB per photo
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY complaint_photos_storage_school_read ON storage.objects
  FOR SELECT
  USING (
    bucket_id = 'complaint-photos'
    AND app_current_scope() = 'school'
    AND (storage.foldername(name))[1] = app_current_tenant_id()::text
  );

CREATE POLICY complaint_photos_storage_school_write ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'complaint-photos'
    AND app_current_scope() = 'school'
    AND (storage.foldername(name))[1] = app_current_tenant_id()::text
  );

CREATE POLICY complaint_photos_storage_parent_read ON storage.objects
  FOR SELECT
  USING (
    bucket_id = 'complaint-photos'
    AND app_current_scope() = 'parent'
    AND (storage.foldername(name))[1] = app_current_tenant_id()::text
    AND EXISTS (
      SELECT 1 FROM complaints c
      WHERE c.id::text = (storage.foldername(name))[3]
        AND c.raised_by = app_current_user_id()
    )
  );

CREATE POLICY complaint_photos_storage_parent_write ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'complaint-photos'
    AND app_current_scope() = 'parent'
    AND (storage.foldername(name))[1] = app_current_tenant_id()::text
    AND EXISTS (
      SELECT 1 FROM complaints c
      WHERE c.id::text = (storage.foldername(name))[3]
        AND c.raised_by = app_current_user_id()
    )
  );

-- ─── RBAC ───────────────────────────────────────────────────────────────────
-- No F2 approval type — assign -> SLA -> resolve, not maker-checker.

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('raiseComplaint', 'Complaints', 'create', 'school', 'Raise a complaint / internal issue ticket'),
  ('manageComplaints', 'Complaints', 'manage', 'school', 'Assign, transition, resolve and manage complaints/issues'),
  ('viewComplaintsPrincipal', 'Complaints', 'view', 'school', 'View the full school complaints/issues queue (principal/management oversight)')
ON CONFLICT (slug) DO NOTHING;

-- All slugs below verified present in role_definitions (20260608100000,
-- 20260851000000 for 'storekeeper').
INSERT INTO role_permissions (role_slug, permission_slug)
SELECT rd.slug, 'raiseComplaint'
FROM role_definitions rd
WHERE rd.slug IN (
  'parent', 'teacher', 'classTeacher', 'coordinator', 'officeStaff',
  'librarian', 'storekeeper', 'principal', 'vicePrincipal', 'schoolAdmin'
)
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug)
SELECT rd.slug, 'manageComplaints'
FROM role_definitions rd
WHERE rd.slug IN (
  'officeStaff', 'coordinator', 'principal', 'vicePrincipal', 'schoolAdmin',
  'management', 'superAdmin', 'organizationOwner', 'organizationAdmin'
)
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug)
SELECT rd.slug, 'viewComplaintsPrincipal'
FROM role_definitions rd
WHERE rd.slug IN (
  'principal', 'vicePrincipal', 'management', 'schoolAdmin',
  'superAdmin', 'organizationOwner', 'organizationAdmin'
)
ON CONFLICT DO NOTHING;
