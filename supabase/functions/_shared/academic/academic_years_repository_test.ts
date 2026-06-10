import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  ACADEMIC_YEARS_PROBE_SQL,
  ACADEMIC_YEAR_SCHOOL_A,
  ConcurrentCurrentYearError,
  createAcademicYear,
  DuplicateAcademicYearLabelError,
  listAcademicYears,
  updateAcademicYear,
} from "./academic_years_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const SCHOOL_B = "a2000000-0000-4000-8000-000000000002";
const STAFF = "a3000000-0000-4000-8000-000000000001";

type Row = Record<string, unknown>;

class MockAcademicYearsDb {
  clearCurrentEnabled = true;
  years: Row[] = [
    {
      id: ACADEMIC_YEAR_SCHOOL_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      year_label: "2026-27",
      start_date: "2026-04-01",
      end_date: "2027-03-31",
      is_current: true,
      status: "active",
      created_by: STAFF,
      created_at: "2026-06-15T00:00:00.000Z",
      updated_at: "2026-06-15T00:00:00.000Z",
    },
    {
      id: "ce100000-0000-4000-8000-000000000099",
      organization_id: ORG,
      school_id: SCHOOL_B,
      year_label: "2026-27",
      start_date: "2026-04-01",
      end_date: "2027-03-31",
      is_current: true,
      status: "active",
      created_by: STAFF,
      created_at: "2026-06-15T00:00:00.000Z",
      updated_at: "2026-06-15T00:00:00.000Z",
    },
  ];

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
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
    if (sql.includes("UPDATE academic_years SET is_current = false")) {
      if (!this.clearCurrentEnabled) return [] as T[];
      for (const y of this.years) {
        if (
          y.organization_id === args[0] &&
          y.school_id === args[1] &&
          y.is_current === true &&
          (args[2] == null || y.id !== args[2])
        ) {
          y.is_current = false;
        }
      }
      return [] as T[];
    }
    if (sql.includes("INSERT INTO academic_years")) {
      const duplicate = this.years.some((y) =>
        y.school_id === args[1] && y.year_label === args[2]
      );
      if (duplicate) {
        throw new Error("duplicate key value violates unique constraint academic_years_school_id_year_label_key");
      }
      if (args[5] === true) {
        const existingCurrent = this.years.some((y) =>
          y.school_id === args[1] && y.is_current === true
        );
        if (existingCurrent) {
          throw new Error(
            "duplicate key value violates unique constraint academic_years_one_current_per_school",
          );
        }
      }
      const row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        school_id: args[1],
        year_label: args[2],
        start_date: args[3],
        end_date: args[4],
        is_current: args[5],
        status: args[6],
        created_by: args[7],
        created_at: "2026-06-15T00:00:00.000Z",
        updated_at: "2026-06-15T00:00:00.000Z",
      };
      this.years.push(row);
      return [row as T];
    }
    if (sql.includes("UPDATE academic_years SET") && sql.includes("year_label = COALESCE")) {
      const idx = this.years.findIndex((y) =>
        y.id === args[0] && y.organization_id === args[1] && y.school_id === args[2]
      );
      if (idx < 0) return [] as T[];
      if (args[3] != null) this.years[idx]!.year_label = args[3];
      if (args[6] != null) this.years[idx]!.is_current = args[6];
      return [this.years[idx] as T];
    }
    return [] as T[];
  }
}

function asDb(mock: MockAcademicYearsDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

Deno.test("ACADEMIC_YEARS_PROBE_SQL targets academic_years table", () => {
  assertEquals(ACADEMIC_YEARS_PROBE_SQL.includes("FROM academic_years"), true);
});

Deno.test("createAcademicYear rejects duplicate year label per school", async () => {
  const db = new MockAcademicYearsDb();
  await assertRejects(
    () =>
      createAcademicYear(asDb(db), ORG, SCHOOL_A, {
        yearLabel: "2026-27",
        startDate: "2026-04-01",
        endDate: "2027-03-31",
        createdBy: STAFF,
      }),
    DuplicateAcademicYearLabelError,
  );
});

Deno.test("createAcademicYear clears existing current year in same school", async () => {
  const db = new MockAcademicYearsDb();
  const created = await createAcademicYear(asDb(db), ORG, SCHOOL_A, {
    yearLabel: "2027-28",
    startDate: "2027-04-01",
    endDate: "2028-03-31",
    isCurrent: true,
    createdBy: STAFF,
  });
  const currentInA = db.years.filter((y) => y.school_id === SCHOOL_A && y.is_current);
  assertEquals(currentInA.length, 1);
  assertEquals(currentInA[0]!.id, created.id);
});

Deno.test("listAcademicYears isolates rows by school", async () => {
  const db = new MockAcademicYearsDb();
  const schoolA = await listAcademicYears(asDb(db), ORG, SCHOOL_A);
  const schoolB = await listAcademicYears(asDb(db), ORG, SCHOOL_B);
  assertEquals(schoolA.every((y) => y.school_id === SCHOOL_A), true);
  assertEquals(schoolB.every((y) => y.school_id === SCHOOL_B), true);
  assertEquals(schoolA.length, 1);
  assertEquals(schoolB.length, 1);
});

Deno.test("updateAcademicYear can mark a year current and demote prior current", async () => {
  const db = new MockAcademicYearsDb();
  const draft = await createAcademicYear(asDb(db), ORG, SCHOOL_A, {
    yearLabel: "2025-26",
    startDate: "2025-04-01",
    endDate: "2026-03-31",
    isCurrent: false,
    createdBy: STAFF,
  });
  await updateAcademicYear(asDb(db), ORG, SCHOOL_A, draft.id as string, {
    isCurrent: true,
  });
  const current = db.years.filter((y) => y.school_id === SCHOOL_A && y.is_current);
  assertEquals(current.length, 1);
  assertEquals(current[0]!.year_label, "2025-26");
});

Deno.test("createAcademicYear maps partial unique current-year violation", async () => {
  const db = new MockAcademicYearsDb();
  db.clearCurrentEnabled = false;
  await assertRejects(
    () =>
      createAcademicYear(asDb(db), ORG, SCHOOL_A, {
        yearLabel: "2027-28",
        startDate: "2027-04-01",
        endDate: "2028-03-31",
        isCurrent: true,
        createdBy: STAFF,
      }),
    ConcurrentCurrentYearError,
  );
});
