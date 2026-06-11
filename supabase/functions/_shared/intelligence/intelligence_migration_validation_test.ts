import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

const FOUNDATION_PATH = new URL(
  "../../../migrations/20260621000000_intelligence_layer_foundation.sql",
  import.meta.url,
);
const RECOVERY_PATH = new URL(
  "../../../migrations/20260627100000_staging_intelligence_layer_recovery.sql",
  import.meta.url,
);
const PERMISSIONS_PATH = new URL(
  "../../../migrations/20260621000001_intelligence_permissions.sql",
  import.meta.url,
);
const MIGRATIONS_DIR = new URL("../../../migrations/", import.meta.url);

const foundationSql = await Deno.readTextFile(FOUNDATION_PATH);
const recoverySql = await Deno.readTextFile(RECOVERY_PATH);
const permissionsSql = await Deno.readTextFile(PERMISSIONS_PATH);

Deno.test("intelligence foundation migration creates intel_student_risk_snapshots", () => {
  assert(foundationSql.includes("CREATE TABLE intel_student_risk_snapshots"));
  assert(foundationSql.includes("REFERENCES students (id)"));
  assert(foundationSql.includes("intel_student_risk_school_scope"));
  assert(foundationSql.includes("GRANT SELECT, INSERT, UPDATE, DELETE ON intel_student_risk_snapshots"));
});

Deno.test("staging recovery migration is idempotent for intelligence layer", () => {
  assert(recoverySql.includes("CREATE TABLE IF NOT EXISTS intel_student_risk_snapshots"));
  assert(recoverySql.includes("CREATE INDEX IF NOT EXISTS idx_intel_student_risk_school_class"));
  assert(recoverySql.includes("CREATE TABLE IF NOT EXISTS intel_communication_drafts"));
  assert(recoverySql.includes("CREATE TABLE IF NOT EXISTS intel_parent_guidance_reports"));
  assert(recoverySql.includes("INSERT INTO permission_definitions"));
  assert(recoverySql.includes("ON CONFLICT (id) DO NOTHING"));
  assertEquals(
    (recoverySql.match(/CREATE TABLE IF NOT EXISTS/g) ?? []).length >= 3,
    true,
  );
});

Deno.test("intelligence permissions migration targets permission_definitions", () => {
  assert(permissionsSql.includes("INSERT INTO permission_definitions"));
  assert(!permissionsSql.includes("INSERT INTO permissions ("));
  assert(permissionsSql.includes("viewStudentRisk"));
  assert(permissionsSql.includes("role_slug, permission_slug"));
});

Deno.test("no migration inserts into deprecated permissions table", async () => {
  const bad: string[] = [];
  for await (const entry of Deno.readDir(MIGRATIONS_DIR)) {
    if (!entry.name.endsWith(".sql")) continue;
    const text = await Deno.readTextFile(new URL(entry.name, MIGRATIONS_DIR));
    if (/INSERT INTO permissions\s*\(/i.test(text)) {
      bad.push(entry.name);
    }
  }
  assertEquals(bad, [], `deprecated permissions table in: ${bad.join(", ")}`);
});
