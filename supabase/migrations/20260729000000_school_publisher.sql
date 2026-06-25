-- Holiday/Event Calendar + Marketing Publisher (Phase 1).
--
-- Generalises the certified achievement-promotion module into a multi-channel
-- School Publisher and adds the principal-managed holiday/festival/event calendar.
-- Reuses the communication hub (comm_broadcasts / comm_recipients /
-- notification_deliveries) for in-ERP delivery to parents/students/teachers/staff.
-- Social channels (Facebook/Instagram) are recorded as selectable-but-pending here
-- and made real in Phase 2 (Meta OAuth/Graph API).

-- ─── 1. School calendar (holiday / festival / event) ─────────────────────────
CREATE TABLE school_calendar_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  event_date DATE NOT NULL,
  end_date DATE,
  title TEXT NOT NULL,
  event_type TEXT NOT NULL DEFAULT 'holiday',
  description TEXT,
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT school_calendar_events_type_check CHECK (
    event_type IN ('holiday', 'festival', 'event', 'exam', 'result', 'admission', 'achievement', 'general')
  )
);

CREATE INDEX idx_school_calendar_events_school
  ON school_calendar_events (organization_id, school_id, event_date);

CREATE TRIGGER school_calendar_events_updated_at
  BEFORE UPDATE ON school_calendar_events
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE school_calendar_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_calendar_events FORCE ROW LEVEL SECURITY;

CREATE POLICY school_calendar_events_school_scope ON school_calendar_events
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON school_calendar_events TO erp_tenant;

-- ─── 2. Publisher columns on achievement_promotions (additive) ───────────────
-- The certified achievement-promotion workflow (draft → generate → approve →
-- publish) becomes the general publisher. Existing rows stay valid (defaults).
ALTER TABLE achievement_promotions
  ADD COLUMN IF NOT EXISTS subject_type TEXT NOT NULL DEFAULT 'achievement',
  ADD COLUMN IF NOT EXISTS calendar_event_id UUID REFERENCES school_calendar_events (id),
  ADD COLUMN IF NOT EXISTS destinations JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS publish_results JSONB NOT NULL DEFAULT '{}'::jsonb;

-- ─── 3. Staff audience for broadcasts (additive constraint widen) ────────────
ALTER TABLE comm_broadcasts DROP CONSTRAINT IF EXISTS comm_broadcasts_audience_check;
ALTER TABLE comm_broadcasts ADD CONSTRAINT comm_broadcasts_audience_check CHECK (
  audience IN ('all_parents', 'all_teachers', 'all_students', 'all_staff', 'school_wide')
);

-- ─── 4. School website content sink (the "School Website" channel) ───────────
CREATE TABLE school_website_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  source_promotion_id UUID REFERENCES achievement_promotions (id),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  image_caption TEXT,
  category TEXT NOT NULL DEFAULT 'news',
  status TEXT NOT NULL DEFAULT 'published',
  published_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_school_website_posts_school
  ON school_website_posts (organization_id, school_id, published_at);

ALTER TABLE school_website_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_website_posts FORCE ROW LEVEL SECURITY;

CREATE POLICY school_website_posts_school_scope ON school_website_posts
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON school_website_posts TO erp_tenant;

-- ─── 5. Calendar permissions ─────────────────────────────────────────────────
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewSchoolCalendar', 'Calendar', 'view', 'school', 'View the school holiday/event calendar'),
  ('manageSchoolCalendar', 'Calendar', 'manage', 'school', 'Create and manage holidays/events')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'viewSchoolCalendar'),
  ('superAdmin', 'manageSchoolCalendar'),
  ('schoolAdmin', 'viewSchoolCalendar'),
  ('schoolAdmin', 'manageSchoolCalendar'),
  ('principal', 'viewSchoolCalendar'),
  ('principal', 'manageSchoolCalendar'),
  ('vicePrincipal', 'viewSchoolCalendar'),
  ('vicePrincipal', 'manageSchoolCalendar'),
  ('teacher', 'viewSchoolCalendar')
ON CONFLICT (role_slug, permission_slug) DO NOTHING;
