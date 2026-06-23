-- Storage-api post-init SQL (Batch 7) — run as supabase_admin AFTER storage-api
-- has booted once and created its own schema (storage.objects/buckets/prefixes/…).
--
-- Why this is separate from the storage-api migrations: we run storage-api with
-- DB_INSTALL_ROLES=false (the supabase roles already exist on this DB), which
-- also skips its GRANT step. So we grant the storage privileges to the supabase
-- roles ourselves here, (re)create the school-memories bucket, and re-apply the
-- tenant-isolation policies from migration 20260622700000_v104_storage_foundation.
-- Idempotent: safe to re-run.

-- ─── Grants (service_role bypasses RLS but still needs table privileges) ──────
GRANT USAGE ON SCHEMA storage TO anon, authenticated, service_role;
GRANT ALL    ON ALL TABLES    IN SCHEMA storage TO service_role;
GRANT ALL    ON ALL SEQUENCES IN SCHEMA storage TO service_role;
GRANT ALL    ON ALL FUNCTIONS IN SCHEMA storage TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA storage TO authenticated, anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA storage TO authenticated, anon;
GRANT USAGE   ON ALL SEQUENCES IN SCHEMA storage TO authenticated, anon;
-- Future objects created by storage-api upgrades inherit the grants.
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_storage_admin IN SCHEMA storage GRANT ALL ON TABLES    TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_storage_admin IN SCHEMA storage GRANT ALL ON SEQUENCES TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_storage_admin IN SCHEMA storage GRANT ALL ON FUNCTIONS TO service_role;

-- ─── Bucket ──────────────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'school-memories', 'school-memories', false, 52428800,
  ARRAY['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm']
)
ON CONFLICT (id) DO NOTHING;

-- ─── Tenant-isolation policies (path[1] = org/tenant id) ─────────────────────
DROP POLICY IF EXISTS school_memories_storage_school_read   ON storage.objects;
DROP POLICY IF EXISTS school_memories_storage_school_write  ON storage.objects;
DROP POLICY IF EXISTS school_memories_storage_school_update ON storage.objects;
DROP POLICY IF EXISTS school_memories_storage_school_delete ON storage.objects;

CREATE POLICY school_memories_storage_school_read ON storage.objects FOR SELECT
  USING (bucket_id='school-memories' AND app_current_scope() IN ('school','parent','student')
         AND (storage.foldername(name))[1] = app_current_tenant_id()::text);
CREATE POLICY school_memories_storage_school_write ON storage.objects FOR INSERT
  WITH CHECK (bucket_id='school-memories' AND app_current_scope()='school'
         AND (storage.foldername(name))[1] = app_current_tenant_id()::text);
CREATE POLICY school_memories_storage_school_update ON storage.objects FOR UPDATE
  USING (bucket_id='school-memories' AND app_current_scope()='school'
         AND (storage.foldername(name))[1] = app_current_tenant_id()::text);
CREATE POLICY school_memories_storage_school_delete ON storage.objects FOR DELETE
  USING (bucket_id='school-memories' AND app_current_scope()='school'
         AND (storage.foldername(name))[1] = app_current_tenant_id()::text);
