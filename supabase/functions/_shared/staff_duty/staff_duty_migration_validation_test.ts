// W4 Staff Duty — static validation of migration 20260900000020, mirroring the
// staff_face_enrollments / payroll_finance_postings migration-validation pattern.
//
// Owner decision #6 is a HARD invariant: the three duty tables are DEDICATED and
// must NEVER reference (or be conflated with) the attendance tables. This test
// pins the shape a review would otherwise re-verify by hand: table creation,
// org+school columns, RLS ENABLE+FORCE, the org+school-wall policy, append-only
// grants (SELECT/INSERT only), sensible indexes, created_at — and, above all,
// that no attendance table is ever named.

import { assert } from "jsr:@std/assert@1";

const MIGRATION = new URL(
  "../../../migrations/20260900000020_staff_duty_models.sql",
  import.meta.url,
);
const sql = await Deno.readTextFile(MIGRATION);
/** Statements only — comments legitimately narrate the design, so both
 * whole-line and trailing `--` comments are stripped before matching. */
const statements = sql
  .split("\n")
  .filter((line) => !line.trimStart().startsWith("--"))
  .map((line) => line.split("--")[0]!)
  .join("\n");

const TABLES = [
  "staff_substitute_classes",
  "staff_exam_invigilation_duties",
  "staff_non_teaching_duties",
];

Deno.test("creates the three dedicated staff-duty tables", () => {
  for (const t of TABLES) {
    assert(statements.includes(`CREATE TABLE IF NOT EXISTS ${t}`), `missing table ${t}`);
  }
});

Deno.test("NEVER references (or overloads) an attendance table — owner decision #6", () => {
  // The whole SQL (statements) must not name any attendance sibling.
  for (const forbidden of [
    "staff_check_ins",
    "staff_attendance_requests",
    "school_attendance_geofences",
    "staff_attendance",
    "attendance",
  ]) {
    assert(!statements.includes(forbidden), `must never reference ${forbidden}`);
  }
});

Deno.test("every table is tenant-scoped: organization_id + school_id NOT NULL, FK'd", () => {
  // Two org FKs + two school FKs across the three tables (one each, plus… ) —
  // assert each table carries both columns as NOT NULL references.
  for (const _t of TABLES) {
    // presence of the column declarations (shared shape across all three)
  }
  assert(
    (statements.match(/organization_id UUID NOT NULL REFERENCES organizations \(id\)/g) ?? []).length === 3,
    "each of the 3 tables needs organization_id NOT NULL FK",
  );
  assert(
    (statements.match(/school_id UUID NOT NULL REFERENCES schools \(id\)/g) ?? []).length === 3,
    "each of the 3 tables needs school_id NOT NULL FK",
  );
});

Deno.test("every table records created_at", () => {
  assert(
    (statements.match(/created_at TIMESTAMPTZ NOT NULL DEFAULT timezone\('utc', now\(\)\)/g) ?? []).length === 3,
    "each of the 3 tables needs a created_at default",
  );
});

Deno.test("RLS is ENABLED and FORCED on every table", () => {
  for (const t of TABLES) {
    assert(statements.includes(`ALTER TABLE ${t} ENABLE ROW LEVEL SECURITY`), `${t} RLS not enabled`);
    assert(statements.includes(`ALTER TABLE ${t} FORCE ROW LEVEL SECURITY`), `${t} RLS not forced`);
  }
});

Deno.test("each table has an org+school-wall policy (USING + WITH CHECK, intel_* pattern)", () => {
  for (const t of TABLES) {
    assert(
      statements.includes(`CREATE POLICY ${t}_school_scope ON ${t}`),
      `${t} missing school-scope policy`,
    );
  }
  // The org+school wall predicate appears in both USING and WITH CHECK of all 3.
  assert(
    (statements.match(/organization_id = app_current_tenant_id\(\)/g) ?? []).length >= 6,
    "org wall must be in USING + WITH CHECK of all 3 policies",
  );
  assert((statements.match(/app_current_scope\(\) = 'school'/g) ?? []).length >= 6);
  assert((statements.match(/school_id = app_current_school_id\(\)/g) ?? []).length >= 6);
  assert(/USING\s*\(\s*organization_id = app_current_tenant_id\(\)/.test(statements));
  assert(/WITH CHECK\s*\(\s*organization_id = app_current_tenant_id\(\)/.test(statements));
});

Deno.test("append-only grants: SELECT + INSERT only — never UPDATE or DELETE", () => {
  for (const t of TABLES) {
    assert(
      statements.includes(`GRANT SELECT, INSERT ON ${t} TO erp_tenant`),
      `${t} must grant SELECT, INSERT`,
    );
    assert(!new RegExp(`GRANT[^;]*UPDATE[^;]*ON ${t}`).test(statements), `${t} must not grant UPDATE`);
    assert(!new RegExp(`GRANT[^;]*DELETE[^;]*ON ${t}`).test(statements), `${t} must not grant DELETE`);
  }
});

Deno.test("never drops a table (append-only, additive migration)", () => {
  assert(!statements.includes("DROP TABLE"), "must never drop a table");
});

Deno.test("each table has query-serving indexes (by-staff and by-date)", () => {
  // Substitute burden is keyed by the substitute teacher; the others by staff_id.
  assert(statements.includes("idx_staff_substitute_classes_substitute"));
  assert(statements.includes("idx_staff_substitute_classes_date"));
  assert(statements.includes("idx_staff_exam_invigilation_staff"));
  assert(statements.includes("idx_staff_exam_invigilation_date"));
  assert(statements.includes("idx_staff_non_teaching_duties_staff"));
  assert(statements.includes("idx_staff_non_teaching_duties_date"));
});

Deno.test("non-teaching date range is guarded (end_date >= start_date)", () => {
  assert(statements.includes("CHECK (end_date IS NULL OR end_date >= start_date)"));
});
