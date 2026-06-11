-- v9.6 Employee Platform

CREATE TABLE employees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  user_id UUID REFERENCES users (id),
  employee_code TEXT NOT NULL,
  display_name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive', 'on_leave')),
  primary_department TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE UNIQUE INDEX idx_employees_code
  ON employees (organization_id, school_id, employee_code);

CREATE INDEX idx_employees_user
  ON employees (organization_id, school_id, user_id)
  WHERE user_id IS NOT NULL;

CREATE TRIGGER employees_updated_at
  BEFORE UPDATE ON employees
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE employee_role_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  employee_id UUID NOT NULL REFERENCES employees (id) ON DELETE CASCADE,
  role_code TEXT NOT NULL,
  effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
  effective_to DATE,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  notes TEXT,
  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_employee_roles_employee
  ON employee_role_assignments (employee_id, effective_from DESC);

ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees FORCE ROW LEVEL SECURITY;
ALTER TABLE employee_role_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_role_assignments FORCE ROW LEVEL SECURITY;

CREATE POLICY employees_school_scope ON employees
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

CREATE POLICY employee_roles_school_scope ON employee_role_assignments
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

GRANT SELECT, INSERT, UPDATE, DELETE ON employees TO erp_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON employee_role_assignments TO erp_tenant;

-- Backward compatibility: project existing school memberships into employees (idempotent)
INSERT INTO employees (
  organization_id, school_id, user_id, employee_code, display_name, status, primary_department
)
SELECT DISTINCT ON (sch.organization_id, sm.school_id, sm.user_id)
  sch.organization_id,
  sm.school_id,
  sm.user_id,
  'EMP-' || substr(replace(sm.user_id::text, '-', ''), 1, 8),
  coalesce(sm.member_display_name, u.display_name, 'Staff Member'),
  CASE WHEN sm.status = 'active' THEN 'active' ELSE 'inactive' END,
  'General'
FROM school_memberships sm
JOIN schools sch ON sch.id = sm.school_id
JOIN users u ON u.id = sm.user_id
WHERE NOT EXISTS (
  SELECT 1 FROM employees e
  WHERE e.organization_id = sch.organization_id
    AND e.school_id = sm.school_id
    AND e.user_id = sm.user_id
);

INSERT INTO employee_role_assignments (
  organization_id, school_id, employee_id, role_code, is_primary
)
SELECT
  e.organization_id,
  e.school_id,
  e.id,
  smr.role_slug,
  smr.is_primary
FROM employees e
JOIN school_memberships sm
  ON sm.school_id = e.school_id
 AND sm.user_id = e.user_id
JOIN schools sch ON sch.id = sm.school_id AND sch.organization_id = e.organization_id
JOIN school_membership_roles smr ON smr.school_membership_id = sm.id
WHERE smr.status = 'active'
  AND NOT EXISTS (
    SELECT 1 FROM employee_role_assignments era
    WHERE era.employee_id = e.id AND era.role_code = smr.role_slug
  );
