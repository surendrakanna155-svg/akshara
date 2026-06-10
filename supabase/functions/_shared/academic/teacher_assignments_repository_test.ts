import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { ACADEMIC_SECTION_SCHOOL_A } from "./sections_repository.ts";
import {
  ACADEMIC_TEACHER_ASSIGNMENTS_PROBE_SQL,
  ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_A,
  createTeacherAssignment,
  DuplicatePrimaryClassTeacherError,
  listTeacherAssignments,
  ValidationError,
} from "./teacher_assignments_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const SCHOOL_B = "a2000000-0000-4000-8000-000000000002";
const STAFF = "a3000000-0000-4000-8000-000000000001";
const TEACHER_A = "d1000000-0000-4000-8000-000000000001";
const TEACHER_B = "d1000000-0000-4000-8000-000000000002";

type Row = Record<string, unknown>;

class MockTeacherAssignmentsDb {
  clearPrimaryEnabled = true;
  sections: Row[] = [
    {
      id: ACADEMIC_SECTION_SCHOOL_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      class_id: "cf100000-0000-4000-8000-000000000001",
      section_name: "A",
    },
    {
      id: "d0100000-0000-4000-8000-000000000099",
      organization_id: ORG,
      school_id: SCHOOL_B,
      class_id: "cf100000-0000-4000-8000-000000000099",
      section_name: "A",
    },
  ];
  assignments: Row[] = [
    {
      id: ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      teacher_id: TEACHER_A,
      section_id: ACADEMIC_SECTION_SCHOOL_A,
      role: "class_teacher",
      is_primary: true,
      created_by: STAFF,
      created_at: "2026-06-15T00:00:00.000Z",
      updated_at: "2026-06-15T00:00:00.000Z",
    },
  ];
  memberships = new Set<string>([`${TEACHER_A}:${SCHOOL_A}`, `${TEACHER_B}:${SCHOOL_B}`]);

  filterAssignments(orgId: unknown, schoolId: unknown): Row[] {
    return this.assignments.filter((a) =>
      a.organization_id === orgId && a.school_id === schoolId
    );
  }

  async queryCount(sql: string, args: unknown[] = []): Promise<number> {
    if (sql.includes("FROM teacher_assignments ta")) {
      return this.filterAssignments(args[0], args[1]).length;
    }
    return 0;
  }

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("SELECT * FROM sections") && sql.includes("WHERE id = $1")) {
      const row = this.sections.find((s) =>
        s.id === args[0] && s.organization_id === args[1] && s.school_id === args[2]
      );
      return (row ? [row] : []) as T[];
    }
    if (sql.includes("FROM school_memberships")) {
      const key = `${args[0]}:${args[1]}`;
      return (this.memberships.has(key) ? [{ count: "1" }] : [{ count: "0" }]) as T[];
    }
    if (sql.includes("UPDATE teacher_assignments") && sql.includes("is_primary = false")) {
      if (!this.clearPrimaryEnabled) return [] as T[];
      for (const row of this.assignments) {
        if (
          row.organization_id === args[0] &&
          row.school_id === args[1] &&
          row.section_id === args[2] &&
          row.role === "class_teacher" &&
          row.is_primary === true &&
          (args[3] == null || row.id !== args[3])
        ) {
          row.is_primary = false;
        }
      }
      return [] as T[];
    }
    if (sql.includes("INSERT INTO teacher_assignments")) {
      const duplicatePrimary = this.assignments.some((a) =>
        a.section_id === args[3] &&
        a.role === "class_teacher" &&
        a.is_primary === true &&
        args[4] === "class_teacher" &&
        args[5] === true
      );
      if (duplicatePrimary) {
        throw new Error("duplicate key value violates unique constraint teacher_assignments_one_primary_class_teacher");
      }
      const row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        school_id: args[1],
        teacher_id: args[2],
        section_id: args[3],
        role: args[4],
        is_primary: args[5],
        created_by: args[6],
        created_at: "2026-06-15T00:00:00.000Z",
        updated_at: "2026-06-15T00:00:00.000Z",
      };
      this.assignments.push(row);
      return [row as T];
    }
    if (sql.includes("FROM teacher_assignments ta")) {
      return this.filterAssignments(args[0], args[1])
        .map((a) => {
          const section = this.sections.find((s) => s.id === a.section_id)!;
          return {
            ...a,
            class_id: section.class_id,
            class_name: "5",
            section_name: section.section_name,
            teacher_name: "Teacher",
          };
        }) as T[];
    }
    return [] as T[];
  }
}

function asDb(mock: MockTeacherAssignmentsDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

Deno.test("ACADEMIC_TEACHER_ASSIGNMENTS_PROBE_SQL targets teacher_assignments", () => {
  assertEquals(
    ACADEMIC_TEACHER_ASSIGNMENTS_PROBE_SQL.includes("FROM teacher_assignments"),
    true,
  );
});

Deno.test("createTeacherAssignment requires section in school scope", async () => {
  const db = new MockTeacherAssignmentsDb();
  await assertRejects(
    () =>
      createTeacherAssignment(asDb(db), ORG, SCHOOL_A, {
        teacherId: TEACHER_A,
        sectionId: "d0100000-0000-4000-8000-000000000099",
        role: "subject_teacher",
        createdBy: STAFF,
      }),
    ValidationError,
  );
});

Deno.test("createTeacherAssignment creates subject teacher on valid section", async () => {
  const db = new MockTeacherAssignmentsDb();
  const created = await createTeacherAssignment(asDb(db), ORG, SCHOOL_A, {
    teacherId: TEACHER_A,
    sectionId: ACADEMIC_SECTION_SCHOOL_A,
    role: "subject_teacher",
    isPrimary: false,
    createdBy: STAFF,
  });
  assertEquals(created.section_id, ACADEMIC_SECTION_SCHOOL_A);
  assertEquals(created.role, "subject_teacher");
});

Deno.test("createTeacherAssignment requires teacher membership in target school", async () => {
  const db = new MockTeacherAssignmentsDb();
  await assertRejects(
    () =>
      createTeacherAssignment(asDb(db), ORG, SCHOOL_A, {
        teacherId: TEACHER_B,
        sectionId: ACADEMIC_SECTION_SCHOOL_A,
        role: "subject_teacher",
        createdBy: STAFF,
      }),
    ValidationError,
  );
});

Deno.test("createTeacherAssignment maps partial unique primary teacher violation", async () => {
  const db = new MockTeacherAssignmentsDb();
  db.clearPrimaryEnabled = false;
  await assertRejects(
    () =>
      createTeacherAssignment(asDb(db), ORG, SCHOOL_A, {
        teacherId: TEACHER_A,
        sectionId: ACADEMIC_SECTION_SCHOOL_A,
        role: "class_teacher",
        isPrimary: true,
        createdBy: STAFF,
      }),
    DuplicatePrimaryClassTeacherError,
  );
});

Deno.test("createTeacherAssignment keeps a single primary class teacher per section", async () => {
  const db = new MockTeacherAssignmentsDb();
  db.memberships.add(`${TEACHER_B}:${SCHOOL_A}`);
  await createTeacherAssignment(asDb(db), ORG, SCHOOL_A, {
    teacherId: TEACHER_B,
    sectionId: ACADEMIC_SECTION_SCHOOL_A,
    role: "class_teacher",
    isPrimary: true,
    createdBy: STAFF,
  });
  const primaries = db.assignments.filter((a) =>
    a.section_id === ACADEMIC_SECTION_SCHOOL_A &&
    a.role === "class_teacher" &&
    a.is_primary === true
  );
  assertEquals(primaries.length, 1);
  assertEquals(primaries[0]!.teacher_id, TEACHER_B);
});

Deno.test("listTeacherAssignments isolates assignments by school", async () => {
  const db = new MockTeacherAssignmentsDb();
  db.assignments.push({
    id: "d2000000-0000-4000-8000-000000000099",
    organization_id: ORG,
    school_id: SCHOOL_B,
    teacher_id: TEACHER_B,
    section_id: "d0100000-0000-4000-8000-000000000099",
    role: "class_teacher",
    is_primary: true,
    created_by: STAFF,
    created_at: "2026-06-15T00:00:00.000Z",
    updated_at: "2026-06-15T00:00:00.000Z",
  });
  const schoolA = await listTeacherAssignments(asDb(db), ORG, SCHOOL_A);
  assertEquals(schoolA.length, 1);
  assertEquals(schoolA[0]!.school_id, SCHOOL_A);
});

Deno.test("listTeacherAssignments resolves teacher names via membership snapshot join", async () => {
  const source = await Deno.readTextFile(
    new URL("./teacher_assignments_repository.ts", import.meta.url),
  );
  assertEquals(source.includes("TEACHER_ASSIGNMENT_NAME_JOIN"), true);
  assertEquals(source.includes("member_display_name AS teacher_name"), true);
  assertEquals(source.includes("JOIN users"), false);
});
