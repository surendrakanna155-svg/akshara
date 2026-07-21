import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  ACADEMIC_CLASS_SCHOOL_A,
} from "../academic/classes_repository.ts";
import {
  ACADEMIC_YEAR_SCHOOL_A,
} from "../academic/academic_years_repository.ts";
import { ACADEMIC_SECTION_SCHOOL_A } from "../academic/sections_repository.ts";
import { enrollmentListItemToApi } from "./sis_mapper.ts";
import {
  createEnrollment,
  CurrentEnrollmentConflictError,
  DuplicateEnrollmentError,
  EnrollmentNotFoundError,
  listEnrollments,
  promoteStudentsBulk,
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
      academic_year_id: ACADEMIC_YEAR_SCHOOL_A,
      class_name: "5",
      class_id: ACADEMIC_CLASS_SCHOOL_A,
      section_name: "A",
      section_id: ACADEMIC_SECTION_SCHOOL_A,
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
      academic_year_id: "ce100000-0000-4000-8000-000000000011",
      class_name: "4",
      class_id: "cf100000-0000-4000-8000-000000000011",
      section_name: "B",
      section_id: "d0100000-0000-4000-8000-000000000011",
      roll_number: "8",
      is_current: false,
      created_by: STAFF,
      created_at: "2025-06-01T00:00:00.000Z",
      updated_at: "2025-06-07T00:00:00.000Z",
    },
  ];
  years: Row[] = [
    {
      id: ACADEMIC_YEAR_SCHOOL_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      year_label: "2026-27",
      status: "active",
    },
    {
      id: "ce100000-0000-4000-8000-000000000011",
      organization_id: ORG,
      school_id: SCHOOL_A,
      year_label: "2025-26",
      status: "active",
    },
    {
      id: "ce100000-0000-4000-8000-000000000010",
      organization_id: ORG,
      school_id: SCHOOL_A,
      year_label: "2027-28",
      status: "active",
    },
  ];
  classes: Row[] = [
    {
      id: ACADEMIC_CLASS_SCHOOL_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      academic_year_id: ACADEMIC_YEAR_SCHOOL_A,
      class_name: "5",
      status: "active",
    },
    {
      id: "cf100000-0000-4000-8000-000000000011",
      organization_id: ORG,
      school_id: SCHOOL_A,
      academic_year_id: "ce100000-0000-4000-8000-000000000011",
      class_name: "4",
      status: "active",
    },
    {
      id: "cf100000-0000-4000-8000-000000000010",
      organization_id: ORG,
      school_id: SCHOOL_A,
      academic_year_id: "ce100000-0000-4000-8000-000000000010",
      class_name: "6",
      status: "active",
    },
  ];
  sections: Row[] = [
    {
      id: ACADEMIC_SECTION_SCHOOL_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      class_id: ACADEMIC_CLASS_SCHOOL_A,
      section_name: "A",
      status: "active",
    },
    {
      id: "d0100000-0000-4000-8000-000000000011",
      organization_id: ORG,
      school_id: SCHOOL_A,
      class_id: "cf100000-0000-4000-8000-000000000011",
      section_name: "B",
      status: "active",
    },
    {
      id: "d0100000-0000-4000-8000-000000000010",
      organization_id: ORG,
      school_id: SCHOOL_A,
      class_id: "cf100000-0000-4000-8000-000000000010",
      section_name: "C",
      status: "active",
    },
  ];
  queries: string[] = [];

  // ICA-E1 race simulation: when set to a constraint/index name, the next
  // INSERT into sis_student_enrollments raises a Postgres unique_violation
  // (SQLSTATE 23505) carrying that constraint — exactly what the new
  // single-current partial-unique index (or the per-year UNIQUE) raises for the
  // LOSER of a concurrent enroll/promote once a winner has already committed a
  // current row. Set to "" to simulate a 23505 with no constraint name surfaced.
  uniqueViolationOnInsert: string | null = null;

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
      academic_year_id: e.academic_year_id,
      class_name: e.class_name,
      class_id: e.class_id,
      section_name: e.section_name,
      section_id: e.section_id,
      roll_number: e.roll_number,
      is_current: e.is_current,
      created_at: e.created_at,
      updated_at: e.updated_at,
    };
  }

  async queryCount(sql: string, args: unknown[] = []): Promise<number> {
    this.queries.push(sql);
    if (sql.includes("sis_student_enrollments se")) {
      return this.filterList(args).length;
    }
    return 0;
  }

  handleCatalogQuery<T>(sql: string, args: unknown[]): T[] {
    if (sql.includes("FROM academic_years") && sql.includes("ORDER BY start_date")) {
      return this.years.filter((y) =>
        y.organization_id === args[0] && y.school_id === args[1]
      ) as T[];
    }
    if (sql.includes("SELECT * FROM academic_years") && sql.includes("WHERE id = $1")) {
      const row = this.years.find((y) =>
        y.id === args[0] && y.organization_id === args[1] && y.school_id === args[2]
      );
      return (row ? [row] : []) as T[];
    }
    if (sql.includes("SELECT id, class_name, status FROM classes")) {
      return this.classes.filter((c) =>
        c.organization_id === args[0] &&
        c.school_id === args[1] &&
        c.academic_year_id === args[2] &&
        c.class_name === args[3]
      ).slice(0, 2) as T[];
    }
    if (sql.includes("SELECT * FROM classes") && sql.includes("WHERE id = $1")) {
      const row = this.classes.find((c) =>
        c.id === args[0] && c.organization_id === args[1] && c.school_id === args[2]
      );
      return (row ? [row] : []) as T[];
    }
    if (sql.includes("SELECT id, section_name, status FROM sections")) {
      return this.sections.filter((s) =>
        s.organization_id === args[0] &&
        s.school_id === args[1] &&
        s.class_id === args[2] &&
        s.section_name === args[3]
      ).slice(0, 2) as T[];
    }
    if (sql.includes("SELECT * FROM sections") && sql.includes("WHERE id = $1")) {
      const row = this.sections.find((s) =>
        s.id === args[0] && s.organization_id === args[1] && s.school_id === args[2]
      );
      return (row ? [row] : []) as T[];
    }
    return [] as T[];
  }

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    this.queries.push(sql);
    const catalog = this.handleCatalogQuery<T>(sql, args);
    if (catalog.length > 0 || (
      sql.includes("academic_years") ||
      sql.includes("FROM classes") ||
      sql.includes("FROM sections")
    )) {
      if (
        sql.includes("academic_years") ||
        sql.includes("FROM classes") ||
        sql.includes("FROM sections")
      ) {
        return catalog;
      }
    }
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
      if (this.uniqueViolationOnInsert !== null) {
        const constraint = this.uniqueViolationOnInsert;
        const err = new Error(
          `duplicate key value violates unique constraint "${constraint}"`,
        ) as Error & { code?: string; fields?: Record<string, string> };
        err.code = "23505";
        err.fields = constraint === ""
          ? { code: "23505" }
          : { code: "23505", constraint };
        throw err;
      }
      const row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        school_id: args[1],
        student_id: args[2],
        academic_year: args[3],
        academic_year_id: args[4],
        class_name: args[5],
        class_id: args[6],
        section_name: args[7],
        section_id: args[8],
        roll_number: args[9],
        is_current: args[10],
        created_by: args[11],
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
    if (sql.includes("UPDATE sis_student_enrollments SET") && sql.includes("academic_year_id = $2")) {
      const enrollment = this.enrollments.find((e) =>
        e.id === args[8] && e.organization_id === args[9] && e.school_id === args[10]
      );
      if (enrollment) {
        enrollment.academic_year = args[0];
        enrollment.academic_year_id = args[1];
        enrollment.class_name = args[2];
        enrollment.class_id = args[3];
        enrollment.section_name = args[4];
        enrollment.section_id = args[5];
        enrollment.roll_number = args[6];
        enrollment.is_current = args[7];
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
  assertEquals(row.academic_year_id, "ce100000-0000-4000-8000-000000000010");
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
    rollNumber: "15",
  });
  assertEquals(row.class_name, "5");
  assertEquals(row.roll_number, "15");
});

Deno.test("updateEnrollment rejects duplicate academic year on change", async () => {
  const db = new MockEnrollmentsDb() as unknown as TenantQueryClient;
  await assertRejects(
    () =>
      updateEnrollment(db, ORG, SCHOOL_A, ENROLLMENT_B_YEAR, {
        academicYear: "2026-27",
        className: "5",
        sectionName: "A",
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
    academic_year_id: ACADEMIC_YEAR_SCHOOL_A,
    class_name: "5",
    class_id: ACADEMIC_CLASS_SCHOOL_A,
    section_name: "A",
    section_id: ACADEMIC_SECTION_SCHOOL_A,
    roll_number: "12",
    is_current: true,
    created_at: "2026-06-01T00:00:00.000Z",
    updated_at: "2026-06-07T00:00:00.000Z",
  });
  assertEquals(api.enrollmentId, ENROLLMENT_A);
  assertEquals(api.isCurrent, true);
  assertEquals(api.studentCode, "STU-2026-00001");
  assertEquals(api.academicYearId, ACADEMIC_YEAR_SCHOOL_A);
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
  const mock = new MockEnrollmentsDb();
  const db = mock as unknown as TenantQueryClient;
  await listEnrollments(db, ORG, SCHOOL_A, {}, { page: 1, pageSize: 20 });
  const listSelect = mock.queries.filter((sql) =>
    sql.includes("LIMIT $8") && sql.includes("INNER JOIN students s")
  );
  const countQueries = mock.queries.filter((sql) =>
    sql.includes("count(*)") && sql.includes("INNER JOIN students s")
  );
  assertEquals(listSelect.length, 1);
  assertEquals(countQueries.length, 1);
  assertEquals(listSelect[0]!.includes("for ("), false);
});

// ─── ICA-E1: single current-enrollment invariant ─────────────────────────────
//
// The AUTHORITATIVE guarantee is the DB partial-unique index
// sis_student_enrollments_one_current_uq (migration 20260920000090). The fake-db
// cannot enforce a partial-unique across a concurrent snapshot, so these tests
// prove the REPOSITORY'S resilience: when the index raises the 23505 for the
// racing loser, the clear-then-write path catches it and surfaces a typed,
// retryable conflict — never a duplicate current row and never a raw 500. The
// true DB-level race is proven separately by a live concurrency cert (see the
// task report's live-cert plan: two concurrent createEnrollment(isCurrent:true)
// for one student → exactly one is_current=true row survives).

Deno.test("ICA-E1: createEnrollment maps single-current 23505 to a conflict, not a 500", async () => {
  const mock = new MockEnrollmentsDb();
  const db = mock as unknown as TenantQueryClient;
  // A concurrent enroll already committed the student's current row; our INSERT
  // trips the single-current partial-unique index.
  mock.uniqueViolationOnInsert = "sis_student_enrollments_one_current_uq";
  await assertRejects(
    () =>
      createEnrollment(db, ORG, SCHOOL_A, {
        studentId: STUDENT_A,
        academicYear: "2027-28",
        className: "6",
        isCurrent: true,
        createdBy: STAFF,
      }),
    CurrentEnrollmentConflictError,
  );
});

Deno.test("ICA-E1: CurrentEnrollmentConflictError is a DuplicateEnrollmentError (handler → 409)", () => {
  // The handler maps `instanceof DuplicateEnrollmentError` → 409 CONFLICT; the
  // subclass inherits that mapping so a concurrency conflict is a clean 409, not
  // an INTERNAL_ERROR 500, without editing the handler.
  const err = new CurrentEnrollmentConflictError(STUDENT_A);
  assertEquals(err instanceof DuplicateEnrollmentError, true);
  assertEquals(err.name, "CurrentEnrollmentConflictError");
  assertEquals(err.message.includes("concurrently"), true);
});

Deno.test("ICA-E1: createEnrollment maps per-year 23505 (race past pre-check) to DuplicateEnrollmentError", async () => {
  const mock = new MockEnrollmentsDb();
  const db = mock as unknown as TenantQueryClient;
  // New year passes the enrollmentExistsForYear pre-check, but a concurrent
  // insert of the same (student, year) won → the UNIQUE(student_id, academic_year)
  // constraint raises 23505.
  mock.uniqueViolationOnInsert =
    "sis_student_enrollments_student_id_academic_year_key";
  await assertRejects(
    () =>
      createEnrollment(db, ORG, SCHOOL_A, {
        studentId: STUDENT_A,
        academicYear: "2027-28",
        className: "6",
        isCurrent: true,
        createdBy: STAFF,
      }),
    DuplicateEnrollmentError,
  );
});

Deno.test("ICA-E1: createEnrollment treats an unnamed 23505 while making-current as a conflict", async () => {
  const mock = new MockEnrollmentsDb();
  const db = mock as unknown as TenantQueryClient;
  // Driver surfaced no constraint name; since this write is setting the row
  // current, the only unique guard beyond the pre-checked per-year one is the
  // single-current index → a retryable conflict beats a raw 500.
  mock.uniqueViolationOnInsert = "";
  await assertRejects(
    () =>
      createEnrollment(db, ORG, SCHOOL_A, {
        studentId: STUDENT_A,
        academicYear: "2027-28",
        className: "6",
        isCurrent: true,
        createdBy: STAFF,
      }),
    CurrentEnrollmentConflictError,
  );
});

Deno.test("ICA-E1: promoteStudentsBulk reports a single-current race as status 'conflict'", async () => {
  const mock = new MockEnrollmentsDb();
  const db = mock as unknown as TenantQueryClient;
  mock.uniqueViolationOnInsert = "sis_student_enrollments_one_current_uq";
  const outcomes = await promoteStudentsBulk(
    db,
    ORG,
    SCHOOL_A,
    [{ studentId: STUDENT_A, academicYear: "2027-28", className: "6" }],
    STAFF,
  );
  assertEquals(outcomes.length, 1);
  assertEquals(outcomes[0]!.status, "conflict");
});

Deno.test("ICA-E1: migration 20260920000090 declares the single-current partial-unique index + self-heal dedup", async () => {
  const migration = await Deno.readTextFile(
    new URL(
      "../../../migrations/20260920000090_sis_single_current_enrollment_guarantee.sql",
      import.meta.url,
    ),
  );
  // The partial UNIQUE index that makes the invariant un-bypassable.
  assertEquals(
    migration.includes("CREATE UNIQUE INDEX IF NOT EXISTS sis_student_enrollments_one_current_uq"),
    true,
  );
  assertEquals(migration.includes("WHERE is_current = true"), true);
  // Column set + school scoping MATCH the existing non-unique partial index.
  assertEquals(migration.includes("(school_id, student_id)"), true);
  // Idempotent self-heal dedup runs BEFORE the CREATE so it cannot fail on data.
  const updateIdx = migration.indexOf("UPDATE sis_student_enrollments");
  const createIdx = migration.indexOf("CREATE UNIQUE INDEX");
  assertEquals(updateIdx >= 0, true);
  assertEquals(createIdx > updateIdx, true);
  assertEquals(migration.includes("SET is_current = false"), true);
});
