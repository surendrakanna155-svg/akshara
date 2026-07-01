import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../../jwt.ts";
import type { TenantQueryClient } from "../../tenant_db.ts";
import { requirePermission } from "../../permission_middleware.ts";
import {
  EXAM_OPERATION_PERMISSIONS,
  isSubjectTeacherScoped,
} from "./exam_administration_handlers.ts";
import {
  type ExamSessionRow,
  isClassTeacherForExam,
  teacherTeachesExamSession,
} from "./exam_administration_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const TEACHER = "d1000000-0000-4000-8000-000000000001";

function claims(permissions: string[]): AccessTokenClaims {
  return {
    sub: TEACHER,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL,
    role: "teacher",
    role_slugs: ["teacher"],
    primary_role: "teacher",
    permissions,
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "sess-1",
  } as AccessTokenClaims;
}

function session(overrides: Partial<ExamSessionRow> = {}): ExamSessionRow {
  return {
    id: "exam_1",
    organization_id: ORG,
    school_id: SCHOOL,
    title: "Unit Test — Mathematics",
    subject: "Mathematics",
    grade: "8",
    section_name: "A",
    term_label: "Term 2",
    date_label: "12 Jun 2026",
    time_label: "9:00 AM",
    venue_label: "Room 8A",
    syllabus_label: "Algebra",
    max_marks: 50,
    phase: "marks_entry",
    exam_type: "unit_test",
    marks_entry_deadline: null,
    coordinator_verified_by: null,
    coordinator_verified_at: null,
    rejection_comment: null,
    created_by: null,
    created_at: "2026-06-12T00:00:00.000Z",
    updated_at: "2026-06-12T00:00:00.000Z",
    ...overrides,
  };
}

interface Assignment {
  teacherId: string;
  subject: string;
  grade: string;
  section: string;
}

/** Returns count=1 only when the scoping query args match a seeded assignment. */
class MockAssignmentsDb {
  constructor(private readonly assignments: Assignment[]) {}

  queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("teacher_subject_assignments")) {
      const [, , teacherId, subject, grade, section] = args as string[];
      const match = this.assignments.some((a) =>
        a.teacherId === teacherId &&
        a.subject === subject &&
        a.grade === grade &&
        a.section === section
      );
      return Promise.resolve([{ count: match ? "1" : "0" }] as unknown as T[]);
    }
    return Promise.resolve([] as T[]);
  }

  queryCount(): Promise<number> {
    return Promise.resolve(0);
  }
}

function db(assignments: Assignment[]): TenantQueryClient {
  return new MockAssignmentsDb(assignments) as unknown as TenantQueryClient;
}

// ---------------------------------------------------------------------------
// P1 — granular exam permissions (not coarse viewSis/manageSis)
// ---------------------------------------------------------------------------

Deno.test("P1 — coarse manageSis no longer authorizes exam mark management", () => {
  const coarse = claims(["viewSis", "manageSis"]);
  assertEquals(
    requirePermission(coarse, EXAM_OPERATION_PERMISSIONS.updateExamMark)?.status,
    403,
  );
  assertEquals(
    requirePermission(coarse, EXAM_OPERATION_PERMISSIONS.listExamMarks)?.status,
    403,
  );
});

Deno.test("P1 — teacher with granular marks permission is allowed; cannot verify/publish", () => {
  const teacher = claims([
    "viewExams",
    "manageExamMarks",
    "submitExamResults",
  ]);
  assertEquals(
    requirePermission(teacher, EXAM_OPERATION_PERMISSIONS.updateExamMark),
    null,
  );
  assertEquals(
    requirePermission(teacher, EXAM_OPERATION_PERMISSIONS.processResults),
    null,
  );
  assertEquals(
    requirePermission(teacher, EXAM_OPERATION_PERMISSIONS.verifyCoordinator)
      ?.status,
    403,
  );
  assertEquals(
    requirePermission(teacher, EXAM_OPERATION_PERMISSIONS.publishResults)
      ?.status,
    403,
  );
});

Deno.test("P1 — oversight role can verify, approve, and publish", () => {
  const principal = claims([
    "viewExams",
    "manageExams",
    "manageExamMarks",
    "submitExamResults",
    "verifyExamResults",
    "approveExamResults",
    "publishExamResults",
  ]);
  assertEquals(
    requirePermission(principal, EXAM_OPERATION_PERMISSIONS.verifyCoordinator),
    null,
  );
  assertEquals(
    requirePermission(principal, EXAM_OPERATION_PERMISSIONS.publishResults),
    null,
  );
});

// ---------------------------------------------------------------------------
// P2 — subject-teacher scoping of marks read/update
// ---------------------------------------------------------------------------

Deno.test("P2 — plain teacher is scoped; oversight roles are not", () => {
  assertEquals(isSubjectTeacherScoped(claims(["manageExamMarks"])), true);
  assertEquals(
    isSubjectTeacherScoped(claims(["manageExamMarks", "verifyExamResults"])),
    false,
  );
});

// Remark authoring: only the class teacher of the exam's section qualifies.
class ClassTeacherDb {
  constructor(
    private readonly rows: Array<
      { teacherId: string; grade: string; section: string }
    >,
  ) {}

  queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("teacher_assignments") && sql.includes("class_teacher")) {
      const [, , teacherId, grade, section] = args as string[];
      const match = this.rows.some((r) =>
        r.teacherId === teacherId && r.grade === grade && r.section === section
      );
      return Promise.resolve([{ count: match ? "1" : "0" }] as unknown as T[]);
    }
    return Promise.resolve([] as T[]);
  }

  queryCount(): Promise<number> {
    return Promise.resolve(0);
  }
}

function classTeacherDb(
  rows: Array<{ teacherId: string; grade: string; section: string }>,
): TenantQueryClient {
  return new ClassTeacherDb(rows) as unknown as TenantQueryClient;
}

Deno.test("remark authz — only the class teacher of the section may author", async () => {
  const assigned = classTeacherDb([
    { teacherId: TEACHER, grade: "8", section: "A" },
  ]);

  // Class teacher of 8-A → allowed for an 8-A exam.
  assertEquals(
    await isClassTeacherForExam(assigned, ORG, SCHOOL, TEACHER, session()),
    true,
  );
  // Same teacher is not the class teacher of 8-B.
  assertEquals(
    await isClassTeacherForExam(
      assigned,
      ORG,
      SCHOOL,
      TEACHER,
      session({ section_name: "B" }),
    ),
    false,
  );
  // No class-teacher assignment at all.
  assertEquals(
    await isClassTeacherForExam(classTeacherDb([]), ORG, SCHOOL, TEACHER, session()),
    false,
  );
});

Deno.test("P2 — teacherTeachesExamSession matches subject + class + section", async () => {
  const assigned = db([
    { teacherId: TEACHER, subject: "Mathematics", grade: "8", section: "A" },
  ]);

  assertEquals(
    await teacherTeachesExamSession(assigned, ORG, SCHOOL, TEACHER, session()),
    true,
  );
  // Same section, different subject → denied (a Maths teacher can't edit Science).
  assertEquals(
    await teacherTeachesExamSession(
      assigned,
      ORG,
      SCHOOL,
      TEACHER,
      session({ subject: "Science" }),
    ),
    false,
  );
  // Same subject, different section → denied.
  assertEquals(
    await teacherTeachesExamSession(
      assigned,
      ORG,
      SCHOOL,
      TEACHER,
      session({ section_name: "B" }),
    ),
    false,
  );
  // No assignment at all → denied.
  assertEquals(
    await teacherTeachesExamSession(db([]), ORG, SCHOOL, TEACHER, session()),
    false,
  );
});
