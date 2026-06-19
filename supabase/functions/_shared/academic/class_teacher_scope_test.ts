import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { isClassTeacherForClass } from "./teacher_assignments_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const TEACHER = "d1000000-0000-4000-8000-000000000001";

class MockDb {
  constructor(
    private readonly rows: Array<
      { teacherId: string; className: string; sectionName: string }
    >,
  ) {}

  queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("teacher_assignments") && sql.includes("class_teacher")) {
      const [, , teacherId, className, sectionName] = args as string[];
      const match = this.rows.some((r) =>
        r.teacherId === teacherId &&
        r.className === className &&
        r.sectionName === sectionName
      );
      return Promise.resolve([{ count: match ? "1" : "0" }] as unknown as T[]);
    }
    return Promise.resolve([] as T[]);
  }

  queryCount(): Promise<number> {
    return Promise.resolve(0);
  }
}

function db(
  rows: Array<{ teacherId: string; className: string; sectionName: string }>,
): TenantQueryClient {
  return new MockDb(rows) as unknown as TenantQueryClient;
}

Deno.test("isClassTeacherForClass — only the class teacher of that section qualifies", async () => {
  const assigned = db([
    { teacherId: TEACHER, className: "8", sectionName: "A" },
  ]);

  assertEquals(
    await isClassTeacherForClass(assigned, ORG, SCHOOL, TEACHER, "8", "A"),
    true,
  );
  // Not the class teacher of 8-B.
  assertEquals(
    await isClassTeacherForClass(assigned, ORG, SCHOOL, TEACHER, "8", "B"),
    false,
  );
  // No class-teacher assignment.
  assertEquals(
    await isClassTeacherForClass(db([]), ORG, SCHOOL, TEACHER, "8", "A"),
    false,
  );
});
