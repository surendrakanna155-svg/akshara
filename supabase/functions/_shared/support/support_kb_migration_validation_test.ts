// Static validation of migration 20260920000060 (ASIP-8 KB). Pins:
//  * the deterministic article table is PLATFORM_ORG-walled (same RLS as the
//    mirror) and additive — a school session can never touch it;
//  * the OPTIONAL embedding substrate is DEFENSIVE — created only inside a
//    pg_available_extensions guard, degrading with a NOTICE (never aborting the
//    deploy bundle) when pgvector is absent.

import { assert } from "jsr:@std/assert@1";

const sql = await Deno.readTextFile(
  new URL("../../../migrations/20260920000060_support_kb.sql", import.meta.url),
);
const statements = sql
  .split("\n")
  .filter((line) => !line.trimStart().startsWith("--"))
  .map((line) => line.split("--")[0]!)
  .join("\n");

Deno.test("20260920000060 article table is PLATFORM_ORG-walled + additive", () => {
  assert(statements.includes("CREATE TABLE support_kb_article"));
  assert(statements.includes("ENABLE ROW LEVEL SECURITY"));
  assert(statements.includes("FORCE ROW LEVEL SECURITY"));
  assert(statements.includes("app_current_tenant_id() = app_support_platform_org()"));
  assert(statements.includes("platform_org_id = app_support_platform_org()"));
  assert(statements.includes("UNIQUE (platform_org_id, fingerprint)"), "one active article per signature");
  assert(!statements.includes("DROP POLICY"), "creates only; drops nothing");
  assert(!statements.includes("DROP TABLE"), "never drops anything");
});

Deno.test("20260920000060 uses NO SECURITY DEFINER (all writes are support-side)", () => {
  assert(!statements.includes("SECURITY DEFINER"), "KB needs no cross-boundary bridge");
});

Deno.test("20260920000060 embedding substrate is guarded + dormant-safe", () => {
  assert(statements.includes("pg_available_extensions"));
  assert(statements.includes("CREATE EXTENSION IF NOT EXISTS vector"));
  assert(statements.includes("RAISE NOTICE"), "must degrade with a NOTICE, never abort");
  assert(statements.includes("CREATE TABLE IF NOT EXISTS support_kb_embedding"));
  assert(statements.includes("vector(1024)"), "matches the embeddings_client dimensionality");
});

Deno.test("20260920000060 grants only the tenant edge role (no service_role, no PUBLIC)", () => {
  assert(statements.includes("GRANT SELECT, INSERT, UPDATE ON support_kb_article TO erp_tenant"));
  assert(!statements.includes("TO service_role"), "no RLS-bypass role on the data plane");
  assert(!statements.includes("TO PUBLIC"));
});
