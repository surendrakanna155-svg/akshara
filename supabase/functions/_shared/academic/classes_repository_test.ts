import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { ACADEMIC_YEAR_SCHOOL_A } from "./academic_years_repository.ts";
import {
  ACADEMIC_CLASSES_PROBE_SQL,
  ACADEMIC_CLASS_SCHOOL_A,
  createClass,
  DuplicateClassError,
  listClasses,
} from "./classes_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const SCHOOL_B = "a2000000-0000-4000-8000-000000000002";
const STAFF = "a3000000-0000-4000-8000-000000000001";

type Row = Record<string, unknown>;

class MockClassesDb {
  years: Row[] = [
    {
      id: ACADEMIC_YEAR_SCHOOL_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
    },
    {
      id: "ce100000-0000-4000-8000-000000000099",
      organization_id: ORG,
      school_id: SCHOOL_B,
    },
  ];
  classes: Row[] = [
    {
      id: ACADEMIC_CLASS_SCHOOL_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      academic_year_id: ACADEMIC_YEAR_SCHOOL_A,
      class_name: "5",
      display_order: 1,
      status: "active",
      created_by: STAFF,
      created_at: "2026-06-15T00:00:00.000Z",
      updated_at: "2026-06-15T00:00:00.000Z",
    },
  ];

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("SELECT * FROM academic_years") && sql.includes("WHERE id = $1")) {
      const row = this.years.find((y) =>
        y.id === args[0] && y.organization_id === args[1] && y.school_id === args[2]
      );
      return (row ? [row] : []) as T[];
    }
    if (sql.includes("FROM classes") && sql.includes("ORDER BY display_order")) {
      return this.classes.filter((c) =>
        c.organization_id === args[0] &&
        c.school_id === args[1] &&
        (args[2] == null || c.academic_year_id === args[2])
      ) as T[];
    }
    if (sql.includes("INSERT INTO classes")) {
      const duplicate = this.classes.some((c) =>
        c.academic_year_id === args[2] && c.class_name === args[3]
      );
      if (duplicate) {
        throw new Error("duplicate key value violates unique constraint classes_academic_year_id_class_name_key");
      }
      const row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        school_id: args[1],
        academic_year_id: args[2],
        class_name: args[3],
        display_order: args[4],
        status: args[5],
        created_by: args[6],
        created_at: "2026-06-15T00:00:00.000Z",
        updated_at: "2026-06-15T00:00:00.000Z",
      };
      this.classes.push(row);
      return [row as T];
    }
    return [] as T[];
  }
}

function asDb(mock: MockClassesDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

Deno.test("ACADEMIC_CLASSES_PROBE_SQL targets classes table", () => {
  assertEquals(ACADEMIC_CLASSES_PROBE_SQL.includes("FROM classes"), true);
});

Deno.test("createClass rejects duplicate class name within academic year", async () => {
  const db = new MockClassesDb();
  await assertRejects(
    () =>
      createClass(asDb(db), ORG, SCHOOL_A, {
        academicYearId: ACADEMIC_YEAR_SCHOOL_A,
        className: "5",
        createdBy: STAFF,
      }),
    DuplicateClassError,
  );
});

Deno.test("listClasses returns only classes for requested school", async () => {
  const db = new MockClassesDb();
  db.classes.push({
    id: "cf100000-0000-4000-8000-000000000099",
    organization_id: ORG,
    school_id: SCHOOL_B,
    academic_year_id: "ce100000-0000-4000-8000-000000000099",
    class_name: "5",
    display_order: 1,
    status: "active",
    created_by: STAFF,
    created_at: "2026-06-15T00:00:00.000Z",
    updated_at: "2026-06-15T00:00:00.000Z",
  });
  const schoolA = await listClasses(asDb(db), ORG, SCHOOL_A);
  assertEquals(schoolA.length, 1);
  assertEquals(schoolA[0]!.school_id, SCHOOL_A);
});
