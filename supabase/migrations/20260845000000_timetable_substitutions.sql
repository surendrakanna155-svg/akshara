-- Roadmap gap #8 (Smart Timetable Expansion) — PRAGMATIC CORE.
--
-- (1) PERSISTED substitutions. Until now a "substitute teacher for period X on
--     day D" was 100% client-side mock and never saved. This table persists a
--     per-period, per-date substitution that attaches to the v7.5 academic
--     timetable (academic_timetable_periods), NOT the legacy timetable_slots.
--
-- (2) Published-immutability guard. A published timetable's PERIODS must not be
--     silently mutated (moved/deleted). Substitutions live in a SEPARATE table,
--     so they remain fully allowed on a published timetable — that is the point:
--     the published grid is the contract; a substitution is a dated overlay on
--     top of it, never an edit of the grid itself.

-- ─── (1) Persisted substitutions ────────────────────────────────────────────
CREATE TABLE academic_timetable_substitutions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  academic_year_id UUID NOT NULL REFERENCES academic_years (id),
  -- The v7.5 period this substitution overlays. CASCADE: if the period is gone
  -- (e.g. timetable regenerated), stale substitutions go with it.
  period_id UUID NOT NULL REFERENCES academic_timetable_periods (id) ON DELETE CASCADE,
  sub_date DATE NOT NULL,
  original_teacher_id UUID,
  substitute_teacher_id UUID,
  reason TEXT NOT NULL DEFAULT '',
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  -- One substitution per period per calendar day → idempotent re-assign.
  UNIQUE (period_id, sub_date)
);

CREATE INDEX idx_academic_timetable_substitutions_lookup
  ON academic_timetable_substitutions
    (organization_id, school_id, sub_date, period_id);

ALTER TABLE academic_timetable_substitutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE academic_timetable_substitutions FORCE ROW LEVEL SECURITY;

-- School-scope policy (USING + WITH CHECK), mirroring
-- academic_timetable_periods_school from 20260615050000.
CREATE POLICY academic_timetable_substitutions_school ON academic_timetable_substitutions
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND app_current_scope() IN ('school', 'organization')
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON academic_timetable_substitutions TO erp_tenant;

-- ─── (2) Published-immutability guard ───────────────────────────────────────
-- BEFORE UPDATE/DELETE on academic_timetable_periods: if the parent timetable is
-- 'published', reject the mutation. Substitutions are a separate table and are
-- unaffected by this trigger.
CREATE OR REPLACE FUNCTION reject_published_period_edit()
RETURNS TRIGGER AS $$
DECLARE
  parent_status TEXT;
  target_timetable UUID;
BEGIN
  -- On DELETE the affected row is OLD; on UPDATE we key off the pre-image too
  -- (a period cannot change which timetable it belongs to).
  IF (TG_OP = 'DELETE') THEN
    target_timetable := OLD.timetable_id;
  ELSE
    target_timetable := OLD.timetable_id;
  END IF;

  SELECT status INTO parent_status
  FROM academic_timetables
  WHERE id = target_timetable;

  IF parent_status = 'published' THEN
    RAISE EXCEPTION 'timetable_published: periods of a published timetable are immutable (%).', target_timetable
      USING ERRCODE = 'check_violation';
  END IF;

  IF (TG_OP = 'DELETE') THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER academic_timetable_periods_reject_published_edit
  BEFORE UPDATE OR DELETE ON academic_timetable_periods
  FOR EACH ROW EXECUTE FUNCTION reject_published_period_edit();

-- ─── Permission + role grants ───────────────────────────────────────────────
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('manageTimetableSubstitution', 'AcademicTimetable', 'substitute', 'school',
   'Assign and remove per-day teacher substitutions on the academic timetable')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'manageTimetableSubstitution'),
  ('schoolAdmin', 'manageTimetableSubstitution'),
  ('principal', 'manageTimetableSubstitution')
ON CONFLICT DO NOTHING;
