import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  buildDashboardKpis,
  buildDeterministicInsight,
  composeDashboard,
  computeDashboardFacts,
  type DashboardInputs,
  employeeDetailToApi,
  getEmployee,
  getSnapshot,
  HR_EMPLOYEE_SCHOOL_A,
  HrEmployeeNotFoundError,
  HrSnapshotNotFoundError,
  listEntities,
} from "./hr_read_repository.ts";
import { generateHrInsightWithClaude } from "./hr_dashboard_ai.ts";

/** Empty live HR state — a brand-new school with nothing on record. */
function emptyInputs(): DashboardInputs {
  return { employees: [], openings: [], attendance: {}, leave: {}, recruitment: {} };
}

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

// --- Dashboard is now COMPUTED live (MJ-H17 / HR-5) — no static 148 / no fake
// attrition insight. KPIs reflect real rows; AI insight falls back deterministically.

Deno.test("computeDashboardFacts: empty live state => all zeros (honest fresh school)", () => {
  const facts = computeDashboardFacts(emptyInputs());
  assertEquals(facts.totalEmployees, 0);
  assertEquals(facts.activeEmployees, 0);
  assertEquals(facts.presentToday, 0);
  assertEquals(facts.onLeaveToday, 0);
  assertEquals(facts.openPositions, 0);
  assertEquals(facts.pendingLeaveCount, 0);
  assertEquals(facts.topDepartment, "");
});

Deno.test("buildDashboardKpis on empty state never reports the old hardcoded 148", () => {
  const kpis = buildDashboardKpis(computeDashboardFacts(emptyInputs()));
  const total = kpis.find((k) => k.id === "total_employees");
  assertEquals(total?.value, "0");
  // Field names/labels preserved for the Flutter mapper.
  assertEquals(total?.label, "Total Employees");
  assertEquals(total?.accentName, "primary");
  assertEquals(kpis.map((k) => k.id), [
    "total_employees",
    "present_today",
    "on_leave",
    "open_positions",
  ]);
});

Deno.test("computeDashboardFacts: seeded live rows => real computed counts", () => {
  const today = new Date("2026-06-26T10:00:00Z");
  const inputs: DashboardInputs = {
    employees: [
      { id: "e1", name: "A", department: "academics", status: "active" },
      { id: "e2", name: "B", department: "academics", status: "active" },
      { id: "e3", name: "C", department: "administration", status: "inactive" },
    ],
    openings: [
      { id: "o1", status: "open", openings: 2 },
      { id: "o2", status: "closed", openings: 5 },
    ],
    attendance: {
      records: [
        { employeeId: "e1", date: "2026-06-26", status: "present" },
        { employeeId: "e2", date: "2026-06-26", status: "absent" },
        { employeeId: "e1", date: "2026-06-25", status: "present" }, // not today
      ],
    },
    leave: {
      requests: [
        {
          id: "lv1",
          employeeName: "B",
          leaveType: "sick",
          days: 2,
          status: "approved",
          fromDate: "2026-06-25",
          toDate: "2026-06-27",
        },
        {
          id: "lv2",
          employeeName: "A",
          leaveType: "casual",
          days: 1,
          status: "pending",
          fromDate: "2026-06-26",
          toDate: "2026-06-26",
        },
      ],
    },
    recruitment: { candidates: [] },
  };
  const facts = computeDashboardFacts(inputs, today);
  assertEquals(facts.totalEmployees, 3);
  assertEquals(facts.activeEmployees, 2);
  assertEquals(facts.presentToday, 1); // only e1 present today
  assertEquals(facts.onLeaveToday, 1); // lv1 spans today, approved
  assertEquals(facts.openPositions, 2); // only the open requisition's seats
  assertEquals(facts.pendingLeaveCount, 1);
  assertEquals(facts.topDepartment, "academics");
  assertEquals(facts.topDepartmentCount, 2);
});

Deno.test("composeDashboard: lists derive from real rows; trends honest", () => {
  const inputs: DashboardInputs = {
    employees: [{ id: "e1", name: "A", department: "academics", status: "active" }],
    openings: [],
    attendance: { attendanceTrend: [{ label: "Mon", amountLakhs: 95, targetLakhs: 95 }] },
    leave: {
      requests: [
        {
          id: "lv2",
          employeeName: "A",
          leaveType: "casual",
          days: 1,
          status: "pending",
          fromDate: "2026-06-26",
        },
      ],
    },
    recruitment: {
      candidates: [
        {
          id: "cand_1",
          name: "Deepa",
          role: "Physics Teacher",
          department: "academics",
          appliedOn: "2026-05-28",
          stage: "interview",
          experience: "6 years",
          source: "Referral",
        },
      ],
    },
  };
  const facts = computeDashboardFacts(inputs, new Date("2026-06-26T10:00:00Z"));
  const dash = composeDashboard(inputs, facts, "INSIGHT");
  assertEquals(dash.aiInsight, "INSIGHT");
  // No real headcount history => honest empty series, not a fabricated curve.
  assertEquals(dash.headcountTrend, []);
  // Real attendance trend passes through.
  assertEquals(Array.isArray(dash.attendanceTrend), true);
  assertEquals((dash.attendanceTrend as unknown[]).length, 1);
  // Pending leave reflects the real pending request, field names preserved.
  const pending = dash.pendingLeave as Array<Record<string, unknown>>;
  assertEquals(pending.length, 1);
  assertEquals(pending[0].id, "lv2");
  assertEquals(pending[0].employeeName, "A");
  assertEquals(pending[0].submittedOn, "2026-06-26"); // falls back to fromDate
  // Recruitment snapshot reflects the real candidate with all DTO fields.
  const recruit = dash.recruitmentSnapshot as Array<Record<string, unknown>>;
  assertEquals(recruit.length, 1);
  assertEquals(recruit[0].name, "Deepa");
  assertEquals(recruit[0].stage, "interview");
});

Deno.test("buildDeterministicInsight: never the fake attrition string; grounded in facts", () => {
  const facts = computeDashboardFacts({
    employees: [
      { id: "e1", department: "academics", status: "active" },
      { id: "e2", department: "academics", status: "active" },
      { id: "e3", department: "academics", status: "active" },
    ],
    openings: [{ id: "o1", status: "open", openings: 1 }],
    attendance: {},
    leave: {},
    recruitment: {},
  });
  const insight = buildDeterministicInsight(facts);
  assertEquals(insight.includes("attrition"), false);
  assertEquals(insight.includes("148"), false);
  assertEquals(insight.includes("3 employees"), true);
  assertEquals(insight.includes("1 open position"), true);
});

Deno.test("buildDeterministicInsight: empty school yields an honest no-staff message", () => {
  const insight = buildDeterministicInsight(computeDashboardFacts(emptyInputs()));
  assertEquals(insight.toLowerCase().includes("no staff"), true);
});

Deno.test("generateHrInsightWithClaude: no key => deterministic fallback, never throws", async () => {
  const facts = computeDashboardFacts(emptyInputs());
  const deterministic = buildDeterministicInsight(facts);
  // No apiKey passed => must return the deterministic insight unchanged.
  const insight = await generateHrInsightWithClaude(facts, deterministic, undefined);
  assertEquals(insight, deterministic);
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
