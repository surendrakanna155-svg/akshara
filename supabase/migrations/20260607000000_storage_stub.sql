-- Lean-stack storage stub.
-- Provides a minimal `storage` schema ONLY for deployments without the Supabase
-- Storage service (the self-hosted lean VPS stack, applied as superuser).
-- Strict no-op when storage.objects already exists (full Supabase / local CLI).
DO $stub$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'storage' AND c.relname = 'objects'
  ) THEN
    RETURN;  -- real Supabase Storage present -> nothing to do
  END IF;

  CREATE SCHEMA IF NOT EXISTS storage;

  CREATE TABLE storage.buckets (
    id text PRIMARY KEY,
    name text NOT NULL,
    public boolean DEFAULT false,
    file_size_limit bigint,
    allowed_mime_types text[],
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
  );

  CREATE TABLE storage.objects (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    bucket_id text REFERENCES storage.buckets (id),
    name text,
    owner uuid,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    metadata jsonb
  );

  CREATE FUNCTION storage.foldername(name text)
  RETURNS text[] LANGUAGE sql IMMUTABLE AS $fn$
    SELECT string_to_array(name, '/')
  $fn$;
END
$stub$;
