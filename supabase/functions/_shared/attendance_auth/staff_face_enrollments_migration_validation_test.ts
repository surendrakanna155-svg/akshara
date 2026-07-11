// Static validation of migration 20260877 (P1-PROD-22 SLICE 1: staff_face_enrollments
// evolved to the governed enrollment shape), mirroring the ai_call_reservations
// migration-validation pattern.
//
// This migration ALTERs a table that already existed (staff_face_enrollments,
// created by migration 20260820) rather than creating a fresh one — see its
// header comment for why. That means it legitimately contains DROP POLICY /
// DROP CONSTRAINT / DROP INDEX / DROP COLUMN statements against its OWN table
// (evolving a shape it owns), so this test does not assert "no DROP anything"
// verbatim the way ai_call_reservations_migration_validation_test.ts does.
// Instead it guards the equivalent, adapted property: the migration NEVER drops
// the table itself, and NEVER touches the sibling staff_attendance tables it
// does not own (staff_check_ins, staff_attendance_requests,
// school_attendance_geofences — each owned by a different migration) — the same
// "don't touch what you don't own" class of bug the ai_call_reservations guard
// exists to catch.

import { assert } from "jsr:@std/assert@1";

const MIGRATION = new URL(
  "../../../migrations/20260877000000_staff_face_enrollments.sql",
  import.meta.url,
);
const sql = await Deno.readTextFile(MIGRATION);
/** Statements only — comments legitimately narrate sibling tables/columns, so
 * both whole-line and trailing `--` comments are stripped before matching. */
const statements = sql
  .split("\n")
  .filter((line) => !line.trimStart().startsWith("--"))
  .map((line) => line.split("--")[0]!)
  .join("\n");

Deno.test("20260877 never drops the table, and never touches a sibling staff_attendance table it doesn't own", () => {
  assert(!statements.includes("DROP TABLE"), "must never drop a table");
  for (const sibling of ["staff_check_ins", "staff_attendance_requests", "school_attendance_geofences"]) {
    assert(!statements.includes(sibling), `must not touch sibling table ${sibling}`);
  }
});

Deno.test("20260877 keeps RLS ENABLE+FORCE on staff_face_enrollments", () => {
  assert(statements.includes("ALTER TABLE staff_face_enrollments ENABLE ROW LEVEL SECURITY"));
  assert(statements.includes("ALTER TABLE staff_face_enrollments FORCE ROW LEVEL SECURITY"));
});

Deno.test("20260877 widens RLS to the org+school wall (USING + WITH CHECK, intel_* pattern)", () => {
  assert(statements.includes("CREATE POLICY staff_face_enrollments_school_scope ON staff_face_enrollments"));
  assert(statements.includes("organization_id = app_current_tenant_id()"));
  assert(statements.includes("app_current_scope() = 'school'"));
  assert(statements.includes("school_id = app_current_school_id()"));
  // Both USING and WITH CHECK are present (not read-only, not write-only).
  assert(/USING\s*\(\s*organization_id = app_current_tenant_id\(\)/.test(statements));
  assert(/WITH CHECK\s*\(\s*organization_id = app_current_tenant_id\(\)/.test(statements));
});

Deno.test("20260877 keeps the partial UNIQUE index — ONE active enrollment per org+school+user", () => {
  assert(statements.includes("CREATE UNIQUE INDEX idx_staff_face_active"));
  assert(statements.includes("ON staff_face_enrollments (organization_id, school_id, user_id)"));
  assert(statements.includes("WHERE status = 'active'"));
});

Deno.test("20260877 gives status a lifecycle CHECK constraint (active|revoked)", () => {
  assert(statements.includes("CHECK (status IN ('active', 'revoked'))"));
});

Deno.test("20260877 tightens embedding_dims to 64..1024", () => {
  assert(statements.includes("CHECK (embedding_dims BETWEEN 64 AND 1024)"));
});

Deno.test("20260877 grants no DELETE — revocation is an UPDATE, the row is kept as an audit record", () => {
  assert(statements.includes("GRANT SELECT, INSERT, UPDATE ON staff_face_enrollments TO erp_tenant"));
  assert(!/GRANT[^;]*DELETE[^;]*ON staff_face_enrollments/.test(statements));
});

Deno.test("20260877 converts embedding to a plain REAL[] (no pgvector dependency)", () => {
  assert(statements.includes("ALTER COLUMN embedding TYPE REAL[]"));
  assert(!statements.includes("CREATE EXTENSION"), "must not depend on pgvector being provisioned");
});
