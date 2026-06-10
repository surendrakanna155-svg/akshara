import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { ACADEMIC_CLASS_SCHOOL_A } from "./classes_repository.ts";
import {
  ACADEMIC_SECTIONS_PROBE_SQL,
  ACADEMIC_SECTION_SCHOOL_A,
  createSection,
  DuplicateSectionError,
  listSections,
  ValidationError,
} from "./sections_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const SCHOOL_B = "a2000000-0000-4000-8000-000000000002";
const STAFF = "a3000000-0000-4000-8000-000000000001";

type Row = Record<string, unknown>;

class MockSectionsDb {
  classes: Row[] = [
    {
      id: ACADEMIC_CLASS_SCHOOL_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
    },
    {
      id: "cf100000-0000-4000-8000-000000000099",
      organization_id: ORG,
      school_id: SCHOOL_B,
    },
  ];
  sections: Row[] = [
    {
      id: ACADEMIC_SECTION_SCHOOL_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      class_id: ACADEMIC_CLASS_SCHOOL_A,
      section_name: "A",
      capacity: 40,
      strength: 0,
      status: "active",
      created_by: STAFF,
      created_at: "2026-06-15T00:00:00.000Z",
      updated_at: "2026-06-15T00:00:00.000Z",
    },
    {
      id: "d0100000-0000-4000-8000-000000000099",
      organization_id: ORG,
      school_id: SCHOOL_B,
      class_id: "cf100000-0000-4000-8000-000000000099",
      section_name: "A",
      capacity: 40,
      strength: 0,
      status: "active",
      created_by: STAFF,
      created_at: "2026-06-15T00:00:00.000Z",
      updated_at: "2026-06-15T00:00:00.000Z",
    },
  ];

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("SELECT * FROM classes") && sql.includes("WHERE id = $1")) {
      const row = this.classes.find((c) =>
        c.id === args[0] && c.organization_id === args[1] && c.school_id === args[2]
      );
      return (row ? [row] : []) as T[];
    }
    if (sql.includes("FROM sections") && sql.includes("ORDER BY section_name")) {
      return this.sections.filter((s) =>
        s.organization_id === args[0] &&
        s.school_id === args[1] &&
        (args[2] == null || s.class_id === args[2])
      ) as T[];
    }
    if (sql.includes("INSERT INTO sections")) {
      const duplicate = this.sections.some((s) =>
        s.class_id === args[2] && s.section_name === args[3]
      );
      if (duplicate) {
        throw new Error("duplicate key value violates unique constraint sections_class_id_section_name_key");
      }
      const row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        school_id: args[1],
        class_id: args[2],
        section_name: args[3],
        capacity: args[4],
        strength: args[5],
        status: args[6],
        created_by: args[7],
        created_at: "2026-06-15T00:00:00.000Z",
        updated_at: "2026-06-15T00:00:00.000Z",
      };
      this.sections.push(row);
      return [row as T];
    }
    return [] as T[];
  }
}

function asDb(mock: MockSectionsDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

Deno.test("ACADEMIC_SECTIONS_PROBE_SQL targets sections table", () => {
  assertEquals(ACADEMIC_SECTIONS_PROBE_SQL.includes("FROM sections"), true);
});

Deno.test("createSection rejects duplicate section name within class", async () => {
  const db = new MockSectionsDb();
  await assertRejects(
    () =>
      createSection(asDb(db), ORG, SCHOOL_A, {
        classId: ACADEMIC_CLASS_SCHOOL_A,
        sectionName: "A",
        createdBy: STAFF,
      }),
    DuplicateSectionError,
  );
});

Deno.test("createSection defaults strength to zero", async () => {
  const db = new MockSectionsDb();
  const created = await createSection(asDb(db), ORG, SCHOOL_A, {
    classId: ACADEMIC_CLASS_SCHOOL_A,
    sectionName: "B",
    createdBy: STAFF,
  });
  assertEquals(created.strength, 0);
});

Deno.test("createSection rejects empty section name", async () => {
  const db = new MockSectionsDb();
  await assertRejects(
    () =>
      createSection(asDb(db), ORG, SCHOOL_A, {
        classId: ACADEMIC_CLASS_SCHOOL_A,
        sectionName: "   ",
        createdBy: STAFF,
      }),
    ValidationError,
  );
});

Deno.test("listSections isolates rows by school", async () => {
  const db = new MockSectionsDb();
  const schoolA = await listSections(asDb(db), ORG, SCHOOL_A);
  const schoolB = await listSections(asDb(db), ORG, SCHOOL_B);
  assertEquals(schoolA.length, 1);
  assertEquals(schoolB.length, 1);
  assertEquals(schoolA[0]!.school_id, SCHOOL_A);
  assertEquals(schoolB[0]!.school_id, SCHOOL_B);
});
