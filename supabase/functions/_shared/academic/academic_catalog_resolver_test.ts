import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  ACADEMIC_YEAR_SCHOOL_A,
} from "./academic_years_repository.ts";
import { ACADEMIC_CLASS_SCHOOL_A } from "./classes_repository.ts";
import { ACADEMIC_SECTION_SCHOOL_A } from "./sections_repository.ts";
import {
  CatalogMismatchError,
  CatalogNotFoundError,
  normalizeAcademicYearLabel,
  resolveAcademicPlacement,
} from "./academic_catalog_resolver.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const SCHOOL_B = "a2000000-0000-4000-8000-000000000002";
const YEAR_B = "ce100000-0000-4000-8000-000000000002";

type Row = Record<string, unknown>;

class MockCatalogDb {
  years: Row[] = [
    {
      id: ACADEMIC_YEAR_SCHOOL_A,
      organization_id: ORG,
      school_id: SCHOOL_A,
      year_label: "2026-27",
      status: "active",
    },
    {
      id: YEAR_B,
      organization_id: ORG,
      school_id: SCHOOL_B,
      year_label: "2026-27",
      status: "active",
    },
    {
      id: "ce100000-0000-4000-8000-000000000099",
      organization_id: ORG,
      school_id: SCHOOL_A,
      year_label: "2025-26",
      status: "archived",
    },
    {
      id: "ce100000-0000-4000-8000-000000000088",
      organization_id: ORG,
      school_id: SCHOOL_A,
      year_label: "2027-28",
      status: "draft",
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
      id: "cf100000-0000-4000-8000-000000000099",
      organization_id: ORG,
      school_id: SCHOOL_B,
      academic_year_id: YEAR_B,
      class_name: "5",
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
    if (sql.includes("SELECT id, class_name, status FROM classes")) {
      const matches = this.classes.filter((c) =>
        c.organization_id === args[0] &&
        c.school_id === args[1] &&
        c.academic_year_id === args[2] &&
        c.class_name === args[3]
      );
      return matches.slice(0, 2) as T[];
    }
    if (sql.includes("SELECT * FROM classes") && sql.includes("WHERE id = $1")) {
      const row = this.classes.find((c) =>
        c.id === args[0] && c.organization_id === args[1] && c.school_id === args[2]
      );
      return (row ? [row] : []) as T[];
    }
    if (sql.includes("SELECT id, section_name, status FROM sections")) {
      const matches = this.sections.filter((s) =>
        s.organization_id === args[0] &&
        s.school_id === args[1] &&
        s.class_id === args[2] &&
        s.section_name === args[3]
      );
      return matches.slice(0, 2) as T[];
    }
    if (sql.includes("SELECT * FROM sections") && sql.includes("WHERE id = $1")) {
      const row = this.sections.find((s) =>
        s.id === args[0] && s.organization_id === args[1] && s.school_id === args[2]
      );
      return (row ? [row] : []) as T[];
    }
    return [] as T[];
  }

  async queryCount(): Promise<number> {
    return 0;
  }
}

const ctx = (db: TenantQueryClient) => ({
  db,
  organizationId: ORG,
  schoolId: SCHOOL_A,
});

Deno.test("normalizeAcademicYearLabel matches Flutter behavior", () => {
  assertEquals(normalizeAcademicYearLabel("2026–27"), "2026-27");
  assertEquals(normalizeAcademicYearLabel("2026—27"), "2026-27");
  assertEquals(normalizeAcademicYearLabel(" 2026 - 27 "), "2026-27");
});

Deno.test("resolveAcademicPlacement label-only resolves canonical labels (R10)", async () => {
  const db = new MockCatalogDb() as unknown as TenantQueryClient;
  const result = await resolveAcademicPlacement(
    ctx(db),
    { academicYear: "2026–27", className: "5", sectionName: "A" },
    { mode: "full" },
  );
  assertEquals(result.academicYearId, ACADEMIC_YEAR_SCHOOL_A);
  assertEquals(result.academicYear, "2026-27");
  assertEquals(result.classId, ACADEMIC_CLASS_SCHOOL_A);
  assertEquals(result.className, "5");
  assertEquals(result.sectionId, ACADEMIC_SECTION_SCHOOL_A);
  assertEquals(result.sectionName, "A");
});

Deno.test("resolveAcademicPlacement rejects class label without year context (R1)", async () => {
  const db = new MockCatalogDb() as unknown as TenantQueryClient;
  await assertRejects(
    () =>
      resolveAcademicPlacement(
        ctx(db),
        { className: "5" },
        { mode: "full" },
      ),
    CatalogMismatchError,
  );
});

Deno.test("resolveAcademicPlacement rejects archived and draft years (R2)", async () => {
  const db = new MockCatalogDb() as unknown as TenantQueryClient;
  await assertRejects(
    () =>
      resolveAcademicPlacement(
        ctx(db),
        { academicYear: "2025-26", className: "5" },
        { mode: "full" },
      ),
    CatalogMismatchError,
  );
  await assertRejects(
    () =>
      resolveAcademicPlacement(
        ctx(db),
        { academicYear: "2027-28", className: "5" },
        { mode: "full" },
      ),
    CatalogMismatchError,
  );
});

Deno.test("resolveAcademicPlacement wrong-school UUID returns CATALOG_NOT_FOUND (R9)", async () => {
  const db = new MockCatalogDb() as unknown as TenantQueryClient;
  await assertRejects(
    () =>
      resolveAcademicPlacement(
        ctx(db),
        { academicYearId: YEAR_B },
        { mode: "year_only" },
      ),
    CatalogNotFoundError,
  );
});

Deno.test("resolveAcademicPlacement admissions empty year leaves FKs null (R5)", async () => {
  const db = new MockCatalogDb() as unknown as TenantQueryClient;
  const result = await resolveAcademicPlacement(
    ctx(db),
    { academicYear: "", className: "5", sectionName: "A" },
    { mode: "admissions" },
  );
  assertEquals(result.academicYearId, null);
  assertEquals(result.classId, null);
  assertEquals(result.sectionId, null);
  assertEquals(result.className, "5");
});

Deno.test("resolveAcademicPlacement empty section yields null section_id (R6)", async () => {
  const db = new MockCatalogDb() as unknown as TenantQueryClient;
  const result = await resolveAcademicPlacement(
    ctx(db),
    { academicYear: "2026-27", className: "5", sectionName: "  " },
    { mode: "full" },
  );
  assertEquals(result.sectionId, null);
  assertEquals(result.sectionName, null);
});

Deno.test("resolveAcademicPlacement ID label mismatch returns CATALOG_MISMATCH", async () => {
  const db = new MockCatalogDb() as unknown as TenantQueryClient;
  await assertRejects(
    () =>
      resolveAcademicPlacement(
        ctx(db),
        {
          academicYearId: ACADEMIC_YEAR_SCHOOL_A,
          academicYear: "2025-26",
          className: "5",
        },
        { mode: "full" },
      ),
    CatalogMismatchError,
  );
});

Deno.test("resolveAcademicPlacement year_only mode resolves finance year", async () => {
  const db = new MockCatalogDb() as unknown as TenantQueryClient;
  const result = await resolveAcademicPlacement(
    ctx(db),
    { academicYear: "2026-27" },
    { mode: "year_only" },
  );
  assertEquals(result.academicYearId, ACADEMIC_YEAR_SCHOOL_A);
  assertEquals(result.academicYear, "2026-27");
  assertEquals(result.classId, null);
});
