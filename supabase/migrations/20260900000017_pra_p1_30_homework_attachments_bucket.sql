-- PRA-P1-30 — real file storage for homework attachments.
-- Previously the HWK-4 teacher attachment and the HWK-7 student submission
-- attachment stored a LABEL STRING only (attachment_label / payload attachmentRef)
-- with NO bucket, NO bytes, NO presign — the handler comment literally said "not
-- a real file upload; no homework bucket exists yet". This adds a dedicated,
-- private, tenant-isolated Storage bucket plus the attachment_storage_path column
-- on homework_submissions. Mirrors the admissions/student-documents foundation.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'homework-attachments',
  'homework-attachments',
  false,
  26214400, -- 25 MiB per attachment
  ARRAY[
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic'
  ]
)
ON CONFLICT (id) DO NOTHING;

-- Path layout:
--   teacher worksheet:   {organization_id}/{school_id}/{teacher_id}/{uuid}_{file}
--   student submission:  {organization_id}/{school_id}/{student_id}/{homework_id}/{uuid}_{file}
-- The first folder segment is the tenant id, matching the other document buckets
-- so storage RLS isolates tenants. Homework is read by teacher (school),
-- student and parent scopes; writes come from teacher (school) and student.

CREATE POLICY homework_attachments_storage_read ON storage.objects
  FOR SELECT
  USING (
    bucket_id = 'homework-attachments'
    AND app_current_scope() IN ('school', 'student', 'parent')
    AND (storage.foldername(name))[1] = app_current_tenant_id()::text
  );

CREATE POLICY homework_attachments_storage_write ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'homework-attachments'
    AND app_current_scope() IN ('school', 'student')
    AND (storage.foldername(name))[1] = app_current_tenant_id()::text
  );

CREATE POLICY homework_attachments_storage_update ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'homework-attachments'
    AND app_current_scope() IN ('school', 'student')
    AND (storage.foldername(name))[1] = app_current_tenant_id()::text
  );

CREATE POLICY homework_attachments_storage_delete ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'homework-attachments'
    AND app_current_scope() IN ('school', 'student')
    AND (storage.foldername(name))[1] = app_current_tenant_id()::text
  );

-- Link a student submission row to its stored object. (The teacher assignment
-- attachment path rides the existing homework_assignment/homework_item JSONB
-- payload as `attachmentStoragePath`, so it needs no new column.)
ALTER TABLE homework_submissions ADD COLUMN IF NOT EXISTS attachment_storage_path TEXT;
