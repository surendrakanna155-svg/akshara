import { assert } from "https://deno.land/std@0.224.0/assert/mod.ts";

// Program D · M3.1 / M3.3 — edu_program_d_settings per-tenant flag store. DORMANT
// additive migration: CREATE-only, zero data seed, zero wiring. These tests assert the
// flag defaults reproduce EXACT current production behaviour (certified_pool_enabled
// false; gap_fill_policy 'marked_unpublishable'), and that it carries school-scope RLS
// ONLY (tenant-owned settings — NO _platform_read) with a narrow no-DELETE grant.
// Contract-2 §2.4 is normative.

const PATH = new URL(
  "../../../migrations/20260920000240_edu_program_d_settings.sql",
  import.meta.url,
);
const MIGRATIONS_DIR = new URL("../../../migrations/", import.meta.url);
const sql = await Deno.readTextFile(PATH);
const code = sql.replace(/--[^\n]*/g, ""); // strip line comments for destructive-scan

Deno.test("M3.x creates the per-tenant flag store keyed by (organization_id, school_id)", () => {
  assert(sql.includes("CREATE TABLE edu_program_d_settings"));
  assert(
    sql.includes("PRIMARY KEY (organization_id, school_id)"),
    "one row per tenant-school (PK = UNIQUE natural key)",
  );
  assert(/organization_id\s+UUID\s+NOT NULL/.test(sql));
  assert(/school_id\s+UUID\s+NOT NULL/.test(sql));
});

Deno.test("M3.1 certified_pool_enabled defaults FALSE (exact current behaviour — union pool OFF)", () => {
  assert(
    /certified_pool_enabled\s+BOOLEAN\s+NOT NULL\s+DEFAULT\s+false/.test(sql),
    "certified_pool_enabled must default false",
  );
});

Deno.test("M3.3 gap_fill_policy defaults 'marked_unpublishable' with the (marked_unpublishable, hard_off) CHECK", () => {
  assert(
    /gap_fill_policy\s+TEXT\s+NOT NULL\s+DEFAULT\s+'marked_unpublishable'/.test(sql),
    "gap_fill_policy must default 'marked_unpublishable'",
  );
  assert(
    sql.includes("CHECK (gap_fill_policy IN ('marked_unpublishable', 'hard_off'))"),
    "gap_fill_policy CHECK enum missing",
  );
});

Deno.test("M3.x carries school-scope RLS ONLY (FORCE RLS + _school_scope + no-DELETE grant, NO platform_read)", () => {
  const t = "edu_program_d_settings";
  assert(sql.includes(`ALTER TABLE ${t} ENABLE ROW LEVEL SECURITY`));
  assert(sql.includes(`ALTER TABLE ${t} FORCE ROW LEVEL SECURITY`));
  assert(sql.includes(`CREATE POLICY ${t}_school_scope ON ${t}`));
  assert(
    !sql.includes(`CREATE POLICY ${t}_platform_read`),
    "tenant-owned settings must NOT have a platform_read policy",
  );
  assert(sql.includes("organization_id = app_current_tenant_id()"));
  assert(sql.includes("app_current_scope() = 'school'"));
  assert(sql.includes("school_id = app_current_school_id()"));
  assert(sql.includes(`GRANT SELECT, INSERT, UPDATE ON ${t} TO erp_tenant`));
  assert(
    !new RegExp(`GRANT[^;]*DELETE[^;]*ON ${t}\\b`).test(sql),
    "settings must not grant DELETE (edit flags, never delete the row)",
  );
});

Deno.test("M3.x is dormant: zero data seed, no destructive statements", () => {
  assert(!/\bINSERT\s+INTO\s+edu_program_d_settings\b/i.test(sql));
  assert(!/\bDROP\s+TABLE\b/i.test(code));
  assert(!/\bDROP\s+COLUMN\b/i.test(code));
  assert(!/\bTRUNCATE\b/i.test(code));
  assert(!/\bDELETE\s+FROM\b/i.test(code));
});

Deno.test("M3.x migration file exists in the migrations directory", async () => {
  const names: string[] = [];
  for await (const entry of Deno.readDir(MIGRATIONS_DIR)) {
    if (entry.name.endsWith(".sql")) names.push(entry.name);
  }
  assert(names.includes("20260920000240_edu_program_d_settings.sql"));
});
