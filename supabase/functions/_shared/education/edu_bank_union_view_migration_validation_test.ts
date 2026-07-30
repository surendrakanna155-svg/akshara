import { assert } from "https://deno.land/std@0.224.0/assert/mod.ts";

// Program D · M1.4 — edu_bank_items_union VIEW. DORMANT additive migration: read model
// only, zero data seed, zero wiring. These tests assert it projects own bank ∪ adopted,
// active platform items into the EXACT QuestionBankItemRow column set (Contract-2 §2.3),
// applies the platform-side projection rules, and is RLS-safe by construction
// (security_invoker=true, no policy of its own — inherits base-table RLS).

const PATH = new URL(
  "../../../migrations/20260920000230_edu_bank_union_view.sql",
  import.meta.url,
);
const MIGRATIONS_DIR = new URL("../../../migrations/", import.meta.url);
const sql = await Deno.readTextFile(PATH);
const code = sql.replace(/--[^\n]*/g, ""); // strip line comments for destructive-scan

// The 31 QuestionBankItemRow columns (education_types.ts), in order.
const ROW_COLUMNS = [
  "id",
  "organization_id",
  "school_id",
  "subject_name",
  "chapter",
  "topic",
  "difficulty",
  "question_type",
  "marks",
  "question_text",
  "answer_text",
  "options",
  "status",
  "source",
  "source_reference",
  "program_track",
  "jee_question_type",
  "cognitive_level",
  "syllabus_chapter_id",
  "syllabus_topic_id",
  "learning_outcome",
  "fingerprint",
  "review_status",
  "created_by",
  "created_at",
  "updated_at",
  "times_used",
  "last_used_at",
  "competency",
  "question_family_id",
  "concept_id",
];

Deno.test("M1.4 creates the union view", () => {
  assert(sql.includes("CREATE OR REPLACE VIEW edu_bank_items_union"));
});

Deno.test("M1.4 view is RLS-safe by construction: security_invoker=true, no policy of its own", () => {
  assert(
    sql.includes("WITH (security_invoker = true)"),
    "view must run as the querying role so base-table RLS applies (no owner-rights bypass)",
  );
  assert(
    !sql.includes("CREATE POLICY edu_bank_items_union"),
    "the union view must not define its own RLS policy — it inherits base-table RLS",
  );
  assert(
    !/ALTER\s+(?:TABLE|VIEW)\s+edu_bank_items_union\s+ENABLE ROW LEVEL SECURITY/i.test(sql),
  );
});

Deno.test("M1.4 own bank side projects every QuestionBankItemRow column unchanged", () => {
  for (const col of ROW_COLUMNS) {
    assert(
      new RegExp(`\\bb\\.${col}\\b`).test(sql),
      `own-bank projection missing b.${col}`,
    );
  }
});

Deno.test("M1.4 platform side applies the Contract-2 §2.3 projection rules", () => {
  assert(sql.includes("'certified_platform'::text AS source"));
  assert(sql.includes("'approved'::text AS review_status"));
  assert(sql.includes("'active'::text AS status"));
  assert(sql.includes("p.content_hash AS fingerprint"));
  assert(sql.includes("p.concept_uuid AS concept_id"));
  assert(sql.includes("p.id,"), "platform id must be projected as the union id");
  assert(sql.includes("a.organization_id"), "org must come from the adopting tenant");
  assert(sql.includes("a.school_id"), "school must come from the adopting tenant");
  // exposure lives on the own-bank seam
  assert(sql.includes("0 AS times_used"));
  assert(sql.includes("NULL::timestamptz AS last_used_at"));
  // §2.3 nulls on the platform side
  assert(sql.includes("NULL::text AS jee_question_type"));
  assert(sql.includes("NULL::uuid AS syllabus_chapter_id"));
  assert(sql.includes("NULL::uuid AS syllabus_topic_id"));
  assert(sql.includes("NULL::text AS learning_outcome"));
  assert(sql.includes("NULL::text AS competency"));
  assert(sql.includes("NULL::uuid AS question_family_id"));
});

Deno.test("M1.4 unions own + adopted, and only ACTIVE platform rows (recall drops out)", () => {
  assert(sql.includes("UNION ALL"));
  assert(sql.includes("FROM edu_question_bank_items"));
  assert(sql.includes("FROM edu_school_adopted_items"));
  assert(sql.includes("JOIN edu_platform_question_bank"));
  assert(
    /p\.id = a\.platform_item_id\s*\n?\s*AND p\.status = 'active'/.test(sql),
    "platform side must join adopted items and filter status='active'",
  );
});

Deno.test("M1.4 grants read-only SELECT to erp_tenant (never written)", () => {
  assert(sql.includes("GRANT SELECT ON edu_bank_items_union TO erp_tenant"));
  assert(!/GRANT[^;]*(INSERT|UPDATE|DELETE)[^;]*ON edu_bank_items_union\b/i.test(sql));
});

Deno.test("M1.4 is dormant: zero data seed, no destructive statements", () => {
  assert(!/\bINSERT\s+INTO\b/i.test(code));
  assert(!/\bDROP\s+VIEW\b/i.test(code));
  assert(!/\bDROP\s+TABLE\b/i.test(code));
  assert(!/\bTRUNCATE\b/i.test(code));
  assert(!/\bDELETE\s+FROM\b/i.test(code));
});

Deno.test("M1.4 migration file exists in the migrations directory", async () => {
  const names: string[] = [];
  for await (const entry of Deno.readDir(MIGRATIONS_DIR)) {
    if (entry.name.endsWith(".sql")) names.push(entry.name);
  }
  assert(names.includes("20260920000230_edu_bank_union_view.sql"));
});
