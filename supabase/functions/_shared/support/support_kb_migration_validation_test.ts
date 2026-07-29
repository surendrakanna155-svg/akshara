// Static validation of the ASIP-8 KB migration. Pins:
//  * the deterministic article table is PLATFORM_ORG-walled (same RLS as the
//    mirror) and additive — a school session can never touch it;
//  * the OPTIONAL embedding substrate is DEFENSIVE — created only inside a
//    pg_available_extensions guard, degrading with a NOTICE (never aborting the
//    deploy bundle) when pgvector is absent.
//
// The migration is located by SUFFIX, never by version number. It previously
// hardcoded `20260920000060_support_kb.sql`, which meant renumbering the
// migration off a colliding trunk slot silently broke this test — and the
// version DID have to move (…000060 collided with the trunk's
// finance_recovery_minor_backfill). Version numbers are allocated at fold-in
// time against a moving trunk; the filename suffix is the stable identity.

import { assert, assertEquals } from "jsr:@std/assert@1";

const MIGRATIONS_DIR = new URL("../../../migrations/", import.meta.url);

const kbMigrations: string[] = [];
for await (const entry of Deno.readDir(MIGRATIONS_DIR)) {
  if (entry.isFile && entry.name.endsWith("_support_kb.sql")) {
    kbMigrations.push(entry.name);
  }
}
kbMigrations.sort();

Deno.test("exactly one ASIP-8 KB migration exists (a renumber must MOVE it, not copy it)", () => {
  assertEquals(
    kbMigrations.length,
    1,
    `expected exactly one *_support_kb.sql, found: ${kbMigrations.join(", ")}`,
  );
});

Deno.test("KB migration version is a well-formed 14-digit version", () => {
  const version = kbMigrations[0]!.split("_")[0]!;
  assert(/^\d{14}$/.test(version), `bad migration version: ${version}`);
});

const sql = await Deno.readTextFile(new URL(kbMigrations[0]!, MIGRATIONS_DIR));
const statements = sql
  .split("\n")
  .filter((line) => !line.trimStart().startsWith("--"))
  .map((line) => line.split("--")[0]!)
  .join("\n");

Deno.test("KB migration article table is PLATFORM_ORG-walled + additive", () => {
  assert(statements.includes("CREATE TABLE support_kb_article"));
  assert(statements.includes("ENABLE ROW LEVEL SECURITY"));
  assert(statements.includes("FORCE ROW LEVEL SECURITY"));
  assert(statements.includes("app_current_tenant_id() = app_support_platform_org()"));
  assert(statements.includes("platform_org_id = app_support_platform_org()"));
  assert(statements.includes("UNIQUE (platform_org_id, fingerprint)"), "one active article per signature");
  assert(!statements.includes("DROP POLICY"), "creates only; drops nothing");
  assert(!statements.includes("DROP TABLE"), "never drops anything");
});

Deno.test("KB migration uses NO SECURITY DEFINER (all writes are support-side)", () => {
  assert(!statements.includes("SECURITY DEFINER"), "KB needs no cross-boundary bridge");
});

Deno.test("KB migration embedding substrate is guarded + dormant-safe", () => {
  assert(statements.includes("pg_available_extensions"));
  assert(statements.includes("CREATE EXTENSION IF NOT EXISTS vector"));
  assert(statements.includes("RAISE NOTICE"), "must degrade with a NOTICE, never abort");
  assert(statements.includes("CREATE TABLE IF NOT EXISTS support_kb_embedding"));
  assert(statements.includes("vector(1024)"), "matches the embeddings_client dimensionality");
});

Deno.test("KB migration grants only the tenant edge role (no service_role, no PUBLIC)", () => {
  assert(statements.includes("GRANT SELECT, INSERT, UPDATE ON support_kb_article TO erp_tenant"));
  assert(!statements.includes("TO service_role"), "no RLS-bypass role on the data plane");
  assert(!statements.includes("TO PUBLIC"));
});
