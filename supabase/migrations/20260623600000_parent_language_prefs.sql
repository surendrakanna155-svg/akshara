-- v11.5: Persist parent insight language preferences per user/student.
CREATE TABLE parent_language_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  user_id UUID NOT NULL REFERENCES users (id),
  student_id UUID,
  language TEXT NOT NULL DEFAULT 'english',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE UNIQUE INDEX parent_language_global_pref
  ON parent_language_preferences (organization_id, school_id, user_id)
  WHERE student_id IS NULL;

CREATE UNIQUE INDEX parent_language_student_pref
  ON parent_language_preferences (organization_id, school_id, user_id, student_id)
  WHERE student_id IS NOT NULL;

CREATE TRIGGER parent_language_preferences_updated_at
  BEFORE UPDATE ON parent_language_preferences
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE parent_language_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_language_preferences FORCE ROW LEVEL SECURITY;

CREATE POLICY parent_language_preferences_scope ON parent_language_preferences
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON parent_language_preferences TO erp_tenant;
