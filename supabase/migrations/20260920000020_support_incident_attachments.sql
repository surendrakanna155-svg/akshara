-- ASIP — Phase 1, migration 3/4: incident attachments (screenshot + optional
-- screen recording) with REAL binary storage.
--
-- The school provides Description + Screenshot (+ optional screen recording).
-- Every other client "attachment" in the codebase is a metadata-only reference
-- (no bytes) — ASIP introduces the first genuine binary upload pipeline, reusing
-- the proven presign → PUT bytes → confirm Storage pattern (storage_service.ts)
-- against a dedicated, private, tenant-isolated bucket.
--
-- Object path layout: {organization_id}/{school_id}/{incident_id}/{uuid}_{file}
-- The first folder segment is the tenant id (matches the other document buckets)
-- so storage RLS isolates tenants. Additive/dormant.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'support-incident-attachments',
  'support-incident-attachments',
  false,
  104857600, -- 100 MiB — screen recordings can be large
  ARRAY[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
    'video/mp4',
    'video/webm',
    'video/quicktime',
    'text/plain',
    'application/json'
  ]
)
ON CONFLICT (id) DO NOTHING;

-- Reads: a reporter (school scope) reads their own school's attachments. The
-- reporter-owns-vs-support finer authz is enforced at the handler; storage RLS
-- guarantees the tenant boundary. Phase 2 cross-tenant support access is layered
-- separately (owner-gated) and does not weaken this policy.
CREATE POLICY support_attachments_storage_read ON storage.objects
  FOR SELECT
  USING (
    bucket_id = 'support-incident-attachments'
    AND app_current_scope() = 'school'
    AND (storage.foldername(name))[1] = app_current_tenant_id()::text
  );

CREATE POLICY support_attachments_storage_write ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'support-incident-attachments'
    AND app_current_scope() = 'school'
    AND (storage.foldername(name))[1] = app_current_tenant_id()::text
  );

-- ─── Attachment metadata rows ─────────────────────────────────────────────────

CREATE TABLE support_incident_attachment (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  incident_id UUID NOT NULL REFERENCES support_incident (id) ON DELETE CASCADE,

  kind TEXT NOT NULL
    CHECK (kind IN ('screenshot', 'screen_recording', 'log_export')),
  storage_path TEXT NOT NULL,
  file_name TEXT NOT NULL,
  content_type TEXT NOT NULL DEFAULT '',
  size_bytes BIGINT NOT NULL DEFAULT 0 CHECK (size_bytes >= 0),

  uploaded_by UUID NOT NULL REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),

  CONSTRAINT support_incident_attachment_path_uq UNIQUE (storage_path)
);

CREATE INDEX idx_support_incident_attachment_incident
  ON support_incident_attachment (incident_id, created_at);

ALTER TABLE support_incident_attachment ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_incident_attachment FORCE ROW LEVEL SECURITY;

CREATE POLICY support_incident_attachment_school_scope ON support_incident_attachment
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT ON support_incident_attachment TO erp_tenant;
