-- v10.4 Storage foundation for School Memories

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'school-memories',
  'school-memories',
  false,
  52428800,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'video/mp4', 'video/webm']
)
ON CONFLICT (id) DO NOTHING;

-- Path layout: {organization_id}/{school_id}/{event_id}/{album_id}/{filename}

CREATE POLICY school_memories_storage_school_read ON storage.objects
  FOR SELECT
  USING (
    bucket_id = 'school-memories'
    AND app_current_scope() IN ('school', 'parent', 'student')
    AND (storage.foldername(name))[1] = app_current_tenant_id()::text
  );

CREATE POLICY school_memories_storage_school_write ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'school-memories'
    AND app_current_scope() = 'school'
    AND (storage.foldername(name))[1] = app_current_tenant_id()::text
  );

CREATE POLICY school_memories_storage_school_update ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'school-memories'
    AND app_current_scope() = 'school'
    AND (storage.foldername(name))[1] = app_current_tenant_id()::text
  );

CREATE POLICY school_memories_storage_school_delete ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'school-memories'
    AND app_current_scope() = 'school'
    AND (storage.foldername(name))[1] = app_current_tenant_id()::text
  );

-- Album/media write helpers
ALTER TABLE school_memory_albums ADD COLUMN IF NOT EXISTS cover_storage_path TEXT;
ALTER TABLE school_memory_media ADD COLUMN IF NOT EXISTS storage_path TEXT;
ALTER TABLE school_memory_media ADD COLUMN IF NOT EXISTS share_token TEXT UNIQUE;

CREATE INDEX IF NOT EXISTS idx_school_memory_media_share
  ON school_memory_media (share_token) WHERE share_token IS NOT NULL;
