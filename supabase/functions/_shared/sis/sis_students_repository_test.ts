import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  studentDetailToApi,
  studentDirectoryItemToApi,
} from "./sis_mapper.ts";
import {
  getStudent,
  listStudents,
  searchStudents,
} from "./sis_students_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const SCHOOL_B = "a2000000-0000-4000-8000-000000000002";
const STUDENT_A = "a4000000-0000-4000-8000-000000000001";
const STUDENT_B = "a4000000-0000-4000-8000-000000000002";
const PROFILE_A = "bc000000-0000-4000-8000-000000000001";
const ENROLLMENT_A = "bc100000-0000-4000-8000-000000000001";
const GUARDIAN_USER = "a3000000-0000-4000-8000-000000000003";

type Row = Record<string, unknown>;

class MockSisStudentsDb {
  students: Row[] = [
    {
      id: STUDENT_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      student_code: "STU-001",
      display_name: "Staging Student",
      status: "active",
      created_at: "2026-06-01T00:00:00.000Z",
      updated_at: "2026-06-07T00:00:00.000Z",
    },
    {
      id: STUDENT_B,
      organization_id: ORG,
      school_id: SCHOOL_B,
      student_code: "STU-002",
      display_name: "School B Student",
      status: "active",
      created_at: "2026-06-01T00:00:00.000Z",
      updated_at: "2026-06-07T00:00:00.000Z",
    },
    {
      id: "student-prospect",
      organization_id: ORG,
      school_id: SCHOOL_A,
      student_code: "STU-003",
      display_name: "Prospect Student",
      status: "inactive",
      created_at: "2026-06-02T00:00:00.000Z",
      updated_at: "2026-06-02T00:00:00.000Z",
    },
  ];
  profiles: Row[] = [
    {
      id: PROFILE_A,
      student_id: STUDENT_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      admission_number: "ADM-2026-PROBE001",
      date_of_birth: "2014-05-15",
      gender: "male",
      blood_group: "O+",
      address: "12 Akshara Lane",
      city: "Hyderabad",
      state: "Telangana",
      postal_code: "500001",
      country: "India",
      created_at: "2026-06-01T00:00:00.000Z",
      updated_at: "2026-06-07T00:00:00.000Z",
    },
  ];
  enrollments: Row[] = [
    {
      id: ENROLLMENT_A,
      student_id: STUDENT_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      academic_year: "2026-27",
      class_name: "5",
      section_name: "A",
      roll_number: "12",
      is_current: true,
      created_at: "2026-06-01T00:00:00.000Z",
      updated_at: "2026-06-07T00:00:00.000Z",
    },
  ];
  guardians: Row[] = [
    {
      id: "guardian-link-1",
      student_id: STUDENT_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      guardian_user_id: GUARDIAN_USER,
      relationship: "mother",
      is_primary: true,
      status: "active",
      display_name: "Staging Parent",
      phone: "+919876543211",
      email: "staging.parent@aksharaerp.com",
    },
  ];

  async queryCount(sql: string, args: unknown[] = []): Promise<number> {
    return this.filterDirectory(sql, args).length;
  }

  filterDirectory(sql: string, args: unknown[]): Row[] {
    if (!sql.includes("FROM students s")) return [];
    const orgId = args[0];
    const schoolId = args[1];
    const status = args[2] as string | null;
    const academicYear = args[3] as string | null;
    const className = args[4] as string | null;
    const sectionName = args[5] as string | null;
    const search = args[6] as string | null;

    const rows = this.students
      .filter((student) =>
        student.organization_id === orgId && student.school_id === schoolId
      )
      .map((student) => {
        const profile = this.profiles.find((p) => p.student_id === student.id);
        const enrollment = this.enrollments.find((e) =>
          e.student_id === student.id && e.is_current === true
        );
        const guardianCount = this.guardians.filter((g) =>
          g.student_id === student.id && g.status === "active"
        ).length;
        return {
          student_id: student.id,
          student_code: student.student_code,
          display_name: student.display_name,
          status: student.status,
          admission_number: profile?.admission_number ?? null,
          academic_year: enrollment?.academic_year ?? null,
          class_name: enrollment?.class_name ?? null,
          section_name: enrollment?.section_name ?? null,
          roll_number: enrollment?.roll_number ?? null,
          guardian_count: String(guardianCount),
          created_at: student.created_at,
          updated_at: student.updated_at,
        };
      })
      .filter((row) => !status || row.status === status)
      .filter((row) => !academicYear || row.academic_year === academicYear)
      .filter((row) => !className || row.class_name === className)
      .filter((row) => !sectionName || row.section_name === sectionName)
      .filter((row) => {
        if (!search) return true;
        const term = search.toLowerCase();
        return String(row.display_name).toLowerCase().includes(term) ||
          String(row.student_code).toLowerCase().includes(term) ||
          String(row.admission_number ?? "").toLowerCase().includes(term);
      });

    return rows;
  }

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("FROM students s") && sql.includes("guardian_count")) {
      const rows = this.filterDirectory(sql, args);
      const limit = Number(args[7]);
      const offset = Number(args[8]);
      return rows.slice(offset, offset + limit) as T[];
    }
    if (sql.includes("FROM students") && sql.includes("WHERE id = $1")) {
      const student = this.students.find((row) =>
        row.id === args[0] &&
        row.organization_id === args[1] &&
        row.school_id === args[2]
      );
      return (student ? [student] : []) as T[];
    }
    if (sql.includes("FROM student_profiles")) {
      const profile = this.profiles.find((row) =>
        row.student_id === args[0] &&
        row.organization_id === args[1] &&
        row.school_id === args[2]
      );
      return (profile ? [profile] : []) as T[];
    }
    if (sql.includes("FROM sis_student_enrollments")) {
      const enrollment = this.enrollments.find((row) =>
        row.student_id === args[0] &&
        row.organization_id === args[1] &&
        row.school_id === args[2] &&
        row.is_current === true
      );
      return (enrollment ? [enrollment] : []) as T[];
    }
    if (sql.includes("FROM student_guardians sg")) {
      return this.guardians.filter((row) =>
        row.student_id === args[0] &&
        row.organization_id === args[1] &&
        row.school_id === args[2]
      ) as T[];
    }
    return [] as T[];
  }
}

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

Deno.test("listStudents returns paginated directory rows", async () => {
  const db = new MockSisStudentsDb() as unknown as TenantQueryClient;
  const result = await listStudents(db, ORG, SCHOOL_A, {}, { page: 1, pageSize: 20 });

  assertEquals(result.total, 2);
  assertEquals(result.items.length, 2);
  assertEquals(result.items[0]?.student_id, STUDENT_A);
});

Deno.test("searchStudents filters by search term", async () => {
  const db = new MockSisStudentsDb() as unknown as TenantQueryClient;
  const result = await searchStudents(
    db,
    ORG,
    SCHOOL_A,
    { search: "ADM-2026-PROBE001" },
    { page: 1, pageSize: 20 },
  );

  assertEquals(result.total, 1);
  assertEquals(result.items[0]?.student_id, STUDENT_A);
});

Deno.test("listStudents filters by class section status and academic year", async () => {
  const db = new MockSisStudentsDb() as unknown as TenantQueryClient;
  const result = await listStudents(
    db,
    ORG,
    SCHOOL_A,
    {
      academicYear: "2026-27",
      className: "5",
      sectionName: "A",
      status: "active",
    },
    { page: 1, pageSize: 20 },
  );

  assertEquals(result.total, 1);
  assertEquals(result.items[0]?.roll_number, "12");
});

Deno.test("getStudent returns profile enrollment and guardians", async () => {
  const db = new MockSisStudentsDb() as unknown as TenantQueryClient;
  const detail = await getStudent(db, ORG, SCHOOL_A, STUDENT_A);

  assertEquals(detail?.student.display_name, "Staging Student");
  assertEquals(detail?.profile?.admission_number, "ADM-2026-PROBE001");
  assertEquals(detail?.currentEnrollment?.class_name, "5");
  assertEquals(detail?.guardians.length, 1);
});

Deno.test("getStudent returns null for cross-school student", async () => {
  const db = new MockSisStudentsDb() as unknown as TenantQueryClient;
  const detail = await getStudent(db, ORG, SCHOOL_A, STUDENT_B);
  assertEquals(detail, null);
});

Deno.test("studentDirectoryItemToApi uses camelCase response fields", () => {
  const api = studentDirectoryItemToApi({
    student_id: STUDENT_A,
    student_code: "STU-001",
    display_name: "Staging Student",
    status: "active",
    admission_number: "ADM-2026-PROBE001",
    academic_year: "2026-27",
    class_name: "5",
    section_name: "A",
    roll_number: "12",
    guardian_count: "1",
    created_at: "2026-06-01T00:00:00.000Z",
    updated_at: "2026-06-07T00:00:00.000Z",
  });

  assertEquals(api.studentId, STUDENT_A);
  assertEquals(api.guardianCount, 1);
  assertEquals(api.className, "5");
});

Deno.test("studentDetailToApi nests student profile enrollment guardians", async () => {
  const db = new MockSisStudentsDb() as unknown as TenantQueryClient;
  const detail = await getStudent(db, ORG, SCHOOL_A, STUDENT_A);
  const api = studentDetailToApi(detail!);

  assertEquals((api.student as Record<string, unknown>).displayName, "Staging Student");
  assertEquals((api.profile as Record<string, unknown>).admissionNumber, "ADM-2026-PROBE001");
  assertEquals((api.currentEnrollment as Record<string, unknown>).sectionName, "A");
  assertEquals((api.guardians as unknown[]).length, 1);
});

Deno.test("org scope denied for SIS read middleware", () => {
  const denied = requirePermission(orgClaims(), "viewSis") ??
    requireSchoolOperationalScope(orgClaims());
  assertEquals(denied?.status, 403);
});

Deno.test("viewSis required for SIS read middleware", () => {
  const claims = { ...schoolClaims(), permissions: [] as string[] };
  const denied = requirePermission(claims, "viewSis") ??
    requireSchoolOperationalScope(claims);
  assertEquals(denied?.status, 403);
});
