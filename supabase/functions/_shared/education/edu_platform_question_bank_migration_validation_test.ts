import { assert } from "https://deno.land/std@0.224.0/assert/mod.ts";

// Program D · M1.1 (+ M2.1) — edu_platform_question_bank + edu_school_adopted_items.
// DORMANT additive migration: CREATE-only, zero data seed, zero wiring. These tests
// assert it stays additive/well-formed, carries the certified edu_* platform-read
// governance shape (FORCE RLS + _school_scope + _platform_read + narrow no-DELETE grant
// + COALESCE identity index), and matches Contract-2 §2.1/§2.2 column names / CHECK
// values — mirroring edu_concept_vocabulary_migration_validation_test.ts.

const PATH = new URL(
  "../../../migrations/20260920000220_edu_platform_question_bank.sql",
  import.meta.url,
);
const MIGRATIONS_DIR = new URL("../../../migrations/", import.meta.url);
const sql = await Deno.readTextFile(PATH);
const code = sql.replace(/--[^\n]*/g, ""); // strip line comments for destructive-scan

Deno.test("M1.1 creates both tables (platform bank + adoption-by-reference)", () => {
  assert(sql.includes("CREATE TABLE edu_platform_question_bank"));
  assert(sql.includes("CREATE TABLE edu_school_adopted_items"));
});

Deno.test("M1.1 content_hash is the global idempotency key (TEXT NOT NULL UNIQUE)", () => {
  assert(
    /content_hash\s+TEXT\s+NOT NULL\s+UNIQUE/.test(sql),
    "content_hash TEXT NOT NULL UNIQUE missing",
  );
});

Deno.test("M2.1 difficulty_calibration separates predicted vs measured (never blend)", () => {
  assert(
    /difficulty_calibration\s+TEXT\s+NOT NULL\s+DEFAULT\s+'predicted_uncalibrated'/.test(sql),
    "difficulty_calibration default must be 'predicted_uncalibrated'",
  );
  assert(
    sql.includes("CHECK (difficulty_calibration IN ('predicted_uncalibrated', 'measured_pilot'))"),
    "difficulty_calibration CHECK enum missing",
  );
});

Deno.test("M1.1 question_type CHECK is WIDENED with 'numerical' (a widening, never a weakening)", () => {
  for (
    const t of [
      "'mcq'",
      "'fill_blank'",
      "'match'",
      "'short_answer'",
      "'long_answer'",
      "'diagram'",
      "'numerical'",
    ]
  ) {
    assert(sql.includes(t), `question_type CHECK missing ${t}`);
  }
  assert(/CHECK \(question_type IN \(/.test(sql));
});

Deno.test("M1.1 status is (active, tombstoned) default active — recall = tombstone, never hard-delete", () => {
  assert(/status\s+TEXT\s+NOT NULL\s+DEFAULT\s+'active'/.test(sql));
  assert(sql.includes("CHECK (status IN ('active', 'tombstoned'))"));
});

Deno.test("M1.1 carries the remaining Contract-2 §2.1 CHECKs + columns", () => {
  assert(sql.includes("CHECK (difficulty IN ('easy', 'medium', 'hard'))"));
  assert(sql.includes("marks INT CHECK (marks > 0)"));
  assert(/cognitive_level\s+TEXT/.test(sql));
  for (
    const col of [
      "organization_id",
      "school_id",
      "stem_norm_hash",
      "subject_name",
      "answer_label",
      "program_track",
      "kc_id",
      "concept_uuid",
      "near_dup_embedding",
      "near_dup_model_version",
      "provenance",
      "frozen_version",
      "recalled_at",
    ]
  ) {
    assert(sql.includes(col), `missing column ${col}`);
  }
});

Deno.test("M1.1 concept_uuid is a LOOSE reference (no FK — canonical_concepts dormant/empty)", () => {
  const line = sql.split("\n").find((l) => l.trim().startsWith("concept_uuid")) ?? "";
  assert(line.length > 0, "concept_uuid column not found");
  assert(!/REFERENCES/i.test(line), `concept_uuid must have no FK: "${line}"`);
});

Deno.test("M1.1 platform bank carries the certified platform-read governance shape (FORCE RLS + school_scope + platform_read + no-DELETE grant)", () => {
  const t = "edu_platform_question_bank";
  assert(sql.includes(`ALTER TABLE ${t} ENABLE ROW LEVEL SECURITY`));
  assert(sql.includes(`ALTER TABLE ${t} FORCE ROW LEVEL SECURITY`));
  assert(sql.includes(`CREATE POLICY ${t}_school_scope ON ${t}`));
  assert(sql.includes(`CREATE POLICY ${t}_platform_read ON ${t}`));
  assert(sql.includes(`GRANT SELECT, INSERT, UPDATE ON ${t} TO erp_tenant`));
  assert(
    !new RegExp(`GRANT[^;]*DELETE[^;]*ON ${t}\\b`).test(sql),
    "platform bank must not grant DELETE (recall = tombstone, never delete)",
  );
});

Deno.test("M1.1 platform-read keys on organization_id IS NULL + scope='school'", () => {
  assert(sql.includes("organization_id IS NULL"));
  assert(sql.includes("app_current_scope() = 'school'"));
  assert(sql.includes("organization_id = app_current_tenant_id()"));
  assert(sql.includes("school_id = app_current_school_id()"));
});

Deno.test("M1.1 platform bank has a COALESCE identity unique index (governance shape)", () => {
  assert(sql.includes("CREATE UNIQUE INDEX edu_platform_question_bank_identity"));
  assert((sql.match(/COALESCE\(/g) ?? []).length >= 3);
  assert(/COALESCE\(content_hash/.test(sql), "identity index must key on content_hash");
});

Deno.test("M1.1 adoption table is BY REFERENCE (real FK, unique adoption, school-scope only — NO platform_read)", () => {
  const t = "edu_school_adopted_items";
  assert(
    sql.includes("platform_item_id UUID NOT NULL REFERENCES edu_platform_question_bank (id)"),
    "adoption must reference the platform bank (by reference, not a copy)",
  );
  assert(sql.includes("UNIQUE (organization_id, school_id, platform_item_id)"));
  assert(sql.includes(`ALTER TABLE ${t} ENABLE ROW LEVEL SECURITY`));
  assert(sql.includes(`ALTER TABLE ${t} FORCE ROW LEVEL SECURITY`));
  assert(sql.includes(`CREATE POLICY ${t}_school_scope ON ${t}`));
  assert(
    !sql.includes(`CREATE POLICY ${t}_platform_read`),
    "adoption records are tenant-owned — must NOT have a platform_read policy",
  );
  assert(sql.includes(`GRANT SELECT, INSERT, UPDATE ON ${t} TO erp_tenant`));
  assert(!new RegExp(`GRANT[^;]*DELETE[^;]*ON ${t}\\b`).test(sql));
});

Deno.test("M1.1 is dormant: zero data seed, no destructive statements", () => {
  assert(!/\bINSERT\s+INTO\s+edu_platform_question_bank\b/i.test(sql));
  assert(!/\bINSERT\s+INTO\s+edu_school_adopted_items\b/i.test(sql));
  assert(!/\bDROP\s+TABLE\b/i.test(code));
  assert(!/\bDROP\s+COLUMN\b/i.test(code));
  assert(!/\bTRUNCATE\b/i.test(code));
  assert(!/\bDELETE\s+FROM\b/i.test(code));
});

Deno.test("M1.1 migration file exists in the migrations directory", async () => {
  const names: string[] = [];
  for await (const entry of Deno.readDir(MIGRATIONS_DIR)) {
    if (entry.name.endsWith(".sql")) names.push(entry.name);
  }
  assert(names.includes("20260920000220_edu_platform_question_bank.sql"));
});
