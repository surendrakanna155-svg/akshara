import type { TenantQueryClient } from "../tenant_db.ts";

export interface EmployeeRow {
  id: string;
  organization_id: string;
  school_id: string;
  user_id: string | null;
  employee_code: string;
  display_name: string;
  email: string | null;
  phone: string | null;
  status: string;
  primary_department: string | null;
  created_at: string;
  updated_at: string;
}

export interface EmployeeRoleRow {
  id: string;
  employee_id: string;
  role_code: string;
  effective_from: string;
  effective_to: string | null;
  is_primary: boolean;
  notes: string | null;
  created_at: string;
}

export interface EmployeeDashboard {
  totalEmployees: number;
  activeEmployees: number;
  roleDistribution: Array<{ roleCode: string; count: number }>;
  workloadIndex: number;
  recentAssignments: Array<{
    employeeId: string;
    employeeName: string;
    roleCode: string;
    effectiveFrom: string;
  }>;
}

export async function listEmployees(
  client: TenantQueryClient,
  filters: { search?: string; status?: string },
): Promise<EmployeeRow[]> {
  const conditions = ["1=1"];
  const params: unknown[] = [];
  let idx = 1;
  if (filters.search) {
    conditions.push(`(display_name ILIKE $${idx} OR employee_code ILIKE $${idx})`);
    params.push(`%${filters.search}%`);
    idx += 1;
  }
  if (filters.status) {
    conditions.push(`status = $${idx}`);
    params.push(filters.status);
    idx += 1;
  }
  return await client.queryObject<EmployeeRow>(
    `SELECT * FROM employees WHERE ${conditions.join(" AND ")}
     ORDER BY display_name ASC`,
    params,
  );
}

export async function getEmployee(
  client: TenantQueryClient,
  employeeId: string,
): Promise<EmployeeRow | null> {
  const rows = await client.queryObject<EmployeeRow>(
    `SELECT * FROM employees WHERE id = $1`,
    [employeeId],
  );
  return rows[0] ?? null;
}

export async function listEmployeeRoles(
  client: TenantQueryClient,
  employeeId: string,
): Promise<EmployeeRoleRow[]> {
  return await client.queryObject<EmployeeRoleRow>(
    `SELECT * FROM employee_role_assignments
     WHERE employee_id = $1
     ORDER BY effective_from DESC, created_at DESC`,
    [employeeId],
  );
}

export async function assignEmployeeRole(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  employeeId: string,
  roleCode: string,
  createdBy: string | null,
  isPrimary = false,
): Promise<EmployeeRoleRow> {
  const rows = await client.queryObject<EmployeeRoleRow>(
    `INSERT INTO employee_role_assignments (
       organization_id, school_id, employee_id, role_code, is_primary, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [organizationId, schoolId, employeeId, roleCode, isPrimary, createdBy],
  );
  return rows[0]!;
}

export async function buildEmployeeDashboard(
  client: TenantQueryClient,
): Promise<EmployeeDashboard> {
  const totals = await client.queryObject<{ total: number; active: number }>(
    `SELECT count(*)::int AS total,
       count(*) FILTER (WHERE status = 'active')::int AS active
     FROM employees`,
  );

  const roles = await client.queryObject<{ role_code: string; count: number }>(
    `SELECT role_code, count(*)::int AS count
     FROM employee_role_assignments
     WHERE effective_to IS NULL OR effective_to >= CURRENT_DATE
     GROUP BY role_code
     ORDER BY count DESC`,
  );

  const recent = await client.queryObject<{
    employee_id: string;
    display_name: string;
    role_code: string;
    effective_from: string;
  }>(
    `SELECT era.employee_id, e.display_name, era.role_code, era.effective_from::text
     FROM employee_role_assignments era
     JOIN employees e ON e.id = era.employee_id
     ORDER BY era.created_at DESC
     LIMIT 10`,
  );

  const roleCount = roles.length || 1;
  const workloadIndex = Math.min(100, Math.round((totals[0]?.active ?? 0) / roleCount * 10));

  return {
    totalEmployees: totals[0]?.total ?? 0,
    activeEmployees: totals[0]?.active ?? 0,
    roleDistribution: roles.map((r) => ({ roleCode: r.role_code, count: r.count })),
    workloadIndex,
    recentAssignments: recent.map((r) => ({
      employeeId: r.employee_id,
      employeeName: r.display_name,
      roleCode: r.role_code,
      effectiveFrom: r.effective_from,
    })),
  };
}
