import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

const MIGRATION_PATH = new URL(
  "../../../migrations/20260615000000_academic_foundation.sql",
  import.meta.url,
);

const sql = await Deno.readTextFile(MIGRATION_PATH);

function extractPolicyExpr(block: string, clause: "USING" | "WITH CHECK"): string {
  const marker = `${clause} (`;
  const start = block.indexOf(marker);
  if (start < 0) return "";
  let depth = 1;
  let i = start + marker.length;
  while (i < block.length && depth > 0) {
    if (block[i] === "(") depth++;
    if (block[i] === ")") depth--;
    i++;
  }
  return block.slice(start + marker.length, i - 1).replace(/\s+/g, " ").trim();
}

Deno.test("Academic 5C.0a migration creates academic_years with required columns", () => {
  assert(sql.includes("CREATE TABLE academic_years"));
  for (const column of [
    "organization_id",
    "school_id",
    "year_label",
    "start_date",
    "end_date",
    "is_current",
    "status",
    "created_by",
    "created_at",
    "updated_at",
  ]) {
    assert(sql.includes(column), `missing academic_years column: ${column}`);
  }
  assert(sql.includes("UNIQUE (school_id, year_label)"));
  assert(sql.includes("CREATE UNIQUE INDEX academic_years_one_current_per_school"));
  assert(sql.includes("CHECK (status IN ('active', 'archived', 'draft'))"));
});

Deno.test("Academic 5C.0a migration creates classes with year-scoped uniqueness", () => {
  assert(sql.includes("CREATE TABLE classes"));
  assert(sql.includes("academic_year_id UUID NOT NULL REFERENCES academic_years"));
  assert(sql.includes("UNIQUE (academic_year_id, class_name)"));
});

Deno.test("Academic 5C.0a migration creates sections with capacity and strength", () => {
  assert(sql.includes("CREATE TABLE sections"));
  assert(sql.includes("capacity INT"));
  assert(sql.includes("strength INT NOT NULL DEFAULT 0"));
  assert(sql.includes("UNIQUE (class_id, section_name)"));
});

Deno.test("Academic 5C.0a migration creates section-based teacher_assignments", () => {
  assert(sql.includes("CREATE TABLE teacher_assignments"));
  const teacherAssignmentsBlock = sql.split("CREATE TABLE teacher_assignments")[1]!
    .split("-- ───")[0]!;
  assert(teacherAssignmentsBlock.includes("section_id UUID NOT NULL REFERENCES sections"));
  assert(!teacherAssignmentsBlock.includes("class_id"));
  assert(sql.includes(
    "CREATE UNIQUE INDEX teacher_assignments_one_primary_class_teacher",
  ));
  assert(sql.includes("CHECK (role IN ('class_teacher', 'subject_teacher', 'coordinator'))"));
});

Deno.test("Academic 5C.0a migration applies FORCE RLS and school-scope policies", () => {
  for (const table of [
    "academic_years",
    "classes",
    "sections",
    "teacher_assignments",
  ]) {
    assert(sql.includes(`ALTER TABLE ${table} FORCE ROW LEVEL SECURITY`));
    assert(sql.includes(`CREATE POLICY ${table}_school_scope`));
  }
  assert(sql.includes("app_current_scope() = 'school'"));
  assert(!sql.includes("app_current_scope() = 'organization'"));
  for (const policy of [
    "academic_years_school_scope",
    "classes_school_scope",
    "sections_school_scope",
    "teacher_assignments_school_scope",
  ]) {
    const tail = sql.split(`CREATE POLICY ${policy}`)[1] ?? "";
    const block = tail.split(/CREATE POLICY |GRANT /)[0] ?? "";
    const using = extractPolicyExpr(block, "USING");
    const withCheck = extractPolicyExpr(block, "WITH CHECK");
    assert(using.length > 0, `${policy} missing USING`);
    assert(withCheck.length > 0, `${policy} missing WITH CHECK`);
    assertEquals(using, withCheck, `${policy} USING/WITH CHECK mismatch`);
  }
});

Deno.test("Academic 5C.0a migration grants erp_tenant SELECT INSERT UPDATE only", () => {
  for (const table of [
    "academic_years",
    "classes",
    "sections",
    "teacher_assignments",
  ]) {
    assert(sql.includes(`GRANT SELECT, INSERT, UPDATE ON ${table} TO erp_tenant`));
  }
  assert(!sql.includes("GRANT DELETE"));
});

Deno.test("Academic 5C.0a migration seeds School A and School B fixtures", () => {
  for (const id of [
    "ce100000-0000-4000-8000-000000000001",
    "ce100000-0000-4000-8000-000000000002",
    "cf100000-0000-4000-8000-000000000001",
    "cf100000-0000-4000-8000-000000000004",
    "d0100000-0000-4000-8000-000000000001",
    "d0100000-0000-4000-8000-000000000004",
    "d2000000-0000-4000-8000-000000000001",
    "d2000000-0000-4000-8000-000000000002",
    "d1000000-0000-4000-8000-000000000001",
    "d1000000-0000-4000-8000-000000000002",
  ]) {
    assert(sql.includes(id), `missing fixture id: ${id}`);
  }
  assertEquals((sql.match(/INSERT INTO academic_years/g) ?? []).length, 2);
  assertEquals((sql.match(/INSERT INTO teacher_assignments/g) ?? []).length, 2);
});
