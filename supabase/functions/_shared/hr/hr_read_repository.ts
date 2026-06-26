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
      "Payroll entries post to Finance module (FN-05 salary disbursement placeholder).",
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
