import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { enrollmentListItemToApi } from "./sis_mapper.ts";
import {
  createEnrollment,
  DuplicateEnrollmentError,
  EnrollmentNotFoundError,
  listEnrollments,
  updateEnrollment,
  ValidationError,
} from "./sis_enrollments_repository.ts";
import { StudentNotFoundError } from "./sis_students_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const SCHOOL_B = "a2000000-0000-4000-8000-000000000002";
const STAFF = "a3000000-0000-4000-8000-000000000001";
const STUDENT_A = "a4000000-0000-4000-8000-000000000001";
const STUDENT_B = "a4000000-0000-4000-8000-000000000002";
const ENROLLMENT_A = "bc100000-0000-4000-8000-000000000001";
const ENROLLMENT_B_YEAR = "bc100000-0000-4000-8000-000000000099";

type Row = Record<string, unknown>;

class MockEnrollmentsDb {
  students: Row[] = [
    {
      id: STUDENT_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      student_code: "STU-2026-00001",
      display_name: "Staging Student",
    },
    {
      id: STUDENT_B,
      organization_id: ORG,
      school_id: SCHOOL_B,
      student_code: "STU-2026-00002",
      display_name: "School B Student",
    },
  ];
  enrollments: Row[] = [
    {
      id: ENROLLMENT_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      student_id: STUDENT_A,
      academic_year: "2026-27",
      class_name: "5",
      section_name: "A",
      roll_number: "12",
      is_current: true,
      created_by: STAFF,
      created_at: "2026-06-01T00:00:00.000Z",
      updated_at: "2026-06-07T00:00:00.000Z",
    },
    {
      id: ENROLLMENT_B_YEAR,
      organization_id: ORG,
      school_id: SCHOOL_A,
      student_id: STUDENT_A,
      academic_year: "2025-26",
      class_name: "4",
      section_name: "B",
      roll_number: "8",
      is_current: false,
      created_by: STAFF,
      created_at: "2025-06-01T00:00:00.000Z",
      updated_at: "2025-06-07T00:00:00.000Z",
    },
  ];

  filterList(args: unknown[]): Row[] {
    const orgId = args[0];
    const schoolId = args[1];
    const academicYear = args[2] as string | null;
    const className = args[3] as string | null;
    const sectionName = args[4] as string | null;
    const studentId = args[5] as string | null;
    const isCurrent = args[6] as boolean | null;

    return this.enrollments
      .filter((e) => e.organization_id === orgId && e.school_id === schoolId)
      .filter((e) => academicYear == null || e.academic_year === academicYear)
      .filter((e) => className == null || e.class_name === className)
      .filter((e) => sectionName == null || e.section_name === sectionName)
      .filter((e) => studentId == null || e.student_id === studentId)
      .filter((e) => isCurrent == null || e.is_current === isCurrent)
      .map((e) => this.toListRow(e));
  }

  toListRow(e: Row): Row {
    const student = this.students.find((s) => s.id === e.student_id)!;
    return {
      enrollment_id: e.id,
      student_id: e.student_id,
      student_code: student.student_code,
      student_name: student.display_name,
      academic_year: e.academic_year,
      class_name: e.class_name,
      section_name: e.section_name,
      roll_number: e.roll_number,
      is_current: e.is_current,
      created_at: e.created_at,
      updated_at: e.updated_at,
    };
  }

  async queryCount(sql: string, args: unknown[] = []): Promise<number> {
    if (sql.includes("sis_student_enrollments se")) {
      return this.filterList(args).length;
    }
    return 0;
  }

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("SELECT id FROM students") && sql.includes("WHERE id = $1")) {
      const match = this.students.find((s) =>
        s.id === args[0] && s.organization_id === args[1] && s.school_id === args[2]
      );
      return match ? [{ id: match.id }] as T[] : [];
    }
    if (sql.includes("FROM sis_student_enrollments") && sql.includes("academic_year = $4")) {
      const match = this.enrollments.find((e) =>
        e.organization_id === args[0] &&
        e.school_id === args[1] &&
        e.student_id === args[2] &&
        e.academic_year === args[3] &&
        (args[4] == null || e.id !== args[4])
      );
      return match ? [{ id: match.id }] as T[] : [];
    }
    if (sql.includes("UPDATE sis_student_enrollments SET") && sql.includes("is_current = false")) {
      const orgId = args[0];
      const schoolId = args[1];
      const studentId = args[2];
      const exceptId = args[3] as string | null;
      for (const e of this.enrollments) {
        if (
          e.organization_id === orgId &&
          e.school_id === schoolId &&
          e.student_id === studentId &&
          e.is_current === true &&
          (exceptId == null || e.id !== exceptId)
        ) {
          e.is_current = false;
          e.updated_at = "2026-06-09T00:00:00.000Z";
        }
      }
      return [] as T[];
    }
    if (sql.includes("INSERT INTO sis_student_enrollments")) {
      const row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        school_id: args[1],
        student_id: args[2],
        academic_year: args[3],
        class_name: args[4],
        section_name: args[5],
        roll_number: args[6],
        is_current: args[7],
        created_by: args[8],
        created_at: "2026-06-09T00:00:00.000Z",
        updated_at: "2026-06-09T00:00:00.000Z",
      };
      this.enrollments.push(row);
      return [{ id: row.id }] as T[];
    }
    if (sql.includes("SELECT * FROM sis_student_enrollments") && sql.includes("WHERE id = $1")) {
      const match = this.enrollments.find((e) =>
        e.id === args[0] && e.organization_id === args[1] && e.school_id === args[2]
      );
      return match ? [match] as T[] : [];
    }
    if (sql.includes("UPDATE sis_student_enrollments SET") && sql.includes("academic_year = $1")) {
      const enrollment = this.enrollments.find((e) =>
        e.id === args[5] && e.organization_id === args[6] && e.school_id === args[7]
      );
      if (enrollment) {
        enrollment.academic_year = args[0];
        enrollment.class_name = args[1];
        enrollment.section_name = args[2];
        enrollment.roll_number = args[3];
        enrollment.is_current = args[4];
        enrollment.updated_at = "2026-06-09T00:00:00.000Z";
      }
      return [] as T[];
    }
    if (sql.includes("sis_student_enrollments se") && sql.includes("WHERE se.id = $1")) {
      const match = this.enrollments.find((e) =>
        e.id === args[0] && e.organization_id === args[1] && e.school_id === args[2]
      );
      return match ? [this.toListRow(match)] as T[] : [];
    }
    if (sql.includes("sis_student_enrollments se") && sql.includes("LIMIT $8")) {
      const limit = args[7] as number;
      const offset = args[8] as number;
      const rows = this.filterList(args.slice(0, 7));
      rows.sort((a, b) => {
        if (a.is_current !== b.is_current) {
          return (b.is_current as boolean) ? 1 : -1;
        }
        return String(b.created_at).localeCompare(String(a.created_at));
      });
      return rows.slice(offset, offset + limit) as T[];
    }
    return [] as T[];
  }
}

function schoolClaims(permissions: string[] = ["viewSis", "manageSis"]): AccessTokenClaims {
  return {
    sub: STAFF,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL_A,
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions,
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
    ...schoolClaims(["viewSis", "manageSis"]),
    school_id: null,
    scope: "organization",
    role: "organizationAdmin",
    role_slugs: ["organizationAdmin"],
    primary_role: "organizationAdmin",
  };
}

Deno.test("listEnrollments returns paginated rows with student join fields", async () => {
  const db = new MockEnrollmentsDb() as unknown as TenantQueryClient;
  const result = await listEnrollments(db, ORG, SCHOOL_A, {}, { page: 1, pageSize: 20 });
  assertEquals(result.total, 2);
  assertEquals(result.items.length, 2);
  assertEquals(result.items[0]!.student_code, "STU-2026-00001");
  assertEquals(result.items[0]!.student_name, "Staging Student");
});

Deno.test("listEnrollments filters by academicYear className sectionName studentId isCurrent", async () => {
  const db = new MockEnrollmentsDb() as unknown as TenantQueryClient;
  const byYear = await listEnrollments(db, ORG, SCHOOL_A, { academicYear: "2025-26" }, {
    page: 1,
    pageSize: 20,
  });
  assertEquals(byYear.total, 1);
  assertEquals(byYear.items[0]!.class_name, "4");

  const byCurrent = await listEnrollments(db, ORG, SCHOOL_A, { isCurrent: true }, {
    page: 1,
    pageSize: 20,
  });
  assertEquals(byCurrent.total, 1);
  assertEquals(byCurrent.items[0]!.enrollment_id, ENROLLMENT_A);

  const byStudent = await listEnrollments(db, ORG, SCHOOL_A, { studentId: STUDENT_A }, {
    page: 1,
    pageSize: 1,
  });
  assertEquals(byStudent.total, 2);
  assertEquals(byStudent.pageSize, 1);
  assertEquals(byStudent.hasMore, true);
});

Deno.test("listEnrollments enforces school isolation", async () => {
  const db = new MockEnrollmentsDb() as unknown as TenantQueryClient;
  const result = await listEnrollments(db, ORG, SCHOOL_B, {}, { page: 1, pageSize: 20 });
  assertEquals(result.total, 0);
});

Deno.test("createEnrollment assigns enrollment to existing student", async () => {
  const db = new MockEnrollmentsDb() as unknown as TenantQueryClient;
  const row = await createEnrollment(db, ORG, SCHOOL_A, {
    studentId: STUDENT_A,
    academicYear: "2027-28",
    className: "6",
    sectionName: "C",
    rollNumber: "3",
    isCurrent: false,
    createdBy: STAFF,
  });
  assertEquals(row.academic_year, "2027-28");
  assertEquals(row.class_name, "6");
  assertEquals(row.is_current, false);
});

Deno.test("createEnrollment rejects missing student", async () => {
  const db = new MockEnrollmentsDb() as unknown as TenantQueryClient;
  await assertRejects(
    () =>
      createEnrollment(db, ORG, SCHOOL_A, {
        studentId: "missing-student",
        academicYear: "2027-28",
        className: "6",
        createdBy: STAFF,
      }),
    StudentNotFoundError,
  );
});

Deno.test("createEnrollment rejects duplicate academic year", async () => {
  const db = new MockEnrollmentsDb() as unknown as TenantQueryClient;
  await assertRejects(
    () =>
      createEnrollment(db, ORG, SCHOOL_A, {
        studentId: STUDENT_A,
        academicYear: "2026-27",
        className: "5",
        createdBy: STAFF,
      }),
    DuplicateEnrollmentError,
  );
});

Deno.test("createEnrollment clears other current enrollments when isCurrent true", async () => {
  const mock = new MockEnrollmentsDb();
  const db = mock as unknown as TenantQueryClient;
  const row = await createEnrollment(db, ORG, SCHOOL_A, {
    studentId: STUDENT_A,
    academicYear: "2027-28",
    className: "6",
    isCurrent: true,
    createdBy: STAFF,
  });
  assertEquals(row.is_current, true);
  const current = mock.enrollments.filter((e) =>
    e.student_id === STUDENT_A && e.is_current === true
  );
  assertEquals(current.length, 1);
  assertEquals(current[0]!.academic_year, "2027-28");
  const prior = mock.enrollments.find((e) => e.id === ENROLLMENT_A);
  assertEquals(prior?.is_current, false);
});

Deno.test("updateEnrollment updates allowed fields", async () => {
  const db = new MockEnrollmentsDb() as unknown as TenantQueryClient;
  const row = await updateEnrollment(db, ORG, SCHOOL_A, ENROLLMENT_A, {
    className: "5A",
    rollNumber: "15",
  });
  assertEquals(row.class_name, "5A");
  assertEquals(row.roll_number, "15");
});

Deno.test("updateEnrollment rejects duplicate academic year on change", async () => {
  const db = new MockEnrollmentsDb() as unknown as TenantQueryClient;
  await assertRejects(
    () =>
      updateEnrollment(db, ORG, SCHOOL_A, ENROLLMENT_B_YEAR, {
        academicYear: "2026-27",
      }),
    DuplicateEnrollmentError,
  );
});

Deno.test("updateEnrollment maintains single current enrollment", async () => {
  const mock = new MockEnrollmentsDb();
  const db = mock as unknown as TenantQueryClient;
  const row = await updateEnrollment(db, ORG, SCHOOL_A, ENROLLMENT_B_YEAR, {
    isCurrent: true,
  });
  assertEquals(row.is_current, true);
  const prior = mock.enrollments.find((e) => e.id === ENROLLMENT_A);
  assertEquals(prior?.is_current, false);
});

Deno.test("updateEnrollment returns not found for cross-school id", async () => {
  const db = new MockEnrollmentsDb() as unknown as TenantQueryClient;
  await assertRejects(
    () => updateEnrollment(db, ORG, SCHOOL_B, ENROLLMENT_A, { className: "X" }),
    EnrollmentNotFoundError,
  );
});

Deno.test("createEnrollment validates required fields", async () => {
  const db = new MockEnrollmentsDb() as unknown as TenantQueryClient;
  await assertRejects(
    () =>
      createEnrollment(db, ORG, SCHOOL_A, {
        studentId: "",
        academicYear: "2027-28",
        className: "6",
        createdBy: STAFF,
      }),
    ValidationError,
  );
});

Deno.test("enrollmentListItemToApi maps camelCase response", () => {
  const api = enrollmentListItemToApi({
    enrollment_id: ENROLLMENT_A,
    student_id: STUDENT_A,
    student_code: "STU-2026-00001",
    student_name: "Staging Student",
    academic_year: "2026-27",
    class_name: "5",
    section_name: "A",
    roll_number: "12",
    is_current: true,
    created_at: "2026-06-01T00:00:00.000Z",
    updated_at: "2026-06-07T00:00:00.000Z",
  });
  assertEquals(api.enrollmentId, ENROLLMENT_A);
  assertEquals(api.isCurrent, true);
  assertEquals(api.studentCode, "STU-2026-00001");
});

Deno.test("enrollment write requires manageSis and school scope", () => {
  const claims = { ...schoolClaims(), permissions: ["viewSis"] };
  const denied = requirePermission(claims, "manageSis") ??
    requireSchoolOperationalScope(claims);
  assertEquals(denied?.status, 403);
});

Deno.test("enrollment read requires viewSis and school scope", () => {
  const claims = { ...schoolClaims(), permissions: [] as string[] };
  const denied = requirePermission(claims, "viewSis") ??
    requireSchoolOperationalScope(claims);
  assertEquals(denied?.status, 403);
});

Deno.test("org scope denied for enrollment API middleware", () => {
  const denied = requirePermission(orgClaims(), "viewSis") ??
    requireSchoolOperationalScope(orgClaims());
  assertEquals(denied?.status, 403);
});

Deno.test("list enrollments uses single join query (no N+1)", async () => {
  const source = await Deno.readTextFile(
    new URL("./sis_enrollments_repository.ts", import.meta.url),
  );
  assertEquals(source.includes("INNER JOIN students s"), true);
  const listBody = source.match(
    /export async function listEnrollments[\s\S]*?^}/m,
  )?.[0] ?? "";
  assertEquals(listBody.includes("for ("), false);
  assertEquals((listBody.match(/queryObject/g) ?? []).length, 1);
});
