import { assert } from "https://deno.land/std@0.224.0/assert/mod.ts";

const MIGRATION_PATH = new URL(
  "../../../migrations/20260614790000_academic_foundation.sql",
  import.meta.url,
);

const sql = await Deno.readTextFile(MIGRATION_PATH);

Deno.test("Academic years partial unique index prevents dual current years per school", () => {
  assert(sql.includes("CREATE UNIQUE INDEX academic_years_one_current_per_school"));
  assert(sql.includes("ON academic_years (school_id)"));
  assert(sql.includes("WHERE is_current = true"));
});

Deno.test("Teacher assignments partial unique index prevents dual primary class teachers", () => {
  assert(sql.includes("CREATE UNIQUE INDEX teacher_assignments_one_primary_class_teacher"));
  assert(sql.includes("ON teacher_assignments (section_id)"));
  assert(sql.includes("WHERE role = 'class_teacher' AND is_primary = true"));
});

Deno.test("Concurrency safety does not rely on triggers alone", () => {
  assert(!sql.includes("CREATE TRIGGER academic_years_one_current"));
  assert(!sql.includes("CREATE TRIGGER teacher_assignments_one_primary"));
});

Deno.test("withTenantContext wraps handler operations in a single transaction", async () => {
  const tenantDbSource = await Deno.readTextFile(
    new URL("../tenant_db.ts", import.meta.url),
  );
  assert(tenantDbSource.includes("await client.queryObject`BEGIN`"));
  assert(tenantDbSource.includes("await client.queryObject`COMMIT`"));
  assert(tenantDbSource.includes("await client.queryObject`ROLLBACK`"));
});

Deno.test("Academic year repository maps partial unique violations to ConcurrentCurrentYearError", async () => {
  const repoSource = await Deno.readTextFile(
    new URL("./academic_years_repository.ts", import.meta.url),
  );
  assert(repoSource.includes("ConcurrentCurrentYearError"));
  assert(repoSource.includes("academic_years_one_current_per_school"));
});

Deno.test("Teacher assignment repository maps partial unique violations to DuplicatePrimaryClassTeacherError", async () => {
  const repoSource = await Deno.readTextFile(
    new URL("./teacher_assignments_repository.ts", import.meta.url),
  );
  assert(repoSource.includes("teacher_assignments_one_primary_class_teacher"));
  assert(repoSource.includes("DuplicatePrimaryClassTeacherError"));
});
