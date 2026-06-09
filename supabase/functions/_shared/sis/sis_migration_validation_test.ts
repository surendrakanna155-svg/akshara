import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

const MIGRATION_PATH = new URL(
  "../../../migrations/20260613000000_sis_slice0_foundation.sql",
  import.meta.url,
);

const sql = await Deno.readTextFile(MIGRATION_PATH);

Deno.test("SIS 5A0 migration creates student_profiles with required columns", () => {
  assert(sql.includes("CREATE TABLE student_profiles"));
  for (const column of [
    "organization_id",
    "school_id",
    "student_id",
    "admission_number",
    "date_of_birth",
    "gender",
    "blood_group",
    "address",
    "city",
    "state",
    "postal_code",
    "country",
    "created_by",
    "created_at",
    "updated_at",
  ]) {
    assert(sql.includes(column), `missing student_profiles column: ${column}`);
  }
  assert(sql.includes("UNIQUE (student_id)"));
  assert(sql.includes("REFERENCES students (id)"));
});

Deno.test("SIS 5A0 migration creates sis_student_enrollments with required columns", () => {
  assert(sql.includes("CREATE TABLE sis_student_enrollments"));
  for (const column of [
    "academic_year",
    "class_name",
    "section_name",
    "roll_number",
    "is_current",
  ]) {
    assert(sql.includes(column), `missing sis_student_enrollments column: ${column}`);
  }
  assert(sql.includes("UNIQUE (student_id, academic_year)"));
});

Deno.test("SIS 5A0 migration extends students without altering identity structure", () => {
  assert(sql.includes("ALTER TABLE students"));
  assert(sql.includes("ADD COLUMN IF NOT EXISTS created_by"));
  assert(!sql.includes("DROP COLUMN"));
  assert(!sql.includes("ALTER COLUMN student_code"));
});

Deno.test("SIS 5A0 migration applies FORCE RLS and school-scope policies", () => {
  assert(sql.includes("ALTER TABLE student_profiles FORCE ROW LEVEL SECURITY"));
  assert(sql.includes("ALTER TABLE sis_student_enrollments FORCE ROW LEVEL SECURITY"));
  assert(sql.includes("CREATE POLICY student_profiles_school_scope"));
  assert(sql.includes("CREATE POLICY sis_student_enrollments_school_scope"));
  assert(sql.includes("app_current_scope() = 'school'"));
  assert(!sql.includes("app_current_scope() = 'organization'"));
  assert(!sql.includes("app_current_scope() = 'parent'"));
});

Deno.test("SIS 5A0 migration grants erp_tenant DML on new tables", () => {
  assert(sql.includes("GRANT SELECT, INSERT, UPDATE ON student_profiles TO erp_tenant"));
  assert(sql.includes("GRANT SELECT, INSERT, UPDATE ON sis_student_enrollments TO erp_tenant"));
});

Deno.test("SIS 5A0 migration adds school UPDATE policies on students and guardians", () => {
  assert(sql.includes("CREATE POLICY students_school_update"));
  assert(sql.includes("CREATE POLICY student_guardians_school_update"));
  assert(sql.includes("GRANT UPDATE ON students, student_guardians TO erp_tenant"));
});

Deno.test("SIS 5A0 migration seeds School A and School B probe fixtures", () => {
  assert(sql.includes("bc000000-0000-4000-8000-000000000001"));
  assert(sql.includes("bc000000-0000-4000-8000-000000000002"));
  assert(sql.includes("bc100000-0000-4000-8000-000000000001"));
  assert(sql.includes("bc100000-0000-4000-8000-000000000002"));
  assert(sql.includes("a4000000-0000-4000-8000-000000000001"));
  assert(sql.includes("a4000000-0000-4000-8000-000000000002"));
  assertEquals((sql.match(/INSERT INTO student_profiles/g) ?? []).length, 1);
  assertEquals((sql.match(/INSERT INTO sis_student_enrollments/g) ?? []).length, 1);
});
