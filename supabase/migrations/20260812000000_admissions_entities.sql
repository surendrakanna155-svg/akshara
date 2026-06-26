-- MJ-H14/MJ-H15 — admissions_entities: school-scoped JSONB store backing the
-- admissions settings snapshot and persisted approval notes. Mirrors the DDL +
-- RLS of management_entities (20260614300000) exactly, scoped to admissions.
-- Forward-only and idempotent (safe to re-run).

CREATE TABLE IF NOT EXISTS admissions_entities (
  id TEXT NOT NULL,
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  entity_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  PRIMARY KEY (organization_id, school_id, entity_type, id)
);

CREATE INDEX IF NOT EXISTS idx_admissions_entities_org_school_type
  ON admissions_entities (organization_id, school_id, entity_type);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'admissions_entities_updated_at'
  ) THEN
    CREATE TRIGGER admissions_entities_updated_at
      BEFORE UPDATE ON admissions_entities
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END$$;

ALTER TABLE admissions_entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE admissions_entities FORCE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'admissions_entities'
      AND policyname = 'admissions_entities_school_scope'
  ) THEN
    CREATE POLICY admissions_entities_school_scope ON admissions_entities
      FOR ALL USING (
        organization_id = app_current_tenant_id()
        AND app_current_scope() = 'school'
        AND school_id = app_current_school_id()
      ) WITH CHECK (
        organization_id = app_current_tenant_id()
        AND app_current_scope() = 'school'
        AND school_id = app_current_school_id()
      );
  END IF;
END$$;

GRANT SELECT, INSERT, UPDATE, DELETE ON admissions_entities TO erp_tenant;
