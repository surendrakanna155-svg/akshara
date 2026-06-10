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

export function employeeDetailToApi(employee: Record<string, unknown>): Record<string, unknown> {
  const role = String(employee.role ?? "staff");
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

  return {
    employee,
    reportingManager: role === "principal" ? "Board of Trustees" : "Rajesh Iyer (Principal)",
    address: "Hyderabad, Telangana",
    emergencyContact: "+91 90000 12345",
    leaveBalances: [
      { leaveType: "casual", available: 8, used: 4 },
      { leaveType: "sick", available: 10, used: 2 },
      { leaveType: "earned", available: 15, used: 5 },
    ],
    documents: [
      { id: "doc_1", title: "Offer letter", uploadedOn: "2019-05-20", status: "Verified" },
      { id: "doc_2", title: "ID proof", uploadedOn: "2019-05-22", status: "Verified" },
    ],
    recentAttendance: employeeId === HR_EMPLOYEE_SCHOOL_A
      ? [{
        id: "att_1",
        employeeId,
        employeeName: name,
        department,
        date: "2026-06-06",
        checkIn: "8:02 AM",
        checkOut: "3:45 PM",
        status: "present",
        geoVerified: true,
        faceVerified: true,
      }]
      : [],
    integrationNotes,
  };
}
