import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

const MIGRATION_PATH = new URL(
  "../../../migrations/20260614790000_academic_foundation.sql",
  import.meta.url,
);

const sql = await Deno.readTextFile(MIGRATION_PATH);

const EXPECTED_INDEXES = [
  "academic_years_one_current_per_school",
  "idx_academic_years_org_school",
  "idx_classes_org_school",
  "idx_classes_academic_year",
  "idx_sections_org_school",
  "idx_sections_class",
  "teacher_assignments_one_primary_class_teacher",
  "idx_teacher_assignments_org_school",
  "idx_teacher_assignments_teacher",
  "idx_teacher_assignments_section",
] as const;

Deno.test("Academic migration defines expected lookup and constraint indexes", () => {
  for (const indexName of EXPECTED_INDEXES) {
    assert(sql.includes(indexName), `missing index: ${indexName}`);
  }
  assertEquals((sql.match(/CREATE UNIQUE INDEX/g) ?? []).length, 2);
  assertEquals((sql.match(/CREATE INDEX/g) ?? []).length, 8);
});

Deno.test("Academic indexes cover organization, school, year, section, and teacher lookups", () => {
  assert(sql.includes("ON academic_years (organization_id, school_id)"));
  assert(sql.includes("ON classes (academic_year_id)"));
  assert(sql.includes("ON sections (class_id)"));
  assert(sql.includes("ON teacher_assignments (teacher_id)"));
  assert(sql.includes("ON teacher_assignments (section_id)"));
});

Deno.test("Academic indexes avoid redundant single-column school_id duplicates", () => {
  assert(!sql.includes("CREATE INDEX idx_academic_years_school_id"));
  assert(!sql.includes("CREATE INDEX idx_classes_school_id"));
});

Deno.test("Table-level UNIQUE constraints complement partial unique indexes", () => {
  assert(sql.includes("UNIQUE (school_id, year_label)"));
  assert(sql.includes("UNIQUE (academic_year_id, class_name)"));
  assert(sql.includes("UNIQUE (class_id, section_name)"));
});
