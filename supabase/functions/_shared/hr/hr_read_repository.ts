import type { TenantQueryClient } from "../tenant_db.ts";
import {
  clampPageSize,
  offsetFor,
  type PaginationParams,
  type PaginationResult,
} from "../academic/academic_pagination.ts";

export const HR_EMPLOYEE_SCHOOL_A = "be100000-0000-4000-8000-000000000001";
export const HR_EMPLOYEE_SCHOOL_B = "be100000-0000-4000-8000-000000000002";

/** SQL fragment used by tenant isolation probes for HR entity visibility. */
export const HR_ENTITIES_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM hr_entities
`;

/** SQL fragment used by API-layer tenant isolation probes (employee list). */
export const HR_EMPLOYEES_API_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM hr_entities
  WHERE entity_type = 'employee'
    AND organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
`;

/** SQL fragment used by API-layer tenant isolation probes (employee detail by id). */
export const HR_EMPLOYEE_DETAIL_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM hr_entities
  WHERE entity_type = 'employee'
    AND id = $1
`;

export class HrSnapshotNotFoundError extends Error {
  constructor(entityType: string) {
    super(`HR snapshot not found: ${entityType}`);
    this.name = "HrSnapshotNotFoundError";
  }
}

export class HrEmployeeNotFoundError extends Error {
  constructor(id: string) {
    super(`Employee not found: ${id}`);
    this.name = "HrEmployeeNotFoundError";
  }
}

export async function getSnapshot(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  entityType: string,
  snapshotId = "default",
): Promise<Record<string, unknown>> {
  const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
    `SELECT payload
     FROM hr_entities
     WHERE organization_id = $1
       AND school_id = $2
       AND entity_type = $3
       AND id = $4`,
    [organizationId, schoolId, entityType, snapshotId],
  );
  const row = rows[0];
  if (!row) {
    throw new HrSnapshotNotFoundError(entityType);
  }
  return row.payload;
}

export async function listEntities(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  entityType: string,
  pagination: PaginationParams,
): Promise<PaginationResult<Record<string, unknown>>> {
  const pageSize = clampPageSize(pagination.pageSize);
  const page = Math.max(1, pagination.page);
  const offset = offsetFor(page, pageSize);

  const countRows = await db.queryObject<{ total: string }>(
    `SELECT count(*)::text AS total
     FROM hr_entities
     WHERE organization_id = $1
       AND school_id = $2
       AND entity_type = $3`,
    [organizationId, schoolId, entityType],
  );
  const total = parseInt(countRows[0]?.total ?? "0", 10);

  const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
    `SELECT payload
     FROM hr_entities
     WHERE organization_id = $1
       AND school_id = $2
       AND entity_type = $3
     ORDER BY id
     LIMIT $4 OFFSET $5`,
    [organizationId, schoolId, entityType, pageSize, offset],
  );

  return {
    items: rows.map((row) => row.payload),
    total,
    page,
    pageSize,
    hasMore: offset + rows.length < total,
  };
}

/**
 * Returns every payload of one entity_type for this school. Used by the
 * dashboard compute path to derive KPIs from the REAL employee / opening rows
 * (not a pre-seeded snapshot count).
 */
export async function listPayloads(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  entityType: string,
): Promise<Array<Record<string, unknown>>> {
  const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
    `SELECT payload
     FROM hr_entities
     WHERE organization_id = $1
       AND school_id = $2
       AND entity_type = $3
     ORDER BY id`,
    [organizationId, schoolId, entityType],
  );
  return rows.map((row) => row.payload ?? {});
}

// ---------------------------------------------------------------------------
// Dashboard: computed live (MJ-H17 / HR-5). KPIs + trends + lists are derived
// from the real HR tables for THIS school inside the tenant RLS context — never
// from a hardcoded snapshot. A fresh school with 3 employees reports 3, not 148.
// Field names mirror the seeded `snapshot_dashboard` shape EXACTLY because the
// Flutter HR dashboard mapper (lib/.../hr/mapper/hr_mapper.dart) depends on them.
// ---------------------------------------------------------------------------

/** ISO yyyy-mm-dd for "today" (UTC), used to scope attendance / leave. */
function isoToday(now = new Date()): string {
  return now.toISOString().slice(0, 10);
}

function asArray(value: unknown): Array<Record<string, unknown>> {
  return Array.isArray(value) ? value as Array<Record<string, unknown>> : [];
}

/** Raw, real inputs the dashboard is computed from (all from live HR rows). */
export interface DashboardInputs {
  /** All `employee` entity payloads for this school. */
  employees: Array<Record<string, unknown>>;
  /** All `opening` (recruitment requisition) payloads for this school. */
  openings: Array<Record<string, unknown>>;
  /** `snapshot_attendance` payload (records + attendanceTrend), or {}. */
  attendance: Record<string, unknown>;
  /** `snapshot_leave` payload (requests + pendingCount), or {}. */
  leave: Record<string, unknown>;
  /** `snapshot_recruitment` payload (candidates), or {}. */
  recruitment: Record<string, unknown>;
}

/** The numeric facts that ground both the KPI cards and the AI insight. */
export interface DashboardKpiFacts {
  totalEmployees: number;
  activeEmployees: number;
  presentToday: number;
  onLeaveToday: number;
  openPositions: number;
  pendingLeaveCount: number;
  /** Department with the most employees, or "" when there are none. */
  topDepartment: string;
  topDepartmentCount: number;
}

/**
 * Computes the grounding facts from the live inputs. Empty inputs => all zeros
 * (an honest "fresh school" picture), never a fabricated headline number.
 */
export function computeDashboardFacts(
  inputs: DashboardInputs,
  now = new Date(),
): DashboardKpiFacts {
  const today = isoToday(now);
  const employees = inputs.employees;
  const totalEmployees = employees.length;
  const activeEmployees = employees.filter(
    (e) => String(e.status ?? "active") === "active",
  ).length;

  // Present today: attendance records dated today with a present status.
  const attendanceRecords = asArray(inputs.attendance.records);
  const presentToday = attendanceRecords.filter(
    (r) => String(r.date ?? "") === today && String(r.status ?? "") === "present",
  ).length;

  // On leave today: approved leave requests whose [fromDate, toDate] spans today.
  const leaveRequests = asArray(inputs.leave.requests);
  const onLeaveToday = leaveRequests.filter((r) => {
    if (String(r.status ?? "") !== "approved") return false;
    const from = String(r.fromDate ?? "");
    const to = String(r.toDate ?? from);
    return from !== "" && from <= today && today <= (to || from);
  }).length;

  // Open positions: sum of open requisition seats (count seats, not requisitions).
  const openPositions = inputs.openings
    .filter((o) => String(o.status ?? "open") === "open")
    .reduce((sum, o) => sum + Math.max(0, Number(o.openings ?? 1) || 0), 0);

  const pendingLeaveCount = leaveRequests.filter(
    (r) => String(r.status ?? "") === "pending",
  ).length;

  // Largest department by headcount (drives the deterministic insight).
  const deptCounts = new Map<string, number>();
  for (const e of employees) {
    const dept = String(e.department ?? "");
    if (dept === "") continue;
    deptCounts.set(dept, (deptCounts.get(dept) ?? 0) + 1);
  }
  let topDepartment = "";
  let topDepartmentCount = 0;
  for (const [dept, count] of deptCounts) {
    if (count > topDepartmentCount) {
      topDepartment = dept;
      topDepartmentCount = count;
    }
  }

  return {
    totalEmployees,
    activeEmployees,
    presentToday,
    onLeaveToday,
    openPositions,
    pendingLeaveCount,
    topDepartment,
    topDepartmentCount,
  };
}

/** Builds the four KPI cards (same ids/labels/accents as the legacy snapshot). */
export function buildDashboardKpis(
  facts: DashboardKpiFacts,
): Array<Record<string, unknown>> {
  return [
    {
      id: "total_employees",
      value: String(facts.totalEmployees),
      label: "Total Employees",
      accentName: "primary",
    },
    {
      id: "present_today",
      value: String(facts.presentToday),
      label: "Present Today",
      accentName: "success",
    },
    {
      id: "on_leave",
      value: String(facts.onLeaveToday),
      label: "On Leave",
      accentName: "warning",
    },
    {
      id: "open_positions",
      value: String(facts.openPositions),
      label: "Open Positions",
      accentName: "primary",
    },
  ];
}

/** Pending leave list for the dashboard, from the REAL leave requests. */
export function buildPendingLeave(
  inputs: DashboardInputs,
): Array<Record<string, unknown>> {
  return asArray(inputs.leave.requests)
    .filter((r) => String(r.status ?? "") === "pending")
    .map((r) => ({
      id: String(r.id ?? ""),
      employeeName: String(r.employeeName ?? ""),
      leaveType: String(r.leaveType ?? "casual"),
      days: Number(r.days ?? 0) || 0,
      // The dashboard card labels this "submitted on"; the request's own start
      // date is the closest real signal we record.
      submittedOn: String(r.submittedOn ?? r.fromDate ?? ""),
    }));
}

/** Recruitment snapshot list for the dashboard, from REAL candidate rows. */
export function buildRecruitmentSnapshot(
  inputs: DashboardInputs,
): Array<Record<string, unknown>> {
  return asArray(inputs.recruitment.candidates).map((c) => ({
    id: String(c.id ?? ""),
    name: String(c.name ?? ""),
    role: String(c.role ?? ""),
    department: String(c.department ?? "academics"),
    appliedOn: String(c.appliedOn ?? ""),
    stage: String(c.stage ?? "applied"),
    experience: String(c.experience ?? ""),
    source: String(c.source ?? ""),
  }));
}

/**
 * A deterministic, honest management note grounded in the real numbers — used
 * directly, and as the safe fallback when no AI key is configured.
 */
export function buildManagementKpiNote(facts: DashboardKpiFacts): string {
  if (facts.totalEmployees === 0) {
    return "No employees on record yet. Add staff under HR to populate the dashboard.";
  }
  const attendancePct = facts.activeEmployees > 0
    ? Math.round((facts.presentToday / facts.activeEmployees) * 100)
    : 0;
  return `${facts.presentToday} of ${facts.activeEmployees} active staff marked present today ` +
    `(${attendancePct}%). Feeds the Management attendance KPI.`;
}

/**
 * A deterministic insight built only from the computed facts. This is the safe
 * fallback the AI layer returns when no key is configured or the call fails —
 * it never names a person who is not present in the data and never fabricates a
 * headline number.
 */
export function buildDeterministicInsight(facts: DashboardKpiFacts): string {
  if (facts.totalEmployees === 0) {
    return "No staff are on record yet. Once you add employees, this insight will " +
      "summarise attendance, leave, and hiring for your school.";
  }
  const parts: string[] = [];
  parts.push(
    `${facts.totalEmployees} employees on record` +
      (facts.activeEmployees !== facts.totalEmployees
        ? ` (${facts.activeEmployees} active)`
        : "") + ".",
  );
  parts.push(
    `${facts.presentToday} present today, ${facts.onLeaveToday} on approved leave.`,
  );
  if (facts.pendingLeaveCount > 0) {
    parts.push(
      `${facts.pendingLeaveCount} leave request${
        facts.pendingLeaveCount === 1 ? "" : "s"
      } awaiting approval.`,
    );
  }
  if (facts.openPositions > 0) {
    parts.push(
      `${facts.openPositions} open position${
        facts.openPositions === 1 ? "" : "s"
      } in recruitment.`,
    );
  }
  if (facts.topDepartment !== "") {
    parts.push(
      `Largest team: ${facts.topDepartment} (${facts.topDepartmentCount}).`,
    );
  }
  return parts.join(" ");
}

/**
 * Assembles the full dashboard payload from the computed facts + real lists.
 * `aiInsight` is supplied by the caller (real Claude, or the deterministic
 * fallback). Trends that have no real historical source degrade to honest empty
 * series rather than fabricated curves; `attendanceTrend` is reused from the
 * real attendance snapshot when present.
 */
export function composeDashboard(
  inputs: DashboardInputs,
  facts: DashboardKpiFacts,
  aiInsight: string,
): Record<string, unknown> {
  return {
    aiInsight,
    managementKpiNote: buildManagementKpiNote(facts),
    kpis: buildDashboardKpis(facts),
    // No real month-over-month headcount history is recorded yet — honest empty.
    headcountTrend: [],
    // Attendance trend is genuine when the attendance snapshot carries it.
    attendanceTrend: asArray(inputs.attendance.attendanceTrend),
    pendingLeave: buildPendingLeave(inputs),
    recruitmentSnapshot: buildRecruitmentSnapshot(inputs),
  };
}

export async function getEmployee(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  employeeId: string,
): Promise<Record<string, unknown>> {
  const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
    `SELECT payload
     FROM hr_entities
     WHERE organization_id = $1
       AND school_id = $2
       AND entity_type = 'employee'
       AND id = $3`,
    [organizationId, schoolId, employeeId],
  );
  const row = rows[0];
  if (!row) {
    throw new HrEmployeeNotFoundError(employeeId);
  }
  return row.payload;
}

/**
 * Default leave entitlements (days per year) used when a school has not
 * configured a `leavePolicy` in its `snapshot_settings`. These are ORG-POLICY
 * entitlements that apply equally to every employee — they are NOT a per-person
 * usage claim. Per-employee "used"/"available" is derived from that employee's
 * own approved leave requests (see `buildLeaveBalances`).
 */
export const DEFAULT_LEAVE_POLICY: Array<{ leaveType: string; entitlement: number }> = [
  { leaveType: "casual", entitlement: 12 },
  { leaveType: "sick", entitlement: 12 },
  { leaveType: "earned", entitlement: 15 },
];

/** Honest placeholder for an unrecorded text field (never a fabricated value). */
export const NOT_ON_RECORD = "Not on record";

/**
 * Optional real per-employee context, sourced from existing HR snapshots, used
 * to derive a truthful employee detail. All fields are optional: when a source
 * is absent the corresponding section degrades to an honest empty/neutral value.
 */
export interface EmployeeDetailContext {
  /** Rows from `snapshot_attendance.records` (all employees, this school). */
  attendanceRecords?: Array<Record<string, unknown>>;
  /** Rows from `snapshot_leave.requests` (all employees, this school). */
  leaveRequests?: Array<Record<string, unknown>>;
  /** Org leave policy from `snapshot_settings.leavePolicy`, if configured. */
  leavePolicy?: Array<{ leaveType: string; entitlement: number }>;
}

/**
 * Per-employee leave balances. The entitlement is a genuine org policy (same
 * for everyone); the `used`/`available` split is computed from THIS employee's
 * own approved leave requests, so two employees with different leave histories
 * see different balances.
 */
function buildLeaveBalances(
  employeeId: string,
  ctx: EmployeeDetailContext,
): Array<Record<string, unknown>> {
  const policy = ctx.leavePolicy && ctx.leavePolicy.length > 0
    ? ctx.leavePolicy
    : DEFAULT_LEAVE_POLICY;
  const approved = (ctx.leaveRequests ?? []).filter(
    (r) => String(r.employeeId ?? "") === employeeId && String(r.status ?? "") === "approved",
  );
  return policy.map((p) => {
    const used = approved
      .filter((r) => String(r.leaveType ?? "") === p.leaveType)
      .reduce((sum, r) => sum + (Number(r.days ?? 0) || 0), 0);
    const available = Math.max(0, p.entitlement - used);
    return { leaveType: p.leaveType, available, used };
  });
}

export function employeeDetailToApi(
  employee: Record<string, unknown>,
  ctx: EmployeeDetailContext = {},
): Record<string, unknown> {
  const department = String(employee.department ?? "");
  const name = String(employee.name ?? "");
  const employeeId = String(employee.id ?? "");

  const integrationNotes: string[] = [];
  if (employee.teacherAppLinked === true) {
    integrationNotes.push(
      `Linked to Teacher app — ${name} uses TA-01 attendance and TA-07 leave.`,
    );
  }
  if (department === "finance") {
    integrationNotes.push(
      "Payroll is tracked in the HR module and is NOT posted to the Finance ledger — " +
        "record salary disbursements against the FN-05 head in Finance manually.",
    );
  }
  if (department === "transport") {
    integrationNotes.push("Also listed in Transport driver roster (TR-04).");
  }

  // Address / emergency contact / reporting manager come from the employee's OWN
  // payload (backfilled per-employee by migration 20260805000000). Absent values
  // degrade to an honest neutral rather than a fabricated shared string.
  const reportingManager = optionalText(employee.reportingManager);
  const address = optionalText(employee.address);
  const emergencyContact = optionalText(employee.emergencyContact);

  // Documents come only from the employee's own record; never fabricated.
  const documents = Array.isArray(employee.documents)
    ? employee.documents as Array<Record<string, unknown>>
    : [];

  // Recent attendance is filtered to THIS employee from the real attendance
  // snapshot — no hardcoded single-employee literal.
  const recentAttendance = (ctx.attendanceRecords ?? []).filter(
    (r) => String(r.employeeId ?? "") === employeeId,
  );

  return {
    employee,
    reportingManager,
    address,
    emergencyContact,
    leaveBalances: buildLeaveBalances(employeeId, ctx),
    documents,
    recentAttendance,
    integrationNotes,
  };
}

/** Returns a trimmed payload string, or the honest "Not on record" placeholder. */
function optionalText(value: unknown): string {
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (trimmed.length > 0) return trimmed;
  }
  return NOT_ON_RECORD;
}
