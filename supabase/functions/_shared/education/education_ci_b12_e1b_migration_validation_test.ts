import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

// B12 (Question Factory asset schema) + CI-E1b (canonical concept graph) —
// both DORMANT additive migrations (CREATE-only, zero data seed, zero
// wiring). These tests assert the migrations stay additive/well-formed and
// keep the certified edu_* governance shape (FORCE RLS + _school_scope +
// _platform_read + narrow no-DELETE grant + COALESCE identity index),
// mirroring the migration-validation pattern already used by
// sis_migration_validation_test.ts / academic_migration_validation_test.ts /
// intelligence_migration_validation_test.ts.

const B12_PATH = new URL(
  "../../../migrations/20260858000000_edu_question_factory_schema.sql",
  import.meta.url,
);
const E1B_PATH = new URL(
  "../../../migrations/20260859000000_edu_canonical_concept_graph.sql",
  import.meta.url,
);
const MIGRATIONS_DIR = new URL("../../../migrations/", import.meta.url);

const b12Sql = await Deno.readTextFile(B12_PATH);
const e1bSql = await Deno.readTextFile(E1B_PATH);

// ── B12 — edu_question_families / edu_question_templates / edu_distractors ──

Deno.test("B12 creates the three Question Factory asset tables (no edu_diagrams — that is CI-C11 scope)", () => {
  assert(b12Sql.includes("CREATE TABLE edu_question_families"));
  assert(b12Sql.includes("CREATE TABLE edu_question_templates"));
  assert(b12Sql.includes("CREATE TABLE edu_distractors"));
  assert(
    !b12Sql.includes("CREATE TABLE edu_diagrams"),
    "edu_diagrams belongs to CI-C11 (Diagram Intelligence), not B12",
  );
});

Deno.test("B12 tables carry the certified edu_* governance shape (FORCE RLS + school_scope + platform_read + no-DELETE grant)", () => {
  for (
    const table of [
      "edu_question_families",
      "edu_question_templates",
      "edu_distractors",
    ]
  ) {
    assert(
      b12Sql.includes(`ALTER TABLE ${table} ENABLE ROW LEVEL SECURITY`),
      `${table} missing ENABLE ROW LEVEL SECURITY`,
    );
    assert(
      b12Sql.includes(`ALTER TABLE ${table} FORCE ROW LEVEL SECURITY`),
      `${table} missing FORCE ROW LEVEL SECURITY`,
    );
    assert(
      b12Sql.includes(`CREATE POLICY ${table}_school_scope ON ${table}`),
      `${table} missing _school_scope policy`,
    );
    assert(
      b12Sql.includes(`CREATE POLICY ${table}_platform_read ON ${table}`),
      `${table} missing _platform_read policy`,
    );
    assert(
      b12Sql.includes(`GRANT SELECT, INSERT, UPDATE ON ${table} TO erp_tenant`),
      `${table} missing narrow no-DELETE grant`,
    );
    assert(
      !new RegExp(`GRANT[^;]*DELETE[^;]*ON ${table}\\b`).test(b12Sql),
      `${table} must not grant DELETE (archive/retire, never delete)`,
    );
  }
});

Deno.test("B12 edu_question_families/templates carry a COALESCE identity unique index", () => {
  assert(b12Sql.includes("CREATE UNIQUE INDEX edu_question_families_identity"));
  assert(b12Sql.includes("CREATE UNIQUE INDEX edu_question_templates_identity"));
  assert(
    (b12Sql.match(/COALESCE\(/g) ?? []).length >= 8,
    "expected multiple COALESCE(...) identity-index expressions",
  );
});

Deno.test("B12 edu_question_templates references edu_question_families with a real FK (same migration, no forward reference needed)", () => {
  assert(
    b12Sql.includes(
      "question_family_id UUID REFERENCES edu_question_families (id)",
    ),
  );
});

Deno.test("B12 edu_distractors reuses the already-certified edu_question_bank_items (real FK)", () => {
  assert(
    b12Sql.includes(
      "question_id UUID REFERENCES edu_question_bank_items (id) ON DELETE SET NULL",
    ),
  );
});

Deno.test("B12 concept_id columns are dormant loose forward-references (no FK yet — added by E1b)", () => {
  const concept_id_lines = b12Sql
    .split("\n")
    .filter((l) => l.trim().startsWith("concept_id"));
  assert(concept_id_lines.length >= 3, "expected concept_id on families/templates/distractors");
  for (const line of concept_id_lines) {
    assert(
      !/REFERENCES/i.test(line),
      `concept_id must stay a plain UUID with no FK in B12 (forward reference): "${line}"`,
    );
  }
});

Deno.test("B12 backfills the edu_question_bank_items.question_family_id FK left dormant by 20260857000000", () => {
  assert(
    b12Sql.includes(
      "ADD CONSTRAINT edu_question_bank_items_question_family_id_fkey",
    ),
  );
  assert(b12Sql.includes("FOREIGN KEY (question_family_id) REFERENCES edu_question_families (id)"));
});

Deno.test("B12 has zero data seed (CREATE-only, no INSERT of business rows)", () => {
  assert(!/\bINSERT\s+INTO\s+edu_question_families\b/i.test(b12Sql));
  assert(!/\bINSERT\s+INTO\s+edu_question_templates\b/i.test(b12Sql));
  assert(!/\bINSERT\s+INTO\s+edu_distractors\b/i.test(b12Sql));
});

// ── CI-E1b — canonical_concepts / concept_prerequisites / concept_board_mappings ──

Deno.test("E1b creates the canonical concept graph tables", () => {
  assert(e1bSql.includes("CREATE TABLE canonical_concepts"));
  assert(e1bSql.includes("CREATE TABLE concept_prerequisites"));
  assert(e1bSql.includes("CREATE TABLE concept_board_mappings"));
});

Deno.test("E1b tables carry the certified edu_* governance shape (FORCE RLS + school_scope + platform_read + no-DELETE grant)", () => {
  for (
    const table of [
      "canonical_concepts",
      "concept_prerequisites",
      "concept_board_mappings",
    ]
  ) {
    assert(
      e1bSql.includes(`ALTER TABLE ${table} ENABLE ROW LEVEL SECURITY`),
      `${table} missing ENABLE ROW LEVEL SECURITY`,
    );
    assert(
      e1bSql.includes(`ALTER TABLE ${table} FORCE ROW LEVEL SECURITY`),
      `${table} missing FORCE ROW LEVEL SECURITY`,
    );
    assert(
      e1bSql.includes(`CREATE POLICY ${table}_school_scope ON ${table}`),
      `${table} missing _school_scope policy`,
    );
    assert(
      e1bSql.includes(`CREATE POLICY ${table}_platform_read ON ${table}`),
      `${table} missing _platform_read policy`,
    );
    assert(
      e1bSql.includes(`GRANT SELECT, INSERT, UPDATE ON ${table} TO erp_tenant`),
      `${table} missing narrow no-DELETE grant`,
    );
  }
});

Deno.test("E1b concept_prerequisites extends the v3.0 §8.2 edge table with A1-1 relationship richness + a self-loop guard", () => {
  assert(e1bSql.includes("relationship_type"));
  assert(e1bSql.includes("'prerequisite'"));
  assert(e1bSql.includes("'parent_child'"));
  assert(e1bSql.includes("'related'"));
  assert(e1bSql.includes("'confused_with'"));
  assert(e1bSql.includes("CHECK (from_concept_id <> to_concept_id)"));
});

Deno.test("E1b concept_board_mappings reuses the already-certified syllabus_chapters/syllabus_topics (real FKs)", () => {
  assert(
    e1bSql.includes(
      "syllabus_chapter_id UUID REFERENCES syllabus_chapters (id) ON DELETE SET NULL",
    ),
  );
  assert(
    e1bSql.includes(
      "syllabus_topic_id UUID REFERENCES syllabus_topics (id) ON DELETE SET NULL",
    ),
  );
});

Deno.test("E1b backfills every concept_id FK left dormant by 20260857000000 and B12 (20260858000000)", () => {
  for (
    const table of [
      "edu_question_bank_items",
      "edu_question_families",
      "edu_question_templates",
      "edu_distractors",
    ]
  ) {
    assert(
      e1bSql.includes(`ADD CONSTRAINT ${table}_concept_id_fkey`),
      `missing concept_id FK backfill for ${table}`,
    );
  }
  assertEquals(
    (e1bSql.match(/FOREIGN KEY \(concept_id\) REFERENCES canonical_concepts \(id\)/g) ?? [])
      .length,
    4,
  );
});

Deno.test("E1b has zero data seed (CREATE-only, no INSERT of concept rows)", () => {
  assert(!/\bINSERT\s+INTO\s+canonical_concepts\b/i.test(e1bSql));
  assert(!/\bINSERT\s+INTO\s+concept_prerequisites\b/i.test(e1bSql));
  assert(!/\bINSERT\s+INTO\s+concept_board_mappings\b/i.test(e1bSql));
});

// ── Cross-cutting: no destructive statements anywhere in either migration ───

Deno.test("B12 + E1b contain no destructive statements (DROP TABLE / DROP COLUMN / TRUNCATE / DELETE FROM)", () => {
  for (const sql of [b12Sql, e1bSql]) {
    assert(!/\bDROP\s+TABLE\b/i.test(sql));
    assert(!/\bDROP\s+COLUMN\b/i.test(sql));
    assert(!/\bTRUNCATE\b/i.test(sql));
    assert(!/\bDELETE\s+FROM\b/i.test(sql));
  }
});

Deno.test("both migration files exist in the migrations directory in the correct order", async () => {
  const names: string[] = [];
  for await (const entry of Deno.readDir(MIGRATIONS_DIR)) {
    if (entry.name.endsWith(".sql")) names.push(entry.name);
  }
  assert(names.includes("20260858000000_edu_question_factory_schema.sql"));
  assert(names.includes("20260859000000_edu_canonical_concept_graph.sql"));
});
