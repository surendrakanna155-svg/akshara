import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { teacherAssignmentToApi } from "./academic_mapper.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  ACADEMIC_TEACHER_ASSIGNMENTS_API_PROBE_SQL,
  ACADEMIC_TEACHER_ASSIGNMENT_DETAIL_PROBE_SQL,
  listTeacherAssignments,
  TEACHER_ASSIGNMENT_NAME_JOIN,
} from "./teacher_assignments_repository.ts";
import { ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_A } from "./teacher_assignments_repository.ts";

const projectionMigration = await Deno.readTextFile(
  new URL("../../../migrations/20260617000000_staff_directory_projection.sql", import.meta.url),
);
const repositorySource = await Deno.readTextFile(
  new URL("./teacher_assignments_repository.ts", import.meta.url),
);
const handlerSource = await Deno.readTextFile(
  new URL("./academic_handlers.ts", import.meta.url),
);

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const SCHOOL_B = "a2000000-0000-4000-8000-000000000002";
const TEACHER_A = "d1000000-0000-4000-8000-000000000001";
const TEACHER_B = "d1000000-0000-4000-8000-000000000002";

Deno.test("5C.0e staff directory projection replaces users directory policy", () => {
  assertEquals(projectionMigration.includes("member_display_name"), true);
  assertEquals(projectionMigration.includes("DROP POLICY IF EXISTS users_school_staff_directory"), true);
  assertEquals(projectionMigration.includes("CREATE POLICY users_school_staff_directory"), false);
});

Deno.test("teacher assignment queries resolve names via membership snapshot only", () => {
  assertEquals(repositorySource.includes("TEACHER_ASSIGNMENT_NAME_JOIN"), true);
  assertEquals(repositorySource.includes("sm_teacher.role = 'teacher'"), true);
  assertEquals(repositorySource.includes("member_display_name AS teacher_name"), true);
  assertEquals(repositorySource.includes("JOIN users"), false);
  assertEquals(
    ACADEMIC_TEACHER_ASSIGNMENTS_API_PROBE_SQL.includes("INNER JOIN school_memberships sm_teacher"),
    true,
  );
  assertEquals(
    ACADEMIC_TEACHER_ASSIGNMENT_DETAIL_PROBE_SQL.includes("INNER JOIN school_memberships sm_teacher"),
    true,
  );
  assertEquals(TEACHER_ASSIGNMENT_NAME_JOIN.includes("school_memberships sm_teacher"), true);
});

Deno.test("teacher assignment repository has no users table dependency", () => {
  assertEquals(repositorySource.match(/\bJOIN users\b/g) ?? [], []);
  assertEquals(repositorySource.match(/\bLEFT JOIN users\b/g) ?? [], []);
  assertEquals(repositorySource.includes("u.display_name"), false);
});

Deno.test("teacher assignment handlers expose teacherName in API responses", () => {
  assertEquals(handlerSource.includes("teacherAssignmentToApi"), true);
  assertEquals(handlerSource.includes("listTeacherAssignmentsPage"), true);
});

Deno.test("teacherAssignmentToApi maps teacherName from repository row", () => {
  const api = teacherAssignmentToApi({
    id: ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_A,
    organization_id: ORG,
    school_id: SCHOOL_A,
    teacher_id: TEACHER_A,
    section_id: "d0100000-0000-4000-8000-000000000001",
    role: "class_teacher",
    is_primary: true,
    created_by: null,
    created_at: "2026-06-15T00:00:00.000Z",
    updated_at: "2026-06-15T00:00:00.000Z",
    class_id: "cf100000-0000-4000-8000-000000000001",
    class_name: "5",
    section_name: "A",
    teacher_name: "Staging Teacher A",
  });
  assertEquals(api.teacherName, "Staging Teacher A");
});

class TeacherNameMockDb {
  assignments = [
    {
      id: ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      teacher_id: TEACHER_A,
      section_id: "d0100000-0000-4000-8000-000000000001",
      role: "class_teacher",
      is_primary: true,
      created_by: null,
      created_at: "2026-06-15T00:00:00.000Z",
      updated_at: "2026-06-15T00:00:00.000Z",
    },
    {
      id: "d2000000-0000-4000-8000-000000000099",
      organization_id: ORG,
      school_id: SCHOOL_B,
      teacher_id: TEACHER_B,
      section_id: "d0100000-0000-4000-8000-000000000099",
      role: "class_teacher",
      is_primary: true,
      created_by: null,
      created_at: "2026-06-15T00:00:00.000Z",
      updated_at: "2026-06-15T00:00:00.000Z",
    },
  ];
  teacherNames: Record<string, string> = {
    [`${TEACHER_A}:${SCHOOL_A}`]: "Staging Teacher A",
    [`${TEACHER_B}:${SCHOOL_B}`]: "Staging Teacher B",
  };

  async queryCount(_sql: string, args: unknown[] = []): Promise<number> {
    return this.assignments.filter((a) =>
      a.organization_id === args[0] && a.school_id === args[1]
    ).length;
  }

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("FROM teacher_assignments ta")) {
      const rows = this.assignments.filter((a) =>
        a.organization_id === args[0] && a.school_id === args[1]
      );
      return rows.map((a) => ({
        ...a,
        class_id: "cf100000-0000-4000-8000-000000000001",
        class_name: "5",
        section_name: "A",
        teacher_name: this.teacherNames[`${a.teacher_id}:${a.school_id}`] ?? null,
      })) as T[];
    }
    return [] as T[];
  }
}

Deno.test("listTeacherAssignments populates teacherName for same-school teachers", async () => {
  const db = new TeacherNameMockDb();
  const items = await listTeacherAssignments(db as unknown as TenantQueryClient, ORG, SCHOOL_A);
  assertEquals(items.length, 1);
  assertEquals(items[0]!.teacher_name, "Staging Teacher A");
});

Deno.test("listTeacherAssignments hides cross-school teachers from school A list", async () => {
  const db = new TeacherNameMockDb();
  const items = await listTeacherAssignments(db as unknown as TenantQueryClient, ORG, SCHOOL_A);
  assertEquals(items.every((row) => row.school_id === SCHOOL_A), true);
  assertEquals(items.some((row) => row.teacher_id === TEACHER_B), false);
});
