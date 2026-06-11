import type { TenantQueryClient } from "../tenant_db.ts";
import {
  getEmployee,
  listEmployeeRoles,
} from "./employee_repository.ts";

export interface Employee360Profile {
  profile: Record<string, unknown>;
  roles: Array<Record<string, unknown>>;
  assignments: Array<Record<string, unknown>>;
  workload: {
    workloadPercent: number;
    burnoutRisk: string;
    overloadScore: number;
    substitutionLoad: number;
    coordinatorLoad: number;
  };
  attendance: Record<string, unknown>;
  leave: Record<string, unknown>;
  performance: Record<string, unknown>;
  communication: Record<string, unknown>;
  insights: string[];
}

export interface EmployeeIntelligenceDashboard {
  teachersNeedingSupport: Array<{ employeeId: string; name: string; burnoutRisk: string }>;
  highPerformers: Array<{ employeeId: string; name: string; score: number }>;
  workloadBalancing: Array<{ employeeId: string; name: string; workloadPercent: number }>;
  avgWorkloadPercent: number;
}

export async function buildEmployee360(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  employeeId: string,
): Promise<Employee360Profile> {
  const employee = await getEmployee(client, employeeId);
  if (!employee) throw new Error(`Employee not found: ${employeeId}`);

  const roles = await listEmployeeRoles(client, employeeId);
  const assignments = roles.map((r) => ({
    roleCode: r.role_code,
    effectiveFrom: r.effective_from,
    isPrimary: r.is_primary,
  }));

  const intel = await client.queryObject<{
    workload_percent: number;
    burnout_risk: string;
    overload_score: number;
    substitution_load: number;
    coordinator_load: number;
    insights: unknown;
  }>(
    `SELECT workload_percent, burnout_risk, overload_score, substitution_load,
            coordinator_load, insights
     FROM employee_intelligence_snapshots
     WHERE employee_id = $1 AND organization_id = $2 AND school_id = $3
     ORDER BY computed_at DESC LIMIT 1`,
    [employeeId, organizationId, schoolId],
  );

  const snapshot = intel[0];
  const workloadPercent = snapshot?.workload_percent ??
    Math.min(100, roles.length * 15 + 20);
  const burnoutRisk = snapshot?.burnout_risk ??
    (workloadPercent > 85 ? "high" : workloadPercent > 65 ? "medium" : "low");

  const leave = employee.user_id
    ? await client.queryObject<{ approved: number; pending: number }>(
      `SELECT
         count(*) FILTER (WHERE status = 'approved')::int AS approved,
         count(*) FILTER (WHERE status = 'pending')::int AS pending
       FROM mobile_leave_requests
       WHERE requester_user_id = $1 AND organization_id = $2 AND school_id = $3`,
      [employee.user_id, organizationId, schoolId],
    )
    : [{ approved: 0, pending: 0 }];

  const insights = Array.isArray(snapshot?.insights)
    ? (snapshot!.insights as string[])
    : workloadPercent > 80
    ? ["Consider reducing substitution assignments"]
    : ["Workload within healthy range"];

  return {
    profile: {
      id: employee.id,
      displayName: employee.display_name,
      email: employee.email,
      department: employee.primary_department,
      status: employee.status,
      employeeCode: employee.employee_code,
    },
    roles: roles.map((r) => ({
      id: r.id,
      roleCode: r.role_code,
      effectiveFrom: r.effective_from,
      isPrimary: r.is_primary,
    })),
    assignments,
    workload: {
      workloadPercent,
      burnoutRisk,
      overloadScore: snapshot?.overload_score ?? Math.round(workloadPercent * 0.8),
      substitutionLoad: snapshot?.substitution_load ?? 0,
      coordinatorLoad: snapshot?.coordinator_load ?? 0,
    },
    attendance: { presentDays: 0, absentDays: 0 },
    leave: { approved: leave[0]?.approved ?? 0, pending: leave[0]?.pending ?? 0 },
    performance: { rating: workloadPercent > 75 ? "strong" : "steady" },
    communication: { messagesSent: 0 },
    insights,
  };
}

export async function buildEmployeeIntelligenceDashboard(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<EmployeeIntelligenceDashboard> {
  const rows = await client.queryObject<{
    employee_id: string;
    display_name: string;
    workload_percent: number;
    burnout_risk: string;
    overload_score: number;
  }>(
    `SELECT
       e.id AS employee_id,
       e.display_name,
       coalesce(s.workload_percent, 50)::int AS workload_percent,
       coalesce(s.burnout_risk, 'low') AS burnout_risk,
       coalesce(s.overload_score, 40)::int AS overload_score
     FROM employees e
     LEFT JOIN LATERAL (
       SELECT workload_percent, burnout_risk, overload_score
       FROM employee_intelligence_snapshots
       WHERE employee_id = e.id
         AND organization_id = $1
         AND school_id = $2
       ORDER BY computed_at DESC
       LIMIT 1
     ) s ON true
     WHERE e.organization_id = $1
       AND e.school_id = $2
       AND e.status = 'active'
     LIMIT 100`,
    [organizationId, schoolId],
  );

  const teachersNeedingSupport = rows
    .filter((e) => ["high", "critical"].includes(e.burnout_risk))
    .map((e) => ({
      employeeId: e.employee_id,
      name: e.display_name,
      burnoutRisk: e.burnout_risk,
    }));

  const highPerformers = rows
    .filter((e) => e.workload_percent >= 60 && e.workload_percent <= 80)
    .map((e) => ({
      employeeId: e.employee_id,
      name: e.display_name,
      score: 100 - e.overload_score,
    }))
    .slice(0, 5);

  const workloadBalancing = rows
    .map((e) => ({
      employeeId: e.employee_id,
      name: e.display_name,
      workloadPercent: e.workload_percent,
    }))
    .sort((a, b) => b.workloadPercent - a.workloadPercent);

  const avgWorkloadPercent = rows.length > 0
    ? Math.round(rows.reduce((sum, e) => sum + e.workload_percent, 0) / rows.length)
    : 0;

  return {
    teachersNeedingSupport,
    highPerformers,
    workloadBalancing,
    avgWorkloadPercent,
  };
}

export async function upsertEmployeeIntelligenceSnapshot(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  employeeId: string,
): Promise<void> {
  const profile = await buildEmployee360(client, organizationId, schoolId, employeeId);
  await client.queryObject(
    `INSERT INTO employee_intelligence_snapshots (
       organization_id, school_id, employee_id,
       workload_percent, burnout_risk, overload_score,
       substitution_load, coordinator_load, insights
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb)`,
    [
      organizationId,
      schoolId,
      employeeId,
      profile.workload.workloadPercent,
      profile.workload.burnoutRisk,
      profile.workload.overloadScore,
      profile.workload.substitutionLoad,
      profile.workload.coordinatorLoad,
      JSON.stringify(profile.insights),
    ],
  );
}
