import { assert } from "https://deno.land/std@0.224.0/assert/mod.ts";

// Program D · M0.2 — edu_concept_vocabulary (KC_ ↔ UUID crosswalk). DORMANT additive migration:
// CREATE-only, zero data seed, zero wiring. These tests assert it stays additive/well-formed and carries
// the certified edu_* platform-read governance shape (FORCE RLS + _school_scope + _platform_read + narrow
// no-DELETE grant + COALESCE identity index), mirroring education_ci_b12_e1b_migration_validation_test.ts.

const PATH = new URL(
  "../../../migrations/20260877000000_edu_concept_vocabulary.sql",
  import.meta.url,
);
const MIGRATIONS_DIR = new URL("../../../migrations/", import.meta.url);
const sql = await Deno.readTextFile(PATH);

Deno.test("M0.2 creates edu_concept_vocabulary with the crosswalk columns", () => {
  assert(sql.includes("CREATE TABLE edu_concept_vocabulary"));
  assert(/kc_id\s+TEXT\s+NOT NULL/.test(sql), "kc_id TEXT NOT NULL missing");
  assert(/concept_uuid\s+UUID\s+NOT NULL/.test(sql), "concept_uuid UUID NOT NULL missing");
  for (const col of ["subject", "canonical_name", "frozen_version"]) {
    assert(sql.includes(col), `missing column ${col}`);
  }
});

Deno.test("M0.2 carries the certified edu_* governance shape (FORCE RLS + school_scope + platform_read + no-DELETE grant)", () => {
  const table = "edu_concept_vocabulary";
  assert(sql.includes(`ALTER TABLE ${table} ENABLE ROW LEVEL SECURITY`));
  assert(sql.includes(`ALTER TABLE ${table} FORCE ROW LEVEL SECURITY`));
  assert(sql.includes(`CREATE POLICY ${table}_school_scope ON ${table}`));
  assert(sql.includes(`CREATE POLICY ${table}_platform_read ON ${table}`));
  assert(sql.includes(`GRANT SELECT, INSERT, UPDATE ON ${table} TO erp_tenant`));
  assert(
    !new RegExp(`GRANT[^;]*DELETE[^;]*ON ${table}\\b`).test(sql),
    "must not grant DELETE (retire, never delete)",
  );
});

Deno.test("M0.2 platform-read keys on organization_id IS NULL + scope='school'", () => {
  assert(sql.includes("organization_id IS NULL"));
  assert(sql.includes("app_current_scope() = 'school'"));
  assert(sql.includes("organization_id = app_current_tenant_id()"));
  assert(sql.includes("school_id = app_current_school_id()"));
});

Deno.test("M0.2 has a COALESCE identity unique index over (org, school, kc_id)", () => {
  assert(sql.includes("CREATE UNIQUE INDEX edu_concept_vocabulary_identity"));
  assert((sql.match(/COALESCE\(/g) ?? []).length >= 3);
  assert(/COALESCE\(kc_id/.test(sql), "identity index must key on kc_id");
});

Deno.test("M0.2 concept_uuid is a LOOSE reference (no FK — canonical_concepts is dormant/empty)", () => {
  const line = sql.split("\n").find((l) => l.trim().startsWith("concept_uuid")) ?? "";
  assert(line.length > 0, "concept_uuid column not found");
  assert(!/REFERENCES/i.test(line), `concept_uuid must have no FK: "${line}"`);
});

Deno.test("M0.2 is dormant: zero data seed, no destructive statements", () => {
  assert(!/\bINSERT\s+INTO\s+edu_concept_vocabulary\b/i.test(sql));
  assert(!/\bDROP\s+TABLE\b(?![^\n]*IF EXISTS[^\n]*-- )/i.test(sql.replace(/--[^\n]*/g, "")));
  assert(!/\bDROP\s+COLUMN\b/i.test(sql));
  assert(!/\bTRUNCATE\b/i.test(sql));
  assert(!/\bDELETE\s+FROM\b/i.test(sql));
});

Deno.test("M0.2 migration file exists in the migrations directory", async () => {
  const names: string[] = [];
  for await (const entry of Deno.readDir(MIGRATIONS_DIR)) {
    if (entry.name.endsWith(".sql")) names.push(entry.name);
  }
  assert(names.includes("20260877000000_edu_concept_vocabulary.sql"));
});
