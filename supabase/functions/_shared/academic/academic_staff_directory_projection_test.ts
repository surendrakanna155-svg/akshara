import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { teacherAssignmentToApi } from "./academic_mapper.ts";
import {
  ACADEMIC_TEACHER_ASSIGNMENTS_API_PROBE_SQL,
  ACADEMIC_TEACHER_ASSIGNMENT_DETAIL_PROBE_SQL,
  ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_A,
  createTeacherAssignment,
  getTeacherAssignmentWithDetails,
  listTeacherAssignments,
  TEACHER_ASSIGNMENT_NAME_JOIN,
  updateTeacherAssignment,
} from "./teacher_assignments_repository.ts";
import { ACADEMIC_SECTION_SCHOOL_A } from "./sections_repository.ts";

const projectionMigration = await Deno.readTextFile(
  new URL("../../../migrations/20260617000000_staff_directory_projection.sql", import.meta.url),
);
const transitionalMigration = await Deno.readTextFile(
  new URL("../../../migrations/20260616000000_academic_teacher_directory_rls.sql", import.meta.url),
);
const phase2Migration = await Deno.readTextFile(
  new URL("../../../migrations/20260609100000_phase2_rls_scope.sql", import.meta.url),
);
const repositorySource = await Deno.readTextFile(
  new URL("./teacher_assignments_repository.ts", import.meta.url),
);
const academicSources = [];
for await (const entry of Deno.readDir(new URL(".", import.meta.url))) {
  if (!entry.isFile || !entry.name.endsWith(".ts") || entry.name.endsWith("_test.ts")) {
    continue;
  }
  academicSources.push(await Deno.readTextFile(new URL(`./${entry.name}`, import.meta.url)));
}
const academicProductionSource = academicSources.join("\n");

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const SCHOOL_B = "a2000000-0000-4000-8000-000000000002";
const STAFF = "a3000000-0000-4000-8000-000000000001";
const TEACHER_A = "d1000000-0000-4000-8000-000000000001";
const TEACHER_B = "d1000000-0000-4000-8000-000000000002";

Deno.test("5C.0e migration adds member_display_name with backfill and sync trigger", () => {
  assertEquals(projectionMigration.includes("ADD COLUMN IF NOT EXISTS member_display_name"), true);
  assertEquals(projectionMigration.includes("UPDATE school_memberships sm"), true);
  assertEquals(projectionMigration.includes("u.display_name"), true);
  assertEquals(projectionMigration.includes("users_sync_school_membership_display_names"), true);
  assertEquals(projectionMigration.includes("school_memberships_snapshot_display_name"), true);
  assertEquals(projectionMigration.includes("DROP POLICY IF EXISTS users_school_staff_directory"), true);
});

Deno.test("5C.0e migration removes transitional users directory policy", () => {
  assertEquals(transitionalMigration.includes("users_school_staff_directory"), true);
  assertEquals(projectionMigration.includes("DROP POLICY IF EXISTS users_school_staff_directory"), true);
});

Deno.test("users_self_access remains the tenant users read policy baseline", () => {
  assertEquals(phase2Migration.includes("users_self_access"), true);
  assertEquals(phase2Migration.includes("id = app_current_user_id()"), true);
});

Deno.test("Academic production code has no users table dependency", () => {
  assertEquals(academicProductionSource.includes("users_school_staff_directory"), false);
  assertEquals(academicProductionSource.match(/\bJOIN users\b/g) ?? [], []);
  assertEquals(academicProductionSource.match(/\bLEFT JOIN users\b/g) ?? [], []);
  assertEquals(academicProductionSource.match(/\bFROM users\b/g) ?? [], []);
  assertEquals(academicProductionSource.includes("u.display_name"), false);
  assertEquals(academicProductionSource.includes("users.display_name"), false);
});

Deno.test("teacher assignment repository resolves teacher_name from membership snapshot", () => {
  assertEquals(repositorySource.includes("member_display_name AS teacher_name"), true);
  assertEquals(TEACHER_ASSIGNMENT_NAME_JOIN.includes("school_memberships sm_teacher"), true);
  assertEquals(TEACHER_ASSIGNMENT_NAME_JOIN.includes("JOIN users"), false);
  assertEquals(ACADEMIC_TEACHER_ASSIGNMENTS_API_PROBE_SQL.includes("JOIN users"), false);
  assertEquals(ACADEMIC_TEACHER_ASSIGNMENT_DETAIL_PROBE_SQL.includes("JOIN users"), false);
});

Deno.test("teacherAssignmentToApi contract unchanged with teacherId and teacherName", () => {
  const api = teacherAssignmentToApi({
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
    class_id: "cf100000-0000-4000-8000-000000000001",
    class_name: "5",
    section_name: "A",
    teacher_name: "Staging Teacher A",
  });
  assertEquals(api.teacherId, TEACHER_A);
  assertEquals(api.teacherName, "Staging Teacher A");
  assertEquals(Object.keys(api).includes("phone"), false);
  assertEquals(Object.keys(api).includes("email"), false);
});

class MembershipSnapshotMockDb {
  clearPrimaryEnabled = true;
  memberships = new Map<string, { role: string; status: string; member_display_name: string }>([
    [`${TEACHER_A}:${SCHOOL_A}`, {
      role: "teacher",
      status: "active",
      member_display_name: "Staging Teacher A",
    }],
    [`${TEACHER_B}:${SCHOOL_B}`, {
      role: "teacher",
      status: "active",
      member_display_name: "Staging Teacher B",
    }],
  ]);
  sections = [{
    id: ACADEMIC_SECTION_SCHOOL_A,
    organization_id: ORG,
    school_id: SCHOOL_A,
    class_id: "cf100000-0000-4000-8000-000000000001",
    section_name: "A",
  }];
  assignments: Record<string, unknown>[] = [{
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
  }];

  teacherName(teacherId: string, schoolId: string): string | null {
    return this.memberships.get(`${teacherId}:${schoolId}`)?.member_display_name ?? null;
  }

  assignmentDetailRow(
    assignment: Record<string, unknown>,
  ): Record<string, unknown> {
    const section = this.sections.find((s) => s.id === assignment.section_id)!;
    return {
      ...assignment,
      class_id: section.class_id,
      class_name: "5",
      section_name: section.section_name,
      teacher_name: this.teacherName(
        assignment.teacher_id as string,
        assignment.school_id as string,
      ),
    };
  }

  async queryCount(sql: string, args: unknown[] = []): Promise<number> {
    if (sql.includes("FROM teacher_assignments ta")) {
      return this.assignments.filter((a) =>
        a.organization_id === args[0] && a.school_id === args[1]
      ).length;
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
    if (sql.includes("FROM school_memberships") && sql.includes("count(*)")) {
      const key = `${args[0]}:${args[1]}`;
      const membership = this.memberships.get(key);
      const ok = membership?.role === "teacher" && membership.status === "active";
      return [{ count: ok ? "1" : "0" }] as T[];
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
    if (sql.includes("UPDATE teacher_assignments SET") && sql.includes("teacher_id = $4")) {
      const idx = this.assignments.findIndex((a) =>
        a.id === args[0] && a.organization_id === args[1] && a.school_id === args[2]
      );
      if (idx < 0) return [] as T[];
      this.assignments[idx] = {
        ...this.assignments[idx]!,
        teacher_id: args[3],
        section_id: args[4],
        role: args[5],
        is_primary: args[6],
      };
      return [this.assignments[idx] as T];
    }
    if (sql.includes("SELECT * FROM teacher_assignments") && sql.includes("WHERE id = $1")) {
      const row = this.assignments.find((a) =>
        a.id === args[0] && a.organization_id === args[1] && a.school_id === args[2]
      );
      return (row ? [row] : []) as T[];
    }
    if (sql.includes("FROM teacher_assignments ta")) {
      if (sql.includes("WHERE ta.id = $1 AND ta.organization_id = $2")) {
        const row = this.assignments.find((a) =>
          a.id === args[0] && a.organization_id === args[1] && a.school_id === args[2]
        );
        return (row ? [this.assignmentDetailRow(row) as T] : []) as T[];
      }
      return this.assignments
        .filter((a) => a.organization_id === args[0] && a.school_id === args[1])
        .map((a) => this.assignmentDetailRow(a) as T);
    }
    return [] as T[];
  }
}

function asDb(mock: MembershipSnapshotMockDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

Deno.test("listTeacherAssignments resolves teacherName from membership snapshot", async () => {
  const db = new MembershipSnapshotMockDb();
  const items = await listTeacherAssignments(asDb(db), ORG, SCHOOL_A);
  assertEquals(items[0]!.teacher_name, "Staging Teacher A");
});

Deno.test("cross-school teacher names are not resolved from foreign memberships", async () => {
  const db = new MembershipSnapshotMockDb();
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
  assertEquals(schoolA.every((row) => row.school_id === SCHOOL_A), true);
  assertEquals(schoolA[0]!.teacher_name, "Staging Teacher A");
});

Deno.test("createTeacherAssignment detail fetch populates teacherName from snapshot", async () => {
  const db = new MembershipSnapshotMockDb();
  const created = await createTeacherAssignment(asDb(db), ORG, SCHOOL_A, {
    teacherId: TEACHER_A,
    sectionId: ACADEMIC_SECTION_SCHOOL_A,
    role: "subject_teacher",
    isPrimary: false,
    createdBy: STAFF,
  });
  const detail = await getTeacherAssignmentWithDetails(
    asDb(db),
    ORG,
    SCHOOL_A,
    created.id,
  );
  assertEquals(detail?.teacher_name, "Staging Teacher A");
});

Deno.test("updateTeacherAssignment keeps teacherName resolvable from snapshot", async () => {
  const db = new MembershipSnapshotMockDb();
  await updateTeacherAssignment(asDb(db), ORG, SCHOOL_A, ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_A, {
    role: "subject_teacher",
    isPrimary: false,
  });
  const detail = await getTeacherAssignmentWithDetails(
    asDb(db),
    ORG,
    SCHOOL_A,
    ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_A,
  );
  assertEquals(detail?.teacher_name, "Staging Teacher A");
});
