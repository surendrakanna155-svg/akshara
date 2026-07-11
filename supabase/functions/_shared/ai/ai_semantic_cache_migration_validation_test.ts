// Static validation of migration 20260876 (W2.8) — pins the DEFENSIVE shape:
// everything inside a pg_available_extensions guard so a pilot DB without
// pgvector logs a NOTICE instead of aborting the deploy bundle.

import { assert } from "jsr:@std/assert@1";

const sql = await Deno.readTextFile(
  new URL("../../../migrations/20260876000000_ai_semantic_cache.sql", import.meta.url),
);
const statements = sql
  .split("\n")
  .filter((line) => !line.trimStart().startsWith("--"))
  .map((line) => line.split("--")[0]!)
  .join("\n");

Deno.test("20260876 is guarded: creates only when pgvector is available", () => {
  assert(statements.includes("pg_available_extensions"));
  assert(statements.includes("CREATE EXTENSION IF NOT EXISTS vector"));
  assert(statements.includes("RAISE NOTICE"), "must degrade with a NOTICE, never abort");
  assert(statements.includes("CREATE TABLE IF NOT EXISTS ai_semantic_cache_embeddings"));
});

Deno.test("20260876 substrate is school-walled and additive", () => {
  assert(statements.includes("ENABLE ROW LEVEL SECURITY"));
  assert(statements.includes("FORCE ROW LEVEL SECURITY"));
  assert(statements.includes("app_current_scope() = 'school'"));
  assert(statements.includes("school_id = app_current_school_id()"));
  assert(!statements.includes("DROP POLICY"), "creates only; drops nothing");
  assert(!statements.includes("ALTER TABLE ai_response_cache"), "never touches Stage-1's table");
});
