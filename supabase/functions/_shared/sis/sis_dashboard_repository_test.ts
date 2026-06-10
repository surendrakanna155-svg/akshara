import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  computeDistributionPercentages,
  getDashboard,
} from "./sis_dashboard_repository.ts";
import { dashboardToApi } from "./sis_mapper.ts";

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
    permissions: ["viewSis"],
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
    permissions: ["viewSis"],
  };
}

class MockSisDashboardDb {
  students = [
    {
      id: "stu-1",
      display_name: "Arjun Patel",
      status: "active",
      created_at: "2026-06-10T10:00:00.000Z",
    },
    {
      id: "stu-2",
      display_name: "Emma Thomas",
      status: "inactive",
      created_at: "2026-06-09T10:00:00.000Z",
    },
    {
      id: "stu-3",
      display_name: "Alumni Student",
      status: "alumni",
      created_at: "2026-05-01T10:00:00.000Z",
    },
  ];
  profiles = [
    { student_id: "stu-1", admission_number: "ADM-001", gender: "male" },
    { student_id: "stu-2", admission_number: "ADM-002", gender: "female" },
    { student_id: "stu-3", admission_number: "ADM-003", gender: "female" },
  ];
  enrollments = [
    {
      id: "enr-1",
      student_id: "stu-1",
      class_name: "10",
      section_name: "A",
      is_current: true,
      created_at: "2026-06-10T10:00:00.000Z",
    },
    {
      id: "enr-2",
      student_id: "stu-2",
      class_name: "7",
      section_name: "B",
      is_current: true,
      created_at: "2026-06-09T10:00:00.000Z",
    },
  ];
  admissions = [
    {
      id: "adm-1",
      student_name: "Pending Student",
      seeking_class: "5",
      section: "A",
      admission_number: "ADM-010",
      conversion_status: "pending",
      converted_at: null,
      submitted_at: "2026-06-08T10:00:00.000Z",
    },
    {
      id: "adm-2",
      student_name: "Converted Student",
      seeking_class: "8",
      section: "C",
      admission_number: "ADM-011",
      conversion_status: "converted",
      converted_at: "2026-06-07T10:00:00.000Z",
      submitted_at: "2026-06-01T10:00:00.000Z",
    },
  ];

  async queryObject<T>(sql: string, _args: unknown[] = []): Promise<T[]> {
    if (sql.includes("total_students") && sql.includes("pending_conversions")) {
      const active = this.students.filter((s) => s.status === "active").length;
      const inactive = this.students.filter((s) => s.status === "inactive").length;
      const alumni = this.students.filter((s) => s.status === "alumni").length;
      const transferred = this.students.filter((s) => s.status === "transferred").length;
      const currentEnrollments = this.enrollments.filter((e) => e.is_current).length;
      const pending = this.admissions.filter((a) =>
        a.conversion_status === "pending" && a.converted_at == null
      ).length;
      const recentAdmissions = this.admissions.length;
      const recentConversions = this.admissions.filter((a) => a.converted_at != null).length;
      const classes = new Set(
        this.enrollments.filter((e) => e.is_current).map((e) => e.class_name),
      ).size;
      const sections = new Set(
        this.enrollments.filter((e) => e.is_current).map((e) => e.section_name),
      ).size;
      return [{
        total_students: String(this.students.length),
        active_students: String(active),
        inactive_students: String(inactive),
        graduated_students: String(alumni),
        transferred_students: String(transferred),
        current_enrollments: String(currentEnrollments),
        recent_admissions: String(recentAdmissions),
        recent_conversions: String(recentConversions),
        pending_conversions: String(pending),
        distinct_classes: String(classes),
        distinct_sections: String(sections),
      }] as T[];
    }

    if (sql.includes("GROUP BY e.class_name")) {
      const counts = new Map<string, number>();
      for (const row of this.enrollments.filter((e) => e.is_current)) {
        counts.set(row.class_name, (counts.get(row.class_name) ?? 0) + 1);
      }
      return [...counts.entries()].map(([class_name, count]) => ({
        class_name,
        count: String(count),
      })) as T[];
    }

    if (sql.includes("GROUP BY section_label")) {
      return [
        { section_label: "A", count: "1" },
        { section_label: "B", count: "1" },
      ] as T[];
    }

    if (sql.includes("GROUP BY gender_label")) {
      return [
        { gender_label: "Male", count: "1" },
        { gender_label: "Female", count: "2" },
      ] as T[];
    }

    if (sql.includes("ORDER BY s.created_at DESC") && sql.includes("LIMIT 10")) {
      return this.students.map((student) => {
        const profile = this.profiles.find((p) => p.student_id === student.id);
        const enrollment = this.enrollments.find((e) => e.student_id === student.id);
        return {
          id: student.id,
          student_name: student.display_name,
          admission_number: profile?.admission_number ?? "",
          class_name: enrollment?.class_name ?? "",
          section_name: enrollment?.section_name ?? "",
          created_at: student.created_at,
          status: student.status,
        };
      }) as T[];
    }

    if (sql.includes("FROM sis_student_enrollments e") && sql.includes("ORDER BY e.created_at DESC")) {
      return this.enrollments.map((enrollment) => {
        const student = this.students.find((s) => s.id === enrollment.student_id)!;
        const profile = this.profiles.find((p) => p.student_id === enrollment.student_id);
        return {
          id: enrollment.id,
          student_id: enrollment.student_id,
          student_name: student.display_name,
          admission_number: profile?.admission_number ?? "",
          class_name: enrollment.class_name,
          section_name: enrollment.section_name,
          enrolled_at: enrollment.created_at,
          status: student.status,
        };
      }) as T[];
    }

    if (sql.includes("FROM admissions_enrollments ae") && sql.includes("converted_at IS NOT NULL")) {
      return this.admissions
        .filter((row) => row.converted_at != null)
        .map((row) => ({
          id: row.id,
          student_name: row.student_name,
          admission_number: row.admission_number,
          class_name: row.seeking_class,
          section_name: row.section,
          converted_at: row.converted_at,
        })) as T[];
    }

    return [] as T[];
  }
}

Deno.test("computeDistributionPercentages rounds percent totals", () => {
  const rows = computeDistributionPercentages([
    { label: "A", count: 1 },
    { label: "B", count: 1 },
  ]);
  assertEquals(rows, [
    { label: "A", count: 1, percent: 50 },
    { label: "B", count: 1, percent: 50 },
  ]);
});

Deno.test("getDashboard aggregates KPIs", async () => {
  const db = new MockSisDashboardDb() as unknown as TenantQueryClient;
  const dashboard = await getDashboard(db, ORG, SCHOOL_A);
  assertEquals(dashboard.totalStudents, 3);
  assertEquals(dashboard.activeStudents, 1);
  assertEquals(dashboard.inactiveStudents, 1);
  assertEquals(dashboard.graduatedStudents, 1);
  assertEquals(dashboard.currentEnrollments, 2);
  assertEquals(dashboard.pendingConversions, 1);
  assertEquals(dashboard.classDistribution.length, 2);
  assertEquals(dashboard.recentStudents.length, 3);
  assertEquals(dashboard.recentEnrollments.length, 2);
  assertEquals(dashboard.recentConversionsList.length, 1);
});

Deno.test("dashboardToApi serializes camelCase response", async () => {
  const db = new MockSisDashboardDb() as unknown as TenantQueryClient;
  const dashboard = await getDashboard(db, ORG, SCHOOL_A);
  const api = dashboardToApi(dashboard);
  assertEquals(typeof api.totalStudents, "number");
  assertEquals(Array.isArray(api.kpis), true);
  assertEquals(Array.isArray(api.classDistribution), true);
  assertEquals(Array.isArray(api.sectionDistribution), true);
  assertEquals(Array.isArray(api.genderDistribution), true);
  assertEquals(Array.isArray(api.recentStudents), true);
  assertEquals(Array.isArray(api.recentEnrollments), true);
  assertEquals(Array.isArray(api.recentConversionItems), true);
  assertEquals(typeof api.aiInsight, "string");
});

Deno.test("org scope denied for SIS dashboard read", () => {
  const denied = requirePermission(orgClaims(), "viewSis") ??
    requireSchoolOperationalScope(orgClaims());
  assertEquals(denied?.status, 403);
});

Deno.test("viewSis required for SIS dashboard read", () => {
  const claims = { ...schoolClaims(), permissions: [] as string[] };
  const denied = requirePermission(claims, "viewSis") ??
    requireSchoolOperationalScope(claims);
  assertEquals(denied?.status, 403);
});
