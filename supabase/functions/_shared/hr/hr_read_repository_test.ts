import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  employeeDetailToApi,
  getEmployee,
  getSnapshot,
  HR_EMPLOYEE_SCHOOL_A,
  HrEmployeeNotFoundError,
  HrSnapshotNotFoundError,
  listEntities,
} from "./hr_read_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";

function schoolClaims(): AccessTokenClaims {
  return {
    sub: "staff",
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL_A,
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: ["viewHr"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "test",
  };
}

function orgClaims(): AccessTokenClaims {
  return {
    ...schoolClaims(),
    school_id: null,
    scope: "organization",
    permissions: ["viewHr"],
  };
}

class MockHrDb {
  rows = [
    {
      entity_type: "snapshot_dashboard",
      id: "default",
      payload: {
        aiInsight: "Test insight",
        managementKpiNote: "Management KPI note",
        kpis: [{ id: "total_employees", value: "148", label: "Total Employees", accentName: "primary" }],
        headcountTrend: [{ label: "Jan", amountLakhs: 14.2, targetLakhs: 14.0 }],
        attendanceTrend: [{ label: "W1", amountLakhs: 94.0, targetLakhs: 95.0 }],
        pendingLeave: [],
        recruitmentSnapshot: [],
      },
    },
    {
      entity_type: "employee",
      id: HR_EMPLOYEE_SCHOOL_A,
      payload: {
        id: HR_EMPLOYEE_SCHOOL_A,
        name: "Priya Sharma",
        employeeCode: "EMP-101",
        department: "academics",
        role: "teacher",
        designation: "Mathematics Teacher",
        email: "priya.sharma@akshara.edu",
        phone: "+91 98765 43210",
        joinDate: "2019-06-01",
        status: "active",
        teacherAppLinked: true,
        classLabel: "8-B",
      },
    },
  ];

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("count(*)::text AS total")) {
      const entityType = args[2] as string;
      const total = this.rows.filter((row) => row.entity_type === entityType).length;
      return [{ total: String(total) }] as T[];
    }

    if (sql.includes("entity_type = 'employee'") && sql.includes("AND id = $3")) {
      const id = args[2] as string;
      const row = this.rows.find((entry) => entry.entity_type === "employee" && entry.id === id);
      return row ? [{ payload: row.payload }] as T[] : [] as T[];
    }

    if (sql.includes("entity_type = $3") && sql.includes("AND id = $4")) {
      const entityType = args[2] as string;
      const id = args[3] as string;
      const row = this.rows.find((entry) => entry.entity_type === entityType && entry.id === id);
      return row ? [{ payload: row.payload }] as T[] : [] as T[];
    }

    if (sql.includes("ORDER BY id")) {
      const entityType = args[2] as string;
      const limit = args[3] as number;
      const offset = args[4] as number;
      const items = this.rows
        .filter((row) => row.entity_type === entityType)
        .slice(offset, offset + limit);
      return items.map((row) => ({ payload: row.payload })) as T[];
    }

    return [] as T[];
  }
}

Deno.test("getSnapshot returns HR dashboard payload", async () => {
  const db = new MockHrDb() as unknown as TenantQueryClient;
  const snapshot = await getSnapshot(db, ORG, SCHOOL_A, "snapshot_dashboard");
  assertEquals(typeof snapshot.aiInsight, "string");
  assertEquals(Array.isArray(snapshot.kpis), true);
  assertEquals(Array.isArray(snapshot.headcountTrend), true);
});

Deno.test("getSnapshot throws when HR snapshot missing", async () => {
  const db = new MockHrDb() as unknown as TenantQueryClient;
  await assertRejects(
    () => getSnapshot(db, ORG, SCHOOL_A, "snapshot_leave"),
    HrSnapshotNotFoundError,
  );
});

Deno.test("listEntities paginates employees", async () => {
  const db = new MockHrDb() as unknown as TenantQueryClient;
  const result = await listEntities(db, ORG, SCHOOL_A, "employee", { page: 1, pageSize: 20 });
  assertEquals(result.total, 1);
  assertEquals(result.items[0]?.id, HR_EMPLOYEE_SCHOOL_A);
});

Deno.test("getEmployee returns employee payload", async () => {
  const db = new MockHrDb() as unknown as TenantQueryClient;
  const employee = await getEmployee(db, ORG, SCHOOL_A, HR_EMPLOYEE_SCHOOL_A);
  assertEquals(employee.name, "Priya Sharma");
});

Deno.test("getEmployee throws when employee missing", async () => {
  const db = new MockHrDb() as unknown as TenantQueryClient;
  await assertRejects(
    () => getEmployee(db, ORG, SCHOOL_A, "missing"),
    HrEmployeeNotFoundError,
  );
});

Deno.test("employeeDetailToApi wraps employee detail envelope", () => {
  const employee = {
    id: HR_EMPLOYEE_SCHOOL_A,
    name: "Priya Sharma",
    department: "academics",
    role: "teacher",
    teacherAppLinked: true,
  };
  const detail = employeeDetailToApi(employee);
  assertEquals(detail.employee, employee);
  assertEquals(Array.isArray(detail.leaveBalances), true);
  assertEquals(Array.isArray(detail.documents), true);
  assertEquals(Array.isArray(detail.recentAttendance), true);
  assertEquals(Array.isArray(detail.integrationNotes), true);
});

Deno.test("employeeDetailToApi no longer injects fabricated shared constants", () => {
  const detail = employeeDetailToApi({
    id: "emp-x",
    name: "Some Person",
    role: "staff",
    department: "administration",
  });
  // The old hardcoded values must be gone.
  assertEquals(detail.address, "Not on record");
  assertEquals(detail.emergencyContact, "Not on record");
  assertEquals(detail.reportingManager, "Not on record");
  // Documents are never fabricated; empty when no real source.
  assertEquals(detail.documents, []);
  // No attendance context => no attendance.
  assertEquals(detail.recentAttendance, []);
});

Deno.test("employeeDetailToApi derives distinct values per employee", () => {
  const a = employeeDetailToApi({
    id: "emp-a",
    name: "Aarti Verma",
    role: "teacher",
    department: "academics",
    reportingManager: "Sunil Rao (Principal)",
    address: "Banjara Hills, Hyderabad",
    emergencyContact: "+91 90000 11111",
    documents: [{ id: "d1", title: "Aarti offer", status: "Verified" }],
  });
  const b = employeeDetailToApi({
    id: "emp-b",
    name: "Karthik Menon",
    role: "principal",
    department: "administration",
    reportingManager: "Board of Trustees",
    address: "Gachibowli, Hyderabad",
    emergencyContact: "+91 90000 22222",
  });

  assertEquals(a.reportingManager, "Sunil Rao (Principal)");
  assertEquals(b.reportingManager, "Board of Trustees");
  assertEquals(a.address !== b.address, true);
  assertEquals(a.emergencyContact !== b.emergencyContact, true);
  // Per-employee documents differ (one has a doc, one has none).
  assertEquals((a.documents as unknown[]).length, 1);
  assertEquals((b.documents as unknown[]).length, 0);
});

Deno.test("leaveBalances are per-employee from approved leave, not a shared claim", () => {
  const leaveRequests = [
    { employeeId: "emp-a", leaveType: "casual", days: 3, status: "approved" },
    { employeeId: "emp-a", leaveType: "casual", days: 2, status: "pending" }, // ignored
    { employeeId: "emp-b", leaveType: "sick", days: 4, status: "approved" },
  ];
  const a = employeeDetailToApi({ id: "emp-a", name: "A" }, { leaveRequests });
  const b = employeeDetailToApi({ id: "emp-b", name: "B" }, { leaveRequests });

  const aCasual = (a.leaveBalances as Array<Record<string, unknown>>).find(
    (x) => x.leaveType === "casual",
  );
  const bCasual = (b.leaveBalances as Array<Record<string, unknown>>).find(
    (x) => x.leaveType === "casual",
  );
  const bSick = (b.leaveBalances as Array<Record<string, unknown>>).find(
    (x) => x.leaveType === "sick",
  );

  // emp-a used 3 approved casual days (pending not counted) -> available 9 of 12.
  assertEquals(aCasual?.used, 3);
  assertEquals(aCasual?.available, 9);
  // emp-b has no approved casual -> full entitlement, different from emp-a.
  assertEquals(bCasual?.used, 0);
  assertEquals(bCasual?.used !== aCasual?.used, true);
  // emp-b used 4 sick days.
  assertEquals(bSick?.used, 4);
});

Deno.test("recentAttendance is filtered to the requested employee", () => {
  const attendanceRecords = [
    { id: "att_1", employeeId: "emp-a", date: "2026-06-06", status: "present" },
    { id: "att_2", employeeId: "emp-b", date: "2026-06-06", status: "present" },
  ];
  const a = employeeDetailToApi({ id: "emp-a", name: "A" }, { attendanceRecords });
  const b = employeeDetailToApi({ id: "emp-b", name: "B" }, { attendanceRecords });

  assertEquals((a.recentAttendance as Array<Record<string, unknown>>).length, 1);
  assertEquals((a.recentAttendance as Array<Record<string, unknown>>)[0].employeeId, "emp-a");
  assertEquals((b.recentAttendance as Array<Record<string, unknown>>)[0].employeeId, "emp-b");
});

Deno.test("leaveBalances honour a configured org leave policy", () => {
  const detail = employeeDetailToApi(
    { id: "emp-a", name: "A" },
    { leavePolicy: [{ leaveType: "casual", entitlement: 20 }] },
  );
  const balances = detail.leaveBalances as Array<Record<string, unknown>>;
  assertEquals(balances.length, 1);
  assertEquals(balances[0].available, 20);
  assertEquals(balances[0].used, 0);
});

Deno.test("org scope denied for HR read", () => {
  const denied = requirePermission(orgClaims(), "viewHr") ??
    requireSchoolOperationalScope(orgClaims());
  assertEquals(denied?.status, 403);
});

Deno.test("viewHr required for HR read", () => {
  const claims = { ...schoolClaims(), permissions: [] as string[] };
  const denied = requirePermission(claims, "viewHr") ??
    requireSchoolOperationalScope(claims);
  assertEquals(denied?.status, 403);
});
