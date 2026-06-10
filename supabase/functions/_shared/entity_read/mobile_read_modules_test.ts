import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { requirePermission } from "../permission_middleware.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { parentStore } from "../parent/parent_read_repository.ts";
import { teacherStore } from "../teacher/teacher_read_repository.ts";
import { studentStore } from "../student/student_read_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const STUDENT_A = "a4000000-0000-4000-8000-000000000001";

class MockStudentScopedDb {
  constructor(
    private readonly rows: Array<{
      student_id: string;
      entity_type: string;
      id: string;
      payload: Record<string, unknown>;
    }>,
  ) {}

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("count(*)::text AS total")) {
      const studentId = args[2] as string;
      const entityType = args[3] as string;
      const total = this.rows.filter(
        (row) => row.student_id === studentId && row.entity_type === entityType,
      ).length;
      return [{ total: String(total) }] as T[];
    }

    if (sql.includes("student_id = $3") && sql.includes("AND id = $5")) {
      const studentId = args[2] as string;
      const entityType = args[3] as string;
      const id = args[4] as string;
      const row = this.rows.find(
        (entry) =>
          entry.student_id === studentId &&
          entry.entity_type === entityType &&
          entry.id === id,
      );
      return row ? [{ payload: row.payload }] as T[] : [] as T[];
    }

    if (sql.includes("ORDER BY id")) {
      const studentId = args[2] as string;
      const entityType = args[3] as string;
      const limit = args[4] as number;
      const offset = args[5] as number;
      const items = this.rows
        .filter((row) => row.student_id === studentId && row.entity_type === entityType)
        .slice(offset, offset + limit);
      return items.map((row) => ({ payload: row.payload })) as T[];
    }

    return [] as T[];
  }
}

class MockSchoolDb {
  constructor(
    private readonly rows: Array<{ entity_type: string; id: string; payload: Record<string, unknown> }>,
  ) {}

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("count(*)::text AS total")) {
      const entityType = args[2] as string;
      const total = this.rows.filter((row) => row.entity_type === entityType).length;
      return [{ total: String(total) }] as T[];
    }

    if (sql.includes("entity_type = $3") && sql.includes("AND id = $4")) {
      const row = this.rows.find((r) => r.entity_type === args[2] && r.id === args[3]);
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

Deno.test("parent getSnapshot returns dashboard", async () => {
  const db = new MockStudentScopedDb([
    {
      student_id: STUDENT_A,
      entity_type: "snapshot_dashboard",
      id: "default",
      payload: { childName: "Ravi Kumar", unreadNotifications: 2 },
    },
  ]) as unknown as TenantQueryClient;
  const snapshot = await parentStore.getSnapshot(
    db,
    ORG,
    SCHOOL_A,
    STUDENT_A,
    "snapshot_dashboard",
  );
  assertEquals(snapshot.childName, "Ravi Kumar");
});

Deno.test("student listEntities returns homework items", async () => {
  const db = new MockStudentScopedDb([
    {
      student_id: STUDENT_A,
      entity_type: "homework_item",
      id: "hw_1",
      payload: { id: "hw_1", title: "Algebra worksheet" },
    },
  ]) as unknown as TenantQueryClient;
  const result = await studentStore.listEntities(
    db,
    ORG,
    SCHOOL_A,
    STUDENT_A,
    "homework_item",
    { page: 1, pageSize: 20 },
  );
  assertEquals(result.items.length, 1);
});

Deno.test("teacher getSnapshot returns dashboard", async () => {
  const db = new MockSchoolDb([
    {
      entity_type: "snapshot_dashboard",
      id: "default",
      payload: { greetingHeadline: "Good morning", unreadNotifications: 1 },
    },
  ]) as unknown as TenantQueryClient;
  const snapshot = await teacherStore.getSnapshot(db, ORG, SCHOOL_A, "snapshot_dashboard");
  assertEquals(snapshot.greetingHeadline, "Good morning");
});

Deno.test("teacher mobile requires viewAdminHub permission", () => {
  const claims: AccessTokenClaims = {
    sub: "teacher",
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL_A,
    role: "teacher",
    role_slugs: ["teacher"],
    primary_role: "teacher",
    permissions: [],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "test",
  };
  assertEquals(requirePermission(claims, "viewAdminHub")?.status, 403);
});
