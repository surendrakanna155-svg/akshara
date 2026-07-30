-- PRA-P1-19 — real file storage for SIS student documents.
-- The upload handler previously fabricated `storage://documents/<name>` with NO
-- bytes, NO bucket, NO presign. This adds a dedicated, private, tenant-isolated
-- Storage bucket plus the storage_path column that links a student_documents row
-- to its real object. Mirrors the admissions-documents storage foundation
-- (migration 20260806000020).

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'student-documents',
  'student-documents',
  false,
  26214400, -- 25 MiB per document
  ARRAY[
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic'
  ]
)
ON CONFLICT (id) DO NOTHING;

-- Path layout: {organization_id}/{school_id}/{student_id}/{uuid}_{filename}
-- The first folder segment is the tenant id, matching the admissions/memories
-- pattern so storage RLS can isolate tenants from each other.

CREATE POLICY student_documents_storage_school_read ON storage.objects
  FOR SELECT
  USING (
    bucket_id = 'student-documents'
    AND app_current_scope() = 'school'
    AND (storage.foldername(name))[1] = app_current_tenant_id()::text
  );

CREATE POLICY student_documents_storage_school_write ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'student-documents'
    AND app_current_scope() = 'school'
    AND (storage.foldername(name))[1] = app_current_tenant_id()::text
  );

CREATE POLICY student_documents_storage_school_update ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'student-documents'
    AND app_current_scope() = 'school'
    AND (storage.foldername(name))[1] = app_current_tenant_id()::text
  );

CREATE POLICY student_documents_storage_school_delete ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'student-documents'
    AND app_current_scope() = 'school'
    AND (storage.foldername(name))[1] = app_current_tenant_id()::text
  );

-- Link the document row to its stored object.
ALTER TABLE student_documents ADD COLUMN IF NOT EXISTS storage_path TEXT;
