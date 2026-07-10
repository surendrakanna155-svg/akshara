// Static validation of migration 20260875 (A5 atomic quota reservations),
// mirroring the intelligence-area migration-validation pattern.
//
// Audit round 2 found the P0 this file now guards against: the migration was
// first authored against a stale base and dropped a policy that migration
// 20260869 had already dropped — which would have aborted the whole deploy
// bundle, invisibly to every unit test. The structural assertions here pin
// the repaired shape: the migration creates ONLY the reservations table and
// never touches ai_call_log's schema or policies (20260869 owns those).

import { assert } from "jsr:@std/assert@1";

const MIGRATION = new URL(
  "../../../migrations/20260875000000_ai_call_reservations.sql",
  import.meta.url,
);
const sql = await Deno.readTextFile(MIGRATION);
/** Statements only — comments legitimately narrate ai_call_log, so both
 * whole-line and trailing `--` comments are stripped before matching
 * (round-3 N4: a trailing comment must not hide statement text). */
const statements = sql
  .split("\n")
  .filter((line) => !line.trimStart().startsWith("--"))
  .map((line) => line.split("--")[0]!)
  .join("\n");

Deno.test("20260875 creates the reservations table with RLS forced and a tenant wall", () => {
  assert(statements.includes("CREATE TABLE ai_call_reservations"));
  assert(statements.includes("ALTER TABLE ai_call_reservations ENABLE ROW LEVEL SECURITY"));
  assert(statements.includes("ALTER TABLE ai_call_reservations FORCE ROW LEVEL SECURITY"));
  assert(statements.includes("CREATE POLICY ai_call_reservations_tenant"));
  assert(statements.includes("USING (organization_id = app_current_tenant_id())"));
  assert(statements.includes("WITH CHECK (organization_id = app_current_tenant_id())"));
  assert(
    statements.includes(
      "GRANT SELECT, INSERT, UPDATE, DELETE ON ai_call_reservations TO erp_tenant",
    ),
  );
  assert(statements.includes("CHECK (status IN ('pending', 'consumed', 'released'))"));
});

Deno.test("20260875 never touches ai_call_log (owned by 20260869) — the stale-base P0 guard", () => {
  assert(!statements.includes("ALTER TABLE ai_call_log"), "must not alter ai_call_log");
  assert(!statements.includes("ON ai_call_log"), "must not add/drop ai_call_log policies");
  assert(!statements.includes("DROP POLICY"), "creates only; drops nothing");
  assert(!statements.includes("DROP TABLE"), "creates only; drops nothing");
});
