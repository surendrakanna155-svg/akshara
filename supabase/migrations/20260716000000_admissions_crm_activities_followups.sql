-- B1 Admissions CRM completion — lead activity timeline + follow-up lifecycle
-- Closes the remaining ~30% of the Admissions CRM: gives real persistence to
-- the already-built UI for notes, stage changes, counselor assignment,
-- follow-ups, WhatsApp/call logging and the activity timeline.
-- Rules (mirror admissions_leads slice 1): FORCE RLS, school-scope operational
-- access, erp_tenant grants, additive only.

-- ─── Lead activity timeline ──────────────────────────────────────────────────
-- One unified table for every timeline entry: notes, stage changes, counselor
-- assignment, follow-up logging, WhatsApp deep-link sends and call logs. Reuses
-- the existing audit/RBAC plumbing rather than a new subsystem per channel.
CREATE TABLE admissions_lead_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  lead_id UUID NOT NULL REFERENCES admissions_leads (id) ON DELETE CASCADE,
  activity_type TEXT NOT NULL DEFAULT 'note',
  title TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  actor TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_admissions_lead_activities_lead
  ON admissions_lead_activities (lead_id, created_at DESC);
CREATE INDEX idx_admissions_lead_activities_school
  ON admissions_lead_activities (school_id);

ALTER TABLE admissions_lead_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE admissions_lead_activities FORCE ROW LEVEL SECURITY;

CREATE POLICY admissions_lead_activities_school_scope ON admissions_lead_activities
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

GRANT SELECT, INSERT ON admissions_lead_activities TO erp_tenant;

-- ─── Lead follow-ups ─────────────────────────────────────────────────────────
CREATE TABLE admissions_lead_follow_ups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  lead_id UUID NOT NULL REFERENCES admissions_leads (id) ON DELETE CASCADE,
  task TEXT NOT NULL,
  scheduled_label TEXT NOT NULL DEFAULT '',
  completed_label TEXT NOT NULL DEFAULT '',
  counselor TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending',
  outcome TEXT NOT NULL DEFAULT 'Scheduled',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_admissions_lead_follow_ups_lead
  ON admissions_lead_follow_ups (lead_id, created_at DESC);
CREATE INDEX idx_admissions_lead_follow_ups_school
  ON admissions_lead_follow_ups (school_id);

CREATE TRIGGER admissions_lead_follow_ups_updated_at
  BEFORE UPDATE ON admissions_lead_follow_ups
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE admissions_lead_follow_ups ENABLE ROW LEVEL SECURITY;
ALTER TABLE admissions_lead_follow_ups FORCE ROW LEVEL SECURITY;

CREATE POLICY admissions_lead_follow_ups_school_scope ON admissions_lead_follow_ups
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

GRANT SELECT, INSERT, UPDATE ON admissions_lead_follow_ups TO erp_tenant;
