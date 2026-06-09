-- v6.1 Sprint 3 Phase 2 — RLS, scope expansion, parent/student model
-- Baseline: v6.1-phase1-rbac-foundation
-- Architecture: v6.1 §6, §9, §19 Phase 2; AuthArchitecture §2; TenantArchitecture §4

-- ─── Parent / student relationship tables (v6.1 §9.1) ─────────────────────

CREATE TABLE students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  user_id UUID REFERENCES users (id),
  student_code TEXT NOT NULL,
  display_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'transferred', 'alumni')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (school_id, student_code)
);

CREATE INDEX idx_students_org ON students (organization_id);
CREATE INDEX idx_students_school ON students (school_id);
CREATE INDEX idx_students_user ON students (user_id) WHERE user_id IS NOT NULL;

CREATE TABLE student_guardians (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL REFERENCES students (id) ON DELETE CASCADE,
  guardian_user_id UUID NOT NULL REFERENCES users (id),
  relationship TEXT NOT NULL DEFAULT 'guardian',
  is_primary BOOLEAN NOT NULL DEFAULT false,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (student_id, guardian_user_id)
);

CREATE INDEX idx_student_guardians_guardian ON student_guardians (guardian_user_id);
CREATE INDEX idx_student_guardians_school ON student_guardians (school_id);

CREATE TRIGGER students_updated_at
  BEFORE UPDATE ON students
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─── Session context persistence (refresh + context switch) ─────────────────

ALTER TABLE sessions
  ADD COLUMN IF NOT EXISTS scope TEXT NOT NULL DEFAULT 'school'
    CHECK (scope IN ('school', 'organization', 'school_group', 'parent', 'student', 'platform')),
  ADD COLUMN IF NOT EXISTS context_school_id UUID REFERENCES schools (id),
  ADD COLUMN IF NOT EXISTS context_school_group_id UUID,
  ADD COLUMN IF NOT EXISTS context_student_id UUID REFERENCES students (id),
  ADD COLUMN IF NOT EXISTS context_child_ids UUID[] NOT NULL DEFAULT '{}';

-- ─── Parent / student role permissions (Phase 1 roles existed without grants) ─

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('parent', 'viewSis'),
  ('parent', 'viewFinance'),
  ('student', 'viewSis')
ON CONFLICT DO NOTHING;

-- ─── Org aggregate view — no raw cross-school PII (v6.1 §6.4 Pattern D) ─────

CREATE OR REPLACE VIEW org_school_summary
WITH (security_invoker = true) AS
SELECT
  s.organization_id AS tenant_id,
  s.id AS school_id,
  s.name AS school_name,
  s.code AS school_code,
  count(DISTINCT sm.id) FILTER (WHERE sm.status = 'active') AS active_staff_count,
  count(DISTINCT st.id) FILTER (WHERE st.status = 'active') AS active_student_count
FROM schools s
LEFT JOIN school_memberships sm ON sm.school_id = s.id
LEFT JOIN students st ON st.school_id = s.id
WHERE s.deleted_at IS NULL
GROUP BY s.organization_id, s.id, s.name, s.code;

-- ─── Request context RPC (v6.1 §6.3) ────────────────────────────────────────
-- Note: Supabase reserves `auth` schema (GoTrue). Use `app` schema for ERP context.

CREATE SCHEMA IF NOT EXISTS app;

CREATE OR REPLACE FUNCTION app.set_request_context(
  p_tenant_id UUID,
  p_scope TEXT,
  p_user_id UUID,
  p_school_id UUID DEFAULT NULL,
  p_school_group_id UUID DEFAULT NULL,
  p_student_id UUID DEFAULT NULL,
  p_parent_user_id UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM set_config('app.tenant_id', p_tenant_id::text, true);
  PERFORM set_config('app.scope', p_scope, true);
  PERFORM set_config('app.user_id', p_user_id::text, true);
  PERFORM set_config('app.school_id', COALESCE(p_school_id::text, ''), true);
  PERFORM set_config('app.school_group_id', COALESCE(p_school_group_id::text, ''), true);
  PERFORM set_config('app.student_id', COALESCE(p_student_id::text, ''), true);
  PERFORM set_config('app.parent_user_id', COALESCE(p_parent_user_id::text, ''), true);
END;
$$;

-- PostgREST / Supabase RPC wrapper
CREATE OR REPLACE FUNCTION set_request_context(
  p_tenant_id UUID,
  p_scope TEXT,
  p_user_id UUID,
  p_school_id UUID DEFAULT NULL,
  p_school_group_id UUID DEFAULT NULL,
  p_student_id UUID DEFAULT NULL,
  p_parent_user_id UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM app.set_request_context(
    p_tenant_id, p_scope, p_user_id,
    p_school_id, p_school_group_id, p_student_id, p_parent_user_id
  );
END;
$$;

REVOKE ALL ON FUNCTION set_request_context FROM PUBLIC;
GRANT EXECUTE ON FUNCTION set_request_context TO service_role;

-- ─── RLS helpers ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION app_current_tenant_id()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('app.tenant_id', true), '')::uuid;
$$;

CREATE OR REPLACE FUNCTION app_current_scope()
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('app.scope', true), '');
$$;

CREATE OR REPLACE FUNCTION app_current_school_id()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('app.school_id', true), '')::uuid;
$$;

CREATE OR REPLACE FUNCTION app_current_user_id()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('app.user_id', true), '')::uuid;
$$;

CREATE OR REPLACE FUNCTION app_current_student_id()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('app.student_id', true), '')::uuid;
$$;

CREATE OR REPLACE FUNCTION app_current_parent_user_id()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('app.parent_user_id', true), '')::uuid;
$$;

-- ─── Enable RLS on core tables (v6.1 §19 Phase 2) ──────────────────────────

ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_guardians ENABLE ROW LEVEL SECURITY;

-- organizations: tenant boundary
CREATE POLICY organizations_tenant_access ON organizations
  FOR SELECT
  USING (
    app_current_tenant_id() IS NOT NULL
    AND id = app_current_tenant_id()
  );

-- schools: org lists all; school/parent/student scoped to active school
CREATE POLICY schools_scope_access ON schools
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND (
      app_current_scope() = 'organization'
      OR (
        app_current_scope() IN ('school', 'parent', 'student')
        AND id = app_current_school_id()
      )
    )
  );

-- users: self-access only under RLS (staff directory via service role)
CREATE POLICY users_self_access ON users
  FOR SELECT
  USING (id = app_current_user_id());

-- organization_memberships: org scope reads org memberships; users see own
CREATE POLICY organization_memberships_access ON organization_memberships
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND (
      (app_current_scope() = 'organization' AND user_id = app_current_user_id())
      OR user_id = app_current_user_id()
    )
  );

-- school_memberships: school scope only — no cross-school staff PII (v6.1 §6.1)
CREATE POLICY school_memberships_school_scope ON school_memberships
  FOR SELECT
  USING (
    app_current_scope() = 'school'
    AND school_id = app_current_school_id()
    AND EXISTS (
      SELECT 1 FROM schools s
      WHERE s.id = school_memberships.school_id
        AND s.organization_id = app_current_tenant_id()
    )
  );

-- students: school staff, parent (linked children), student (self)
CREATE POLICY students_scope_access ON students
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND (
      (
        app_current_scope() = 'school'
        AND school_id = app_current_school_id()
      )
      OR (
        app_current_scope() = 'parent'
        AND school_id = app_current_school_id()
        AND id IN (
          SELECT sg.student_id
          FROM student_guardians sg
          WHERE sg.guardian_user_id = app_current_parent_user_id()
            AND sg.status = 'active'
        )
      )
      OR (
        app_current_scope() = 'student'
        AND id = app_current_student_id()
        AND user_id = app_current_user_id()
      )
    )
  );

-- student_guardians: parent sees own links; school staff see school links
CREATE POLICY student_guardians_scope_access ON student_guardians
  FOR SELECT
  USING (
    organization_id = app_current_tenant_id()
    AND (
      (
        app_current_scope() = 'school'
        AND school_id = app_current_school_id()
      )
      OR (
        app_current_scope() = 'parent'
        AND guardian_user_id = app_current_parent_user_id()
        AND school_id = app_current_school_id()
      )
    )
  );

-- org_school_summary: org aggregate access; school scope sees own row only
ALTER VIEW org_school_summary SET (security_invoker = true);

-- ─── Tenant isolation self-test (server-side, no service-role bypass) ───────

CREATE SCHEMA IF NOT EXISTS tenant_isolation;

CREATE OR REPLACE FUNCTION tenant_isolation.run_self_test()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org UUID := 'a1000000-0000-4000-8000-000000000001';
  v_school_a UUID := 'a2000000-0000-4000-8000-000000000001';
  v_school_b UUID := 'a2000000-0000-4000-8000-000000000002';
  v_staff_a UUID := 'a3000000-0000-4000-8000-000000000001';
  v_parent UUID := 'a3000000-0000-4000-8000-000000000003';
  v_student_user UUID := 'a3000000-0000-4000-8000-000000000004';
  v_student_a UUID := 'a4000000-0000-4000-8000-000000000001';
  v_student_b UUID := 'a4000000-0000-4000-8000-000000000002';
  v_count INT;
  v_tests JSONB := '[]'::jsonb;
  v_all_pass BOOLEAN := true;
BEGIN
  -- School A cannot read School B
  PERFORM app.set_request_context(v_org, 'school', v_staff_a, v_school_a, NULL, NULL, NULL);
  SELECT count(*) INTO v_count FROM schools WHERE id = v_school_b;
  v_tests := v_tests || jsonb_build_object(
    'name', 'school_a_cannot_see_school_b',
    'pass', v_count = 0,
    'detail', format('visible_schools=%s', v_count)
  );
  IF v_count <> 0 THEN v_all_pass := false; END IF;

  -- Org scope can see both schools (aggregate listing, not operational PII)
  PERFORM app.set_request_context(v_org, 'organization', v_staff_a, NULL, NULL, NULL, NULL);
  SELECT count(*) INTO v_count FROM schools WHERE organization_id = v_org;
  v_tests := v_tests || jsonb_build_object(
    'name', 'org_scope_sees_all_schools_in_tenant',
    'pass', v_count >= 2,
    'detail', format('visible_schools=%s', v_count)
  );
  IF v_count < 2 THEN v_all_pass := false; END IF;

  -- Org scope denied raw cross-school staff memberships
  PERFORM app.set_request_context(v_org, 'organization', v_staff_a, NULL, NULL, NULL, NULL);
  SELECT count(*) INTO v_count FROM school_memberships;
  v_tests := v_tests || jsonb_build_object(
    'name', 'org_scope_denied_raw_school_memberships',
    'pass', v_count = 0,
    'detail', format('visible_memberships=%s', v_count)
  );
  IF v_count <> 0 THEN v_all_pass := false; END IF;

  -- Parent sees only linked child at School A
  PERFORM app.set_request_context(v_org, 'parent', v_parent, v_school_a, NULL, NULL, v_parent);
  SELECT count(*) INTO v_count FROM students WHERE id = v_student_a;
  v_tests := v_tests || jsonb_build_object(
    'name', 'parent_sees_linked_child',
    'pass', v_count = 1,
    'detail', format('visible_students=%s', v_count)
  );
  IF v_count <> 1 THEN v_all_pass := false; END IF;

  -- Parent cannot see student at School B
  PERFORM app.set_request_context(v_org, 'parent', v_parent, v_school_b, NULL, NULL, v_parent);
  SELECT count(*) INTO v_count FROM students WHERE id = v_student_b;
  v_tests := v_tests || jsonb_build_object(
    'name', 'parent_cannot_see_unlinked_school_b_student',
    'pass', v_count = 0,
    'detail', format('visible_students=%s', v_count)
  );
  IF v_count <> 0 THEN v_all_pass := false; END IF;

  -- Student sees only self
  PERFORM app.set_request_context(v_org, 'student', v_student_user, v_school_a, NULL, v_student_a, NULL);
  SELECT count(*) INTO v_count FROM students;
  v_tests := v_tests || jsonb_build_object(
    'name', 'student_sees_self_only',
    'pass', v_count = 1,
    'detail', format('visible_students=%s', v_count)
  );
  IF v_count <> 1 THEN v_all_pass := false; END IF;

  -- Org aggregate view accessible at org scope
  PERFORM app.set_request_context(v_org, 'organization', v_staff_a, NULL, NULL, NULL, NULL);
  SELECT count(*) INTO v_count FROM org_school_summary WHERE tenant_id = v_org;
  v_tests := v_tests || jsonb_build_object(
    'name', 'org_scope_reads_aggregate_view',
    'pass', v_count >= 2,
    'detail', format('summary_rows=%s', v_count)
  );
  IF v_count < 2 THEN v_all_pass := false; END IF;

  RETURN jsonb_build_object('pass', v_all_pass, 'tests', v_tests);
END;
$$;

REVOKE ALL ON FUNCTION tenant_isolation.run_self_test FROM PUBLIC;
GRANT EXECUTE ON FUNCTION tenant_isolation.run_self_test TO service_role;

CREATE OR REPLACE FUNCTION run_tenant_isolation_self_test()
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT tenant_isolation.run_self_test();
$$;

REVOKE ALL ON FUNCTION run_tenant_isolation_self_test FROM PUBLIC;
GRANT EXECUTE ON FUNCTION run_tenant_isolation_self_test TO service_role;

-- ─── Staging seed: School B, parent, student (isolation test fixtures) ──────

INSERT INTO schools (id, organization_id, name, code)
VALUES (
  'a2000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'Akshara Staging School B',
  'AKS-002'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO users (id, phone, email, display_name)
VALUES
  (
    'a3000000-0000-4000-8000-000000000003',
    '+919876543211',
    'staging.parent@aksharaerp.com',
    'Staging Parent'
  ),
  (
    'a3000000-0000-4000-8000-000000000004',
    '+919876543212',
    'staging.student@aksharaerp.com',
    'Staging Student'
  )
ON CONFLICT (phone) DO NOTHING;

INSERT INTO students (id, organization_id, school_id, user_id, student_code, display_name, status)
VALUES
  (
    'a4000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000001',
    'a3000000-0000-4000-8000-000000000004',
    'STU-001',
    'Staging Student',
    'active'
  ),
  (
    'a4000000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000002',
    NULL,
    'STU-002',
    'School B Student',
    'active'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO student_guardians (
  organization_id, school_id, student_id, guardian_user_id, relationship, is_primary, status
)
VALUES (
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'a4000000-0000-4000-8000-000000000001',
  'a3000000-0000-4000-8000-000000000003',
  'mother',
  true,
  'active'
)
ON CONFLICT (student_id, guardian_user_id) DO NOTHING;
