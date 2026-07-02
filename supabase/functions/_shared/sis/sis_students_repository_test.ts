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
  studentTransferItemToApi,
} from "./sis_mapper.ts";
import {
  getStudent,
  listStudents,
  listStudentTransfers,
  searchStudents,
} from "./sis_students_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const SCHOOL_B = "a2000000-0000-4000-8000-000000000002";
const STUDENT_A = "a4000000-0000-4000-8000-000000000001";
const STUDENT_B = "a4000000-0000-4000-8000-000000000002";
const STUDENT_TRANSFERRED = "a4000000-0000-4000-8000-000000000004";
const STUDENT_ALUMNI = "a4000000-0000-4000-8000-000000000005";
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
    {
      id: STUDENT_TRANSFERRED,
      organization_id: ORG,
      school_id: SCHOOL_A,
      student_code: "STU-004",
      display_name: "Exited Student",
      status: "transferred",
      created_at: "2025-06-01T00:00:00.000Z",
      updated_at: "2026-05-15T00:00:00.000Z",
    },
    {
      id: STUDENT_ALUMNI,
      organization_id: ORG,
      school_id: SCHOOL_A,
      student_code: "STU-005",
      display_name: "Graduated Student",
      status: "alumni",
      created_at: "2024-06-01T00:00:00.000Z",
      updated_at: "2026-06-20T00:00:00.000Z",
    },
    {
      id: "student-transferred-school-b",
      organization_id: ORG,
      school_id: SCHOOL_B,
      student_code: "STU-006",
      display_name: "Other School Exit",
      status: "transferred",
      created_at: "2025-06-01T00:00:00.000Z",
      updated_at: "2026-05-15T00:00:00.000Z",
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
    {
      id: "profile-transferred",
      student_id: STUDENT_TRANSFERRED,
      organization_id: ORG,
      school_id: SCHOOL_A,
      admission_number: "ADM-2025-EXIT001",
      created_at: "2025-06-01T00:00:00.000Z",
      updated_at: "2026-05-15T00:00:00.000Z",
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
    {
      id: "enrollment-transferred",
      student_id: STUDENT_TRANSFERRED,
      organization_id: ORG,
      school_id: SCHOOL_A,
      academic_year: "2025-26",
      class_name: "4",
      section_name: "B",
      roll_number: "7",
      // is_current is false — exercises SIS-5 LATERAL last-enrollment fallback.
      is_current: false,
      created_at: "2025-06-01T00:00:00.000Z",
      updated_at: "2025-06-01T00:00:00.000Z",
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
    if (sql.includes("status = ANY($3::text[])")) {
      return this.filterTransfers(args).length;
    }
    return this.filterDirectory(sql, args).length;
  }

  // SIS-5 transfer/exit log mock. args: [org, school, statuses[], statusFilter,
  // fromDate, toDate, (limit, offset)].
  filterTransfers(args: unknown[]): Row[] {
    const orgId = args[0];
    const schoolId = args[1];
    const statuses = (args[2] as string[]) ?? [];
    const statusFilter = args[3] as string | null;
    const fromDate = args[4] as string | null;
    const toDate = args[5] as string | null;

    return this.students
      .filter((student) =>
        student.organization_id === orgId &&
        student.school_id === schoolId &&
        statuses.includes(student.status as string) &&
        (!statusFilter || student.status === statusFilter) &&
        (!fromDate || String(student.updated_at) >= fromDate) &&
        (!toDate ||
          String(student.updated_at) <
            new Date(new Date(toDate as string).getTime() + 86400000).toISOString())
      )
      .map((student) => {
        const profile = this.profiles.find((p) => p.student_id === student.id);
        // Last enrollment (highest created_at) regardless of is_current.
        const enrollment = this.enrollments
          .filter((e) => e.student_id === student.id)
          .sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)))[0];
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
          transitioned_at: student.updated_at,
          created_at: student.created_at,
        };
      })
      .sort((a, b) => String(b.transitioned_at).localeCompare(String(a.transitioned_at)));
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
        const activeGuardians = this.guardians.filter((g) =>
          g.student_id === student.id && g.status === "active"
        );
        const primaryGuardian = activeGuardians.find((g) => g.is_primary === true);
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
          guardian_name: primaryGuardian?.display_name ?? null,
          guardian_phone: primaryGuardian?.phone ?? null,
          guardian_count: String(activeGuardians.length),
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
    if (sql.includes("status = ANY($3::text[])") && sql.includes("transitioned_at")) {
      const rows = this.filterTransfers(args);
      const limit = Number(args[6]);
      const offset = Number(args[7]);
      return rows.slice(offset, offset + limit) as T[];
    }
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

  // SCHOOL_A: active + inactive + transferred + alumni = 4 (SCHOOL_B excluded).
  assertEquals(result.total, 4);
  assertEquals(result.items.length, 4);
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
    guardian_name: "Staging Parent",
    guardian_phone: "+919876543211",
    guardian_count: "1",
    created_at: "2026-06-01T00:00:00.000Z",
    updated_at: "2026-06-07T00:00:00.000Z",
  });

  assertEquals(api.studentId, STUDENT_A);
  assertEquals(api.guardianCount, 1);
  assertEquals(api.className, "5");
  // SIS-2: primary guardian contact surfaced.
  assertEquals(api.guardianName, "Staging Parent");
  assertEquals(api.guardianPhone, "+919876543211");
});

// SIS-2 — the directory list surfaces the primary guardian's name + phone; a
// student with no guardian still lists with blank contact fields.
Deno.test("SIS-2 listStudents surfaces primary guardian name + phone", async () => {
  const db = new MockSisStudentsDb() as unknown as TenantQueryClient;
  const result = await listStudents(db, ORG, SCHOOL_A, { status: "active" }, {
    page: 1,
    pageSize: 20,
  });
  const withGuardian = result.items.find((r) => r.student_id === STUDENT_A);
  const api = studentDirectoryItemToApi(withGuardian!);
  assertEquals(api.guardianName, "Staging Parent");
  assertEquals(api.guardianPhone, "+919876543211");
});

Deno.test("SIS-2 student with no guardian lists with blank contact", async () => {
  const db = new MockSisStudentsDb() as unknown as TenantQueryClient;
  const result = await listStudents(db, ORG, SCHOOL_A, { status: "inactive" }, {
    page: 1,
    pageSize: 20,
  });
  assertEquals(result.total, 1);
  const api = studentDirectoryItemToApi(result.items[0]!);
  assertEquals(api.guardianName, "");
  assertEquals(api.guardianPhone, "");
});

// SIS-5 — transfer / exit log.
Deno.test("SIS-5 listStudentTransfers returns transferred + alumni in scope", async () => {
  const db = new MockSisStudentsDb() as unknown as TenantQueryClient;
  const result = await listStudentTransfers(db, ORG, SCHOOL_A, {}, {
    page: 1,
    pageSize: 20,
  });
  // SCHOOL_A: transferred + alumni = 2 (SCHOOL_B transferred excluded).
  assertEquals(result.total, 2);
  const ids = result.items.map((r) => r.student_id);
  assertEquals(ids.includes(STUDENT_TRANSFERRED), true);
  assertEquals(ids.includes(STUDENT_ALUMNI), true);
  assertEquals(ids.includes("student-transferred-school-b"), false);
  // Ordered by exit timestamp DESC — alumni (2026-06-20) before transferred (2026-05-15).
  assertEquals(result.items[0]?.student_id, STUDENT_ALUMNI);
});

Deno.test("SIS-5 transfers surface last enrollment context even if not current", async () => {
  const db = new MockSisStudentsDb() as unknown as TenantQueryClient;
  const result = await listStudentTransfers(db, ORG, SCHOOL_A, {
    status: "transferred",
  }, { page: 1, pageSize: 20 });
  assertEquals(result.total, 1);
  const row = result.items[0]!;
  const api = studentTransferItemToApi(row);
  assertEquals(api.studentId, STUDENT_TRANSFERRED);
  assertEquals(api.status, "transferred");
  assertEquals(api.className, "4");
  assertEquals(api.sectionName, "B");
  assertEquals(api.admissionNumber, "ADM-2025-EXIT001");
  assertEquals(api.transitionedAt, "2026-05-15T00:00:00.000Z");
});

Deno.test("SIS-5 transfers honour date range on exit timestamp", async () => {
  const db = new MockSisStudentsDb() as unknown as TenantQueryClient;
  // Window that includes the alumni (2026-06-20) but excludes transferred (2026-05-15).
  const result = await listStudentTransfers(db, ORG, SCHOOL_A, {
    fromDate: "2026-06-01",
    toDate: "2026-06-30",
  }, { page: 1, pageSize: 20 });
  assertEquals(result.total, 1);
  assertEquals(result.items[0]?.student_id, STUDENT_ALUMNI);
});

Deno.test("SIS-5 transfers graduated status filter maps to alumni via handler", async () => {
  const db = new MockSisStudentsDb() as unknown as TenantQueryClient;
  // The handler maps graduated→alumni; repository receives the DB status.
  const result = await listStudentTransfers(db, ORG, SCHOOL_A, {
    status: "alumni",
  }, { page: 1, pageSize: 20 });
  assertEquals(result.total, 1);
  assertEquals(result.items[0]?.student_id, STUDENT_ALUMNI);
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
