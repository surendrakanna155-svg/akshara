-- Phase 5 v9.8–v10.3 foundation

-- ─── v9.8 Parent acknowledgements ────────────────────────────────────────────

CREATE TABLE parent_item_acknowledgements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL,
  distribution_id UUID NOT NULL REFERENCES inv_student_distributions (id) ON DELETE CASCADE,
  acknowledged_by UUID NOT NULL REFERENCES users (id),
  acknowledgement_type TEXT NOT NULL DEFAULT 'received'
    CHECK (acknowledgement_type IN ('received', 'replacement_requested')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (distribution_id, acknowledged_by)
);

ALTER TABLE parent_item_acknowledgements ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_item_acknowledgements FORCE ROW LEVEL SECURITY;

CREATE POLICY parent_ack_parent_scope ON parent_item_acknowledgements
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'parent'
    AND student_id IN (
      SELECT sg.student_id FROM student_guardians sg
      WHERE sg.guardian_user_id = app_current_user_id() AND sg.status = 'active'
    )
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'parent'
    AND student_id IN (
      SELECT sg.student_id FROM student_guardians sg
      WHERE sg.guardian_user_id = app_current_user_id() AND sg.status = 'active'
    )
  );

CREATE POLICY parent_ack_school_scope ON parent_item_acknowledgements
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

GRANT SELECT, INSERT, UPDATE, DELETE ON parent_item_acknowledgements TO erp_tenant;

-- Extend distribution statuses for v10.1
ALTER TABLE inv_student_distributions DROP CONSTRAINT IF EXISTS inv_student_distributions_status_check;
ALTER TABLE inv_student_distributions ADD CONSTRAINT inv_student_distributions_status_check
  CHECK (status IN (
    'received', 'available', 'distributed', 'parent_acknowledged',
    'replacement_requested', 'payment_pending', 'paid', 'reissued', 'cancelled',
    'missing', 'lost', 'damaged'
  ));

-- ─── v9.9 Employee intelligence ──────────────────────────────────────────────

CREATE TABLE employee_intelligence_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  employee_id UUID NOT NULL REFERENCES employees (id) ON DELETE CASCADE,
  workload_percent INT NOT NULL DEFAULT 0 CHECK (workload_percent >= 0 AND workload_percent <= 100),
  burnout_risk TEXT NOT NULL DEFAULT 'low'
    CHECK (burnout_risk IN ('low', 'medium', 'high', 'critical')),
  overload_score INT NOT NULL DEFAULT 0,
  substitution_load INT NOT NULL DEFAULT 0,
  coordinator_load INT NOT NULL DEFAULT 0,
  insights JSONB NOT NULL DEFAULT '[]'::jsonb,
  computed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_employee_intel_employee
  ON employee_intelligence_snapshots (employee_id, computed_at DESC);

ALTER TABLE employee_intelligence_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_intelligence_snapshots FORCE ROW LEVEL SECURITY;

CREATE POLICY employee_intel_school_scope ON employee_intelligence_snapshots
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

GRANT SELECT, INSERT, UPDATE, DELETE ON employee_intelligence_snapshots TO erp_tenant;

-- ─── v10.2 School memories ───────────────────────────────────────────────────

CREATE TABLE school_memory_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  title TEXT NOT NULL,
  category TEXT NOT NULL
    CHECK (category IN (
      'annual_day', 'sports_day', 'science_fair', 'cultural_program',
      'celebration', 'trip', 'other'
    )),
  event_date DATE NOT NULL DEFAULT CURRENT_DATE,
  description TEXT,
  visibility TEXT NOT NULL DEFAULT 'school'
    CHECK (visibility IN ('school', 'parents', 'public')),
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'published', 'archived')),
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE school_memory_albums (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  event_id UUID NOT NULL REFERENCES school_memory_events (id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  cover_label TEXT,
  media_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE school_memory_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  album_id UUID NOT NULL REFERENCES school_memory_albums (id) ON DELETE CASCADE,
  media_type TEXT NOT NULL DEFAULT 'photo'
    CHECK (media_type IN ('photo', 'video')),
  title TEXT NOT NULL,
  storage_url TEXT NOT NULL DEFAULT '',
  thumbnail_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TRIGGER school_memory_events_updated_at
  BEFORE UPDATE ON school_memory_events
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE school_memory_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_memory_events FORCE ROW LEVEL SECURITY;
ALTER TABLE school_memory_albums ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_memory_albums FORCE ROW LEVEL SECURITY;
ALTER TABLE school_memory_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_memory_media FORCE ROW LEVEL SECURITY;

CREATE POLICY school_memory_events_school ON school_memory_events
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'parent', 'student')
  );

CREATE POLICY school_memory_albums_school ON school_memory_albums
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'parent', 'student')
  );

CREATE POLICY school_memory_media_school ON school_memory_media
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'parent', 'student')
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON school_memory_events TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON school_memory_albums TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON school_memory_media TO erp_tenant;

-- ─── v10.3 Achievement promotion ─────────────────────────────────────────────

CREATE TABLE achievement_promotions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  achievement_type TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'pending_approval', 'approved', 'published', 'rejected')),
  submitted_by UUID REFERENCES users (id),
  approved_by UUID REFERENCES users (id),
  published_at TIMESTAMPTZ,
  assets JSONB NOT NULL DEFAULT '{}'::jsonb,
  analytics JSONB NOT NULL DEFAULT '{"views":0,"shares":0,"downloads":0}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TRIGGER achievement_promotions_updated_at
  BEFORE UPDATE ON achievement_promotions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE achievement_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievement_promotions FORCE ROW LEVEL SECURITY;

CREATE POLICY achievement_promotions_school ON achievement_promotions
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

GRANT SELECT, INSERT, UPDATE, DELETE ON achievement_promotions TO erp_tenant;
